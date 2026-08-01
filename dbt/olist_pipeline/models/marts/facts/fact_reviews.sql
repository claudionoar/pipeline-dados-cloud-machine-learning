with reviews as (
    select * from {{ ref('stg_order_reviews') }}
),

orders as (
    select order_id, order_key from {{ ref('fact_orders') }}
)

-- Grao: review_id + order_id (nao so review_id) - limitacao real do dataset Olist: ~0,8% dos
-- review_id se repetem em order_id diferentes (ver docs/dicionario_dados.md).
select
    {{ dbt_utils.generate_surrogate_key(['reviews.review_id', 'reviews.order_id']) }} as review_key,
    reviews.review_id,
    reviews.order_id,
    orders.order_key,
    reviews.review_score,
    reviews.review_comment_title,
    reviews.review_comment_message,
    reviews.sentiment_label,
    reviews.review_creation_date,
    reviews.review_answer_timestamp
from reviews
left join orders on reviews.order_id = orders.order_id
