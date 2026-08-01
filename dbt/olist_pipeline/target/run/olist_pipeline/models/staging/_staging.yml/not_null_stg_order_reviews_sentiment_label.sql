
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sentiment_label
from PROJETO_OLIST_DB.ANALYTICS.stg_order_reviews
where sentiment_label is null



  
  
      
    ) dbt_internal_test