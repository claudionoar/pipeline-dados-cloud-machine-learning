
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_ml_predictions
  
   as (
    -- Camada STAGING de raw.ml_predictions
 
-- 

WITH source AS (
    select * FROM PROJETO_OLIST_DB.RAW.ml_predictions
)

SELECT
    order_id,
    true_label,
    predicted_label_hardcode,
    predicted_label_sklearn,
    model_version,
    predicted_at
FROM source
  );

