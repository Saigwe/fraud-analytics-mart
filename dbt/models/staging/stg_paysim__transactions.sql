-- Typed, renamed PaySim transactions. Balances are as the simulator reports them, errors included.
select
    tx_id,
    step,
    cast('{{ var("simulation_start") }}' as timestamp) + to_hours(step - 1)    as tx_ts,
    type                                                as tx_type,
    cast(amount as decimal(18, 2))                      as amount,
    nameOrig                                            as orig_account,
    cast(oldbalanceOrg as decimal(18, 2))               as orig_balance_before,
    cast(newbalanceOrig as decimal(18, 2))              as orig_balance_after,
    nameDest                                            as dest_account,
    cast(oldbalanceDest as decimal(18, 2))              as dest_balance_before,
    cast(newbalanceDest as decimal(18, 2))              as dest_balance_after,
    starts_with(nameDest, 'M')                          as dest_is_merchant,
    isFraud = 1                                         as is_fraud,
    isFlaggedFraud = 1                                  as is_flagged_by_incumbent
from {{ source('bronze', 'paysim_transactions') }}
