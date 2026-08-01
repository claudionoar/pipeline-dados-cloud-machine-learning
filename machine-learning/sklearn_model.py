"""Mesmo algoritmo de `hardcode_logistic_regression.py` (regressão logística sobre features
estruturadas padronizadas), agora usando bibliotecas Python (scikit-learn), conforme pede o
item 4.6.b do enunciado."""
from __future__ import annotations

from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


def build_pipeline() -> Pipeline:
    return Pipeline([
        ("scaler", StandardScaler()),
        ("clf", LogisticRegression(class_weight="balanced", max_iter=2000)),
    ])
