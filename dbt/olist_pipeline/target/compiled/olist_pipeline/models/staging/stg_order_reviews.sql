with source as (
    select * from PROJETO_OLIST_DB.RAW.order_reviews
)

select
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    case
        when review_score >= 4 then 'positive'
        when review_score <= 2 then 'negative'
        else 'neutral'
    end as sentiment_label
from source