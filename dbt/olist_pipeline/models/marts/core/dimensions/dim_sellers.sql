-- Modelo de dimensão de vendedores (dim_sellers)
-- Consome a tabela de staging stg_sellers e gera uma chave substituta (surrogate key)

-- CTE que carrega todos os registros da camada de staging de vendedores
WITH sellers AS (
    SELECT * FROM {{ ref('stg_sellers') }}
)

-- Seleção final: cria a surrogate key a partir do seller_id e retorna os atributos do vendedor
SELECT
    {{ dbt_utils.generate_surrogate_key(['seller_id']) }} AS seller_key,  -- chave substituta única gerada por hash
    seller_id,        -- identificador natural do vendedor
    zip_code_prefix,  -- prefixo do CEP
    cidade,           -- cidade do vendedor
    estado            -- estado (UF) do vendedor
FROM sellers