-- Camada STAGING de raw.category_translation

-- 

WITH source AS (
    SELECT * FROM PROJETO_OLIST_DB.RAW.category_translation
)

SELECT
    product_category_name,
    product_category_name_english
FROM source