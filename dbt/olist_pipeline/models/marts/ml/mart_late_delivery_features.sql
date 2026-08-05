-- Tabela final para consumo pelo módulo de Machine Learning (machine-learning/data_prep.py):
-- uma linha por pedido entregue, com features estruturadas + o alvo is_late (atraso na entrega).
--
-- distance_km usa a função nativa HAVERSINE() do Snowflake entre o centróide de CEP do cliente
-- e do vendedor "primário" do pedido (o do primeiro item - simplificação documentada: pedidos
-- com vários vendedores/itens usam só a localização do primeiro item).

-- CTE que carrega a tabela fato de pedidos
WITH orders AS (
    SELECT * FROM {{ ref('fact_orders') }}
),

-- CTE que carrega a dimensão de clientes
customers AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

-- CTE que carrega a tabela fato de itens de pedido
items AS (
    SELECT * FROM {{ ref('fact_order_items') }}
),

-- CTE que carrega a dimensão de vendedores
sellers AS (
    SELECT * FROM {{ ref('dim_sellers') }}
),

-- CTE que carrega a dimensão de produtos
products AS (
    SELECT * FROM {{ ref('dim_products') }}
),

-- CTE que carrega a tabela fato de pagamentos
payments AS (
    SELECT * FROM {{ ref('fact_payments') }}
),

-- CTE que carrega a dimensão de geolocalização (centróide por prefixo de CEP)
geolocation AS (
    SELECT * FROM {{ ref('dim_geolocation') }}
),

-- CTE que agrega os itens ao grão de pedido (contagem, valores e médias de peso/volume)
item_agg AS (
    SELECT
        items.order_id,                                             -- identificador do pedido
        COUNT(*) AS item_count,                                     -- quantidade de itens no pedido
        SUM(items.preco) AS total_price,                            -- valor total dos itens
        SUM(items.frete) AS total_freight,                          -- valor total de frete
        AVG(products.product_weight_g) AS avg_product_weight_g,     -- peso médio dos produtos (g)
        AVG(products.product_volume_cm3) AS avg_product_volume_cm3  -- volume médio dos produtos (cm³)
    FROM items
    LEFT JOIN products ON items.product_key = products.product_key
    GROUP BY items.order_id
),

-- CTE que identifica o vendedor "primário" (do primeiro item) de cada pedido
primary_seller AS (
    SELECT order_id, seller_key
    FROM items
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_item_id) = 1
),

-- CTE que agrega os pagamentos ao grão de pedido (máx. de parcelas e valor total)
payment_agg AS (
    SELECT
        order_id,                                             -- identificador do pedido
        MAX(payment_installments) AS payment_installments_max, -- maior número de parcelas do pedido
        SUM(payment_value) AS payment_value_total              -- valor total pago no pedido
    FROM payments
    GROUP BY order_id
),

-- CTE que enriquece o cliente com sua localização (lat/long do prefixo de CEP)
customer_geo AS (
    SELECT
        customers.customer_key,     -- chave do cliente
        customers.estado,           -- estado (UF) do cliente
        geolocation.latitude,       -- latitude do cliente
        geolocation.longitude       -- longitude do cliente
    FROM customers
    LEFT JOIN geolocation ON customers.zip_code_prefix = geolocation.zip_code_prefix
),

-- CTE que enriquece o vendedor com sua localização (lat/long do prefixo de CEP)
seller_geo AS (
    SELECT
        sellers.seller_key,         -- chave do vendedor
        sellers.estado,             -- estado (UF) do vendedor
        geolocation.latitude,       -- latitude do vendedor
        geolocation.longitude       -- longitude do vendedor
    FROM sellers
    LEFT JOIN geolocation ON sellers.zip_code_prefix = geolocation.zip_code_prefix
)

-- Seleção final: monta uma linha por pedido entregue com features e o alvo is_late
SELECT
    orders.order_id,                            -- identificador do pedido
    orders.is_late,                             -- ALVO: TRUE se o pedido atrasou
    item_agg.total_price,                       -- valor total dos itens
    item_agg.total_freight,                     -- valor total de frete
    item_agg.item_count,                        -- quantidade de itens
    item_agg.avg_product_weight_g,              -- peso médio dos produtos (g)
    item_agg.avg_product_volume_cm3,            -- volume médio dos produtos (cm³)
    payment_agg.payment_installments_max,       -- máximo de parcelas do pedido
    payment_agg.payment_value_total,            -- valor total pago
    orders.approval_delay_hours,                -- horas entre compra e aprovação do pagamento
    orders.estimated_delivery_days,             -- dias estimados de entrega (compra -> data estimada)
    DAYOFWEEK(orders.order_purchase_timestamp) AS purchase_dow,   -- dia da semana da compra
    MONTH(orders.order_purchase_timestamp) AS purchase_month,     -- mês da compra
    -- Distância geográfica entre cliente e vendedor primário (Haversine, em km)
    HAVERSINE(customer_geo.latitude, customer_geo.longitude, seller_geo.latitude, seller_geo.longitude) AS distance_km,
    IFF(customer_geo.estado = seller_geo.estado, 1, 0) AS same_state_flag,  -- flag: cliente e vendedor no mesmo estado
    customer_geo.estado AS customer_state,      -- estado (UF) do cliente
    seller_geo.estado AS seller_state           -- estado (UF) do vendedor
FROM orders
-- INNER JOIN: mantém apenas pedidos que possuem itens agregados
INNER JOIN item_agg ON orders.order_id = item_agg.order_id
-- LEFT JOIN traz os pagamentos agregados do pedido
LEFT JOIN payment_agg ON orders.order_id = payment_agg.order_id
-- LEFT JOIN identifica o vendedor primário do pedido
LEFT JOIN primary_seller ON orders.order_id = primary_seller.order_id
-- LEFT JOIN traz a localização do vendedor primário
LEFT JOIN seller_geo ON primary_seller.seller_key = seller_geo.seller_key
-- LEFT JOIN traz a localização do cliente
LEFT JOIN customer_geo ON orders.customer_key = customer_geo.customer_key
-- Filtra apenas pedidos efetivamente entregues e com datas completas (necessárias para o alvo)
WHERE orders.order_status = 'delivered'
    AND orders.order_delivered_customer_date IS NOT NULL
    AND orders.order_estimated_delivery_date IS NOT NULL
