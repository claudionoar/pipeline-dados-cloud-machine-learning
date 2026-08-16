"""DAG do pipeline ELT: S3 (bronze/silver) -> Snowflake (RAW) -> dbt (staging/marts) ->
treino/comparação de ML -> predições de volta para S3/Snowflake (rastreabilidade completa).

Requisito mínimo do enunciado (4.4): "DAG funcional no Airflow" + "pipeline deve permitir
reproduzir as principais etapas de preparação e transformação dos dados".

Todas as tasks chamam os mesmos scripts que podem ser rodados manualmente (ver READMEs de
aws/s3/, snowflake/, dbt/ e machine-learning/) - o DAG só orquestra a ordem e as dependências.

Pré-requisito de infraestrutura (rodado uma única vez, fora deste DAG): o bucket S3 é
provisionado via Terraform em Docker (`aws/terraform/README.md`) e a base Snowflake via
`snowflake/load_to_snowflake.py --steps setup,stage,tables` (`snowflake/README.md`).
"""
from __future__ import annotations

import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

PROJECT_DIR = "/opt/airflow/project"
DBT_PROJECT_DIR = f"{PROJECT_DIR}/dbt/olist_pipeline"
DBT_DOCS_DIR = f"{PROJECT_DIR}/dbt/olist_pipeline/docs"
DBT_BIN = "/home/airflow/dbt_venv/bin/dbt"

# Se PIPELINE_USE_SAMPLE_DATA=true (definido no .env), o treino do ML usa dados sintéticos em
# vez de exigir a tabela mart_late_delivery_features no Snowflake - útil para validar o DAG de
# ponta a ponta sem credenciais. O processamento dos 10 CSVs brutos do Olist (data/raw/) não
# tem fallback sintético, pois os arquivos reais já fazem parte do repositório.
ML_SOURCE = '$( [ "${PIPELINE_USE_SAMPLE_DATA:-false}" = "true" ] && echo sample || echo snowflake )'

default_args = {
    "owner": "olist_pipeline",
    "retries": 1,
    "retry_delay": datetime.timedelta(minutes=2),
}

