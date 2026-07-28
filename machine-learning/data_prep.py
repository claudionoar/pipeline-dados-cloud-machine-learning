"""Prepara o dataset de treino/teste para a tarefa de classificação de sentimento.

Fonte preferencial: `ANALYTICS.ML_FEATURE_TABLE` no Snowflake (tabela final gerada pelo dbt,
ver dbt/amazon_pipeline/models/marts/ml/ml_feature_table.sql). Como fallback (para desenvolver
sem depender de credenciais Snowflake), lê `data/processed/reviews.csv` (saída de
`s3/processing.py`) ou gera uma amostra sintética.

Colunas mínimas necessárias, em qualquer fonte: review_id, product_id, review_text, sentiment_label.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sklearn.model_selection import train_test_split

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))
load_dotenv()

REQUIRED_COLUMNS = ["review_id", "product_id", "review_text", "sentiment_label"]


def load_from_snowflake() -> pd.DataFrame:
    import os

    import snowflake.connector

    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        schema=os.environ.get("SNOWFLAKE_SCHEMA", "ANALYTICS"),
    )
    try:
        query = """
            select review_id, product_id, review_text, sentiment_label,
                   category_root, discounted_price, product_rating, product_rating_count
            from ml_feature_table
        """
        with conn.cursor() as cur:
            cur.execute(query)
            columns = [c[0].lower() for c in cur.description]
            rows = cur.fetchall()
        return pd.DataFrame(rows, columns=columns)
    finally:
        conn.close()


def load_from_csv(path: Path = PROJECT_ROOT / "data" / "processed" / "reviews.csv") -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(
            f"{path} não encontrado. Rode s3/processing.py primeiro (ou use --source sample)."
        )
    return pd.read_csv(path)


def load_sample() -> pd.DataFrame:
    from s3.processing import generate_sample_reviews, generate_sample_sales

    sales = generate_sample_sales()
    return generate_sample_reviews(sample_sales=sales)


def load_dataset(source: str = "snowflake") -> pd.DataFrame:
    if source == "snowflake":
        df = load_from_snowflake()
    elif source == "csv":
        df = load_from_csv()
    elif source == "sample":
        df = load_sample()
    else:
        raise ValueError(f"Fonte desconhecida: {source}")

    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"Colunas ausentes na fonte '{source}': {missing}")

    df = df.dropna(subset=["review_text", "sentiment_label"]).copy()
    df = df[df["review_text"].astype(str).str.strip().str.len() > 0]
    df["review_text"] = df["review_text"].astype(str)
    return df.reset_index(drop=True)


def split_dataset(df: pd.DataFrame, test_size: float = 0.2, seed: int = 42):
    return train_test_split(
        df, test_size=test_size, random_state=seed, stratify=df["sentiment_label"]
    )
