# s3/ — Armazenamento em nuvem (AWS S3)

Organização do bucket S3 (arquitetura em camadas / medalhão):

```
s3://<AWS_S3_BUCKET>/
├── bronze/                     # 9 CSVs originais do Olist, como estão em data/raw/ (imutável)
│   ├── customers/<data>/olist_customers_dataset.csv
│   ├── geolocation/<data>/olist_geolocation_dataset.csv
│   ├── orders/<data>/olist_orders_dataset.csv
│   ├── order_items/<data>/olist_order_items_dataset.csv
│   ├── order_payments/<data>/olist_order_payments_dataset.csv
│   ├── order_reviews/<data>/olist_order_reviews_dataset.csv
│   ├── products/<data>/olist_products_dataset.csv
│   ├── sellers/<data>/olist_sellers_dataset.csv
│   └── category_translation/<data>/product_category_name_translation.csv
├── silver/                     # dados tipados/normalizados (saída de processing.py) - 1 pasta por tabela
│   ├── customers/customers.csv, geolocation/geolocation.csv, orders/orders.csv, ...
│   └── ml_predictions/predictions.csv
└── gold/                       # reservado para exports agregados (ex.: extratos para BI externo)
```

Cada partição de `bronze/` usa uma pasta `<data>` no formato `dt=YYYY-MM-DD` para permitir
reprocessamento e rastreabilidade entre execuções do pipeline. `silver/` **não** particiona
por data (chave estável, sobrescrita a cada execução) — ver o comentário em
`upload_to_s3.py::upload_silver` para o motivo (evitar duplicação no `COPY INTO`).

## Criação do bucket

O bucket (e as camadas bronze/silver/gold) não é mais criado por um script Python: é
provisionado via **Terraform, rodado em Docker** — ver `terraform/README.md`. É um passo de
infraestrutura rodado **uma vez**, antes de subir o `docker-compose up` (igual ao setup do
Snowflake). O DAG do Airflow assume que o bucket já existe.

## Scripts

| Script | Função |
|---|---|
| `check_bucket.py` | Verifica que o bucket (provisionado pelo Terraform) existe e está acessível; falha rápido e com mensagem clara se o `terraform apply` ainda não rodou. |
| `processing.py` | Lê os 9 CSVs brutos do Olist (`data/raw/`), tipa/normaliza colunas (datas, CEPs como string, numéricos) por tabela e grava em `data/processed/` - sem joins/agregações, que ficam a cargo do dbt. |
| `upload_to_s3.py` | Sobe os arquivos brutos para `bronze/` e os processados para `silver/`. Também sabe subir as predições de ML geradas por `machine-learning/train_and_compare.py`. |

## Uso local

```bash
cd s3
pip install -r requirements.txt

python processing.py
python upload_to_s3.py --layer bronze
python upload_to_s3.py --layer silver
```

Essas mesmas funções são chamadas pelas tasks do DAG (`airflow/dags/olist_pipeline_dag.py`),
que é a forma "oficial" e reprodutível de rodar o pipeline (ver `README.md` na raiz).

## Segurança básica

- Bucket privado (Block Public Access habilitado) — nenhum dado exposto publicamente.
- Credenciais AWS nunca hardcoded: sempre lidas de variáveis de ambiente (`.env`, carregado via
  `python-dotenv` ou pelas envs do container do Airflow).
- Acesso do Snowflake ao bucket usa as mesmas credenciais AWS do `.env` (nunca hardcoded no
  SQL) — idealmente seria via Storage Integration (IAM Role, sem chave nenhuma dentro do
  Snowflake), mas isso exige permissão para criar IAM Role na conta AWS, que ambientes de
  laboratório (ex.: AWS Academy Learner Lab) bloqueiam para o aluno. Ver `snowflake/README.md`
  para os dois caminhos e a limitação documentada.
