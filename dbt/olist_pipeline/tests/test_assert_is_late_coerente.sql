-- Teste singular: garante que a flag is_late esteja coerente com as datas do pedido.
-- Um pedido marcado como is_late = TRUE deve ter entrega efetiva posterior à data estimada.
-- Se a data de entrega for menor ou igual à estimada, a flag está errada.
-- O teste PASSA se esta query retornar 0 linhas.

SELECT
    order_id,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    is_late
FROM {{ ref('fact_orders') }}
WHERE is_late = TRUE
    AND order_delivered_customer_date <= order_estimated_delivery_date
