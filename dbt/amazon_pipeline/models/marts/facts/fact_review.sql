with reviews as (
    select * from {{ ref('stg_reviews') }}
),

products as (
    select product_id, product_key from {{ ref('dim_product') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['reviews.review_id']) }} as review_key,
    reviews.review_id,
    reviews.product_id,
    products.product_key,
    reviews.user_id,
    reviews.review_title,
    reviews.review_text,
    reviews.rating,
    reviews.sentiment_label,
    reviews.word_count,
    reviews.char_count,
    reviews.exclamation_count,
    reviews.review_date
from reviews
left join products on reviews.product_id = products.product_id
