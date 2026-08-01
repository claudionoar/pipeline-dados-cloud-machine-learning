with products as (
    select * from {{ ref('stg_products') }}
),

category_translation as (
    select * from {{ ref('stg_category_translation') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['products.product_id']) }} as product_key,
    products.product_id,
    products.product_category_name as category_name,
    coalesce(category_translation.product_category_name_english, products.product_category_name)
        as category_name_english,
    products.product_name_lenght,
    products.product_description_lenght,
    products.product_photos_qty,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm,
    products.product_length_cm * products.product_height_cm * products.product_width_cm
        as product_volume_cm3
from products
left join category_translation
    on products.product_category_name = category_translation.product_category_name
