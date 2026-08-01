
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_customers
  
  
  
  
  as (
    with source as (
    select * from PROJETO_OLIST_DB.RAW.customers
)

select
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
from source
  );

