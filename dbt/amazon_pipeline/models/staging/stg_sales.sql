with source as (
    select * from {{ source('raw', 'sales') }}
)

select
    product_id,
    product_name,
    category,
    category_root,
    discounted_price,
    actual_price,
    discount_percentage,
    rating,
    rating_count,
    about_product,
    img_link,
    product_link,
    ingested_at
from source
