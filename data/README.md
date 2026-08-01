# data/

```
data/
├── raw/          # 9 CSVs originais do dataset Olist + tradução de categoria (versionado)
└── processed/    # CSVs tipados/normalizados por s3/processing.py antes do upload ("silver", não versionado)
```

## Dataset: Olist Brazilian E-Commerce

`data/raw/` já contém os arquivos do dataset
[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(marketplace real brasileiro, ~100 mil pedidos entre 2016 e 2018) — não é necessário baixar
nada do Kaggle:

| Arquivo | Grão | Papel no pipeline |
|---|---|---|
| `olist_orders_dataset.csv` | 1 linha por pedido | Base de `stg_orders`/`fact_orders` (datas de compra/aprovação/entrega). |
| `olist_order_items_dataset.csv` | 1 linha por item de pedido | Base de `fact_order_items` (preço, frete, produto, vendedor). |
| `olist_order_payments_dataset.csv` | 1 linha por pagamento | Base de `fact_payments`. |
| `olist_order_reviews_dataset.csv` | 1 linha por review | Texto (`review_comment_message`, ~41% preenchido) + `review_score` → `fact_reviews`. |
| `olist_customers_dataset.csv` | 1 linha por customer_id (por pedido) | Base de `dim_customers`. |
| `olist_sellers_dataset.csv` | 1 linha por vendedor | Base de `dim_sellers`. |
| `olist_products_dataset.csv` | 1 linha por produto | Base de `dim_products` (peso/dimensões usados como feature de ML). |
| `olist_geolocation_dataset.csv` | várias linhas por CEP | Agregada em `dim_geolocation` (lat/lng médios), usada para calcular distância cliente-vendedor. |
| `product_category_name_translation.csv` | 1 linha por categoria | Tradução pt→en, usada em `dim_products`. |

`data/raw/*.csv` é versionado no git (arquivos já fazem parte do repositório) — diferente do
projeto anterior (Amazon), não há mais download via Kaggle API nem detecção automática de
qual CSV é qual: `s3/processing.py` lê cada arquivo pelo nome exato acima.

## Testar o ML sem a base carregada no Snowflake

`machine-learning/train_and_compare.py --source sample` gera features sintéticas com sinal
realista (correlação entre distância/frete/prazo e atraso) em memória, sem precisar de
credenciais Snowflake nem rodar o resto do pipeline. Útil para validar rapidamente o código
dos dois modelos (hard-code e sklearn).
