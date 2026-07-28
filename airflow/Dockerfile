FROM apache/airflow:2.9.3-python3.11

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER airflow

# Dependências usadas pelas tasks Python do DAG (s3/, snowflake/, machine-learning/)
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# dbt roda em um virtualenv isolado: seus pacotes (jinja2/click/etc.) frequentemente colidem
# com as versões fixadas pelo constraints file do Airflow se instalados no mesmo ambiente.
RUN python -m venv /home/airflow/dbt_venv \
    && /home/airflow/dbt_venv/bin/pip install --no-cache-dir "dbt-snowflake>=1.8,<1.9"

ENV DBT_VENV=/home/airflow/dbt_venv
