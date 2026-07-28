with source as (
    select * from {{ source('raw', 'reviews') }}
)

select
    review_id,
    product_id,
    user_id,
    review_title,
    review_text,
    rating,
    review_date,
    word_count,
    char_count,
    exclamation_count,
    sentiment_label,
    ingested_at
from source
