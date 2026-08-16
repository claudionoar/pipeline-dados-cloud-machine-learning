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
| `aws/s3/processing.py` (pandas) | AWS Glue (Crawler + Job PySpark) | Sim — `BronzeCrawler`, `ProcessingGlueJob` |
| Snowflake | Amazon Redshift Serverless | Sim, **opcional** — `RedshiftNamespace`/`RedshiftWorkgroup` (`EnableRedshift=true`) |
| dbt CLI (container do Airflow) | dbt Core em uma instância EC2 (`dbt-redshift`) | Sim, **opcional** — `EnableEC2=true` |
| Airflow (Docker) | Amazon MWAA (Managed Workflows for Apache Airflow) | **Não implantado** — exige VPC dedicada com 2 subnets privadas + NAT Gateway e tem custo fixo mensal (~US$350+) mesmo ocioso; documentado apenas no diagrama (`aws/arquitetura/ArquiteturaAWS.md`) |
| `machine-learning/` (hard-code + sklearn) | Amazon SageMaker (Notebook/Training Job) | Sim, **opcional** — Notebook do SageMaker (`EnableSageMaker=true`) |
| Metabase (Docker) | Amazon QuickSight | **Não implantado** — requer assinatura por usuário/mês e setup de permissões próprio; documentado apenas no diagrama |
| Credenciais AWS estáticas | IAM Roles (Glue/SageMaker/EC2) | Sim — `GlueServiceRole`, `SageMakerExecutionRole` |
| — | VPC + subnets públicas e security group (suporte a Redshift/EC2) | Sim — criada sempre, **sem NAT Gateway** para não gerar custo ocioso |
| — | CloudWatch Log Group (monitoramento básico) | Sim — `DataLakeLogGroup` |

MWAA e QuickSight ficam **fora do template** deliberadamente: são os dois serviços com maior
custo fixo/complexidade de rede da lista, e implantá-los apenas para fins de entrega
acadêmica não se justifica. Eles aparecem no diagrama arquitetural
(`aws/arquitetura/ArquiteturaAWS.md`) com a justificativa de onde encaixariam.

## Deploy (opcional — gera custo real na sua conta AWS)

```bash
aws cloudformation deploy \
  --template-file aws/cloudformation/template.yaml \
  --stack-name olist-pipeline \
  --parameter-overrides \
      BucketSuffix=<seu-sufixo-unico> \
      EnableRedshift=false \
      EnableSageMaker=false \
      EnableEC2=false \
  --capabilities CAPABILITY_NAMED_IAM
```

Por padrão `EnableRedshift`, `EnableSageMaker` e `EnableEC2` ficam `false` — o deploy cria
apenas S3, Glue (Catalog/Crawler/Job), as IAM Roles e a VPC básica, que não têm custo fixo
(a VPC não tem NAT Gateway e o Glue Crawler/Job só cobra por execução). Ative os parâmetros
somente se quiser provisionar de fato o Redshift Serverless, a notebook do SageMaker e/ou a
instância EC2 do dbt (todos têm custo contínuo enquanto ativos).

**Antes de aplicar**: edite `ProcessingGlueJob.Properties.Command.ScriptLocation` para apontar
para um script real (versão PySpark de `aws/s3/processing.py`) já enviado ao bucket — o
CloudFormation não falha na criação do Job por o script ainda não existir, mas o Job falhará
ao ser executado até isso ser feito.

## Custos aproximados

A estimativa de custos por serviço está centralizada na seção 4 de
[`aws/arquitetura/ArquiteturaAWS.md`](../arquitetura/ArquiteturaAWS.md) — mantida em um único
lugar para não divergir. Ela atende ao requisito "registro de eventuais custos envolvidos"
(seção 4.5 do enunciado).

Em resumo, com os três parâmetros opcionais em `false` (o padrão), o stack **não gera custo
fixo**: S3 com poucos GB (< US$ 1/mês), Glue cobrado apenas por execução e VPC sem NAT Gateway.
