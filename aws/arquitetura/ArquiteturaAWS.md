# Proposta de Arquitetura 100% AWS

Esta proposta apresenta uma solução equivalente a 100% em serviços gerenciados da AWS para o pipeline de dados e machine learning do Olist Brazilian E-Commerce.

![Diagrama da Arquitetura Proposta 100% AWS (Conceitual)](aws_architecture_diagram.png)

![Diagrama da Arquitetura Proposta 100% AWS (Gerado via Python Diagrams)](aws_architecture_diagram_generated.png)


---

## 1. Mapeamento de Componentes

A tabela abaixo descreve a transição dos componentes locais/híbridos atuais para os equivalentes totalmente gerenciados na AWS:

| Componente Atual (Híbrido / Local) | Equivalente 100% AWS | Função no Pipeline |
| :--- | :--- | :--- |
| **Arquivos CSV locais** (`data/raw/`) | **Amazon S3 (Bronze Bucket)** | Armazenamento de dados brutos (*raw*) |
| **Script de Ingestão** (`s3/processing.py`) | **AWS Glue Job (PySpark)** | Limpeza, transformação e normalização dos dados brutos |
| **S3 local/híbrido** (Silver/Gold) | **Amazon S3 (Silver/Gold Buckets)** | Armazenamento dos dados limpos (*Silver*) e prontos para consumo (*Gold*) |
| **Metadata Catalog** | **AWS Glue Crawler + Data Catalog** | Catálogo de tabelas estruturadas baseadas nos arquivos do S3 |
| **Snowflake** (SaaS externo) | **Amazon Redshift Serverless** | Data Warehouse analítico para consultas estruturadas |
| **dbt CLI** (Executado via Docker) | **Amazon EC2 (Instância com dbt Core/CLI)** | Execução das transformações dbt conectando ao Redshift Serverless |
| **Modelagem ML** (`machine-learning/`) | **Amazon SageMaker (Training Job/Notebook)** | Treinamento de regressão logística e inferência das previsões de atraso (`is_late`) |
| **Apache Airflow** (Docker Compose local) | **Amazon MWAA (Managed Workflows for Airflow)** | Orquestração ponta a ponta do fluxo de ETL, dbt e SageMaker |
| **Metabase** (Docker local) | **Amazon QuickSight** | Dashboard analítico de KPIs de entregas, análise de sentimentos e resultados de ML |
| **Monitoramento local** | **Amazon CloudWatch** | Centralização de logs e métricas de execução de todos os serviços AWS |

---

## 2. Fluxo de Dados e Processamento

```mermaid
flowchart TD
    RawCSV[1. CSVs em S3 Bronze] -->|Glue Job PySpark| SilverParquet[2. Parquet em S3 Silver]
    SilverParquet -->|Glue Crawler| DataCatalog[3. Glue Data Catalog]
    SilverParquet -->|COPY INTO| RedshiftRAW[4. Redshift Serverless - RAW]
    RedshiftRAW -->|dbt no EC2| RedshiftANALYTICS[5. Redshift Serverless - ANALYTICS]
    RedshiftANALYTICS -->|Features| SageMaker[6. SageMaker Training & Inference]
    SageMaker -->|Predições para S3 / Redshift| RedshiftML[7. Redshift Serverless - ML Results]
    RedshiftML -->|Consumo de Dados| QuickSight[8. Dashboards no Amazon QuickSight]
    
    %% Orchestration
    MWAA -. Orquestra todo o fluxo .-> Glue Job
    MWAA -. Orquestra .-> EC2[dbt no EC2]
    MWAA -. Orquestra .-> SageMaker
    
    %% Monitoring
    Glue Job -. Logs .-> CloudWatch
    MWAA -. Logs .-> CloudWatch
    SageMaker -. Logs .-> CloudWatch
    RedshiftRAW -. Logs .-> CloudWatch
```

### Detalhamento das Fases:

1. **Ingestão e Processamento Inicial**:
   - Os arquivos brutos (CSVs) do dataset Olist são enviados ao bucket **S3 Bronze**.
   - O **AWS Glue Job (PySpark)** lê estes dados brutos, aplica tipagens corretas, trata valores nulos e salva o resultado no formato otimizado **Parquet** no bucket **S3 Silver**.

2. **Catalogação e Carga**:
   - O **AWS Glue Crawler** escaneia as partições do S3 e atualiza o **Glue Data Catalog**, tornando as tabelas disponíveis via consultas SQL.
   - O pipeline realiza a carga dos dados estruturados no **Amazon Redshift Serverless** (camada `RAW`).

