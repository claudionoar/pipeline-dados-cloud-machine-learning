# dashboard/ — Visualização (Metabase)

O Metabase sobe junto com o resto do stack via `docker compose up` (raiz do projeto) —
ver serviços `metabase` e `metabase-db` no `docker-compose.yml`.

## Acesso Rápido ao Dashboard

| Item | Valor |
|---|---|
| **Dashboard** | http://localhost:3000/dashboard/2 |
| **E-mail** | `admin@example.com` |
| **Senha** | `Admin123456!` |

> Após subir os containers com `docker compose up -d`, aguarde ~30 segundos para o Metabase
> inicializar e acesse o link acima diretamente no navegador.

## Conexão com o Snowflake (passo manual, primeira vez)

1. Abra http://localhost:3000 e complete o setup inicial do Metabase (cria o usuário admin).
2. **Admin settings → Databases → Add a database**:
   - Database type: `Snowflake`
   - Account: valor de `SNOWFLAKE_ACCOUNT` (.env)
   - User / Password / Role / Warehouse / Database: os mesmos do `.env`
   - Schema filter: `ANALYTICS` (onde o dbt materializa os marts)
3. Salve e aguarde o Metabase sincronizar o schema (ele lista `mart_delivery_kpis`,
   `mart_sentiment_kpis`, `mart_ml_results`, `dim_customers`, `dim_products`, `fact_orders`).

## Cards / dashboard sugerido ("Risco de atraso na entrega — apoio à decisão")

Requisitos mínimos do enunciado (4.7): indicadores principais, visualização dos dados
tratados, visualização dos resultados do modelo, pelo menos um filtro.

| Card | Fonte | Tipo |
|---|---|---|
| Total de pedidos / % atrasados / tempo médio de entrega (KPIs) | `mart_delivery_kpis` | Number/Trend |
| % de atraso por estado do cliente | `mart_delivery_kpis` (group by `customer_state`) | Mapa/Barra |
| Top estados com maior tempo médio de entrega | `mart_delivery_kpis` (order by `avg_delivery_days desc`) | Tabela |
| % de reviews negativas por categoria | `mart_sentiment_kpis` | Barra empilhada |
| Recall/F1 macro hard-code vs. sklearn no conjunto de teste | `metrics_comparison.json` (import manual) ou `mart_ml_results` (agregando `hardcode_correct`/`sklearn_correct`) | Barra |
| Exemplos de acerto/erro do modelo (para a análise qualitativa) | `mart_ml_results` (filtro `sklearn_correct = false`) | Tabela |
| **Filtro**: seletor de `customer_state` aplicado a todos os cards acima | — | Dashboard filter |

## Como o dashboard apoia a decisão

O gestor de operações/logística usa o filtro de estado para focar em uma região, identifica
onde `pct_late` está mais alto com `order_count` relevante (não apenas 1-2 pedidos isolados) e
prioriza essas regiões/rotas para intervenção proativa (troca de transportadora, aviso ao
cliente) — a decisão descrita em `docs/problema.md`.

## Exportando / Importando o dashboard

A configuração completa do dashboard (cards, queries SQL, layout e filtro global) está
versionada em `dashboard/metabase_export/`:

| Arquivo | Conteúdo |
|---|---|
| `cards.json` | 8 cards com queries SQL, tipo de visualização e configurações |
| `dashboard.json` | Layout (posição/tamanho de cada card), filtro global e mapeamentos |
| `database_connection.json` | Configuração da conexão Snowflake (sem senha) |

### Reimportando em uma nova instância do Metabase

1. Suba o stack: `docker compose up -d`
2. Complete o setup inicial do Metabase (crie o admin e conecte o Snowflake)
3. Execute o script de importação:
   ```bash
   python dashboard/import_metabase.py
   ```
   O script recria automaticamente todos os 8 cards e o dashboard com o layout original.

### Evidências (prints)

Screenshots do dashboard estão em `dashboard/evidencias/` para anexar ao relatório
(entregável 6.1: "evidências de execução, como prints, logs ou exemplos de saída").
