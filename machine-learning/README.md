# machine-learning/ — Previsão de atraso na entrega

Tarefa de ML (item 4.6 do enunciado): **classificação binária** — o pedido vai chegar atrasado
(`is_late = true`, ou seja, `order_delivered_customer_date > order_estimated_delivery_date`)?
Features estruturadas do pedido (frete, prazo estimado, distância cliente-vendedor, número de
itens, parcelamento etc.), materializadas por
`dbt/olist_pipeline/models/marts/ml/mart_late_delivery_features.sql`.

| Arquivo | Papel |
|---|---|
| `data_prep.py` | Carrega `mart_late_delivery_features` (Snowflake, dbt) ou o CSV silver, faz split treino/teste estratificado (80/20). |
| `hardcode_logistic_regression.py` | **Implementação hard-code** (4.6.a): regressão logística escrita do zero em numpy (padronização de features, gradiente descendente em lote, regularização L2, ponderação de classe). |
| `sklearn_model.py` | **Implementação com biblioteca** (4.6.b): `StandardScaler` + `LogisticRegression(class_weight="balanced")` do scikit-learn — mesmo algoritmo, para comparação direta. |
| `evaluate.py` | Baseline (majority-class), métricas (accuracy/precision/recall/F1 macro) e matriz de confusão. |
| `train_and_compare.py` | Orquestra tudo e grava `output/metrics_comparison.json`, `output/predictions.csv` e as matrizes de confusão. |

## Rodando

```bash
cd machine-learning
pip install -r requirements.txt

# com a base já carregada no Snowflake (fluxo oficial, chamado pelo Airflow):
python train_and_compare.py --source snowflake

# ou localmente, sem Snowflake, usando um export manual de mart_late_delivery_features:
python train_and_compare.py --source csv

# ou totalmente offline, com dados sintéticos (só para validar que o código roda):
python train_and_compare.py --source sample
```

## Por que regressão logística

O alvo (`is_late`) é binário e as features são todas numéricas/estruturadas (não texto) — ao
contrário do dataset Amazon anterior (sentimento a partir de texto, resolvido com Naive
Bayes), aqui regressão logística é o algoritmo mais direto de implementar "hard-code" de forma
fiel ao que a biblioteca faz (combinação linear + sigmoide + gradiente descendente sobre a
log-verossimilhança), o que torna a comparação entre as duas implementações (4.6.a vs. 4.6.b)
uma comparação de *implementação*, não de *algoritmo*.

O dataset é desbalanceado (~8% dos pedidos entregues atrasam), por isso os dois modelos usam
ponderação de classe (`class_weight="balanced"` / equivalente no hard-code) e a comparação
usa **F1/recall macro**, não só accuracy — um modelo que sempre prevê "on_time" já acerta
~92% (baseline majority) sem nenhum valor prático para o negócio.

## Rastreabilidade

`predictions.csv` guarda, por pedido do conjunto de teste: `order_id`, `true_label`
(`on_time`/`late`), a predição de cada modelo e `model_version`/`predicted_at`. Esse arquivo é
subido para `s3://.../silver/ml_predictions/` (`s3/upload_to_s3.py --layer predictions`) e
carregado em `RAW.ML_PREDICTIONS` (`snowflake/sql/05_copy_predictions.sql`), de onde o dbt
materializa `mart_ml_results` para o dashboard — fechando o caminho dado bruto → dado tratado
→ predição exigido na seção 5.3 do enunciado.

## Limitações conhecidas (ver docs/avaliacao.md)

- Pedidos com múltiplos vendedores/itens usam a localização do primeiro item para a distância
  cliente-vendedor (`mart_late_delivery_features`) — simplificação documentada no modelo dbt.
- `distance_km` fica nulo quando o prefixo de CEP do cliente ou do vendedor não aparece em
  `olist_geolocation_dataset.csv` (cobertura incompleta do dataset original).
- O alvo é derivado apenas da data estimada vs. real de entrega, sem considerar o motivo do
  atraso (transportadora, aduana, estoque) — o modelo prevê o sintoma, não a causa raiz.
