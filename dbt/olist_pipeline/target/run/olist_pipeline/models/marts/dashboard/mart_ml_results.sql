
  
    

        create or replace transient table PROJETO_OLIST_DB.ANALYTICS.mart_ml_results
         as
        (-- Predições do conjunto de teste (hard-code vs. sklearn) prontas para o dashboard e para a
-- análise de acertos/erros pedida na avaliação qualitativa (docs/avaliacao.md).

-- CTE que carrega as predições do modelo vindas da camada de staging
WITH predictions AS (
    SELECT * FROM PROJETO_OLIST_DB.ANALYTICS.stg_ml_predictions
),

-- CTE que carrega a tabela fato de pedidos (para ligar predição -> cliente)
orders AS (
    SELECT * FROM PROJETO_OLIST_DB.ANALYTICS.fact_orders
),

-- CTE que carrega a dimensão de clientes (para obter o estado)
customers AS (
    SELECT * FROM PROJETO_OLIST_DB.ANALYTICS.dim_customers
)

-- Seleção final: junta predições, pedidos e clientes e deriva flags de acerto de cada modelo
SELECT
    predictions.order_id,                       -- identificador do pedido predito
    predictions.true_label,                     -- rótulo real (verdade de campo)
    predictions.predicted_label_hardcode,       -- rótulo previsto pelo modelo hard-code (baseline por regras)
    predictions.predicted_label_sklearn,        -- rótulo previsto pelo modelo sklearn
    predictions.model_version,                  -- versão do modelo usado na predição
    predictions.predicted_at,                   -- timestamp da predição
    (predictions.true_label = predictions.predicted_label_hardcode) AS hardcode_correct,  -- TRUE se o hard-code acertou
    (predictions.true_label = predictions.predicted_label_sklearn) AS sklearn_correct,    -- TRUE se o sklearn acertou
    customers.estado AS estado                  -- estado (UF) do cliente, para análise regional
FROM predictions
-- LEFT JOIN traz o pedido correspondente à predição
LEFT JOIN orders ON predictions.order_id = orders.order_id
-- LEFT JOIN traz o cliente do pedido (via customer_key)
LEFT JOIN customers ON orders.customer_key = customers.customer_key
        );
      
  