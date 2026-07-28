# Avaliação

## 5.1 Conjunto de avaliação

- **Split treino/teste estratificado** (80/20, `random_state=42`) sobre `ml_feature_table`,
  feito em `machine-learning/data_prep.py::split_dataset`. Estratificado por
  `sentiment_label` para preservar a proporção das 3 classes no conjunto de teste.
- **Perguntas de negócio que o dashboard deve responder** (usadas para validar os cards do
  Metabase, ver `dashboard/README.md`):
  1. Quais categorias concentram a maior proporção de reviews negativas?
  2. Quais produtos específicos (com volume relevante de reviews) têm pior sentimento?
  3. O modelo de sentimento é confiável o suficiente para confiar nas predições agregadas
     (accuracy/F1 do conjunto de teste vs. baseline)?
  4. Existe relação entre preço/desconto e sentimento por categoria?

## 5.2 Métricas (tarefa de classificação)

Calculadas em `machine-learning/evaluate.py::compute_metrics` para os 3 modelos
(baseline majority-class, Naive Bayes hard-code, Naive Bayes sklearn):

- accuracy
- precision (macro)
- recall (macro)
- F1-score (macro)
- matriz de confusão (`confusion_matrix_hardcode.png`, `confusion_matrix_sklearn.png`)

Resultados numéricos completos em `machine-learning/output/metrics_comparison.json` após
rodar `train_and_compare.py` (gerado ao rodar o pipeline — não versionado, ver `.gitignore`).

## 5.3 Avaliação do pipeline

| Aspecto | Como é verificado |
|---|---|
| Execução correta das etapas | DAG do Airflow (`amazon_pipeline`) — status de cada task na UI |
| Organização dos dados | Camadas bronze/silver/gold no S3 (`s3/README.md`) |
| Qualidade dos dados após transformação | Testes dbt (`dbt test`) — not_null/unique/accepted_values/relationships |
| Testes dbt | 10 testes distribuídos em staging e marts (`dbt/README.md`) |
| Rastreabilidade bruto → tratado → predição | `review_id`/`product_id` preservados em toda a cadeia: `data/raw` → `RAW.REVIEWS` → `fact_review`/`ml_feature_table` → `RAW.ML_PREDICTIONS` → `mart_ml_results` |
| Limitações da arquitetura | Ver seção "Limitações" abaixo e `machine-learning/README.md` |

## 5.4 Avaliação qualitativa (preencher após rodar o pipeline com dados reais)

Usar `mart_ml_results` (filtrando `sklearn_correct = false` / `= true`) para localizar
exemplos concretos:

- **Exemplos de acerto**: reviews claramente positivas/negativas classificadas corretamente
  por ambos os modelos — preencher com 2-3 exemplos reais (`review_text`, `true_label`,
  predições) após a primeira execução completa.
- **Exemplos de erro**: reviews ambíguas (ex.: rating 3, sarcasmo, negação — "não gostei nada
  do produto, mas o preço compensa") tendem a ser mal classificadas por um modelo bag-of-words.
- **Possíveis causas dos erros**: (1) rótulo derivado do rating é uma proxy imperfeita de
  sentimento real; (2) Naive Bayes bag-of-words ignora ordem das palavras/negação; (3)
  vocabulário limitado a `max_features` palavras mais frequentes pode descartar termos raros
  mas discriminativos.
- **Limitações dos dados**: catálogo de produtos (dataset 1) e corpus de reviews (dataset 2)
  não compartilham os mesmos produtos na maior parte dos casos (ver
  `docs/dicionario_dados.md`); rótulo de sentimento não é anotado manualmente.
- **Riscos de uso da solução**: decisões de negócio não devem se basear apenas na predição de
  um review isolado — o valor está nos agregados (`mart_sentiment_kpis`) com volume mínimo de
  reviews por produto.
- **Melhorias futuras**: usar embeddings (word2vec/transformers) em vez de bag-of-words;
  anotação manual de uma amostra para validar o rótulo derivado do rating; incorporar dados
  de imagem (`img_link`) como segunda fonte não estruturada complementar.
