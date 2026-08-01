with source as (
    select * from {{ source('raw', 'ml_predictions') }}
)

select
    order_id,
    true_label,
    predicted_label_hardcode,
    predicted_label_sklearn,
    model_version,
    predicted_at
from source
