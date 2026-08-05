-- Tabela fato de pedidos (fact_orders)
-- Consome a staging stg_orders e enriquece com a customer_key vinda de dim_customers
-- Calcula métricas de entrega (atraso, dias de entrega, tempo de aprovação)

-- CTE que carrega todos os registros da camada de staging de pedidos
WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

-- CTE que traz apenas as chaves de cliente necessárias para o join
customers AS (
    SELECT customer_id, customer_key FROM {{ ref('dim_customers') }}
)

-- Seleção final: cria a surrogate key, junta a customer_key e deriva métricas de entrega
SELECT
    {{ dbt_utils.generate_surrogate_key(['orders.order_id']) }} AS order_key,  -- chave substituta única gerada por hash
    orders.order_id,                            -- identificador natural do pedido
    customers.customer_key,                     -- chave substituta do cliente (vinda de dim_customers)
    orders.order_status,                        -- status do pedido (entregue, cancelado, etc.)
    orders.order_purchase_timestamp,            -- momento da compra
    orders.order_approved_at,                   -- momento da aprovação do pagamento
    orders.order_delivered_carrier_date,        -- momento em que o pedido foi entregue à transportadora
    orders.order_delivered_customer_date,       -- momento da entrega ao cliente
    orders.order_estimated_delivery_date,       -- data estimada de entrega
    -- Flag de atraso: TRUE se a entrega real ocorreu após a data estimada (NULL se faltar alguma data)
    CASE
        WHEN orders.order_delivered_customer_date IS NOT NULL
            AND orders.order_estimated_delivery_date IS NOT NULL
        THEN orders.order_delivered_customer_date > orders.order_estimated_delivery_date
    END AS is_late,
    DATEDIFF('day', orders.order_purchase_timestamp, orders.order_delivered_customer_date)
        AS delivery_days,                       -- dias entre a compra e a entrega efetiva
    DATEDIFF('day', orders.order_purchase_timestamp, orders.order_estimated_delivery_date)
        AS estimated_delivery_days,             -- dias entre a compra e a data estimada de entrega
    DATEDIFF('hour', orders.order_purchase_timestamp, orders.order_approved_at)
        AS approval_delay_hours                 -- horas entre a compra e a aprovação do pagamento
FROM orders
-- LEFT JOIN mantém todos os pedidos, mesmo sem cliente correspondente em dim_customers
LEFT JOIN customers ON orders.customer_id = customers.customer_id
