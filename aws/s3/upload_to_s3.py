"""Sobe arquivos para as camadas bronze/silver do bucket S3.

Uso:
    python upload_to_s3.py --layer bronze
    python upload_to_s3.py --layer silver
    python upload_to_s3.py --layer predictions --file machine-learning/output/predictions.csv
"""
from __future__ import annotations

import argparse
import os
from datetime import date
from pathlib import Path

import boto3
from dotenv import load_dotenv

load_dotenv()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
BUCKET = os.environ.get("AWS_S3_BUCKET")
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

# Uma tabela do dataset Olist por arquivo (ver s3/processing.py) - mesmo nome em bronze e silver.
TABLES = ["customers", "geolocation", "orders", "order_items", "order_payments",
          "order_reviews", "products", "sellers", "category_translation"]

RAW_FILENAMES = {
    "customers": "olist_customers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}


def _s3_client():
    if not BUCKET:
        raise SystemExit("AWS_S3_BUCKET não definido. Configure o .env na raiz do projeto.")
    return boto3.client("s3", region_name=REGION)


def _partition(prefix: str) -> str:
    return f"{prefix}/dt={date.today().isoformat()}"


def upload_bronze(raw_dir: Path = PROJECT_ROOT / "data" / "raw") -> list[str]:
    client = _s3_client()
    uploaded = []
    for table, filename in RAW_FILENAMES.items():
        path = raw_dir / filename
        if not path.exists():
            print(f"[bronze] aviso: {path} não encontrado, pulando")
            continue
        key = f"{_partition('bronze/' + table)}/{path.name}"
        client.upload_file(str(path), BUCKET, key)
        uploaded.append(key)
        print(f"bronze: s3://{BUCKET}/{key}")
    return uploaded


def upload_silver(processed_dir: Path = PROJECT_ROOT / "data" / "processed") -> list[str]:
    # Sem partição por dt=: as tabelas RAW no Snowflake sao truncadas e recarregadas por inteiro
    # a cada execucao (ver 03_copy_into.sql), entao o silver representa so o snapshot mais
    # recente. Particionar por data aqui deixava pastas dt= antigas paradas no bucket, e o COPY
    # INTO (que varre @SILVER_STAGE/<tabela>/ inteiro) carregava todas juntas, duplicando cada
    # linha uma vez por dia em que o pipeline ja rodou.
    client = _s3_client()
    uploaded = []
    for table in TABLES:
        path = processed_dir / f"{table}.csv"
        if not path.exists():
            print(f"[silver] aviso: {path} não encontrado, pulando")
            continue
        key = f"silver/{table}/{path.name}"
        client.upload_file(str(path), BUCKET, key)
        uploaded.append(key)
        print(f"silver: s3://{BUCKET}/{key}")
    return uploaded


def upload_predictions(file_path: Path) -> str:
    # Mesmo motivo do upload_silver: chave estavel, sobrescrita a cada run, para nao acumular
    # pastas dt= antigas que o COPY INTO de 05_copy_predictions.sql recarregaria duplicadas.
    client = _s3_client()
    key = f"silver/ml_predictions/{file_path.name}"
    client.upload_file(str(file_path), BUCKET, key)
    print(f"predictions: s3://{BUCKET}/{key}")
    return key


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layer", choices=["bronze", "silver", "predictions"], required=True)
    parser.add_argument("--file", type=Path, help="Obrigatório para --layer predictions")
    args = parser.parse_args()

    if args.layer == "bronze":
        upload_bronze()
    elif args.layer == "silver":
        upload_silver()
    else:
        if not args.file:
            raise SystemExit("--file é obrigatório para --layer predictions")
        upload_predictions(args.file)


if __name__ == "__main__":
    main()
