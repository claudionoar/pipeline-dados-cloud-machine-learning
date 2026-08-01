
  
    

        create or replace transient table PROJETO_OLIST_DB.ANALYTICS.fact_payments
         as
        (with payments as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_order_payments
)

select
    md5(cast(coalesce(cast(order_id as TEXT), '_dbt_utils_surrogate_key_null_') || '-' || coalesce(cast(payment_sequential as TEXT), '_dbt_utils_surrogate_key_null_') as TEXT)) as payment_key,
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
from payments
        );
      
  