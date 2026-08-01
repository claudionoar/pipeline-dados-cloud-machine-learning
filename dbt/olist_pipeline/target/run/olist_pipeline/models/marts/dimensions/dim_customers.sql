
  
    

        create or replace transient table PROJETO_OLIST_DB.ANALYTICS.dim_customers
         as
        (with customers as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_customers
)

select
    md5(cast(coalesce(cast(customer_id as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT)) as customer_key,
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix as zip_code_prefix,
    customer_city as city,
    customer_state as state
from customers
        );
      
  