
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_sellers
  
   as (
    -- Camada STAGING de raw.sellers
-- seller_id é a chave de negócio.

-- 

WITH source AS (
    SELECT * FROM PROJETO_OLIST_DB.RAW.sellers
)

SELECT
    seller_id,
    seller_zip_code_prefix AS zip_code_prefix,
    upper(seller_city) AS cidade, -- padronização leve: cidade sempre em maiúsculo
    upper(seller_state) AS estado -- padronização leve: UF sempre em maiúsculo
FROM source
  );

