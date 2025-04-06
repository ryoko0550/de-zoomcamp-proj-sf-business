{{
    config(
        materialized='table'
    )
}}

select *
from {{ref('fct_sf_registered_business')}}
where owner in (
    select owner 
    from {{ref('fct_sf_registered_business')}}
    where location_end is null
)