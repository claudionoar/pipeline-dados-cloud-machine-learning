
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        sentiment_label as value_field,
        count(*) as n_records

    from PROJETO_OLIST_DB.ANALYTICS.fact_reviews
    group by sentiment_label

)

select *
from all_values
where value_field not in (
    'positive','neutral','negative'
)



  
  
      
    ) dbt_internal_test