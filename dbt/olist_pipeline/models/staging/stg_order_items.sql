-- Camada STAGING de raw.order_items
-- Esta é a tabela que define o GRÃO da nossa fato: 1 linha por item de pedido.
-- É aqui que vivem as medidas cruas (price, freight_value).
 
-- {{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'order_items') }}
)

SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    -- medidas aditivas em estado bruto: garantimos tipo numérico
    cast(price as decimal(10,2))         as preco,
    cast(freight_value as decimal(10,2)) as frete
FROM source
