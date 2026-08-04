-- Camada STAGING de raw.orders
-- espelha a fonte crua (orders) com padronização mínima.
-- Regra da aula: no staging fazemos pouca ou nenhuma transformação, só limpeza
-- leve de nomes/tipos. Nada de regra de negócio aqui.

-- {{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'orders') }}
)

SELECT
    order_id,
    customer_id,
    order_status,
    cast(order_purchase_timestamp AS timestamp)      AS order_purchase_timestamp, -- padronizamos apenas o tipo das datas (texto -> timestamp)
    order_approved_at,
    order_delivered_carrier_date,
    cast(order_delivered_customer_date AS timestamp) AS order_delivered_customer_date, -- padronizamos apenas o tipo das datas (texto -> timestamp)
    order_estimated_delivery_date
FROM source
