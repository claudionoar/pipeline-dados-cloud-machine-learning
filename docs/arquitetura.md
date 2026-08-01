# Arquitetura

## 1. Arquitetura implementada (híbrida: Docker local + AWS real + Snowflake SaaS)

```mermaid
flowchart LR
    subgraph Olist["Dataset Olist (data/raw/, já versionado)"]
        O1[9 CSVs +\ntradução de categoria]
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

    subgraph SF["Snowflake (SaaS)"]
        RAW[(RAW.ORDERS, RAW.ORDER_ITEMS,\nRAW.CUSTOMERS, RAW.PRODUCTS...\nRAW.ML_PREDICTIONS)]
        AN[(ANALYTICS\nstaging / dim / fact / marts)]
    end

    O1 --> RAWDATA[data/raw/]
    RAWDATA --> |s3/processing.py| SILVER[data/processed/]
    RAWDATA --> |upload bronze| S3B
    SILVER --> |upload silver| S3B
    S3B --> |COPY INTO\nvia stage externo| RAW
    RAW --> |dbt run| AN
    AN --> |mart_late_delivery_features| ML[machine-learning/\nhard-code + sklearn]
    ML --> |predictions.csv| S3B
    S3B --> |COPY INTO| RAW
    AN --> |mart_delivery_kpis\nmart_sentiment_kpis\nmart_ml_results| MB
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
    SAGEMAKER[Amazon SageMaker\nNotebook / Training Job\n(regressão logística\nhard-code + sklearn)]
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
- Credenciais (AWS, Snowflake) só existem em `.env` (fora do controle de versão) e como
  variáveis de ambiente dentro dos containers.
- **Limitação operacional identificada durante a execução real** (item 9 dos objetivos de
  Cloud Computing): o design original previa Snowflake acessando o S3 via **Storage
  Integration** (IAM Role assumida via `sts:AssumeRole`, sem nenhuma chave estática dentro do
  Snowflake). Na prática, a conta AWS usada (AWS Academy Learner Lab) bloqueia `iam:CreateRole`
  para o aluno, então não é possível criar essa IAM Role. Alternativa adotada: o stage do
  Snowflake usa `CREATE STAGE ... CREDENTIALS = (AWS_KEY_ID=... AWS_SECRET_KEY=... AWS_TOKEN=...)`
  com as mesmas credenciais temporárias do `.env` — solução oficialmente suportada pela
  Snowflake, com o trade-off de precisar ser recriada quando a sessão do laboratório expira
  (poucas horas). Em uma conta AWS sem essa restrição, o caminho original com Storage
  Integration volta a ser a opção recomendada (ver `snowflake/README.md`).
- **Conta Snowflake compartilhada**: a role usada (`TRAINING_ROLE`, conta SFEDU02) é
  compartilhada por toda a turma — dezenas de databases pessoais coexistem na mesma conta.
  Para não colidir com o trabalho de outros alunos, o database alvo deste projeto tem nome
  específico (`SNOWFLAKE_DATABASE` no `.env`, não um nome genérico), e os schemas `RAW`/
  `ANALYTICS` ficam isolados dentro dele.
- No template 100% AWS, os serviços (Glue, SageMaker) usam IAM Roles com permissão mínima
  (apenas leitura/escrita no bucket do projeto).
