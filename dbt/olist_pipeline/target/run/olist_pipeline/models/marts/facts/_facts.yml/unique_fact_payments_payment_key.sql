
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    payment_key as unique_field,
    count(*) as n_records

from PROJETO_OLIST_DB.ANALYTICS.fact_payments
where payment_key is not null
group by payment_key
having count(*) > 1



  
  
      
    ) dbt_internal_test