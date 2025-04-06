{{ config(materialized='table') }}

select
    {{ dbt.safe_cast("district", api.Column.translate_type("integer")) }} as district,
    supervisor
from {{ref('supervisor_lookup')}}
where district is not null