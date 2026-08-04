-- Camada STAGING de raw.ml_predictions
 
-- {{ config(materialized='view') }}

WITH source AS (
    select * FROM {{ source('raw', 'ml_predictions') }}
)

SELECT
    order_id,
    true_label,
    predicted_label_hardcode,
    predicted_label_sklearn,
    model_version,
    predicted_at
FROM source
