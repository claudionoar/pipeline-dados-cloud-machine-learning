
    
    

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


