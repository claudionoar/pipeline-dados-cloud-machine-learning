with sales as (
    select * from {{ ref('stg_sales') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['category_root']) }} as category_key,
    category_root,
    count(distinct product_id) as product_count,
    avg(rating) as avg_rating,
    avg(discounted_price) as avg_price
from sales
group by category_root