3. **Transformação Analítica (dbt no EC2)**:
   - O dbt Core é instalado e executado em uma instância **Amazon EC2**, utilizando o adaptador `dbt-redshift` para se conectar ao Redshift Serverless e orquestrar as transformações dentro do banco, estruturando as tabelas nas camadas *Staging*, *Dimensional/Fato* (Star Schema) e *Marts* dentro do schema `ANALYTICS`.

4. **Machine Learning (SageMaker)**:
   - O **Amazon SageMaker** consome as tabelas de features (`mart_late_delivery_features`) do Redshift.
   - Um script Python baseado em Scikit-learn é executado em um *SageMaker Training Job* para treinar o modelo de atraso.
   - As previsões geradas (`predictions.csv`) são salvas de volta no S3 Gold e carregadas no Redshift na tabela `mart_ml_results`.

5. **Visualização (QuickSight)**:
   - O **Amazon QuickSight** conecta-se diretamente ao Redshift Serverless para expor os indicadores operacionais em tempo real para os gestores de logística.

---

## 3. Arquitetura como Código (IaC) e Implantação

A infraestrutura básica para esta arquitetura é definida no template CloudFormation localizado em `cloudformation/template.yaml`.

### Estrutura do Template CloudFormation:
- **S3 Bucket**: Criação do Data Lake unificado com as pastas estruturadas.
- **AWS Glue**: Provisionamento do Glue Database, Glue Service Role, Crawler de tabelas e do ETL Glue Job.
- **Amazon Redshift Serverless**: Configurações condicionais (`EnableRedshift=true`) de Namespace e Workgroup.
- **Amazon SageMaker**: Criação opcional (`EnableSageMaker=true`) da instância de Notebook para experimentos de ML e roles associadas.
- **Amazon EC2**: Provisionamento da instância EC2 (opcional, `EnableEC2=true`) configurada com dbt Core/CLI para executar as transformações no Redshift.
- **Amazon CloudWatch**: Log Groups centralizados para evitar perda de logs de execução.

> [!NOTE]
> Os serviços de orquestração **MWAA** e visualização **QuickSight** foram documentados na arquitetura, mas omitidos do template CloudFormation por apresentarem alto custo fixo mínimo (MWAA exige VPC com NAT Gateways, aproximando-se de US$ 350/mês mesmo ocioso).

---

## 4. Análise de Custos Estimados (Região: us-east-1)

| Serviço AWS | Modelo de Cobrança | Estimativa de Custo Mensal (Uso Moderado) |
| :--- | :--- | :--- |
| **Amazon S3** | Armazenamento por GB/mês + requisições API | < US$ 1.00 (pouco volume de dados brutos) |
| **AWS Glue** | DPU-hora por job rodando (mínimo 10 min por execução) | ~US$ 10.00 a US$ 15.00 (rodando 1x ao dia) |
| **Amazon Redshift Serverless** | RPU-hora (unidades de processamento ativas) | ~US$ 2.88 por hora de processamento ativo |
| **Amazon SageMaker** | Instância rodando (Notebook) + custo de Job de Treino | ~US$ 5.00 a US$ 10.00 (ml.t3.medium para desenvolvimento) |
| **Amazon EC2 (dbt Core)** | Instância rodando (t3.micro para execução do dbt CLI) | ~US$ 7.60/mês (se ligada continuamente) ou < US$ 1.00 (se ligada sob demanda) |
| **Amazon MWAA** (Não implantado) | Custo fixo por hora da instância do Airflow | ~US$ 350.00 (incluindo NAT Gateway na VPC) |
| **Amazon QuickSight** (Não implantado) | Licenciamento por usuário ativo | ~US$ 12.00 a US$ 24.00 por usuário/mês |

---

## 5. Próximos Passos Recomendados

Para migrar a execução atual local/híbrida para a nuvem AWS de forma produtiva:
1. **Refatorar Ingestão**: Converter o script pandas `s3/processing.py` para rodar como PySpark no Glue.
2. **Setup do Adaptador dbt no EC2**: Provisionar a instância EC2, instalar o Python/dbt-redshift e configurar o perfil do dbt (`profiles.yml`) para usar o driver `redshift` ao invés de `snowflake`.
3. **Segurança Avançada**: Configurar VPC Endpoints para garantir que o tráfego entre S3, Glue e Redshift Serverless não transite pela internet pública.
