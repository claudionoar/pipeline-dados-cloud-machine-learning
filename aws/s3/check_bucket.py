"""Verifica que o bucket S3 (provisionado via terraform/, não mais por script Python) existe
e está acessível antes do restante do pipeline seguir.

Uso:
    python check_bucket.py
"""
from __future__ import annotations

import os
import sys

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

load_dotenv()

BUCKET = os.environ.get("AWS_S3_BUCKET")
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")


def main() -> None:
    if not BUCKET:
        sys.exit("AWS_S3_BUCKET não definido. Configure o .env na raiz do projeto.")

    client = boto3.client("s3", region_name=REGION)
    try:
        client.head_bucket(Bucket=BUCKET)
    except ClientError as exc:
        sys.exit(
            f"Bucket '{BUCKET}' não encontrado ou inacessível ({exc}).\n"
            "Rode 'terraform apply' primeiro (ver terraform/README.md) antes de disparar o DAG."
        )
    print(f"Bucket '{BUCKET}' OK.")


if __name__ == "__main__":
    main()
