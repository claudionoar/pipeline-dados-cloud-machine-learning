
  
    

        create or replace transient table PROJETO_OLIST_DB.ANALYTICS.dim_products
         as
        (with products as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_products
),

category_translation as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_category_translation
)

select
    md5(cast(coalesce(cast(products.product_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT)) as product_key,
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
        );
      
  