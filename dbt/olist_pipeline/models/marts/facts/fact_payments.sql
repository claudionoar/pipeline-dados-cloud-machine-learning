with payments as (
    select * from {{ ref('stg_order_payments') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }} as payment_key,
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
from payments
