
  
    

        create or replace transient table PROJETO_OLIST_DB.ANALYTICS.mart_sentiment_kpis
         as
        (-- Fatos agregados para o dashboard Metabase: indicadores de sentimento por categoria de
-- produto. Cada review está ligada a um pedido (não diretamente a um produto); usa-se o
-- produto do primeiro item do pedido para evitar duplicar a review entre categorias em
-- pedidos com vários itens de categorias diferentes (mesma simplificação documentada em
-- mart_late_delivery_features para o vendedor "primário").

with reviews as (
    select * from PROJETO_OLIST_DB.ANALYTICS.fact_reviews
),

primary_item as (
    select order_id, product_key
    from PROJETO_OLIST_DB.ANALYTICS.fact_order_items
    qualify row_number() over (partition by order_id order by order_item_id) = 1
),

products as (
    select * from PROJETO_OLIST_DB.ANALYTICS.dim_products
)

select
    products.category_name_english,
    count(reviews.review_key) as review_count,
    avg(reviews.review_score) as avg_review_score,
    sum(case when reviews.sentiment_label = 'positive' then 1 else 0 end)
        / nullif(count(reviews.review_key), 0)::float as pct_positive,
    sum(case when reviews.sentiment_label = 'neutral' then 1 else 0 end)
        / nullif(count(reviews.review_key), 0)::float as pct_neutral,
    sum(case when reviews.sentiment_label = 'negative' then 1 else 0 end)
        / nullif(count(reviews.review_key), 0)::float as pct_negative
from reviews
left join primary_item on reviews.order_id = primary_item.order_id
left join products on primary_item.product_key = products.product_key
group by products.category_name_english
        );
      
  