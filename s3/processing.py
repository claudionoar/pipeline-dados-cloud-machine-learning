"""Normaliza os datasets brutos (bronze) em um esquema canônico (silver).

Lê os CSVs em `data/raw/` (baixados do Kaggle, ver `data/README.md`), detecta
automaticamente as colunas equivalentes entre as variações de nome usadas pelos dois
datasets do projeto e grava CSVs normalizados em `data/processed/`:

    sales.csv    -> catálogo de produtos (dados estruturados)
    reviews.csv  -> reviews de texto (dados não/semi-estruturados) + rótulo de sentimento

Se os arquivos brutos não estiverem presentes, use --sample-fallback para gerar uma amostra
sintética e validar o restante do pipeline sem depender do download do Kaggle.
"""
from __future__ import annotations

import argparse
import random
import re
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_DIR = PROJECT_ROOT / "data" / "raw"
DEFAULT_OUT_DIR = PROJECT_ROOT / "data" / "processed"

# Aliases conhecidos de coluna por dataset -> ver docs/dicionario_dados.md
SALES_ALIASES = {
    "product_id": ["product_id", "asin", "id"],
    "product_name": ["product_name", "name", "title"],
    "category": ["category", "categories"],
    "discounted_price": ["discounted_price", "price", "sale_price"],
    "actual_price": ["actual_price", "list_price", "mrp"],
    "discount_percentage": ["discount_percentage", "discount_percent"],
    "rating": ["rating", "stars"],
    "rating_count": ["rating_count", "ratings_count", "num_ratings"],
    "about_product": ["about_product", "description"],
    "img_link": ["img_link", "image", "image_url"],
    "product_link": ["product_link", "link", "url"],
}
SALES_REQUIRED = ["product_id", "product_name", "rating"]

REVIEWS_ALIASES = {
    # "id" NAO entra aqui: em datasets estilo Datafiniti (amazon-product-reviews-dataset) a
    # coluna "id" identifica o PRODUTO, nao a review - varias linhas (reviews) repetem o
    # mesmo "id". Sem alias correspondente, review_id fica NaN e cai no fallback "gen-{i}"
    # (sequencial, garantidamente unico) mais abaixo em process_reviews().
    "review_id": ["review_id"],
    "product_id": ["product_id", "asin", "productid", "asins"],
    "user_id": ["user_id", "userid", "reviewerid", "reviewer_id", "reviews.username"],
    "review_title": ["review_title", "summary", "title", "reviews.title"],
    "review_text": ["review_text", "review_content", "reviewtext", "text", "reviews.text"],
    "rating": ["rating", "overall", "score", "stars", "reviews.rating"],
    "review_date": ["review_date", "time", "reviewtime", "unixreviewtime", "reviews.date"],
}
REVIEWS_REQUIRED = ["review_text", "rating"]

CATEGORIES = [
    "Electronics|Accessories", "Home&Kitchen|Appliances", "Computers|Accessories",
    "Electronics|Mobiles", "Home&Kitchen|Kitchen", "Office|Supplies",
]
POSITIVE_WORDS = ["excelente", "ótimo", "adorei", "recomendo", "perfeito", "rápido"]
NEGATIVE_WORDS = ["péssimo", "quebrou", "decepcionante", "atrasou", "arrependi", "ruim"]
NEUTRAL_WORDS = ["ok", "razoável", "mediano", "esperava mais", "cumpre o básico"]


def _find_raw_file(raw_dir: Path, aliases: dict, required: list[str]) -> Path | None:
    candidates = sorted(raw_dir.glob("*.csv"))
    for path in candidates:
        try:
            header = pd.read_csv(path, nrows=0).columns
        except Exception:
            continue
        lower_cols = {c.strip().lower() for c in header}
        hits = 0
        for key in required:
            if any(alias in lower_cols for alias in aliases[key]):
                hits += 1
        if hits == len(required):
            return path
    return None


def _rename_to_canonical(df: pd.DataFrame, aliases: dict) -> pd.DataFrame:
    lower_map = {c.strip().lower(): c for c in df.columns}
    rename = {}
    for canonical, alias_list in aliases.items():
        for alias in alias_list:
            if alias in lower_map:
                rename[lower_map[alias]] = canonical
                break
    df = df.rename(columns=rename)
    for canonical in aliases:
        if canonical not in df.columns:
            df[canonical] = pd.NA
    return df[list(aliases.keys())]


def _to_number(series: pd.Series) -> pd.Series:
    cleaned = series.astype(str).str.replace(r"[^\d.\-]", "", regex=True)
    cleaned = cleaned.replace("", pd.NA)
    return pd.to_numeric(cleaned, errors="coerce")


def sentiment_from_rating(rating: float) -> str:
    if pd.isna(rating):
        return "neutral"
    if rating >= 4:
        return "positive"
    if rating <= 2:
        return "negative"
    return "neutral"


