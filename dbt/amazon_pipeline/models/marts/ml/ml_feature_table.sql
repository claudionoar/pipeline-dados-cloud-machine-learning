-- Tabela final para consumo pelo módulo de Machine Learning (machine-learning/data_prep.py).
-- Uma linha por review, com o texto original e atributos estruturados do produto associado.

with fact_review as (
    select * from {{ ref('fact_review') }}
),

dim_product as (
    select * from {{ ref('dim_product') }}
)

select
    fact_review.review_key,
    fact_review.review_id,
    fact_review.product_id,
    fact_review.review_title,
    fact_review.review_text,
    fact_review.word_count,
    fact_review.char_count,
    fact_review.exclamation_count,
    fact_review.rating as review_rating,
    fact_review.sentiment_label,
    dim_product.category_root,
    dim_product.discounted_price,
    dim_product.rating as product_rating,
    dim_product.rating_count as product_rating_count
from fact_review
left join dim_product on fact_review.product_key = dim_product.product_key
