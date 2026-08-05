-- Tabela fato de pagamentos (fact_payments)
-- Consome a staging stg_order_payments e gera uma chave substituta (surrogate key)
-- Grão: uma linha por pagamento de pedido (order_id + payment_sequential)

-- CTE que carrega todos os registros da camada de staging de pagamentos
WITH payments AS (
    SELECT * FROM {{ ref('stg_order_payments') }}
)

-- Seleção final: cria a surrogate key composta e retorna os atributos do pagamento
SELECT
    {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }} AS payment_key,  -- chave substituta única (order_id + payment_sequential)
    order_id,               -- identificador do pedido pago
    payment_sequential,     -- sequência do pagamento dentro do pedido (permite múltiplos pagamentos)
    payment_type,           -- forma de pagamento (cartão, boleto, voucher, etc.)
    payment_installments,   -- número de parcelas do pagamento
    payment_value           -- valor do pagamento
FROM payments
