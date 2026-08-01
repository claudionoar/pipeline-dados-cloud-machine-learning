# Definição do problema

## Domínio de aplicação

E-commerce (marketplace Olist) — pedidos, itens, pagamentos, produtos, clientes, vendedores e
reviews de um marketplace brasileiro real.

## Usuário / tomador de decisão

Gestor de operações/logística do marketplace, responsável por acompanhar o cumprimento dos
prazos de entrega prometidos ao cliente.

## Decisão que será apoiada

Quais pedidos têm risco elevado de chegar atrasados (depois da data estimada de entrega) —
para priorizar intervenção proativa: troca de transportadora, aviso antecipado ao cliente,
ou negociação com o vendedor, antes que o atraso vire uma reclamação ou review negativa.

## Fontes de dados

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
— dataset relacional real (~100 mil pedidos, 2016-2018), já colocado em `data/raw/`:

- **Estruturado**: pedidos, itens de pedido, pagamentos, produtos, clientes, vendedores e
  geolocalização por CEP (`olist_orders_dataset.csv`, `olist_order_items_dataset.csv`,
  `olist_order_payments_dataset.csv`, `olist_products_dataset.csv`,
  `olist_customers_dataset.csv`, `olist_sellers_dataset.csv`, `olist_geolocation_dataset.csv`).
- **Não estruturado**: `olist_order_reviews_dataset.csv` — texto livre de reviews de clientes
  (`review_comment_message`), usado nos indicadores de sentimento do dashboard (não é a fonte
  do modelo de ML principal, ver abaixo).

Detalhes de origem, colunas e limitações: ver `docs/dicionario_dados.md`.

## Tarefa de Aprendizagem de Máquina

**Classificação binária**: o pedido vai atrasar (`is_late = true`, ou seja,
`order_delivered_customer_date > order_estimated_delivery_date`)? Features estruturadas do
pedido (frete, prazo estimado, distância cliente-vendedor, número de itens, parcelamento
etc.), construídas em `mart_late_delivery_features` (dbt) a partir do grafo real de
pedido→itens→produtos→vendedores→clientes→geolocalização do Olist.

## Resultado esperado da solução

- Uma tabela de predições por pedido (`mart_ml_results`), com rastreabilidade até o dado
  bruto (`order_id`).
- Indicadores agregados por estado do cliente (`mart_delivery_kpis`): % de pedidos atrasados,
  tempo médio de entrega — e por categoria de produto (`mart_sentiment_kpis`): % de reviews
  negativas, complementando a visão de risco operacional com a percepção do cliente.
- Um dashboard (Metabase) que permite ao gestor filtrar por região e identificar rapidamente
  onde o risco de atraso é maior, para priorizar ação.
