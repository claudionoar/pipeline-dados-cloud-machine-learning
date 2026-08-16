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

### Resultados medidos (execução de 01/08/2026, conjunto de teste com 19.193 pedidos, 8,1% `late`)

| Modelo | Accuracy | Precision macro | Recall macro | F1 macro |
|---|---|---|---|---|
| Baseline (majority-class) | 0,919 | 0,459 | 0,500 | 0,479 |
| Regressão logística **hard-code** | 0,609 | 0,541 | **0,635** | 0,478 |
| Regressão logística **sklearn** | 0,607 | 0,541 | 0,635 | 0,477 |

Leitura dos números: as duas implementações ficam praticamente empatadas (diferença < 0,002 em
todas as métricas), o que era o objetivo — confirma que o hard-code reproduz fielmente a
biblioteca, já que o algoritmo é o mesmo. Ambas **perdem em accuracy** para o baseline (0,61
vs. 0,92) e ganham em recall macro (0,635 vs. 0,500), que é exatamente o trade-off esperado da
ponderação de classe: o modelo troca acertos "fáceis" em pedidos pontuais por capturar os
atrasos reais. Na classe `late` especificamente, o sklearn captura **66,8% dos atrasos**
(1.039 de 1.555) com precisão de apenas 12,9% (7.028 falsos positivos) — o baseline captura 0%.

Esse é o ponto central para o negócio: a solução tem valor como **triagem** (reduz ~19 mil
pedidos a ~8 mil para revisão, contendo 2 em cada 3 atrasos reais), mas a precisão baixa
significa que a maioria dos pedidos sinalizados não vai atrasar — por isso o uso recomendado é
priorização, nunca ação automática (ver "Riscos de uso da solução" abaixo).

Resultados numéricos completos em `machine-learning/output/metrics_comparison.json` e matrizes
de confusão em `confusion_matrix_hardcode.png`/`confusion_matrix_sklearn.png` (gerados ao rodar
o pipeline — não versionados, ver `.gitignore`).

## 5.3 Avaliação do pipeline

| Aspecto | Como é verificado |
|---|---|
| Execução correta das etapas | DAG do Airflow (`olist_pipeline`) — status de cada task na UI |
| Organização dos dados | Camadas bronze/silver/gold no S3 (`aws/s3/README.md`) |
| Qualidade dos dados após transformação | Testes dbt (`dbt test`) — not_null/unique/accepted_values/relationships |
| Testes dbt | Distribuídos em staging e marts, cobrindo as 9 tabelas do dataset (`dbt/README.md`) |
| Rastreabilidade bruto → tratado → predição | `order_id` preservado em toda a cadeia: `data/raw` → `RAW.ORDERS` → `fact_orders`/`mart_late_delivery_features` → `RAW.ML_PREDICTIONS` → `mart_ml_results` |
| Limitações da arquitetura | Ver seção "Limitações" abaixo e `machine-learning/README.md` |

## 5.4 Avaliação qualitativa

Exemplos reais da execução de 01/08/2026 (`model_version = late-delivery-logreg-v1`), extraídos
de `predictions.csv` / `mart_ml_results` — filtrando por `sklearn_correct = true` / `= false`:

- **Exemplos de acerto** — pedidos realmente atrasados, corretamente previstos como `late` pelas
  duas implementações:

  | `order_id` | `true_label` | hard-code | sklearn |
  |---|---|---|---|
  | `ef43d5664bd1ab24fd6b38b5a8ca3cf6` | late | late | late |
  | `369c055c7ea13627ab3d3100c5af3e8b` | late | late | late |
  | `32733fc014b67ef70fa6039dd8c6ba82` | late | late | late |

- **Exemplos de erro (falsos negativos)** — pedidos que atrasaram mas foram previstos como
  `on_time` por ambos os modelos; são os casos mais custosos para o negócio, porque o gestor
  não recebe nenhum sinal de alerta:

  | `order_id` | `true_label` | hard-code | sklearn |
  |---|---|---|---|
  | `d6027c4f8b46f61d7d4a2782b56e603d` | late | on_time | on_time |
  | `2bd2241ff5bd59887a8a706c309c5938` | late | on_time | on_time |
  | `3c438ee632629e70a91116ac30f8d511` | late | on_time | on_time |

  São 516 casos assim no conjunto de teste (33,2% dos atrasos reais). O padrão típico:
  pedidos próximos (mesmo estado) e com frete baixo, que atrasaram por causas não capturadas
  nas features — problema pontual da transportadora, ruptura de estoque — já que o modelo não
  tem acesso à causa raiz do atraso.

- **O erro dominante, porém, é o falso positivo**: 7.028 pedidos sinalizados como `late` que
  chegaram no prazo. Isso vem diretamente da ponderação de classe: com apenas 8% de exemplos
  positivos, forçar o modelo a enxergar os atrasos empurra o limiar de decisão para baixo. É um
  erro "barato" no contexto de triagem (custa uma revisão manual desnecessária), ao contrário
  do falso negativo, mas explica a precisão de 12,9% na classe `late`.
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
