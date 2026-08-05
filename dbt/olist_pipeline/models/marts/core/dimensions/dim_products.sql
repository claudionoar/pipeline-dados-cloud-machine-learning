-- Modelo de dimensão de produtos (dim_products)
-- Consome as tabelas de staging stg_products e stg_category_translation
-- Gera uma chave substituta (surrogate key) e traduz a categoria para inglês

-- CTE que carrega todos os registros da camada de staging de produtos
WITH products AS (
    SELECT * FROM {{ ref('stg_products') }}
),

-- CTE que carrega a tabela de tradução dos nomes de categorias (PT -> EN)
category_translation AS (
    SELECT * FROM {{ ref('stg_category_translation') }}
)

-- Seleção final: cria a surrogate key, traduz a categoria e calcula o volume do produto
SELECT
    {{ dbt_utils.generate_surrogate_key(['products.product_id']) }} AS product_key,  -- chave substituta única gerada por hash
    products.product_id,                                    -- identificador natural do produto
    products.product_category_name AS category_name,        -- nome da categoria em português
    COALESCE(category_translation.product_category_name_english, products.product_category_name)
        AS category_name_english,                           -- categoria em inglês; usa o nome em PT caso não haja tradução
    products.product_name_lenght,                           -- comprimento do nome do produto
    products.product_description_lenght,                    -- comprimento da descrição do produto
    products.product_photos_qty,                            -- quantidade de fotos do produto
    products.product_weight_g,                              -- peso do produto (gramas)
    products.product_length_cm,                             -- comprimento do produto (cm)
    products.product_height_cm,                             -- altura do produto (cm)
    products.product_width_cm,                              -- largura do produto (cm)
    products.product_length_cm * products.product_height_cm * products.product_width_cm
        AS product_volume_cm3                               -- volume calculado do produto (cm³)
FROM products
-- LEFT JOIN garante que todos os produtos sejam mantidos, mesmo sem tradução de categoria
LEFT JOIN category_translation
    ON products.product_category_name = category_translation.product_category_name