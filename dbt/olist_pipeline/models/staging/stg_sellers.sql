-- Camada STAGING de raw.sellers
-- seller_id é a chave de negócio.

-- {{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'sellers') }}
)

SELECT
    seller_id,
    seller_zip_code_prefix AS zip_code_prefix,
    upper(seller_city) AS cidade, -- padronização leve: cidade sempre em maiúsculo
    upper(seller_state) AS estado -- padronização leve: UF sempre em maiúsculo
FROM source
