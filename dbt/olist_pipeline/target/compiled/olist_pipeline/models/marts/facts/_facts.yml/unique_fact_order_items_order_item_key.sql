
    
    

select
    order_item_key as unique_field,
    count(*) as n_records

from PROJETO_OLIST_DB.ANALYTICS.fact_order_items
where order_item_key is not null
group by order_item_key
having count(*) > 1


