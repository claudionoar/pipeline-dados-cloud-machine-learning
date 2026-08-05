-- Calendário diário cobrindo o range de datas do dataset Olist (pedidos de 2016-09 a 2018-09,
-- com data estimada de entrega podendo passar disso em algumas semanas).

-- CTE que gera a "espinha" de datas (uma linha por dia) usando a macro date_spine do dbt_utils
WITH spine AS (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="CAST('2016-01-01' AS DATE)",
        end_date="CAST('2019-01-01' AS DATE)"
    ) }}
)

-- Seleção final: deriva atributos de calendário a partir de cada data
SELECT
    date_day,                                   -- data (grão da dimensão de calendário)
    YEAR(date_day) AS year,                     -- ano extraído da data
    MONTH(date_day) AS month,                   -- mês extraído da data
    DAY(date_day) AS day,                       -- dia do mês extraído da data
    DAYOFWEEK(date_day) AS day_of_week,         -- dia da semana (0 = domingo ... 6 = sábado)
    DAYOFWEEK(date_day) IN (0, 6) AS is_weekend -- flag indicando se a data cai no fim de semana
FROM spine