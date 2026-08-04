-- Agrega a granularidade original de raw.geolocation (várias lat/lng por prefixo de CEP,
-- vindas de GPS de usuários distintos) para uma linha por zip_code_prefix - grão necessário
-- para servir de dimensão de localização de clientes/vendedores em mart_late_delivery_features.

-- CTE que carrega todos os registros da camada de staging de geolocalização
WITH geolocation AS (
    SELECT * FROM {{ ref('stg_geolocation') }}
)

-- Seleção final: agrega por prefixo de CEP, calculando médias de coordenadas e valores mais frequentes
SELECT
    zip_code_prefix,                    -- prefixo do CEP (grão da dimensão)
    AVG(latitude) AS latitude,          -- latitude média dos pontos do prefixo
    AVG(longitude) AS longitude,        -- longitude média dos pontos do prefixo
    MODE(cidade) AS cidade,             -- cidade mais frequente para o prefixo
    MODE(estado) AS estado              -- estado (UF) mais frequente para o prefixo
FROM geolocation
GROUP BY zip_code_prefix               -- uma linha por prefixo de CEP
