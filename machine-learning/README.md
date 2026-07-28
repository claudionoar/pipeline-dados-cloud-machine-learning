# machine-learning/ — Classificação de sentimento

Tarefa de ML (item 4.6 do enunciado): **classificação** de sentimento de reviews
(negativo/neutro/positivo), com rótulo derivado do rating (`s3/processing.py`).

| Arquivo | Papel |
|---|---|
| `data_prep.py` | Carrega `ml_feature_table` (Snowflake, dbt) ou o CSV silver, faz split treino/teste estratificado. |
| `hardcode_naive_bayes.py` | **Implementação hard-code** (4.6.a): Naive Bayes multinomial escrito do zero em numpy (contagem de palavras, suavização de Laplace, log-probabilidades). |
| `sklearn_model.py` | **Implementação com biblioteca** (4.6.b): `TfidfVectorizer` + `MultinomialNB` do scikit-learn — mesmo algoritmo, para comparação direta. |
| `evaluate.py` | Baseline (majority-class), métricas (accuracy/precision/recall/F1 macro) e matriz de confusão. |
| `train_and_compare.py` | Orquestra tudo e grava `output/metrics_comparison.json`, `output/predictions.csv` e as matrizes de confusão. |

## Rodando

```bash
cd machine-learning
pip install -r requirements.txt

# com a base já carregada no Snowflake (fluxo oficial, chamado pelo Airflow):
python train_and_compare.py --source snowflake

# ou localmente, sem Snowflake, usando o CSV gerado por s3/processing.py:
python train_and_compare.py --source csv

# ou totalmente offline, com dados sintéticos (só para validar que o código roda):
python train_and_compare.py --source sample
```

## Por que Naive Bayes multinomial

É o algoritmo mais direto de implementar "hard-code" de forma fiel ao que a biblioteca faz
(contagem de palavras + probabilidade condicional), o que torna a comparação entre as duas
implementações (4.6.a vs. 4.6.b) uma comparação de *implementação*, não de *algoritmo* —
exatamente o que o enunciado pede ("repetir o processo com o mesmo dataset utilizando
bibliotecas Python e comparar os resultados").

## Rastreabilidade

`predictions.csv` guarda, por review do conjunto de teste: `review_id`, `product_id`,
`true_label`, a predição de cada modelo e `model_version`/`predicted_at`. Esse arquivo é
subido para `s3://.../silver/ml_predictions/` (`s3/upload_to_s3.py --layer predictions`) e
carregado em `RAW.ML_PREDICTIONS` (`snowflake/sql/05_copy_predictions.sql`), de onde o dbt
materializa `mart_ml_results` para o dashboard — fechando o caminho dado bruto → dado tratado
→ predição exigido na seção 5.3 do enunciado.

## Limitações conhecidas (ver docs/avaliacao.md)

- O rótulo de sentimento é derivado do próprio rating da review (proxy comum em datasets de
  reviews), não anotado manualmente — vieses do rating (ex.: reviews 3 estrelas ambíguas)
  se propagam para o rótulo.
- Bag-of-words/TF-IDF não capturam negação ou sarcasmo.
- Nem toda review tem `product_id` presente no catálogo (`dim_product`) — o join de
  `mart_ml_results`/`fact_review` com produto é `LEFT JOIN` e pode ficar nulo nesses casos.
