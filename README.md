# Pipeline de Dados em Nuvem para ML — Amazon Sales & Reviews

Projeto final integrado (IFG — Pós-graduação em IA Aplicada, Módulo 2). Pipeline completo:
ingestão em S3 → transformação → carga no Snowflake → modelagem dbt → classificação de
sentimento (hard-code + scikit-learn) → dashboard Metabase, orquestrado pelo Airflow via
Docker/docker-compose. Enunciado completo em `Cronograma Projeto Trabalho.md`.

## Problema

Classificação de sentimento de reviews de produtos Amazon (positive/neutral/negative), para
apoiar um gestor de categoria a priorizar produtos com reputação em queda. Detalhes em
[`docs/problema.md`](docs/problema.md).


## Arquitetura

```
Kaggle (CSV) --> data/raw/ --> s3/processing.py --> data/processed/ --> S3 (bronze/silver)
   --> Snowflake RAW (COPY INTO) --> dbt (staging/dim/fact/marts) --> ANALYTICS
   --> machine-learning/ (hard-code NB + sklearn NB) --> predictions --> S3/Snowflake
   --> ANALYTICS.mart_ml_results / mart_sentiment_kpis --> Metabase (dashboard)
```

Diagramas completos (implementação híbrida + arquitetura 100% AWS equivalente) em
[`docs/arquitetura.md`](docs/arquitetura.md). Tudo orquestrado pelo Airflow
(`airflow/dags/amazon_pipeline_dag.py`).

## Estrutura do repositório

```
terraform/        provisionamento do bucket S3 (Terraform, rodado via Docker)
s3/               scripts de ingestão/normalização/upload (boto3 + pandas)
snowflake/        SQL de setup (warehouse/db/stage) + runner Python
dbt/              projeto dbt (staging, dimensions, facts, ml, dashboard marts + testes)
airflow/          Dockerfile da imagem custom + DAG do pipeline
machine-learning/ classificação de sentimento: baseline, hard-code (numpy) e sklearn
dashboard/        setup e cards do dashboard Metabase
cloudformation/   template.yaml da arquitetura 100% AWS equivalente + custos
docs/             arquitetura, dicionário de dados, definição do problema, avaliação
data/             cache local de dados (não versionado) — ver data/README.md
docker-compose.yml orquestra Airflow (LocalExecutor) + Metabase
```

## Quickstart

Pré-requisitos: apenas **Docker** e **Docker Compose** (nada mais é instalado na máquina).

### 1. Configurar credenciais

```bash
cp .env.example .env
# preencha AWS_*, SNOWFLAKE_*, KAGGLE_* no .env
```

- **AWS**: crie um usuário IAM com permissão de `s3:*` no bucket do projeto (free tier).
- **Snowflake**: crie uma conta trial em https://signup.snowflake.com/.
- **Kaggle**: token de API em https://www.kaggle.com/settings.

Sem credenciais reais ainda? Deixe `PIPELINE_USE_SAMPLE_DATA=true` no `.env` — todo o
pipeline roda com dados sintéticos gerados em memória (ver `data/README.md`), exceto as
etapas que exigem S3/Snowflake de fato.

### 2. Baixar os dados (opcional, ver `data/README.md` para rodar com amostra sintética)

```bash
pip install kaggle
kaggle datasets download -d karkavelrajaj/amazon-sales-dataset -p data/raw --unzip
kaggle datasets download -d yasserh/amazon-product-reviews-dataset -p data/raw --unzip
```

### 3. Provisionar o bucket S3 (Terraform, via Docker)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # ajuste bucket_name (mesmo valor de AWS_S3_BUCKET)
./tf.sh init
./tf.sh apply
cd ..
```

Detalhes e alternativa com `docker run` direto em `terraform/README.md`. Só roda uma vez —
igual ao setup do Snowflake abaixo, é infraestrutura, não faz parte do DAG do Airflow.

### 4. Provisionar o Snowflake (uma vez)

```bash
# Storage integration precisa de um passo manual na AWS (trust policy da IAM Role) -
# ver snowflake/README.md antes de rodar "stage".
python snowflake/load_to_snowflake.py --steps setup,stage,tables,grants
```

### 5. Subir o stack

```bash
docker compose up -d --build
```

- Airflow: http://localhost:8080 (usuário/senha em `AIRFLOW_ADMIN_USER`/`AIRFLOW_ADMIN_PASSWORD`)
- Metabase: http://localhost:3000 (setup inicial + conexão Snowflake, ver `dashboard/README.md`)

### 6. Rodar o pipeline

```bash
docker compose exec airflow-webserver airflow dags trigger amazon_pipeline
```

Acompanhe as tasks na UI do Airflow. Ao final, `mart_sentiment_kpis` e `mart_ml_results`
estarão disponíveis no Snowflake para o Metabase.

### Rodando módulos individualmente (fora do Airflow)

Cada pasta (`terraform/`, `s3/`, `snowflake/`, `dbt/`, `machine-learning/`) tem seu próprio README com
instruções para rodar localmente (`pip install -r requirements.txt` + script), útil para
desenvolvimento e debug sem depender do DAG completo.

## Checklist do enunciado

| Item | Onde |
|---|---|
| AWS (S3) | `terraform/` (provisionamento) + `s3/` (ingestão), bucket real (seção 4.5) |
| Snowflake | `snowflake/` |
| dbt (staging/dimensions/facts + testes + docs) | `dbt/` |
| Airflow (DAG funcional) | `airflow/dags/amazon_pipeline_dag.py` |
| Pipeline Airflow → S3 → dbt → Snowflake | DAG `amazon_pipeline` |
| Dataset estruturado + não estruturado | `docs/dicionario_dados.md` |
| Modelagem de dados | `dbt/amazon_pipeline/models/marts/` (star schema) |
| ML hard-code + biblioteca, comparação | `machine-learning/hardcode_naive_bayes.py` + `sklearn_model.py` |
| Template CloudFormation | `cloudformation/template.yaml` |
| Diagrama arquitetural 100% AWS | `docs/arquitetura.md` |
| Dashboard (Metabase) | `dashboard/README.md` |
| Conjunto/critérios de avaliação | `docs/avaliacao.md` |

## Limitações conhecidas

Ver `machine-learning/README.md` e `docs/avaliacao.md` (seção 5.4) para as limitações dos
dados e do modelo, e `cloudformation/README.md` para o que foi deliberadamente deixado de
fora do template 100% AWS (MWAA/QuickSight) e por quê.
