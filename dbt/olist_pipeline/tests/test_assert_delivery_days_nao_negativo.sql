-- Teste singular: garante que o tempo de entrega nunca seja negativo.
-- Um delivery_days negativo indicaria data de entrega anterior à compra (dado inconsistente).
-- O teste PASSA se esta query retornar 0 linhas.

SELECT
    order_id,
    delivery_days
FROM {{ ref('fact_orders') }}
WHERE delivery_days < 0
