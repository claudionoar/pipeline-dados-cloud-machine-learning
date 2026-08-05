-- Camada STAGING de raw.order_payments
-- espelha a fonte crua (order_payments) com padronização mínima.
-- Regra da aula: no staging fazemos pouca ou nenhuma transformação, só limpeza
-- leve de nomes/tipos. Nada de regra de negócio aqui.

-- {{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'order_payments') }}
)

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM source
