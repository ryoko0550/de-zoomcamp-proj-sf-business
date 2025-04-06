{{
    config(
        materialized='table'
    )
}}


select stg.*,
    dl.description as lic_description,
    dn.description as naic_description,
    ds.supervisor,
    case when stg.business_state = 'CA' then 1 else 0  end as in_state_indicator,
    date_diff(date(IFNULL(location_end, current_timestamp())), date(location_start), day) AS location_duration
from {{ref('stg_sf_business_data')}} as stg
left join {{ref('dim_lic')}} as dl
    on stg.lic_code = dl.code
left join {{ref('dim_naic')}} as dn
    on stg.naic_code = dn.code
left join {{ref('dim_supervisor')}} ds
    on stg.supervisor_district = ds.district
where date_diff(date(IFNULL(location_end, current_timestamp())), date(location_start), day) >=0