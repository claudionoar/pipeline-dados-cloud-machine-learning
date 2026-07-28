# dashboard/ — Visualização (Metabase)

O Metabase sobe junto com o resto do stack via `docker compose up` (raiz do projeto) —
ver serviços `metabase` e `metabase-db` no `docker-compose.yml`. Acesse depois em
http://localhost:3000.

## Conexão com o Snowflake (passo manual, primeira vez)

1. Abra http://localhost:3000 e complete o setup inicial do Metabase (cria o usuário admin).
2. **Admin settings → Databases → Add a database**:
   - Database type: `Snowflake`
   - Account: valor de `SNOWFLAKE_ACCOUNT` (.env)
   - User / Password / Role / Warehouse / Database: os mesmos do `.env`
   - Schema filter: `ANALYTICS` (onde o dbt materializa os marts)
3. Salve e aguarde o Metabase sincronizar o schema (ele lista `mart_sentiment_kpis`,
   `mart_ml_results`, `dim_product`, `dim_category`, `fact_review`, `fact_sales`).

## Cards / dashboard sugerido ("Reputação de produto — apoio à decisão")

Requisitos mínimos do enunciado (4.7): indicadores principais, visualização dos dados
tratados, visualização dos resultados do modelo, pelo menos um filtro.

| Card | Fonte | Tipo |
|---|---|---|
| Total de reviews / rating médio / % negativas (KPIs) | `mart_sentiment_kpis` | Number/Trend |
| Distribuição de sentimento por categoria | `mart_sentiment_kpis` (group by `category_root`) | Barra empilhada |
| Top 10 produtos com maior % de reviews negativas | `mart_sentiment_kpis` (order by `pct_negative desc`) | Tabela |
| Preço vs. rating por categoria | `fact_sales` + `dim_category` | Dispersão |
| Acurácia hard-code vs. sklearn no conjunto de teste | `mart_ml_results` (agregando `hardcode_correct`/`sklearn_correct`) | Barra |
| Exemplos de acerto/erro do modelo (para a análise qualitativa) | `mart_ml_results` (filtro `sklearn_correct = false`) | Tabela |
| **Filtro**: seletor de `category_root` aplicado a todos os cards acima | — | Dashboard filter |

## Como o dashboard apoia a decisão

O gestor de categoria/produto usa o filtro de categoria para focar em uma área do catálogo,
identifica produtos com `pct_negative` alta e `review_count` relevante (não apenas 1-2
reviews ruins isolados) e prioriza esses produtos para investigação de qualidade ou resposta
ao cliente — a decisão descrita em `docs/problema.md`.

## Exportando o dashboard para o repositório

Depois de montado, exporte a definição (Admin → ... → Export) ou tire prints das telas e
salve em `dashboard/evidencias/` (crie a pasta) para anexar ao relatório/apresentação
(entregável 6.1: "evidências de execução, como prints, logs ou exemplos de saída").
