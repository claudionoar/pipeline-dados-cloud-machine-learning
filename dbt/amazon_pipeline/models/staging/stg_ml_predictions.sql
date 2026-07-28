with source as (
    select * from {{ source('raw', 'ml_predictions') }}
)

select
    review_id,
    product_id,
    true_label,
    predicted_label_hardcode,
    predicted_label_sklearn,
    model_version,
    predicted_at
from source
