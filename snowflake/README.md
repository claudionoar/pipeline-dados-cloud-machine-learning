# snowflake/ — Base analítica

Scripts SQL para provisionar a base analítica no Snowflake (conta trial —
https://signup.snowflake.com/) e o script Python que os executa a partir do Airflow.

## Ordem de execução

| Arquivo | O que faz |
|---|---|
| `sql/00_setup_warehouse_db.sql` | Cria warehouse, database `AMAZON_PIPELINE` e schemas `RAW`, `ANALYTICS` (usado pelo dbt). |
| `sql/01_create_stage.sql` | Cria a **storage integration** (IAM Role, sem chaves estáticas) e o **stage** externo apontando para `s3://<bucket>/silver/`. |
| `sql/02_create_raw_tables.sql` | Cria `RAW.SALES`, `RAW.REVIEWS`, `RAW.ML_PREDICTIONS` no esquema canônico produzido por `s3/processing.py`. |
| `sql/03_copy_into.sql` | `COPY INTO` dos CSVs em `silver/sales/` e `silver/reviews/` para as tabelas raw. |
| `sql/05_copy_predictions.sql` | `COPY INTO` das predições geradas pelo módulo `machine-learning/` (roda depois do treino). |

`sql/04_grants.sql` garante que o role usado pelo dbt tenha permissão nos schemas.

## Storage integration (passo manual único, fora do SQL)

O `CREATE STORAGE INTEGRATION` (arquivo `01_create_stage.sql`) precisa que, depois de rodar
`DESC INTEGRATION s3_amazon_pipeline_int;`, você copie o `STORAGE_AWS_IAM_USER_ARN` e o
`STORAGE_AWS_EXTERNAL_ID` gerados pelo Snowflake para o **Trust Policy** de uma IAM Role na sua
conta AWS (documentado passo a passo em
https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration). Isso evita
usar `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` estáticas dentro do Snowflake — só o
Airflow/scripts locais usam essas chaves para o boto3.

## Executando via Python (o que o Airflow chama)

```bash
cd snowflake
pip install -r ../airflow/requirements.txt   # snowflake-connector-python já incluso
python load_to_snowflake.py --steps setup,stage,tables,copy
```

O script `load_to_snowflake.py` lê cada `.sql`, substitui os placeholders (`${AWS_S3_BUCKET}`,
`${SNOWFLAKE_STORAGE_INTEGRATION}` etc.) pelas variáveis de ambiente do `.env` e executa os
statements via `snowflake-connector-python`.

## Modelo de dados (schema RAW)

```
RAW.SALES            -- 1 linha por produto (catálogo)
RAW.REVIEWS          -- 1 linha por review de texto (rótulo de sentimento derivado do rating)
RAW.ML_PREDICTIONS   -- 1 linha por review avaliada pelos modelos hard-code e sklearn
```

O schema `ANALYTICS` é onde o dbt materializa staging/dimensions/facts/marts (ver `dbt/`).
