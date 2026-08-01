
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select is_late
from PROJETO_OLIST_DB.ANALYTICS.mart_late_delivery_features
where is_late is null



  
  
      
    ) dbt_internal_test