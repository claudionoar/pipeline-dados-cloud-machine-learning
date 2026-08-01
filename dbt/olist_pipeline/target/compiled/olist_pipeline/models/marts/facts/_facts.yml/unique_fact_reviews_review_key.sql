
    
    

select
    review_key as unique_field,
    count(*) as n_records

from PROJETO_OLIST_DB.ANALYTICS.fact_reviews
where review_key is not null
group by review_key
having count(*) > 1


