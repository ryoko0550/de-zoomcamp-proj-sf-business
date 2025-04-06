{{ config(materialized="view") }}

with
    businessdata as (
        select *
        from {{ source("staging", "sf_business_data") }}
        where unique_row_id is not null
    )

select
    -- identifiers
    {{ dbt.safe_cast("unique_row_id", api.Column.translate_type("bytes")) }}
    as businessid,
    {{ dbt.safe_cast("ownership_name", api.Column.translate_type("string")) }} as owner,
    {{ dbt.safe_cast("full_business_address", api.Column.translate_type("string")) }}
    as business_address,
    {{ dbt.safe_cast("city", api.Column.translate_type("string")) }} as business_city,
    {{ dbt.safe_cast("state", api.Column.translate_type("string")) }} as business_state,
    {{ dbt.safe_cast("business_zip", api.Column.translate_type("integer")) }}
    as business_zip,

    -- timestamps
    cast(dba_start_date as timestamp) as business_start,
    cast(dba_end_date as timestamp) as business_end,
    cast(location_start_date as timestamp) as location_start,
    cast(location_end_date as timestamp) as location_end,

    {{ dbt.safe_cast("lic_code", api.Column.translate_type("string")) }} as lic_code,
    {{ dbt.safe_cast("naic_code", api.Column.translate_type("string")) }} as naic_code,

    {{ dbt.safe_cast("supervisor_district", api.Column.translate_type("string")) }}
    as supervisor_district,
    {{
        dbt.safe_cast(
            "neighborhoods_analysis_boundaries", api.Column.translate_type("string")
        )
    }} as neighborhoods_analysis_boundaries,
    {{ dbt.safe_cast("business_corridor", api.Column.translate_type("string")) }}
    as business_corridor,

    cast(
        (
            case
                when administratively_closed = "***Administratively Closed"
                then 1
                else 0
            end
        ) as integer
    ) as administratively_closed

from
    businessdata,
    unnest(split(lic, " ")) as lic_code,
    unnest(split(naic_code, " ")) as naic_code

limit 1000
