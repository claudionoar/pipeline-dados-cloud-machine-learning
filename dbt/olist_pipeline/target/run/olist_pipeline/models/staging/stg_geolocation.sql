
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_geolocation
  
  
  
  
  as (
    with source as (
    select * from PROJETO_OLIST_DB.RAW.geolocation
)

select
    geolocation_zip_code_prefix as zip_code_prefix,
    geolocation_lat as lat,
    geolocation_lng as lng,
    geolocation_city as city,
    geolocation_state as state
from source
  );

