# Avaliação

## 5.1 Conjunto de avaliação

- **Split treino/teste estratificado** (80/20, `random_state=42`) sobre
  `mart_late_delivery_features`, feito em `machine-learning/data_prep.py::split_dataset`.
  Estratificado por `is_late` para preservar, no conjunto de teste, a proporção real de
  pedidos atrasados (~8%).
- **Perguntas de negócio que o dashboard deve responder** (usadas para validar os cards do
  Metabase, ver `dashboard/README.md`):
  1. Quais estados/regiões concentram a maior proporção de pedidos atrasados?
  2. O modelo de previsão de atraso é confiável o suficiente para acionar intervenção
     proativa (recall/F1 do conjunto de teste vs. baseline majority)?
  3. Existe relação entre distância cliente-vendedor / frete e taxa de atraso?
  4. Categorias com mais reviews negativas coincidem com regiões de maior atraso na entrega?

## 5.2 Métricas (tarefa de classificação)

Calculadas em `machine-learning/evaluate.py::compute_metrics` para os 3 modelos
(baseline majority-class, regressão logística hard-code, regressão logística sklearn):

- accuracy
- precision (macro)
- recall (macro)
- F1-score (macro)
- matriz de confusão (`confusion_matrix_hardcode.png`, `confusion_matrix_sklearn.png`)

Accuracy sozinha é enganosa aqui: como só ~8% dos pedidos atrasam, um modelo que sempre prevê
"on_time" já acerta ~92% sem nenhum valor prático — por isso o critério de comparação
principal é **F1/recall macro**, que penaliza não identificar os atrasos reais.

Resultados numéricos completos em `machine-learning/output/metrics_comparison.json` após
rodar `train_and_compare.py` (gerado ao rodar o pipeline — não versionado, ver `.gitignore`).

## 5.3 Avaliação do pipeline

| Aspecto | Como é verificado |
|---|---|
| Execução correta das etapas | DAG do Airflow (`olist_pipeline`) — status de cada task na UI |
| Organização dos dados | Camadas bronze/silver/gold no S3 (`s3/README.md`) |
| Qualidade dos dados após transformação | Testes dbt (`dbt test`) — not_null/unique/accepted_values/relationships |
| Testes dbt | Distribuídos em staging e marts, cobrindo as 9 tabelas do dataset (`dbt/README.md`) |
| Rastreabilidade bruto → tratado → predição | `order_id` preservado em toda a cadeia: `data/raw` → `RAW.ORDERS` → `fact_orders`/`mart_late_delivery_features` → `RAW.ML_PREDICTIONS` → `mart_ml_results` |
| Limitações da arquitetura | Ver seção "Limitações" abaixo e `machine-learning/README.md` |

## 5.4 Avaliação qualitativa (preencher após rodar o pipeline com dados reais)

Usar `mart_ml_results` (filtrando `sklearn_correct = false` / `= true`) para localizar
exemplos concretos:

- **Exemplos de acerto**: pedidos com distância cliente-vendedor alta e frete elevado
  corretamente previstos como atrasados por ambos os modelos — preencher com 2-3 exemplos
  reais (`order_id`, `true_label`, predições) após a primeira execução completa.
- **Exemplos de erro**: pedidos próximos (mesmo estado) mas ainda assim atrasados por causas
  não capturadas nas features (problema pontual da transportadora, ruptura de estoque) tendem
  a ser mal classificados — o modelo não tem acesso à causa raiz do atraso.
- **Possíveis causas dos erros**: (1) `distance_km` fica nulo quando o CEP não aparece em
  `olist_geolocation_dataset.csv`; (2) pedidos com múltiplos vendedores usam a localização do
  primeiro item como aproximação; (3) o modelo não enxerga eventos externos (greve,
  feriado, clima) que afetam a entrega.
- **Limitações dos dados**: `review_comment_message` vazio em ~59% dos casos (usado só nos
  KPIs de sentimento do dashboard, não no modelo de ML); cobertura de `olist_geolocation_dataset.csv`
  não é 100% dos prefixos de CEP (ver `docs/dicionario_dados.md`).
- **Riscos de uso da solução**: a previsão é probabilística e desbalanceada — usar como
  sinal de priorização (lista de pedidos para revisão manual), não como decisão automática de
  cancelamento/reembolso.
- **Melhorias futuras**: incorporar histórico da transportadora/vendedor (taxa de atraso
  passada) como feature; usar a data efetiva de postagem (`order_delivered_carrier_date`) para
  separar atraso "do vendedor" vs. "da transportadora"; testar um modelo não linear (árvore/
  gradient boosting) como terceiro ponto de comparação.
