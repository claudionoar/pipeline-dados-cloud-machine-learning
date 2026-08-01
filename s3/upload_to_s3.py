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

PROJECT_ROOT = Path(__file__).resolve().parents[1]
BUCKET = os.environ.get("AWS_S3_BUCKET")
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")


def _s3_client():
    if not BUCKET:
        raise SystemExit("AWS_S3_BUCKET não definido. Configure o .env na raiz do projeto.")
    return boto3.client("s3", region_name=REGION)


def _partition(prefix: str) -> str:
    return f"{prefix}/dt={date.today().isoformat()}"


def upload_bronze(raw_dir: Path = PROJECT_ROOT / "data" / "raw") -> list[str]:
    client = _s3_client()
    uploaded = []
    mapping = {"sales": "amazon_sales", "reviews": "amazon_reviews"}
    for csv_path in sorted(raw_dir.glob("*.csv")):
        subfolder = "amazon_sales" if "sale" in csv_path.stem.lower() else "amazon_reviews"
        key = f"{_partition('bronze/' + subfolder)}/{csv_path.name}"
        client.upload_file(str(csv_path), BUCKET, key)
        uploaded.append(key)
        print(f"bronze: s3://{BUCKET}/{key}")
    return uploaded


def upload_silver(processed_dir: Path = PROJECT_ROOT / "data" / "processed") -> list[str]:
    # Sem partição por dt=: RAW.SALES/RAW.REVIEWS no Snowflake sao truncadas e recarregadas por
    # inteiro a cada execucao (ver 03_copy_into.sql), entao o silver representa so o snapshot
    # mais recente. Particionar por data aqui deixava pastas dt= antigas paradas no bucket, e o
    # COPY INTO (que varre @SILVER_STAGE/sales/ inteiro) carregava todas juntas, duplicando cada
    # linha uma vez por dia em que o pipeline ja rodou.
    client = _s3_client()
    uploaded = []
    for name in ["sales.csv", "reviews.csv"]:
        path = processed_dir / name
        if not path.exists():
            continue
        key = f"silver/{path.stem}/{path.name}"
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
