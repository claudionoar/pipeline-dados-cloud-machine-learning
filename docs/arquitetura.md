# Arquitetura

## 1. Arquitetura implementada (híbrida: Docker local + AWS real + Snowflake SaaS)

![Diagrama da arquitetura implementada](diagrama_arquitetura.png)

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
    RAWDATA --> |aws/s3/processing.py| SILVER[data/processed/]
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

O documento **canônico** desta proposta — diagrama, mapeamento componente a componente, fases
do fluxo e análise de custos — é [`aws/arquitetura/ArquiteturaAWS.md`](../aws/arquitetura/ArquiteturaAWS.md).
O template CloudFormation correspondente está em `aws/cloudformation/template.yaml` (detalhes
de deploy e do que ficou fora em `aws/cloudformation/README.md`).

Resumo das substituições: Snowflake → Redshift Serverless · Airflow (Docker) → MWAA ·
pandas → AWS Glue · dbt CLI → dbt Core em EC2 · Metabase → QuickSight · SageMaker para
treino do modelo · CloudWatch para logs.

## Organização de dados em nuvem

Ver `aws/s3/README.md` para a estrutura de camadas (bronze/silver/gold) e `docs/dicionario_dados.md`
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
