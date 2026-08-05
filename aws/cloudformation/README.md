# cloudformation/ — Arquitetura 100% AWS equivalente

O enunciado (seção 4.5) pede um "diagrama arquitetural apresentando a proposta de uma
solução equivalente 100% em serviços da AWS" + o template YAML do CloudFormation. A
implementação real do projeto é híbrida (S3 real + Snowflake + Airflow/dbt/Metabase em
Docker); `template.yaml` documenta como o mesmo pipeline seria construído usando **apenas**
serviços gerenciados da AWS.

## Mapeamento (implementação real → 100% AWS)

| Componente real | Equivalente 100% AWS | No template? |
|---|---|---|
| Bucket S3 (bronze/silver/gold) | S3 (igual) | Sim — `DataLakeBucket` |
| `s3/processing.py` (pandas) | AWS Glue (Crawler + Job PySpark) | Sim — `BronzeCrawler`, `ProcessingGlueJob` |
| Snowflake + dbt | Amazon Redshift Serverless (+ dbt-redshift) | Sim, **opcional** — `RedshiftNamespace`/`RedshiftWorkgroup` (`EnableRedshift=true`) |
| Airflow (Docker) | Amazon MWAA (Managed Workflows for Apache Airflow) | **Não implantado** — exige VPC dedicada com 2 subnets privadas + NAT Gateway e tem custo fixo mensal (~US$350+) mesmo ocioso; documentado apenas no diagrama (`docs/arquitetura.md`) |
| `machine-learning/` (hard-code + sklearn) | Amazon SageMaker (Notebook/Training Job) | Sim, **opcional** — `SentimentModelNotebook` (`EnableSageMaker=true`) |
| Metabase (Docker) | Amazon QuickSight | **Não implantado** — requer assinatura por usuário/mês e setup de permissões próprio; documentado apenas no diagrama |
| Credenciais AWS estáticas | IAM Roles (Glue/SageMaker) | Sim — `GlueServiceRole`, `SageMakerExecutionRole` |
| — | CloudWatch Log Group (monitoramento básico) | Sim — `DataLakeLogGroup` |

MWAA e QuickSight ficam **fora do template** deliberadamente: são os dois serviços com maior
custo fixo/complexidade de rede da lista, e implantá-los apenas para fins de entrega
acadêmica não se justifica. Eles aparecem no diagrama arquitetural (`docs/arquitetura.md`)
com a justificativa de onde encaixariam.

## Deploy (opcional — gera custo real na sua conta AWS)

```bash
aws cloudformation deploy \
  --template-file cloudformation/template.yaml \
  --stack-name olist-pipeline \
  --parameter-overrides \
      BucketSuffix=<seu-sufixo-unico> \
      EnableRedshift=false \
      EnableSageMaker=false \
  --capabilities CAPABILITY_NAMED_IAM
```

Por padrão `EnableRedshift` e `EnableSageMaker` ficam `false` — o deploy cria apenas S3, Glue
(Catalog/Crawler/Job) e as IAM Roles, que não têm custo fixo (Glue Crawler/Job só cobra por
execução). Ative os parâmetros somente se quiser provisionar de fato o Redshift Serverless
e/ou a notebook do SageMaker (ambos têm custo contínuo enquanto ativos).

**Antes de aplicar**: edite `ProcessingGlueJob.Properties.Command.ScriptLocation` para apontar
para um script real (versão PySpark de `s3/processing.py`) já enviado ao bucket — o
CloudFormation não falha na criação do Job por o script ainda não existir, mas o Job falhará
ao ser executado até isso ser feito.

## Custos aproximados (estimativa, us-east-1, 2026)

| Recurso | Custo aproximado |
|---|---|
| S3 (bronze/silver/gold, poucos GB) | < US$ 1/mês |
| Glue Crawler (1x/dia) | ~US$ 0,10/execução |
| Glue Job (2 workers G.1X, execuções pontuais) | ~US$ 0,44/hora rodando |
| Redshift Serverless (8 RPU, se habilitado) | cobrado por segundo de uso, ~US$ 2,88/hora ativa |
| SageMaker Notebook `ml.t3.medium` (se habilitado) | ~US$ 0,05/hora ligada |
| MWAA (não implantado) | ~US$ 0,49/hora + custo de ambiente (referência apenas) |
| QuickSight (não implantado) | US$ 12-24/usuário/mês (referência apenas) |

Valores de referência pública da AWS, podem variar por região/tempo — registrar essa tabela
(com ajustes reais medidos, se o grupo optar por ativar os recursos opcionais) atende ao
requisito "registro de eventuais custos envolvidos" (seção 4.5).
