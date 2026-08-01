"""Regressão logística implementada do zero (sem scikit-learn), para servir de implementação
"hard-code" exigida no item 4.6.a do enunciado - agora sobre features estruturadas do pedido
(frete, prazo, distância cliente-vendedor etc.) para prever atraso na entrega, em vez de texto.

Algoritmo: padronização de features (z-score) + gradiente descendente em lote sobre a
log-verossimilhança logística, com regularização L2 e ponderação de classe (o dataset é
desbalanceado: só ~8% dos pedidos entregues atrasam) - o mesmo princípio usado por
`sklearn.linear_model.LogisticRegression(class_weight="balanced")` (comparado em
`sklearn_model.py`), mas com o gradiente calculado manualmente em numpy puro.
"""
from __future__ import annotations

import numpy as np
import pandas as pd


def _sigmoid(z: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-np.clip(z, -30, 30)))


class LogisticRegressionScratch:
    def __init__(self, lr: float = 0.5, epochs: int = 2000, l2: float = 0.01,
                 class_weight: str | None = "balanced"):
        self.lr = lr
        self.epochs = epochs
        self.l2 = l2
        self.class_weight = class_weight
        self.mean_: np.ndarray | None = None
        self.std_: np.ndarray | None = None
        self.weights_: np.ndarray | None = None
        self.bias_: float = 0.0

    def _standardize(self, X: np.ndarray) -> np.ndarray:
        return (X - self.mean_) / self.std_

    def fit(self, X: pd.DataFrame, y: pd.Series) -> "LogisticRegressionScratch":
        X = np.asarray(X, dtype=float)
        y = np.asarray(y, dtype=float)
        n_samples, n_features = X.shape

        self.mean_ = X.mean(axis=0)
        self.std_ = X.std(axis=0)
        self.std_[self.std_ == 0] = 1.0
        Xs = self._standardize(X)

        if self.class_weight == "balanced":
            n_pos = max(y.sum(), 1)
            n_neg = max(n_samples - y.sum(), 1)
            sample_weight = np.where(y == 1, n_samples / (2 * n_pos), n_samples / (2 * n_neg))
        else:
            sample_weight = np.ones(n_samples)

        self.weights_ = np.zeros(n_features)
        self.bias_ = 0.0
        for _ in range(self.epochs):
            z = Xs @ self.weights_ + self.bias_
            p = _sigmoid(z)
            error = sample_weight * (p - y)
            grad_w = (Xs.T @ error) / n_samples + self.l2 * self.weights_
            grad_b = error.mean()
            self.weights_ -= self.lr * grad_w
            self.bias_ -= self.lr * grad_b
        return self

    def predict_proba(self, X: pd.DataFrame) -> np.ndarray:
        Xs = self._standardize(np.asarray(X, dtype=float))
        return _sigmoid(Xs @ self.weights_ + self.bias_)

    def predict(self, X: pd.DataFrame, threshold: float = 0.5) -> list[str]:
        proba = self.predict_proba(X)
        return ["late" if p >= threshold else "on_time" for p in proba]
