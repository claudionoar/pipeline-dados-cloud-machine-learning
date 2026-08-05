-- Camada STAGING da raw.customers
-- customer_id é a CHAVE DE NEGÓCIO (string longa vinda da origem).
-- A chave substituta (SK) só será gerada na dimensão, não aqui. 

-- 

WITH source AS (
    SELECT * FROM PROJETO_OLIST_DB.RAW.customers
)

SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    upper(customer_city) AS cidade, -- padronização leve: cidade sempre em maiúsculo
    upper(customer_state) AS estado -- padronização leve: UF sempre em maiúsculo
FROM source