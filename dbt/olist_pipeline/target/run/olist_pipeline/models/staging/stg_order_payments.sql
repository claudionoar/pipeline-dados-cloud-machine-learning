
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_order_payments
  
  
  
  
  as (
    with source as (
    select * from PROJETO_OLIST_DB.RAW.order_payments
)

select
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
from source
  );

