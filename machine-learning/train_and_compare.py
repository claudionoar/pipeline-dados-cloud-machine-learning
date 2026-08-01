"""Orquestra o treino/avaliação/comparação dos modelos de previsão de atraso na entrega e
grava os resultados.

Uso:
    python train_and_compare.py --source snowflake   # produção (via Airflow)
    python train_and_compare.py --source csv         # usa data/processed/late_delivery_features.csv
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

from data_prep import FEATURE_COLUMNS, load_dataset, split_dataset
from evaluate import compute_metrics, majority_baseline, save_confusion_matrix, save_metrics_json
from hardcode_logistic_regression import LogisticRegressionScratch
from sklearn_model import build_pipeline

OUTPUT_DIR = Path(__file__).resolve().parent / "output"
MODEL_VERSION = "late-delivery-logreg-v1"
LABELS = ["on_time", "late"]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=["snowflake", "csv", "sample"], default="snowflake")
    args = parser.parse_args()

    print(f"Carregando dados (source={args.source})...")
    df = load_dataset(source=args.source)
    train_df, test_df = split_dataset(df)
    print(f"Treino: {len(train_df)} | Teste: {len(test_df)} | Classes: {LABELS}")
    print(f"Taxa de atraso no treino: {(train_df['label'] == 'late').mean():.1%}")

    all_metrics = {}

    baseline_preds = majority_baseline(train_df["label"], test_df["label"])
    all_metrics["baseline_majority"] = compute_metrics(test_df["label"], baseline_preds, LABELS)

    print("Treinando regressão logística hard-code (numpy, sem sklearn)...")
    hardcode_model = LogisticRegressionScratch()
    hardcode_model.fit(train_df[FEATURE_COLUMNS], train_df["is_late"])
    hardcode_preds = hardcode_model.predict(test_df[FEATURE_COLUMNS])
    all_metrics["logreg_hardcode"] = compute_metrics(test_df["label"], hardcode_preds, LABELS)

    print("Treinando regressão logística com scikit-learn (StandardScaler + LogisticRegression)...")
    sklearn_model = build_pipeline()
    sklearn_model.fit(train_df[FEATURE_COLUMNS], train_df["is_late"])
    sklearn_pred_bool = sklearn_model.predict(test_df[FEATURE_COLUMNS])
    sklearn_preds = ["late" if p else "on_time" for p in sklearn_pred_bool]
    all_metrics["logreg_sklearn"] = compute_metrics(test_df["label"], sklearn_preds, LABELS)

    print("\nComparação de métricas:")
    for name, metrics in all_metrics.items():
        formatted = ", ".join(f"{k}={v:.3f}" for k, v in metrics.items())
        print(f"  {name}: {formatted}")

    save_metrics_json(all_metrics, OUTPUT_DIR / "metrics_comparison.json")
    save_confusion_matrix(test_df["label"], hardcode_preds, LABELS,
                           "Regressão Logística (hard-code)", OUTPUT_DIR / "confusion_matrix_hardcode.png")
    save_confusion_matrix(test_df["label"], sklearn_preds, LABELS,
                           "Regressão Logística (sklearn)", OUTPUT_DIR / "confusion_matrix_sklearn.png")

    predictions_df = pd.DataFrame({
        "order_id": test_df["order_id"].values,
        "true_label": test_df["label"].values,
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
