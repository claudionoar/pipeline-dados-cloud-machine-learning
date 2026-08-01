
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_ml_predictions
  
   as (
    with source as (
    select * from PROJETO_OLIST_DB.RAW.ml_predictions
)

select
    order_id,
    true_label,
    predicted_label_hardcode,
    predicted_label_sklearn,
    model_version,
    predicted_at
from source
  );

