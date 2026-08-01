
  
    

create or replace transient table PROJETO_OLIST_DB.ANALYTICS.mart_ml_results
    
    
    
    
    

    as (-- Predições do conjunto de teste (hard-code vs. sklearn) prontas para o dashboard e para a
-- análise de acertos/erros pedida na avaliação qualitativa (docs/avaliacao.md).

with predictions as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_ml_predictions
),

orders as (
    select * from PROJETO_OLIST_DB.ANALYTICS.fact_orders
),

customers as (
    select * from PROJETO_OLIST_DB.ANALYTICS.dim_customers
)

select
    predictions.order_id,
    predictions.true_label,
    predictions.predicted_label_hardcode,
    predictions.predicted_label_sklearn,
    predictions.model_version,
    predictions.predicted_at,
    (predictions.true_label = predictions.predicted_label_hardcode) as hardcode_correct,
    (predictions.true_label = predictions.predicted_label_sklearn) as sklearn_correct,
    customers.state as customer_state
from predictions
left join orders on predictions.order_id = orders.order_id
left join customers on orders.customer_key = customers.customer_key
    )
;


  