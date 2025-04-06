{{
    config(
        materialized='table'
    )
}}


select stg.*,
    dl.description as lic_description,
    dn.description as naic_description
from {{ref('stg_sf_business_data')}} as stg
left join {{ref('dim_lic')}} as dl
    on stg.lic_code = dl.code
left join {{ref('dim_naic')}} as dn
    on stg.naic_code = dn.code