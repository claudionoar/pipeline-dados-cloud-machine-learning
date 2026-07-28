# airflow/ — Orquestração (Airflow, LocalExecutor via docker-compose)

A imagem (`Dockerfile`) estende `apache/airflow:2.9.3-python3.11` com as dependências de
`requirements.txt` (boto3, pandas, scikit-learn, snowflake-connector-python, kaggle) e cria um
virtualenv isolado em `/home/airflow/dbt_venv` só para o dbt (evita conflito de dependências
entre `dbt-snowflake` e o `apache-airflow` core).

O `docker-compose.yml` da raiz do projeto monta:
- todo o repositório em `/opt/airflow/project` (para as tasks chamarem `s3/`, `snowflake/`,
  `dbt/` e `machine-learning/` como scripts comuns, sem duplicar código);
- `airflow/dags/` como a pasta de DAGs do Airflow.

## DAG

`dags/amazon_pipeline_dag.py` (`dag_id=amazon_pipeline`) — ver o docstring do arquivo para o
fluxo completo. Disparo manual (schedule=None); rode via UI (http://localhost:8080, ver
credenciais no `.env`) ou:

```bash
docker compose exec airflow-webserver airflow dags trigger amazon_pipeline
docker compose exec airflow-webserver airflow dags list-runs -d amazon_pipeline
```

## Rodando uma task isoladamente (debug)

```bash
docker compose exec airflow-webserver airflow tasks test amazon_pipeline process_data 2026-01-01
```
