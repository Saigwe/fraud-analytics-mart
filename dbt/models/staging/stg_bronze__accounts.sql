select
    account_id,
    cast(opened_date as date)            as opened_date,
    country_code
from {{ source('bronze', 'accounts') }}
