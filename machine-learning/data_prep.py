"""Prepara o dataset de treino/teste para a tarefa de previsão de atraso na entrega
(classificação binária: is_late).

Fonte preferencial: `ANALYTICS.MART_LATE_DELIVERY_FEATURES` no Snowflake (tabela final gerada
pelo dbt, ver dbt/olist_pipeline/models/marts/ml/mart_late_delivery_features.sql) - uma linha
por pedido entregue, com features estruturadas (frete, prazo, distância cliente-vendedor etc.)
e o alvo is_late. Como fallback (para desenvolver sem depender de credenciais Snowflake), lê
`data/processed/late_delivery_features.csv` (export manual da mesma query) ou gera uma amostra
sintética.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
from dotenv import load_dotenv
from sklearn.model_selection import train_test_split

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))
load_dotenv()

FEATURE_COLUMNS = [
    "total_price", "total_freight", "item_count", "avg_product_weight_g",
    "avg_product_volume_cm3", "payment_installments_max", "payment_value_total",
    "approval_delay_hours", "estimated_delivery_days", "purchase_dow", "purchase_month",
    "distance_km", "same_state_flag",
]
REQUIRED_COLUMNS = ["order_id", "is_late"] + FEATURE_COLUMNS


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
        query = f"""
            select {', '.join(REQUIRED_COLUMNS)}
            from mart_late_delivery_features
        """
        with conn.cursor() as cur:
            cur.execute(query)
            columns = [c[0].lower() for c in cur.description]
            rows = cur.fetchall()
        return pd.DataFrame(rows, columns=columns)
    finally:
        conn.close()


def load_from_csv(
    path: Path = PROJECT_ROOT / "data" / "processed" / "late_delivery_features.csv",
) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(
            f"{path} não encontrado. Exporte mart_late_delivery_features para esse caminho "
            "(ou use --source sample)."
        )
    return pd.read_csv(path)


def generate_sample(n: int = 2000, seed: int = 42) -> pd.DataFrame:
    """Amostra sintética com sinal real (não puramente aleatório) para validar o código sem
    depender de credenciais Snowflake: pedidos com frete alto, muitos itens, alta distância e
    pouco prazo estimado têm probabilidade maior de atraso."""
    rng = np.random.default_rng(seed)
    df = pd.DataFrame({
        "order_id": [f"SAMPLE{i:06d}" for i in range(n)],
        "total_price": rng.uniform(20, 800, n).round(2),
        "total_freight": rng.uniform(5, 150, n).round(2),
        "item_count": rng.integers(1, 5, n),
        "avg_product_weight_g": rng.uniform(100, 15000, n).round(1),
        "avg_product_volume_cm3": rng.uniform(500, 60000, n).round(1),
        "payment_installments_max": rng.integers(1, 12, n),
        "payment_value_total": rng.uniform(20, 900, n).round(2),
        "approval_delay_hours": rng.exponential(6, n).round(2),
        "estimated_delivery_days": rng.integers(5, 45, n),
        "purchase_dow": rng.integers(0, 7, n),
        "purchase_month": rng.integers(1, 13, n),
        "distance_km": rng.exponential(500, n).round(1),
        "same_state_flag": rng.integers(0, 2, n),
    })
    risk = (
        0.0025 * df["distance_km"]
        + 0.03 * df["total_freight"]
        - 0.08 * df["estimated_delivery_days"]
        - 1.2 * df["same_state_flag"]
        + rng.normal(0, 2, n)
    )
    threshold = np.quantile(risk, 0.92)
    df["is_late"] = risk > threshold
    return df


def load_dataset(source: str = "snowflake") -> pd.DataFrame:
    if source == "snowflake":
        df = load_from_snowflake()
    elif source == "csv":
        df = load_from_csv()
    elif source == "sample":
        df = generate_sample()
    else:
        raise ValueError(f"Fonte desconhecida: {source}")

    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"Colunas ausentes na fonte '{source}': {missing}")

    df = df.dropna(subset=FEATURE_COLUMNS + ["is_late"]).copy()
    df["is_late"] = df["is_late"].astype(bool)
    df["label"] = df["is_late"].map({True: "late", False: "on_time"})
    return df.reset_index(drop=True)


def split_dataset(df: pd.DataFrame, test_size: float = 0.2, seed: int = 42):
    return train_test_split(
        df, test_size=test_size, random_state=seed, stratify=df["label"]
    )
