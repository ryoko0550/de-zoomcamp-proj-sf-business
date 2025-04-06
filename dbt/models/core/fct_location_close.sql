{{
    config(
        materialized='table'
    )
}}

select * from {{ref('fct_sf_registered_business')}}
where location_end is not null