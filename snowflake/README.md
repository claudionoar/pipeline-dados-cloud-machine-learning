# snowflake/ — Base analítica

Scripts SQL para provisionar a base analítica no Snowflake (conta trial —
https://signup.snowflake.com/) e o script Python que os executa a partir do Airflow.

## Ordem de execução

| Arquivo | O que faz |
|---|---|
| `sql/00_setup_warehouse_db.sql` | Cria warehouse, database `AMAZON_PIPELINE` e schemas `RAW`, `ANALYTICS` (usado pelo dbt). |
| `sql/01_create_stage.sql` | Cria o **stage** externo apontando para `s3://<bucket>/silver/`, usando as credenciais AWS diretamente (ver seção abaixo). |
| `sql/02_create_raw_tables.sql` | Cria `RAW.SALES`, `RAW.REVIEWS`, `RAW.ML_PREDICTIONS` no esquema canônico produzido por `s3/processing.py`. |
| `sql/03_copy_into.sql` | `COPY INTO` dos CSVs em `silver/sales/` e `silver/reviews/` para as tabelas raw. |
| `sql/05_copy_predictions.sql` | `COPY INTO` das predições geradas pelo módulo `machine-learning/` (roda depois do treino). |

`sql/04_grants.sql` é **opcional** e não roda por padrão (nem no DAG, nem no comando abaixo):
só é necessário se a role que carrega os dados for **diferente** da role usada pelo dbt/
Metabase. No caso comum (mesma role para tudo, mesmas credenciais do `.env`), ela já é dona
dos objetos que cria e não precisa de grant nenhum. Em contas de laboratório/classroom
(ex.: Snowflake fornecido por professor, role tipo `TRAINING_ROLE`), rodar `grants` costuma
falhar com `Insufficient privileges ... must have MANAGE GRANTS granted on ACCOUNT` — nesse
caso, não rode esse step.

## Autenticação do stage (S3)

O jeito "certo" segundo a Snowflake é criar uma **Storage Integration** (o Snowflake assume
uma IAM Role na sua conta AWS via `sts:AssumeRole`, sem nenhuma chave estática). Isso exige
permissão para criar IAM Role/Policy na conta AWS (`iam:CreateRole`) — permissão que contas de
laboratório (ex.: **AWS Academy Learner Lab**) bloqueiam para o aluno.

Por isso `01_create_stage.sql` usa o caminho alternativo, também oficialmente suportado pela
Snowflake: `CREATE STAGE ... CREDENTIALS = (AWS_KEY_ID=... AWS_SECRET_KEY=... AWS_TOKEN=...)`,
reaproveitando as mesmas `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN` do
`.env`. Trade-off: se as credenciais forem temporárias (sessão de laboratório), elas **expiram**
em algumas horas — quando isso acontecer, atualize o `.env` com uma sessão nova e rode de novo
`python load_to_snowflake.py --steps stage` (o `CREATE OR REPLACE STAGE` recria com as
credenciais atualizadas). Documentado como limitação operacional em `docs/arquitetura.md`.

Se sua conta AWS permitir criar IAM Roles (conta pessoal, não é lab restrito), dá para voltar
para o modelo de Storage Integration — o SQL original fica comentado no histórico do arquivo;
os passos são: `CREATE STORAGE INTEGRATION` → `DESC INTEGRATION` → copiar
`STORAGE_AWS_IAM_USER_ARN`/`STORAGE_AWS_EXTERNAL_ID` para o trust policy de uma IAM Role →
`CREATE STAGE ... STORAGE_INTEGRATION = ...` (ver
https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration).

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
