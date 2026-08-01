-- Calendário diário cobrindo o range de datas do dataset Olist (pedidos de 2016-09 a 2018-09,
-- com data estimada de entrega podendo passar disso em algumas semanas).

with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2016-01-01' as date)",
        end_date="cast('2019-01-01' as date)"
    ) }}
)

select
    date_day,
    year(date_day) as year,
    month(date_day) as month,
    day(date_day) as day,
    dayofweek(date_day) as day_of_week,
    dayofweek(date_day) in (0, 6) as is_weekend
from spine
