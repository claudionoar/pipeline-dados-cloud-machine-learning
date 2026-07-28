"""Mesmo algoritmo de `hardcode_naive_bayes.py` (Naive Bayes multinomial sobre bag-of-words),
agora usando bibliotecas Python (scikit-learn), conforme pede o item 4.6.b do enunciado."""
from __future__ import annotations

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline


def build_pipeline(max_features: int = 4000) -> Pipeline:
    return Pipeline([
        ("tfidf", TfidfVectorizer(max_features=max_features, lowercase=True)),
        ("clf", MultinomialNB()),
    ])
