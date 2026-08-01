-- Fatos agregados para o dashboard Metabase: % de pedidos atrasados e tempo médio de entrega
-- por estado do cliente - a mesma pergunta de negócio que orienta mart_late_delivery_features,
-- em formato pronto para visualização (ex.: priorizar intervenção logística por região).

with orders as (
    select * from PROJETO_OLIST_DB.ANALYTICS.fact_orders
),

customers as (
    select * from PROJETO_OLIST_DB.ANALYTICS.dim_customers
)

select
    customers.state as customer_state,
    count(*) as order_count,
    sum(case when orders.is_late then 1 else 0 end) as late_count,
    sum(case when orders.is_late then 1 else 0 end) / nullif(count(*), 0)::float as pct_late,
    avg(orders.delivery_days) as avg_delivery_days,
    avg(orders.estimated_delivery_days) as avg_estimated_delivery_days
from orders
left join customers on orders.customer_key = customers.customer_key
where orders.order_status = 'delivered'
    and orders.order_delivered_customer_date is not null
    and orders.order_estimated_delivery_date is not null
group by customers.state