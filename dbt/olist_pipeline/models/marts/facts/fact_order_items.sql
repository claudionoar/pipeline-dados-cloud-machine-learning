with order_items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select product_id, product_key from {{ ref('dim_products') }}
),

sellers as (
    select seller_id, seller_key from {{ ref('dim_sellers') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['order_items.order_id', 'order_items.order_item_id']) }}
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
