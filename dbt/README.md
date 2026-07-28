# dbt/ — Modelagem analítica (dbt + Snowflake)

Projeto dbt `amazon_pipeline`. Transforma as tabelas `RAW.*` (carregadas via `snowflake/`) em
um modelo dimensional simples no schema `ANALYTICS`.

```
models/
├── staging/                 # 1:1 com as tabelas raw, apenas seleção/renomeação de colunas
│   ├── stg_sales.sql
│   ├── stg_reviews.sql
│   ├── stg_ml_predictions.sql
│   └── _staging.yml         # sources + testes (not_null, unique, accepted_values)
└── marts/
    ├── dimensions/           # dim_product, dim_category
    ├── facts/                 # fact_review (grão: review), fact_sales (grão: produto)
    ├── ml/                     # ml_feature_table -> consumida por machine-learning/
    └── dashboard/              # mart_sentiment_kpis, mart_ml_results -> consumidas pelo Metabase
```

## Rodando localmente

```bash
cd dbt/amazon_pipeline
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
automaticamente pelas tasks `dbt_run` e `dbt_test` do DAG — ver `airflow/dags/amazon_pipeline_dag.py`.

## Testes incluídos (mínimo exigido: 2)

- `not_null` / `unique` em todas as chaves primárias e surrogate keys.
- `accepted_values` em `sentiment_label` e `true_label` (positive/neutral/negative).
- `relationships` de `fact_review.product_key` e `fact_sales.product_key` para `dim_product`.

Total: 10 testes distribuídos entre staging e marts.
