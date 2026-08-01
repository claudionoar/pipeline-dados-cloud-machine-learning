
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  





with validation_errors as (

    select
        review_id, order_id
    from PROJETO_OLIST_DB.ANALYTICS.stg_order_reviews
    group by review_id, order_id
    having count(*) > 1

)

select *
from validation_errors



  
  
      
    ) dbt_internal_test