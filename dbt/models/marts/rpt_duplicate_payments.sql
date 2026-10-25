-- Control: the same account, amount and merchant category within duplicate_window_minutes.
with t as (
    select
        *,
        lag(tx_id) over (partition by account_id, amount_usd, merchant_category order by tx_ts) as prior_tx_id,
        lag(tx_ts) over (partition by account_id, amount_usd, merchant_category order by tx_ts) as prior_tx_ts
    from {{ ref('stg_bronze__transactions') }}
)

select
    tx_id,
    prior_tx_id,
    account_id,
    amount_usd,
    merchant_category,
    tx_ts,
    {{ dbt.datediff('prior_tx_ts', 'tx_ts', 'minute') }} as minutes_apart
from t
where prior_tx_id is not null
  and {{ dbt.datediff('prior_tx_ts', 'tx_ts', 'minute') }} <= {{ var('duplicate_window_minutes') }}
