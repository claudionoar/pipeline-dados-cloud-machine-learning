-- Modelo de dimensão de clientes (dim_customers)
-- Consome a tabela de staging stg_customers e gera uma chave substituta (surrogate key)

-- CTE que carrega todos os registros da camada de staging de clientes
WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
)

-- Seleção final: cria a surrogate key a partir do customer_id e retorna os atributos do cliente
SELECT
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }} AS customer_key,  -- chave substituta única gerada por hash
    customer_id,                                    -- identificador do cliente por pedido
    customer_unique_id,                             -- identificador único do cliente (mesma pessoa entre pedidos)
    customer_zip_code_prefix AS zip_code_prefix,    -- prefixo do CEP do cliente
    cidade AS cidade,                               -- cidade do cliente
    estado AS estado                                -- estado (UF) do cliente
FROM customers