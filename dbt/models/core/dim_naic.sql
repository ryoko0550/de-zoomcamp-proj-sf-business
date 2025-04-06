{{ config(materialized='table') }}

select
    naics_code as code,
    description
from {{ref('naics_lookup')}}
where naics_code is not null