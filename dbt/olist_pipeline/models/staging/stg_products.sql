-- Camada STAGING de raw.products
-- product_id é a chave de negócio. Atributos descritivos (categoria, peso)
-- moram AQUI e depois na dimensão -- nunca na fato.

-- {{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'products') }}
)

SELECT
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    CAST(product_weight_g AS integer) AS product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM source
