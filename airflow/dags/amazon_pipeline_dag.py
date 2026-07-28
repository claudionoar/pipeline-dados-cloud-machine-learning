"""DAG do pipeline ELT: S3 (bronze/silver) -> Snowflake (RAW) -> dbt (staging/marts) ->
treino/comparação de ML -> predições de volta para S3/Snowflake (rastreabilidade completa).

Requisito mínimo do enunciado (4.4): "DAG funcional no Airflow" + "pipeline deve permitir
reproduzir as principais etapas de preparação e transformação dos dados".

Todas as tasks chamam os mesmos scripts que podem ser rodados manualmente (ver READMEs de
s3/, snowflake/, dbt/ e machine-learning/) - o DAG só orquestra a ordem e as dependências.

Pré-requisito de infraestrutura (rodado uma única vez, fora deste DAG): o bucket S3 é
provisionado via Terraform em Docker (`terraform/README.md`) e a base Snowflake via
`snowflake/load_to_snowflake.py --steps setup,stage,tables,grants` (`snowflake/README.md`).
"""
from __future__ import annotations

import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

PROJECT_DIR = "/opt/airflow/project"
DBT_PROJECT_DIR = f"{PROJECT_DIR}/dbt/amazon_pipeline"
DBT_BIN = "/home/airflow/dbt_venv/bin/dbt"

# Se PIPELINE_USE_SAMPLE_DATA=true (definido no .env), o processamento usa dados sintéticos
# em vez de exigir os CSVs reais do Kaggle em data/raw/ - útil para validar o DAG de ponta a
# ponta antes do download real (ver data/README.md).
SAMPLE_FLAG = '$( [ "${PIPELINE_USE_SAMPLE_DATA:-false}" = "true" ] && echo --sample-fallback )'
ML_SOURCE = '$( [ "${PIPELINE_USE_SAMPLE_DATA:-false}" = "true" ] && echo sample || echo snowflake )'

default_args = {
    "owner": "amazon_pipeline",
    "retries": 1,
    "retry_delay": datetime.timedelta(minutes=2),
}

with DAG(
    dag_id="amazon_pipeline",
    description="S3 -> Snowflake -> dbt -> ML (classificacao de sentimento) -> dashboard",
    default_args=default_args,
    schedule=None,
    start_date=datetime.datetime(2026, 1, 1),
    catchup=False,
    tags=["projeto-final", "s3", "snowflake", "dbt", "ml"],
) as dag:

    # O bucket em si é provisionado via Terraform (rodado em Docker, fora do DAG - ver
    # terraform/README.md), como um passo único de infraestrutura. Esta task só falha rápido
    # e com uma mensagem clara caso alguém dispare o DAG antes do "terraform apply".
    check_s3_bucket = BashOperator(
        task_id="check_s3_bucket",
        bash_command=f"python {PROJECT_DIR}/s3/check_bucket.py",
    )

    process_data = BashOperator(
        task_id="process_data",
        bash_command=f"python {PROJECT_DIR}/s3/processing.py {SAMPLE_FLAG}",
    )

    upload_bronze = BashOperator(
        task_id="upload_bronze_to_s3",
        bash_command=f"python {PROJECT_DIR}/s3/upload_to_s3.py --layer bronze",
    )

    upload_silver = BashOperator(
        task_id="upload_silver_to_s3",
        bash_command=f"python {PROJECT_DIR}/s3/upload_to_s3.py --layer silver",
    )

    load_snowflake_raw = BashOperator(
        task_id="load_snowflake_raw",
        bash_command=(
            f"python {PROJECT_DIR}/snowflake/load_to_snowflake.py "
            "--steps setup,stage,tables,grants,copy"
        ),
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"{DBT_BIN} run --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"{DBT_BIN} test --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}",
    )

    train_ml_models = BashOperator(
        task_id="train_ml_models",
        bash_command=(
            f"cd {PROJECT_DIR}/machine-learning && python train_and_compare.py --source {ML_SOURCE}"
        ),
    )

    upload_predictions = BashOperator(
        task_id="upload_predictions_to_s3",
        bash_command=(
            f"python {PROJECT_DIR}/s3/upload_to_s3.py --layer predictions "
            f"--file {PROJECT_DIR}/machine-learning/output/predictions.csv"
        ),
    )

    load_predictions_snowflake = BashOperator(
        task_id="load_predictions_snowflake",
        bash_command=f"python {PROJECT_DIR}/snowflake/load_to_snowflake.py --steps copy_predictions",
    )

    dbt_run_ml_results = BashOperator(
        task_id="dbt_run_ml_results_mart",
        bash_command=(
            f"{DBT_BIN} run --select stg_ml_predictions mart_ml_results "
            f"--project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}"
        ),
    )

    check_s3_bucket >> [upload_bronze, process_data]
    process_data >> upload_silver
    [upload_bronze, upload_silver] >> load_snowflake_raw
    load_snowflake_raw >> dbt_run >> dbt_test >> train_ml_models
    train_ml_models >> upload_predictions >> load_predictions_snowflake >> dbt_run_ml_results
