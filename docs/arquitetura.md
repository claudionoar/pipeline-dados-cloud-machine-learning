# Arquitetura

## 1. Arquitetura implementada (híbrida: Docker local + AWS real + Snowflake SaaS)

```mermaid
flowchart LR
    subgraph Kaggle["Kaggle (fonte externa)"]
        K1[amazon-sales-dataset]
        K2[amazon-product-reviews-dataset]
    end

    subgraph Docker["docker-compose (local)"]
        AF[Airflow\nwebserver + scheduler]
        DBT[dbt CLI\n(venv isolado na imagem do Airflow)]
        MB[Metabase]
        MBDB[(Postgres\nmetabase-db)]
        AFDB[(Postgres\nairflow-postgres)]
    end

    subgraph AWS["AWS (conta real)"]
        S3B[("S3\nbronze / silver / gold")]
    end

    subgraph SF["Snowflake (SaaS, conta trial)"]
        RAW[(RAW.SALES\nRAW.REVIEWS\nRAW.ML_PREDICTIONS)]
        AN[(ANALYTICS\nstaging / dim / fact / marts)]
    end

    K1 --> |download manual /\nkaggle API| RAWDATA[data/raw/]
    K2 --> RAWDATA
    RAWDATA --> |s3/processing.py| SILVER[data/processed/]
    RAWDATA --> |upload bronze| S3B
    SILVER --> |upload silver| S3B
    S3B --> |COPY INTO\nvia storage integration| RAW
    RAW --> |dbt run| AN
    AN --> |ml_feature_table| ML[machine-learning/\nhard-code + sklearn]
    ML --> |predictions.csv| S3B
    S3B --> |COPY INTO| RAW
    AN --> |mart_sentiment_kpis\nmart_ml_results| MB
    AF -. orquestra todas as etapas .-> S3B
    AF -. orquestra .-> RAW
    AF -. orquestra .-> DBT
    AF -. orquestra .-> ML
```

## 2. Arquitetura 100% AWS equivalente (item 4.5 do enunciado)

Substituições: Snowflake → Redshift Serverless · Airflow (Docker) → MWAA · pandas → AWS Glue ·
Metabase → QuickSight · SageMaker para treino/hospedagem do modelo. Template CloudFormation
correspondente em `cloudformation/template.yaml` (S3, Glue e IAM sempre criados; Redshift e
SageMaker atrás de parâmetros opcionais; MWAA/QuickSight só documentados aqui — motivo em
`cloudformation/README.md`).

```mermaid
flowchart LR
    S3[("Amazon S3\nbronze / silver / gold")]
    GLUECRAWL[AWS Glue Crawler\n+ Data Catalog]
    GLUEJOB[AWS Glue Job\n(ETL PySpark,\nequivalente a\ns3/processing.py)]
    REDSHIFT[(Amazon Redshift\nServerless)]
    DBTR[dbt (dbt-redshift)\nstaging / dim / fact / marts]
    SAGEMAKER[Amazon SageMaker\nNotebook / Training Job\n(Naive Bayes hard-code + sklearn)]
    MWAA[Amazon MWAA\n(orquestra todo o fluxo)]
    QS[Amazon QuickSight\ndashboard]
    CW[Amazon CloudWatch\nlogs e métricas]

    S3 --> GLUECRAWL --> GLUEJOB
    GLUEJOB --> S3
    S3 --> REDSHIFT
    REDSHIFT --> DBTR --> REDSHIFT
    REDSHIFT --> SAGEMAKER
    SAGEMAKER --> S3
    S3 --> REDSHIFT
    REDSHIFT --> QS
    MWAA -. orquestra .-> GLUEJOB
    MWAA -. orquestra .-> DBTR
    MWAA -. orquestra .-> SAGEMAKER
    GLUEJOB -. logs .-> CW
    MWAA -. logs .-> CW
```

## Organização de dados em nuvem

Ver `s3/README.md` para a estrutura de camadas (bronze/silver/gold) e `docs/dicionario_dados.md`
para o esquema de cada tabela/arquivo.

## Segurança básica

- Bucket S3 privado (Block Public Access), versionado e criptografado (SSE-S3).
- Snowflake acessa o S3 via **Storage Integration** (IAM Role com trust policy restrita à
  conta Snowflake) em vez de chaves de acesso estáticas.
- Credenciais (AWS, Snowflake, Kaggle) só existem em `.env` (fora do controle de versão) e
  como variáveis de ambiente dentro dos containers.
- No template 100% AWS, os serviços (Glue, SageMaker) usam IAM Roles com permissão mínima
  (apenas leitura/escrita no bucket do projeto).
