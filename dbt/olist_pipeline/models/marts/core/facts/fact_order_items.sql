-- Tabela fato de itens de pedido (fact_order_items)
-- Consome a staging stg_order_items e enriquece com product_key e seller_key
-- Grão: uma linha por item de pedido (order_id + order_item_id)

-- CTE que carrega todos os registros da camada de staging de itens de pedido
WITH order_items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

-- CTE que traz apenas as chaves de produto necessárias para o join
products AS (
    SELECT product_id, product_key FROM {{ ref('dim_products') }}
),

-- CTE que traz apenas as chaves de vendedor necessárias para o join
sellers AS (
    SELECT seller_id, seller_key FROM {{ ref('dim_sellers') }}
)

-- Seleção final: cria a surrogate key composta e junta as chaves de produto e vendedor
SELECT
    {{ dbt_utils.generate_surrogate_key(['order_items.order_id', 'order_items.order_item_id']) }}
        AS order_item_key,                  -- chave substituta única (order_id + order_item_id)
    order_items.order_id,                   -- identificador do pedido
    order_items.order_item_id,              -- sequência do item dentro do pedido
    products.product_key,                   -- chave substituta do produto (vinda de dim_products)
    sellers.seller_key,                     -- chave substituta do vendedor (vinda de dim_sellers)
    order_items.shipping_limit_date,        -- data limite para envio do item pelo vendedor
    order_items.preco,                      -- preço do item
    order_items.frete                       -- valor do frete do item
FROM order_items
-- LEFT JOIN mantém todos os itens, mesmo sem produto correspondente em dim_products
LEFT JOIN products ON order_items.product_id = products.product_id
-- LEFT JOIN mantém todos os itens, mesmo sem vendedor correspondente em dim_sellers
LEFT JOIN sellers ON order_items.seller_id = sellers.seller_id