with DAG(
    dag_id="olist_pipeline",
    description="S3 -> Snowflake -> dbt -> ML (previsao de atraso na entrega) -> dashboard",
    default_args=default_args,
    schedule=None,
    start_date=datetime.datetime(2026, 1, 1),
    catchup=False,
    tags=["projeto-final", "s3", "snowflake", "dbt", "ml", "olist"],
) as dag:
    dag.doc_md = __doc__

    # O bucket em si é provisionado via Terraform (rodado em Docker, fora do DAG - ver
    # aws/terraform/README.md), como um passo único de infraestrutura. Esta task só confirma
    # que o bucket existe e está acessível com as credenciais do .env, falhando rápido e com
    # mensagem clara caso alguém dispare o DAG antes do "terraform apply".
    check_s3_bucket = BashOperator(
        task_id="check_s3_bucket",
        bash_command=f"python {PROJECT_DIR}/aws/s3/check_bucket.py"
    )

    # Lê os 10 CSVs brutos do Olist (`data/raw/`) e gera as camadas bronze (cópia bruta) e silver (limpeza/tipagem/joins) 
    # localmente, prontas para envio ao S3.
    process_data = BashOperator(
        task_id="process_data",
        bash_command=f"python {PROJECT_DIR}/aws/s3/processing.py"        
    )

    # Envia a camada bronze (dados brutos) gerada por `process_data` para o S3
    upload_bronze = BashOperator(
        task_id="upload_bronze_to_s3",
        bash_command=f"python {PROJECT_DIR}/aws/s3/upload_to_s3.py --layer bronze"
    )

    # Envia a camada silver (dados limpos/tratados) gerada por `process_data` para o S3.",
    upload_silver = BashOperator(
        task_id="upload_silver_to_s3",
        bash_command=f"python {PROJECT_DIR}/aws/s3/upload_to_s3.py --layer silver"        
    )

    # "grants" fica de fora por padrão: só é necessário quando a role que carrega os dados é
    # diferente da role usada pelo dbt/consumidores. Aqui é a mesma role (mesmas credenciais do
    # .env) - ela já é dona dos objetos que cria, não precisa se auto-conceder nada. Em contas
    # de laboratório/classroom (ex.: role sem MANAGE GRANTS), rodar "grants" falha - ver
    # snowflake/README.md.
    # Cria o warehouse/database/stage/tabelas RAW no Snowflake (se ainda não 
    # existirem) e carrega os arquivos da camada silver do S3 via `COPY INTO`.
    load_snowflake_raw = BashOperator(
        task_id="load_snowflake_raw",
        bash_command=(
            f"python {PROJECT_DIR}/snowflake/load_to_snowflake.py "
            "--steps setup,stage,tables,copy"
        )        
    )

    # Instala os pacotes dbt declarados em `packages.yml` (ex.: dbt_utils) antes da compilação/execução dos modelos
    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"{DBT_BIN} deps --project-dir {DBT_PROJECT_DIR}"        
    )

    # Materializa os modelos dbt (staging -> dimensões/fatos -> marts) a partir das tabelas RAW no Snowflake.               
    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"{DBT_BIN} run --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}"        
    )

    # Roda os testes de qualidade de dados do dbt (not_null, unique, accepted_values, relationships) sobre os modelos materializados               
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"{DBT_BIN} test --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}"        
    )

    # Gera o site estático de documentação do dbt (linhagem, descrições de modelos/colunas,
    # testes) e exporta os artefatos (index.html, catalog.json, manifest.json) para
    # dbt/docs/ - fora do target/ (gitignored) para ficar disponível como evidência/entrega.
    dbt_docs_generate = BashOperator(
        task_id="dbt_docs_generate",
        bash_command=(
            f"{DBT_BIN} docs generate --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR} "
            f"&& mkdir -p {DBT_DOCS_DIR} "
            f"&& cp {DBT_PROJECT_DIR}/target/index.html {DBT_PROJECT_DIR}/target/catalog.json "
            f"{DBT_PROJECT_DIR}/target/manifest.json {DBT_DOCS_DIR}/"
        ),
    )

    # Treina e compara os modelos de previsão de atraso na entrega (regressão logística implementada do zero em numpy vs. scikit-learn)
    # sobre os dados do mart `mart_late_delivery_features` (ou dados sintéticos, se 
    # "`PIPELINE_USE_SAMPLE_DATA=true`), e grava as predições/métricas em `machine-learning/output/`.",               
    train_ml_models = BashOperator(
        task_id="train_ml_models",
        bash_command=(
            f"cd {PROJECT_DIR}/machine-learning && python train_and_compare.py --source {ML_SOURCE}"
        )
    )

    # Envia `predictions.csv` (predições do conjunto de teste, hard-code vs. 
    # sklearn) gerado por `train_ml_models` para o S3, para rastreabilidade.
    upload_predictions = BashOperator(
        task_id="upload_predictions_to_s3",
        bash_command=(
            f"python {PROJECT_DIR}/aws/s3/upload_to_s3.py --layer predictions "
            f"--file {PROJECT_DIR}/machine-learning/output/predictions.csv"
        )
    )

    # Carrega `predictions.csv` do S3 para a tabela RAW de predições no Snowflake via `COPY INTO`.",
    load_predictions_snowflake = BashOperator(
        task_id="load_predictions_snowflake",
        bash_command=f"python {PROJECT_DIR}/snowflake/load_to_snowflake.py --steps copy_predictions"
    )

    
    # Materializa `stg_ml_predictions` e `mart_ml_results` (predições + estado do 
    # cliente + flags de acerto por modelo) para alimentar os cards de ML do dashboard Metabase.
    dbt_run_ml_results = BashOperator(
        task_id="dbt_run_ml_results_mart",
        bash_command=(
            f"{DBT_BIN} run --select stg_ml_predictions mart_ml_results "
            f"--project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROJECT_DIR}"
        )
    )

    # ordem das tarefas
    check_s3_bucket >> [upload_bronze, process_data]
    process_data >> upload_silver
    [upload_bronze, upload_silver] >> load_snowflake_raw
    load_snowflake_raw >> dbt_deps >> dbt_run >> dbt_test >> [train_ml_models, dbt_docs_generate]
    train_ml_models >> upload_predictions >> load_predictions_snowflake >> dbt_run_ml_results
