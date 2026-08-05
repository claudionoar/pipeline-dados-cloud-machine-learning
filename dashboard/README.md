# dashboard/ — Visualização (Metabase)

O Metabase sobe junto com o resto do stack via `docker compose up` (raiz do projeto) —
ver serviços `metabase` e `metabase-db` no `docker-compose.yml`.

## Acesso Rápido ao Dashboard

| Item | Valor |
|---|---|
| **Metabase** | http://localhost:3000 |
| **E-mail** | `admin@example.com` |
| **Senha** | `Admin123456!` |

> Após subir os containers com `docker compose up -d`, aguarde ~30 segundos para o Metabase
> inicializar e o serviço `metabase-setup` terminar. O dashboard fica em **Our analytics**
> (menu lateral) com o nome "Risco de Atraso na Entrega - Apoio a Decisao"; o link exato
> (`/dashboard/<id>`) muda a cada resync (ver "Provisionamento automático" abaixo) e é
> impresso ao final de `docker compose logs metabase-setup`.

## Provisionamento automático (admin + Snowflake + dashboard)

Tudo isso acontece sozinho ao rodar `docker compose up -d`: o serviço `metabase-setup`
espera o Metabase ficar disponível, cria o usuário admin, conecta o Snowflake e importa
os cards/dashboard — sem nenhum passo manual na UI. Ver `dashboard/setup_metabase.py`.

- Credenciais do admin vêm de `METABASE_ADMIN_EMAIL` / `METABASE_ADMIN_PASSWORD` (.env,
  raiz do projeto) — os valores padrão são os mesmos da tabela acima.
- A conexão Snowflake usa `SNOWFLAKE_ACCOUNT/USER/PASSWORD/ROLE/WAREHOUSE/DATABASE/SCHEMA`
  do mesmo `.env`, aplicados sobre o template `metabase_export/database_connection.json`
  (placeholders `${VAR}`).
- É idempotente sem duplicar: reaproveita o admin (login) e a conexão Snowflake se já
  existirem. Já o dashboard/cards são sempre ressincronizados com o conteúdo atual de
  `cards.json`/`dashboard.json` a cada execução (a versão antiga é arquivada e recriada) —
  então editar esses JSONs e rodar `docker compose up -d metabase-setup` de novo já aplica
  a mudança no Metabase.
- Acompanhe o progresso com `docker compose logs -f metabase-setup`.

Se preferir rodar fora do Docker (contra um Metabase já no ar em outra porta/host), defina
`METABASE_URL` (ex.: `http://localhost:3000/api`) e execute manualmente:

```bash
pip install -r dashboard/requirements.txt
python dashboard/setup_metabase.py
```

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

Basta subir o stack: `docker compose up -d`. O serviço `metabase-setup` cuida de tudo
(admin, conexão Snowflake, os 8 cards e o dashboard com o layout original) — ver seção
acima.

### Evidências (prints)

Screenshots do dashboard estão em `dashboard/evidencias/` para anexar ao relatório
(entregável 6.1: "evidências de execução, como prints, logs ou exemplos de saída").
