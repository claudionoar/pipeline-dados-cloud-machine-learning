
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_sellers
  
   as (
    with source as (
    select * from PROJETO_OLIST_DB.RAW.sellers
)

select
    seller_id,
    seller_zip_code_prefix as zip_code_prefix,
    seller_city as city,
    seller_state as state
from source
  );

