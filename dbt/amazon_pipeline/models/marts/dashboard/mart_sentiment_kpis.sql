-- Fatos agregados para o dashboard Metabase: indicadores de sentimento por produto/categoria.

with fact_review as (
    select * from {{ ref('fact_review') }}
),

dim_product as (
    select * from {{ ref('dim_product') }}
)

select
    dim_product.category_root,
    dim_product.product_id,
    dim_product.product_name,
    dim_product.discounted_price,
    dim_product.rating as product_rating,
    count(fact_review.review_key) as review_count,
    avg(fact_review.rating) as avg_review_rating,
    sum(case when fact_review.sentiment_label = 'positive' then 1 else 0 end)
        / nullif(count(fact_review.review_key), 0)::float as pct_positive,
    sum(case when fact_review.sentiment_label = 'neutral' then 1 else 0 end)
        / nullif(count(fact_review.review_key), 0)::float as pct_neutral,
    sum(case when fact_review.sentiment_label = 'negative' then 1 else 0 end)
        / nullif(count(fact_review.review_key), 0)::float as pct_negative
from fact_review
inner join dim_product on fact_review.product_key = dim_product.product_key
group by
    dim_product.category_root,
    dim_product.product_id,
    dim_product.product_name,
    dim_product.discounted_price,
    dim_product.rating
