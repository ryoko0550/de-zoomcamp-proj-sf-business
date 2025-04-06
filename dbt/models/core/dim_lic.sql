{{ config(materialized='table') }}

select
    code,
    description
from {{ref('lic_lookup')}}
where code is not null