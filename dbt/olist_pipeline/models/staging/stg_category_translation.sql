-- Camada STAGING de raw.category_translation

-- {{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'category_translation') }}
)

SELECT
    product_category_name,
    product_category_name_english
FROM source
