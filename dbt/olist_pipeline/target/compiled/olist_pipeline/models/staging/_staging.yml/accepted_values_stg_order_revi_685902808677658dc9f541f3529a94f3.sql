
    
    

with all_values as (

    select
        sentiment_label as value_field,
        count(*) as n_records

    from PROJETO_OLIST_DB.ANALYTICS.stg_order_reviews
    group by sentiment_label

)

select *
from all_values
where value_field not in (
    'positive','neutral','negative'
)


