
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_category_translation
  
  
  
  
  as (
    with source as (
    select * from PROJETO_OLIST_DB.RAW.category_translation
)

select
    product_category_name,
    product_category_name_english
from source
  );

