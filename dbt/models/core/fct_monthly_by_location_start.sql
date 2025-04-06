{{
    config(
        materialized='table'
    )
}}

select 
    date_trunc(location_start,month) as location_start_month,
    naic_description,
    lic_description,
    administratively_closed,
    count(businessid) as business_cnt
from {{ref('fct_sf_registered_business')}}
group by 1,2,3,4
order by 1,3,2 desc