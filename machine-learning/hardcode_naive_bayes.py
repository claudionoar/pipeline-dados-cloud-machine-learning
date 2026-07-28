"""Naive Bayes multinomial implementado do zero (sem scikit-learn), para servir de
implementação "hard-code" exigida no item 4.6.a do enunciado.

Algoritmo: bag-of-words + suavização de Laplace (add-alpha) sobre log-probabilidades,
exatamente o mesmo princípio usado por `sklearn.naive_bayes.MultinomialNB` (comparado em
`sklearn_model.py`), mas com contagem de palavras e cálculo de probabilidades feitos
manualmente em numpy puro.
"""
from __future__ import annotations

import re
from collections import Counter

import numpy as np

TOKEN_RE = re.compile(r"[a-zà-ÿ]+", re.IGNORECASE)


def tokenize(text: str) -> list[str]:
    return TOKEN_RE.findall(text.lower())


class MultinomialNaiveBayesScratch:
    def __init__(self, alpha: float = 1.0, max_features: int = 4000):
        self.alpha = alpha
        self.max_features = max_features
        self.classes_: list[str] = []
        self.vocab_: dict[str, int] = {}
        self.log_prior_: dict[str, float] = {}
        self.log_likelihood_: dict[str, np.ndarray] = {}

    def fit(self, texts, labels) -> "MultinomialNaiveBayesScratch":
        texts = list(texts)
        labels = list(labels)
        self.classes_ = sorted(set(labels))
        token_lists = [tokenize(t) for t in texts]

        vocab_counts: Counter = Counter()
        for tokens in token_lists:
            vocab_counts.update(tokens)
        top_words = [w for w, _ in vocab_counts.most_common(self.max_features)]
        self.vocab_ = {w: i for i, w in enumerate(top_words)}
        vocab_size = len(self.vocab_)

        class_word_counts = {c: np.zeros(vocab_size) for c in self.classes_}
        class_doc_counts = Counter(labels)

        for tokens, label in zip(token_lists, labels):
            vec = class_word_counts[label]
            for word, count in Counter(tokens).items():
                idx = self.vocab_.get(word)
                if idx is not None:
                    vec[idx] += count

        n_docs = len(labels)
        self.log_prior_ = {c: float(np.log(class_doc_counts[c] / n_docs)) for c in self.classes_}

        self.log_likelihood_ = {}
        for c in self.classes_:
            counts = class_word_counts[c]
            total = counts.sum()
            self.log_likelihood_[c] = np.log((counts + self.alpha) / (total + self.alpha * vocab_size))
        return self

    def _score(self, tokens: list[str]) -> dict[str, float]:
        counts = Counter(t for t in tokens if t in self.vocab_)
        scores = {}
        for c in self.classes_:
            score = self.log_prior_[c]
            log_likelihood = self.log_likelihood_[c]
            for word, count in counts.items():
                score += count * log_likelihood[self.vocab_[word]]
            scores[c] = score
        return scores

    def predict(self, texts) -> list[str]:
        predictions = []
        for text in texts:
            scores = self._score(tokenize(text))
            predictions.append(max(scores, key=scores.get))
        return predictions
