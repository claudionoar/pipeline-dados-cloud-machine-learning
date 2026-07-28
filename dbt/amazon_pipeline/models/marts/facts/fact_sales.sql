with sales as (
    select * from {{ ref('stg_sales') }}
),

products as (
    select product_id, product_key from {{ ref('dim_product') }}
),

categories as (
    select category_root, category_key from {{ ref('dim_category') }}
)

select
    products.product_key,
    categories.category_key,
    sales.product_id,
    sales.discounted_price,
    sales.actual_price,
    sales.discount_percentage,
    sales.rating,
    sales.rating_count
from sales
left join products on sales.product_id = products.product_id
left join categories on sales.category_root = categories.category_root
