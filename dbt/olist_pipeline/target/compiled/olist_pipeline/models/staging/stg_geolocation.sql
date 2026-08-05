-- Camada STAGING de raw.geolocation
-- geolocation_zip_code_prefix é a CHAVE DE NEGÓCIO (string longa vinda da origem).
-- A chave substituta (SK) só será gerada na dimensão, não aqui. 

-- 

WITH source AS (
    SELECT * FROM PROJETO_OLIST_DB.RAW.geolocation
)

SELECT
    geolocation_zip_code_prefix AS zip_code_prefix,
    geolocation_lat AS latitude,
    geolocation_lng AS longitude,
    upper(geolocation_city) AS cidade, -- padronização leve: cidade sempre em maiúsculo
    upper(geolocation_state) AS estado -- padronização leve: UF sempre em maiúsculo
FROM source