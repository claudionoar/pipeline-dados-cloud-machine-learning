
    
    

select
    zip_code_prefix as unique_field,
    count(*) as n_records

from PROJETO_OLIST_DB.ANALYTICS.dim_geolocation
where zip_code_prefix is not null
group by zip_code_prefix
having count(*) > 1


