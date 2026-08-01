
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    order_id as unique_field,
    count(*) as n_records

from PROJETO_OLIST_DB.ANALYTICS.mart_late_delivery_features
where order_id is not null
group by order_id
having count(*) > 1



  
  
      
    ) dbt_internal_test