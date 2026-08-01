
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        true_label as value_field,
        count(*) as n_records

    from PROJETO_OLIST_DB.ANALYTICS.mart_ml_results
    group by true_label

)

select *
from all_values
where value_field not in (
    'on_time','late'
)



  
  
      
    ) dbt_internal_test