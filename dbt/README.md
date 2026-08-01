# dbt/ — Modelagem analítica (dbt + Snowflake)

Projeto dbt `olist_pipeline`. Transforma as tabelas `RAW.*` (carregadas via `snowflake/`, uma
por arquivo do dataset Olist) em um modelo dimensional no schema `ANALYTICS`.

```
models/
├── staging/                 # 1:1 com as tabelas raw, apenas seleção/renomeação de colunas
│   ├── stg_customers.sql, stg_geolocation.sql, stg_orders.sql, stg_order_items.sql,
│   │   stg_order_payments.sql, stg_order_reviews.sql (deriva sentiment_label),
│   │   stg_products.sql, stg_sellers.sql, stg_category_translation.sql, stg_ml_predictions.sql
│   └── _staging.yml         # sources + testes (not_null, unique, accepted_values)
└── marts/
    ├── dimensions/           # dim_customers, dim_sellers, dim_products, dim_geolocation, dim_date
    ├── facts/                 # fact_orders (grão: pedido, com is_late), fact_order_items,
    │                            fact_payments, fact_reviews
    ├── ml/                     # mart_late_delivery_features -> consumida por machine-learning/
    └── dashboard/              # mart_sentiment_kpis, mart_delivery_kpis, mart_ml_results -> Metabase
```

## Rodando localmente

```bash
cd dbt/olist_pipeline
pip install dbt-snowflake
dbt deps                       # instala dbt_utils (packages.yml)

export DBT_PROFILES_DIR=$(pwd)      # usa o profiles.yml.example (copie para profiles.yml)
cp profiles.yml.example profiles.yml

dbt debug                      # valida a conexão com o Snowflake
dbt run                        # materializa staging (views) + marts (tables)
dbt test                       # roda os testes (schema.yml de cada pasta)
dbt docs generate && dbt docs serve   # documentação navegável dos modelos
```

Dentro do container do Airflow (`airflow/Dockerfile`), `dbt run` e `dbt test` são executados
automaticamente pelas tasks `dbt_run` e `dbt_test` do DAG — ver `airflow/dags/olist_pipeline_dag.py`.

## Testes incluídos (mínimo exigido: 2)

- `not_null` / `unique` em todas as chaves primárias e surrogate keys.
- `accepted_values` em `order_status`, `sentiment_label` e `is_late`.
- `relationships` de `fact_order_items.product_key`/`seller_key`, `fact_orders.customer_key` e
  `fact_reviews.order_key` para as respectivas dimensões/fatos — como `error` (não `warn`):
  diferente do dataset Amazon anterior, o Olist tem chaves estrangeiras reais entre pedidos,
  itens, produtos e vendedores, então uma falha nesse teste indica um bug real no pipeline,
  não uma limitação conhecida do dado.

Total: modelos de staging + marts cobrindo todas as 9 tabelas do dataset.
