
  
    

        create or replace transient table PROJETO_OLIST_DB.ANALYTICS.fact_order_items
         as
        (with order_items as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_order_items
),

products as (
    select product_id, product_key from PROJETO_OLIST_DB.ANALYTICS.dim_products
),

sellers as (
    select seller_id, seller_key from PROJETO_OLIST_DB.ANALYTICS.dim_sellers
)

select
    md5(cast(coalesce(cast(order_items.order_id as TEXT), '_dbt_utils_surrogate_key_null_') || '-' || coalesce(cast(order_items.order_item_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT))
        as order_item_key,
    order_items.order_id,
    order_items.order_item_id,
    products.product_key,
    sellers.seller_key,
    order_items.shipping_limit_date,
    order_items.price,
    order_items.freight_value
from order_items
left join products on order_items.product_id = products.product_id
left join sellers on order_items.seller_id = sellers.seller_id
        );
      
  