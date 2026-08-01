with sellers as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_sellers
)

select
    md5(cast(coalesce(cast(seller_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT)) as seller_key,
    seller_id,
    zip_code_prefix,
    city,
    state
from sellers