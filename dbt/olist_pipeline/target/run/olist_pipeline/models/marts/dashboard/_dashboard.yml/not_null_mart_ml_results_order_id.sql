
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select order_id
from PROJETO_OLIST_DB.ANALYTICS.mart_ml_results
where order_id is null



  
  
      
    ) dbt_internal_test