def clean_sales(df: pd.DataFrame) -> pd.DataFrame:
    df = _rename_to_canonical(df, SALES_ALIASES)
    df["discounted_price"] = _to_number(df["discounted_price"])
    df["actual_price"] = _to_number(df["actual_price"])
    df["discount_percentage"] = _to_number(df["discount_percentage"])
    df["rating"] = pd.to_numeric(df["rating"], errors="coerce").clip(1, 5)
    df["rating_count"] = _to_number(df["rating_count"]).fillna(0).astype(int)
    df["about_product"] = df["about_product"].fillna("")
    df["category"] = df["category"].fillna("Unknown")
    df["category_root"] = df["category"].astype(str).str.split("|").str[0]
    df = df.dropna(subset=["product_id", "product_name"])
    df = df.drop_duplicates(subset=["product_id"], keep="first")
    df["ingested_at"] = datetime.now(timezone.utc).isoformat()
    return df.reset_index(drop=True)


def process_reviews(df: pd.DataFrame) -> pd.DataFrame:
    df = _rename_to_canonical(df, REVIEWS_ALIASES)
    df["review_text"] = df["review_text"].fillna("").astype(str).str.strip()
    df["review_title"] = df["review_title"].fillna("")
    df = df[df["review_text"].str.len() > 0].copy()

    df["rating"] = pd.to_numeric(df["rating"], errors="coerce")
    df = df.dropna(subset=["rating"])
    df["rating"] = df["rating"].round().clip(1, 5).astype(int)

    df["review_date"] = pd.to_datetime(df["review_date"], errors="coerce", utc=True)

    if df["review_id"].isna().all():
        df["review_id"] = [f"gen-{i}" for i in range(len(df))]
    df["review_id"] = df["review_id"].astype(str)

    df["word_count"] = df["review_text"].str.split().str.len()
    df["char_count"] = df["review_text"].str.len()
    df["exclamation_count"] = df["review_text"].str.count("!")
    df["sentiment_label"] = df["rating"].apply(sentiment_from_rating)
    df["ingested_at"] = datetime.now(timezone.utc).isoformat()
    return df.reset_index(drop=True)


def generate_sample_sales(n: int = 200, seed: int = 42) -> pd.DataFrame:
    rng = random.Random(seed)
    rows = []
    for i in range(n):
        actual_price = round(rng.uniform(20, 500), 2)
        discount_pct = rng.uniform(0, 60)
        rows.append(
            {
                "product_id": f"SAMPLE{i:05d}",
                "product_name": f"Sample Product {i}",
                "category": rng.choice(CATEGORIES),
                "discounted_price": round(actual_price * (1 - discount_pct / 100), 2),
                "actual_price": actual_price,
                "discount_percentage": round(discount_pct, 1),
                "rating": round(rng.uniform(1, 5), 1),
                "rating_count": rng.randint(0, 5000),
                "about_product": "Produto de amostra gerado para testes locais do pipeline.",
                "img_link": "",
                "product_link": "",
            }
        )
    return clean_sales(pd.DataFrame(rows))


def generate_sample_reviews(n: int = 600, sample_sales: pd.DataFrame | None = None, seed: int = 42) -> pd.DataFrame:
    rng = random.Random(seed)
    product_ids = sample_sales["product_id"].tolist() if sample_sales is not None else []
    rows = []
    for i in range(n):
        rating = rng.randint(1, 5)
        if rating >= 4:
            words = POSITIVE_WORDS
        elif rating <= 2:
            words = NEGATIVE_WORDS
        else:
            words = NEUTRAL_WORDS
        text = " ".join(rng.choices(words, k=rng.randint(4, 12)))
        product_id = rng.choice(product_ids) if product_ids and rng.random() < 0.5 else f"OTHER{i:05d}"
        rows.append(
            {
                "review_id": f"r{i:06d}",
                "product_id": product_id,
                "user_id": f"u{rng.randint(1, 5000):05d}",
                "review_title": text.split(" ")[0],
                "review_text": text,
                "rating": rating,
                "review_date": "",
            }
        )
    return process_reviews(pd.DataFrame(rows))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--sample-fallback", action="store_true",
                         help="Gera dados sintéticos caso os CSVs reais não sejam encontrados.")
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    sales_path = _find_raw_file(args.raw_dir, SALES_ALIASES, SALES_REQUIRED)
    reviews_path = _find_raw_file(args.raw_dir, REVIEWS_ALIASES, REVIEWS_REQUIRED)

    if sales_path is not None:
        print(f"[sales] usando {sales_path}")
        sales_df = clean_sales(pd.read_csv(sales_path))
    elif args.sample_fallback:
        print("[sales] arquivo real não encontrado, gerando amostra sintética")
        sales_df = generate_sample_sales()
    else:
        raise SystemExit(
            "Nenhum CSV de vendas encontrado em data/raw/. "
            "Baixe o dataset (ver data/README.md) ou use --sample-fallback."
        )

    if reviews_path is not None:
        print(f"[reviews] usando {reviews_path}")
        reviews_df = process_reviews(pd.read_csv(reviews_path))
    elif args.sample_fallback:
        print("[reviews] arquivo real não encontrado, gerando amostra sintética")
        reviews_df = generate_sample_reviews(sample_sales=sales_df)
    else:
        raise SystemExit(
            "Nenhum CSV de reviews encontrado em data/raw/. "
            "Baixe o dataset (ver data/README.md) ou use --sample-fallback."
        )

    sales_df.to_csv(args.out_dir / "sales.csv", index=False)
    reviews_df.to_csv(args.out_dir / "reviews.csv", index=False)
    print(f"OK: {len(sales_df)} produtos e {len(reviews_df)} reviews gravados em {args.out_dir}")


if __name__ == "__main__":
    main()
