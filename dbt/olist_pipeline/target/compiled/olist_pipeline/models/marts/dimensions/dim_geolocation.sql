-- Agrega a granularidade original de raw.geolocation (várias lat/lng por prefixo de CEP,
-- vindas de GPS de usuários distintos) para uma linha por zip_code_prefix - grão necessário
-- para servir de dimensão de localização de clientes/vendedores em mart_late_delivery_features.

with geolocation as (
    select * from PROJETO_OLIST_DB.ANALYTICS.stg_geolocation
)

select
    zip_code_prefix,
    avg(lat) as lat,
    avg(lng) as lng,
    mode(city) as city,
    mode(state) as state
from geolocation
group by zip_code_prefix