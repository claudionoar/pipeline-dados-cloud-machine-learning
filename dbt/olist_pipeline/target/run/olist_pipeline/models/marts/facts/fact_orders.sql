
  
    

        create or replace transient table PROJETO_OLIST_DB.ANALYTICS.fact_orders
         as
        (with orders as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_orders
),

customers as (
    select customer_id, customer_key from PROJETO_OLIST_DB.ANALYTICS.dim_customers
)

select
    md5(cast(coalesce(cast(orders.order_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT)) as order_key,
    orders.order_id,
    customers.customer_key,
    orders.order_status,
    orders.order_purchase_timestamp,
    orders.order_approved_at,
    orders.order_delivered_carrier_date,
    orders.order_delivered_customer_date,
    orders.order_estimated_delivery_date,
    case
        when orders.order_delivered_customer_date is not null
            and orders.order_estimated_delivery_date is not null
        then orders.order_delivered_customer_date > orders.order_estimated_delivery_date
    end as is_late,
    datediff('day', orders.order_purchase_timestamp, orders.order_delivered_customer_date)
        as delivery_days,
    datediff('day', orders.order_purchase_timestamp, orders.order_estimated_delivery_date)
        as estimated_delivery_days,
    datediff('hour', orders.order_purchase_timestamp, orders.order_approved_at)
        as approval_delay_hours
from orders
left join customers on orders.customer_id = customers.customer_id
        );
      
  