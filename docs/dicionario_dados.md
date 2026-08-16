# Dicionário de dados

## Fonte bruta (camada bronze): Olist Brazilian E-Commerce

- **Origem**: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- **Formato**: 9 CSVs relacionais + 1 tabela de tradução de categoria, ~100 mil pedidos reais
  de um marketplace brasileiro (2016-2018), já colocados em `data/raw/`.

| Arquivo | Grão | Colunas principais |
|---|---|---|
| `olist_orders_dataset.csv` | 1 linha por pedido | `order_id`, `customer_id`, `order_status`, `order_purchase_timestamp`, `order_approved_at`, `order_delivered_carrier_date`, `order_delivered_customer_date`, `order_estimated_delivery_date` |
| `olist_order_items_dataset.csv` | 1 linha por item de pedido | `order_id`, `order_item_id`, `product_id`, `seller_id`, `shipping_limit_date`, `price`, `freight_value` |
| `olist_order_payments_dataset.csv` | 1 linha por pagamento | `order_id`, `payment_sequential`, `payment_type`, `payment_installments`, `payment_value` |
| `olist_order_reviews_dataset.csv` | 1 linha por review | `review_id`, `order_id`, `review_score` (1-5), `review_comment_title`, `review_comment_message`, `review_creation_date`, `review_answer_timestamp` |
| `olist_customers_dataset.csv` | 1 linha por customer_id (por pedido) | `customer_id`, `customer_unique_id`, `customer_zip_code_prefix`, `customer_city`, `customer_state` |
| `olist_sellers_dataset.csv` | 1 linha por vendedor | `seller_id`, `seller_zip_code_prefix`, `seller_city`, `seller_state` |
| `olist_products_dataset.csv` | 1 linha por produto | `product_id`, `product_category_name` (pt), `product_weight_g`, `product_length_cm`, `product_height_cm`, `product_width_cm`, `product_photos_qty` |
| `olist_geolocation_dataset.csv` | várias linhas por CEP | `geolocation_zip_code_prefix`, `geolocation_lat`, `geolocation_lng`, `geolocation_city`, `geolocation_state` |
| `product_category_name_translation.csv` | 1 linha por categoria | `product_category_name`, `product_category_name_english` |

### Limitações importantes

- `review_comment_message` está **vazio em ~59% das linhas** (41% têm texto) — usado só nos
  KPIs de sentimento do dashboard (`mart_sentiment_kpis`), não como fonte do modelo de ML
  principal (que usa features estruturadas do pedido, não texto).
- `olist_geolocation_dataset.csv` tem várias linhas por prefixo de CEP (coordenadas de
  usuários distintos que digitaram o mesmo CEP) e cobertura incompleta — nem todo
  `customer_zip_code_prefix`/`seller_zip_code_prefix` tem uma linha correspondente, gerando
  `distance_km` nulo nesses casos (documentado em `dim_geolocation`/`mart_late_delivery_features`).
- `order_status` tem 8 valores possíveis (`delivered`, `shipped`, `canceled`, `unavailable`,
  `invoiced`, `processing`, `created`, `approved`) — a feature de atraso na entrega só é
  calculada para pedidos `delivered` com as duas datas (entregue/estimada) presentes (~97 mil
  de ~99 mil pedidos).
- `customer_id` é por pedido, não por pessoa — para identificar o mesmo cliente entre pedidos
  diferentes, usa-se `customer_unique_id`.
- `review_id` **não é uma chave primária isolada**: ~0,8% dos valores (789 de 99.224) se
  repetem em `order_id` diferentes (limitação real da fonte, confirmada nos dados carregados).
  O grão real de `stg_order_reviews`/`fact_reviews` é `review_id + order_id` — os testes dbt e
  a surrogate key (`review_key`) usam essa combinação, não só `review_id`.

## Esquema canônico (camada silver, saída de `aws/s3/processing.py`)

Uma tabela por arquivo de origem, com o mesmo grão, apenas tipada (datas parseadas, CEPs como
string para preservar zeros à esquerda, numéricos coercidos) — sem joins/agregações, que ficam
a cargo do dbt. Ver `snowflake/sql/02_create_raw_tables.sql` para o schema exato de cada
`RAW.*` correspondente.

## Tabela final de features de ML: `mart_late_delivery_features` (dbt) → `ANALYTICS`

Grão: `order_id` (só pedidos `delivered` com data de entrega e data estimada presentes).

| Coluna | Tipo | Observação |
|---|---|---|
| `order_id` | string | chave primária |
| `is_late` | boolean | **alvo**: `order_delivered_customer_date > order_estimated_delivery_date` |
| `total_price`, `total_freight` | float | soma dos itens do pedido |
| `item_count` | int | número de itens |
| `avg_product_weight_g`, `avg_product_volume_cm3` | float | média dos produtos do pedido |
| `payment_installments_max`, `payment_value_total` | int/float | agregado dos pagamentos |
| `approval_delay_hours` | float | horas entre compra e aprovação do pagamento |
| `estimated_delivery_days` | int | dias prometidos ao cliente |
| `purchase_dow`, `purchase_month` | int | sazonalidade |
| `distance_km` | float | distância (haversine) entre cliente e vendedor "primário" do pedido |
| `same_state_flag` | 0/1 | cliente e vendedor no mesmo estado |
| `customer_state`, `seller_state` | string | usados nos KPIs do dashboard, não no modelo |

### `predictions.csv` (saída de `machine-learning/`) → `RAW.ML_PREDICTIONS`

| Coluna | Tipo | Observação |
|---|---|---|
| `order_id` | string | referência ao pedido avaliado (conjunto de teste) |
| `true_label` | string | `on_time` / `late` |
| `predicted_label_hardcode` | string | predição da regressão logística implementada do zero |
| `predicted_label_sklearn` | string | predição da regressão logística via scikit-learn |
| `model_version`, `predicted_at` | string/timestamp | rastreabilidade |
