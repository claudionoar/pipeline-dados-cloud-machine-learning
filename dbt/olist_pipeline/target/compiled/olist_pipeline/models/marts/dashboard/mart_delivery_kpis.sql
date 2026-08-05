-- Fatos agregados para o dashboard Metabase: % de pedidos atrasados e tempo médio de entrega
-- por estado do cliente - a mesma pergunta de negócio que orienta mart_late_delivery_features,
-- em formato pronto para visualização (ex.: priorizar intervenção logística por região).

-- CTE que carrega a tabela fato de pedidos
WITH orders AS (
    SELECT * FROM PROJETO_OLIST_DB.ANALYTICS.fact_orders
),

-- CTE que carrega a dimensão de clientes (para obter o estado)
customers AS (
    SELECT * FROM PROJETO_OLIST_DB.ANALYTICS.dim_customers
)

-- Seleção final: agrega KPIs de entrega por estado do cliente
SELECT
    customers.estado AS estado,                                             -- estado (UF) do cliente como dimensão de agrupamento
    COUNT(*) AS order_count,                                                -- total de pedidos entregues no estado
    SUM(CASE WHEN orders.is_late THEN 1 ELSE 0 END) AS late_count,          -- total de pedidos atrasados
    SUM(CASE WHEN orders.is_late THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0)::FLOAT AS pct_late,  -- proporção de atrasos (nullif evita divisão por zero)
    AVG(orders.delivery_days) AS avg_delivery_days,                         -- tempo médio de entrega efetivo (dias)
    AVG(orders.estimated_delivery_days) AS avg_estimated_delivery_days      -- tempo médio estimado de entrega (dias)
FROM orders
-- LEFT JOIN traz o cliente do pedido (via customer_key) para obter o estado
LEFT JOIN customers ON orders.customer_key = customers.customer_key
-- Filtra apenas pedidos efetivamente entregues e com datas completas para o cálculo de atraso
WHERE orders.order_status = 'delivered'
    AND orders.order_delivered_customer_date IS NOT NULL
    AND orders.order_estimated_delivery_date IS NOT NULL
GROUP BY customers.estado                                                   -- uma linha por estado