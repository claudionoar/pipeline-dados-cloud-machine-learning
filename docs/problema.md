# Definição do problema

## Domínio de aplicação

E-commerce (marketplace Amazon) — catálogo de produtos e reviews de clientes.

## Usuário / tomador de decisão

Gestor de categoria/produto (product/category manager) de um marketplace ou de um vendedor
que opera na Amazon.

## Decisão que será apoiada

Quais produtos do catálogo precisam de atenção prioritária — por queda de reputação
percebida (aumento de reviews negativas), possíveis problemas de qualidade, ou
descontentamento recorrente em uma categoria — para decidir onde investigar, ajustar preço/
descrição, ou responder ativamente a clientes.

## Fontes de dados

- **Estruturado**: [`karkavelrajaj/amazon-sales-dataset`](https://www.kaggle.com/datasets/karkavelrajaj/amazon-sales-dataset)
  — catálogo de produtos (nome, categoria, preço, desconto, rating agregado).
- **Não estruturado**: [`yasserh/amazon-product-reviews-dataset`](https://www.kaggle.com/datasets/yasserh/amazon-product-reviews-dataset)
  — texto livre de reviews de clientes.

Detalhes de origem, colunas e limitações: ver `docs/dicionario_dados.md`.

## Tarefa de Aprendizagem de Máquina

**Classificação** de sentimento da review em três classes (`positive` / `neutral` /
`negative`), a partir do texto (`review_text`). O rótulo de treino é derivado do rating
numérico da própria review (>=4 → positive, ==3 → neutral, <=2 → negative) — uma técnica
padrão em datasets de review sem anotação manual de sentimento.

## Resultado esperado da solução

- Uma tabela de predições por review (`mart_ml_results`), com rastreabilidade até o dado
  bruto (`review_id`/`product_id`).
- Indicadores agregados por produto/categoria (`mart_sentiment_kpis`): % de reviews
  positivas/neutras/negativas, volume de reviews, rating médio.
- Um dashboard (Metabase) que permite ao gestor filtrar por categoria e identificar
  rapidamente os produtos com maior concentração de sentimento negativo, para priorizar ação.
