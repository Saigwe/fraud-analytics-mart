select
    tx_id,
    account_id,
    tx_ts,
    amount_usd,
    merchant_category,
    channel,
    is_fraud
from {{ source('bronze', 'transactions') }}
