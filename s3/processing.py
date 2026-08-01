"""Normaliza os 10 CSVs brutos do dataset Olist (Brazilian E-Commerce) em `data/raw/` para um
esquema tipado/canônico (silver) em `data/processed/`.

Ao contrário da versão anterior (dataset Amazon, sem FK real entre catálogo e reviews), o Olist
já é um schema relacional real (pedidos/itens/pagamentos/reviews/produtos/clientes/vendedores
ligados por chaves reais) — então aqui não há detecção de alias nem geração de amostra
sintética: cada tabela é lida, tipada (datas, ids/CEPs como string para preservar zeros à
esquerda, numéricos como float ou Int64 nullable) e gravada 1:1 em `data/processed/<tabela>.csv`.
Joins, agregações e regras de negócio (ex.: sentimento a partir do review_score, atraso na
entrega) ficam no dbt — este script só garante que o que chega no Snowflake está limpo e tipado.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DIR = PROJECT_ROOT / "data" / "raw"
DEFAULT_OUT_DIR = PROJECT_ROOT / "data" / "processed"

# Cada tabela: arquivo de origem, colunas string (ids/CEPs/textos livres - preserva zeros à
# esquerda e não tenta inferir tipo), colunas de data e colunas numéricas (nome -> "int" para
# contagens/inteiros nullable, "float" para valores contínuos).
TABLE_SPECS = {
    "customers": {
        "file": "olist_customers_dataset.csv",
        "str_cols": ["customer_id", "customer_unique_id", "customer_zip_code_prefix",
                     "customer_city", "customer_state"],
        "date_cols": [],
        "numeric_cols": {},
    },
    "geolocation": {
        "file": "olist_geolocation_dataset.csv",
        "str_cols": ["geolocation_zip_code_prefix", "geolocation_city", "geolocation_state"],
        "date_cols": [],
        "numeric_cols": {"geolocation_lat": "float", "geolocation_lng": "float"},
    },
    "orders": {
        "file": "olist_orders_dataset.csv",
        "str_cols": ["order_id", "customer_id", "order_status"],
        "date_cols": ["order_purchase_timestamp", "order_approved_at",
                      "order_delivered_carrier_date", "order_delivered_customer_date",
                      "order_estimated_delivery_date"],
        "numeric_cols": {},
    },
    "order_items": {
        "file": "olist_order_items_dataset.csv",
        "str_cols": ["order_id", "product_id", "seller_id"],
        "date_cols": ["shipping_limit_date"],
        "numeric_cols": {"order_item_id": "int", "price": "float", "freight_value": "float"},
    },
    "order_payments": {
        "file": "olist_order_payments_dataset.csv",
        "str_cols": ["order_id", "payment_type"],
        "date_cols": [],
        "numeric_cols": {"payment_sequential": "int", "payment_installments": "int",
                          "payment_value": "float"},
    },
    "order_reviews": {
        "file": "olist_order_reviews_dataset.csv",
        "str_cols": ["review_id", "order_id", "review_comment_title", "review_comment_message"],
        "date_cols": ["review_creation_date", "review_answer_timestamp"],
        "numeric_cols": {"review_score": "int"},
    },
    "products": {
        "file": "olist_products_dataset.csv",
        "str_cols": ["product_id", "product_category_name"],
        "date_cols": [],
        "numeric_cols": {"product_name_lenght": "float", "product_description_lenght": "float",
                          "product_photos_qty": "float", "product_weight_g": "float",
                          "product_length_cm": "float", "product_height_cm": "float",
                          "product_width_cm": "float"},
    },
    "sellers": {
        "file": "olist_sellers_dataset.csv",
        "str_cols": ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"],
        "date_cols": [],
        "numeric_cols": {},
    },
    "category_translation": {
        "file": "product_category_name_translation.csv",
        "str_cols": ["product_category_name", "product_category_name_english"],
        "date_cols": [],
        "numeric_cols": {},
    },
}


def _load_table(raw_dir: Path, spec: dict) -> pd.DataFrame:
    path = raw_dir / spec["file"]
    if not path.exists():
        raise SystemExit(f"Arquivo não encontrado: {path}")

    all_str_cols = list(spec["str_cols"])
    df = pd.read_csv(path, dtype={c: "string" for c in all_str_cols})

    for col in all_str_cols:
        df[col] = df[col].str.strip()

    for col in spec["date_cols"]:
        df[col] = pd.to_datetime(df[col], errors="coerce")

    for col, kind in spec["numeric_cols"].items():
        series = pd.to_numeric(df[col], errors="coerce")
        df[col] = series.round().astype("Int64") if kind == "int" else series.astype("float64")

    return df.drop_duplicates().reset_index(drop=True)


def process_all(raw_dir: Path, out_dir: Path) -> dict[str, int]:
    out_dir.mkdir(parents=True, exist_ok=True)
    row_counts = {}
    for name, spec in TABLE_SPECS.items():
        df = _load_table(raw_dir, spec)
        out_path = out_dir / f"{name}.csv"
        df.to_csv(out_path, index=False)
        row_counts[name] = len(df)
        print(f"[{name}] {len(df)} linhas -> {out_path}")
    return row_counts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args()

    row_counts = process_all(args.raw_dir, args.out_dir)
    total = sum(row_counts.values())
    print(f"\nOK: {total} linhas no total, em {len(row_counts)} tabelas, gravadas em {args.out_dir}")


if __name__ == "__main__":
    main()
