"""Orquestra o treino/avaliação/comparação dos modelos de sentimento e grava os resultados.

Uso:
    python train_and_compare.py --source snowflake   # produção (via Airflow)
    python train_and_compare.py --source csv         # usa data/processed/reviews.csv
    python train_and_compare.py --source sample       # dados sintéticos, para testar o código

Saídas em machine-learning/output/:
    metrics_comparison.json          -- accuracy/precision/recall/F1 do baseline e dos 2 modelos
    confusion_matrix_hardcode.png
    confusion_matrix_sklearn.png
    predictions.csv                   -- predições do conjunto de teste (rastreabilidade)
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from data_prep import load_dataset, split_dataset
from evaluate import compute_metrics, majority_baseline, save_confusion_matrix, save_metrics_json
from hardcode_naive_bayes import MultinomialNaiveBayesScratch
from sklearn_model import build_pipeline

OUTPUT_DIR = Path(__file__).resolve().parent / "output"
MODEL_VERSION = "sentiment-nb-v1"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=["snowflake", "csv", "sample"], default="snowflake")
    parser.add_argument("--max-features", type=int, default=4000)
    args = parser.parse_args()

    print(f"Carregando dados (source={args.source})...")
    df = load_dataset(source=args.source)
    train_df, test_df = split_dataset(df)
    labels = sorted(df["sentiment_label"].unique())
    print(f"Treino: {len(train_df)} | Teste: {len(test_df)} | Classes: {labels}")

    all_metrics = {}

    baseline_preds = majority_baseline(train_df["sentiment_label"], test_df["sentiment_label"])
    all_metrics["baseline_majority"] = compute_metrics(test_df["sentiment_label"], baseline_preds, labels)

    print("Treinando Naive Bayes hard-code (numpy, sem sklearn)...")
    hardcode_model = MultinomialNaiveBayesScratch(max_features=args.max_features)
    hardcode_model.fit(train_df["review_text"], train_df["sentiment_label"])
    hardcode_preds = hardcode_model.predict(test_df["review_text"])
    all_metrics["naive_bayes_hardcode"] = compute_metrics(test_df["sentiment_label"], hardcode_preds, labels)

    print("Treinando Naive Bayes com scikit-learn (TfidfVectorizer + MultinomialNB)...")
    sklearn_model = build_pipeline(max_features=args.max_features)
    sklearn_model.fit(train_df["review_text"], train_df["sentiment_label"])
    sklearn_preds = list(sklearn_model.predict(test_df["review_text"]))
    all_metrics["naive_bayes_sklearn"] = compute_metrics(test_df["sentiment_label"], sklearn_preds, labels)

    print("\nComparação de métricas:")
    for name, metrics in all_metrics.items():
        formatted = ", ".join(f"{k}={v:.3f}" for k, v in metrics.items())
        print(f"  {name}: {formatted}")

    save_metrics_json(all_metrics, OUTPUT_DIR / "metrics_comparison.json")
    save_confusion_matrix(test_df["sentiment_label"], hardcode_preds, labels,
                           "Naive Bayes (hard-code)", OUTPUT_DIR / "confusion_matrix_hardcode.png")
    save_confusion_matrix(test_df["sentiment_label"], sklearn_preds, labels,
                           "Naive Bayes (sklearn)", OUTPUT_DIR / "confusion_matrix_sklearn.png")

    predictions_df = pd.DataFrame({
        "review_id": test_df["review_id"].values,
        "product_id": test_df["product_id"].values,
        "true_label": test_df["sentiment_label"].values,
        "predicted_label_hardcode": hardcode_preds,
        "predicted_label_sklearn": sklearn_preds,
        "model_version": MODEL_VERSION,
        "predicted_at": datetime.now(timezone.utc).isoformat(),
    })
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    predictions_path = OUTPUT_DIR / "predictions.csv"
    predictions_df.to_csv(predictions_path, index=False)

    print(f"\nPredições salvas em {predictions_path}")
    print(f"Métricas salvas em {OUTPUT_DIR / 'metrics_comparison.json'}")


if __name__ == "__main__":
    main()
