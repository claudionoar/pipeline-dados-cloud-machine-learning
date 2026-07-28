# s3/ — Armazenamento em nuvem (AWS S3)

Organização do bucket S3 (arquitetura em camadas / medalhão):

```
s3://<AWS_S3_BUCKET>/
├── bronze/                     # dados brutos, como baixados do Kaggle (imutável)
│   ├── amazon_sales/<data>/amazon_sales.csv
│   └── amazon_reviews/<data>/amazon_reviews.csv
├── silver/                     # dados tratados/normalizados (saída de processing.py)
│   ├── sales/<data>/sales.csv
│   ├── reviews/<data>/reviews.csv
│   └── ml_predictions/<data>/predictions.csv
└── gold/                       # reservado para exports agregados (ex.: extratos para BI externo)
```

Cada partição usa uma pasta `<data>` no formato `dt=YYYY-MM-DD` para permitir reprocessamento e
rastreabilidade entre execuções do pipeline (dado bruto → tratado → predição, exigido na
seção 5.3 do enunciado).

## Criação do bucket

O bucket (e as camadas bronze/silver/gold) não é mais criado por um script Python: é
provisionado via **Terraform, rodado em Docker** — ver `terraform/README.md`. É um passo de
infraestrutura rodado **uma vez**, antes de subir o `docker-compose up` (igual ao setup do
Snowflake). O DAG do Airflow assume que o bucket já existe.

## Scripts

| Script | Função |
|---|---|
| `check_bucket.py` | Verifica que o bucket (provisionado pelo Terraform) existe e está acessível; falha rápido e com mensagem clara se o `terraform apply` ainda não rodou. |
| `processing.py` | Lê os CSVs brutos (`data/raw/`), normaliza colunas, deriva o rótulo de sentimento a partir do rating e extrai features textuais básicas (contagem de palavras, caracteres, exclamações). Grava em `data/processed/`. |
| `upload_to_s3.py` | Sobe os arquivos brutos para `bronze/` e os processados para `silver/`. Também sabe subir as predições de ML geradas por `machine-learning/train_and_compare.py`. |

## Uso local

```bash
cd s3
pip install -r requirements.txt

python processing.py --sample-fallback   # ou sem a flag, se já tiver rodado o download do Kaggle
python upload_to_s3.py --layer bronze
python upload_to_s3.py --layer silver
```

Essas mesmas funções são chamadas pelas tasks do DAG (`airflow/dags/amazon_pipeline_dag.py`),
que é a forma "oficial" e reprodutível de rodar o pipeline (ver `README.md` na raiz).

## Segurança básica

- Bucket privado (Block Public Access habilitado) — nenhum dado exposto publicamente.
- Credenciais AWS nunca hardcoded: sempre lidas de variáveis de ambiente (`.env`, carregado via
  `python-dotenv` ou pelas envs do container do Airflow).
- Acesso do Snowflake ao bucket é feito via **Storage Integration** (IAM Role com trust policy
  restrita à conta Snowflake), não via chaves de acesso estáticas — ver `snowflake/README.md`.
