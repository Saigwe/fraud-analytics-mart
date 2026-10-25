-- One row per transaction, with the balance features auditors and models use.
-- Balance error = how far the reported balances are from what the amount implies (0 = consistent).
select
    t.*,
    (t.step - 1) // 24                                                  as day_index,
    (t.step - 1) % 24                                                   as hour_of_day,
    case
        when t.tx_type = 'CASH_IN' then t.orig_balance_before + t.amount - t.orig_balance_after
        else t.orig_balance_before - t.amount - t.orig_balance_after
    end                                                                 as orig_balance_error,
    case
        when t.dest_is_merchant then null
        when t.tx_type = 'CASH_IN' then t.dest_balance_before - t.amount - t.dest_balance_after
        else t.dest_balance_before + t.amount - t.dest_balance_after
    end                                                                 as dest_balance_error,
    t.tx_type in ('TRANSFER', 'CASH_OUT') and t.amount > 0
        and t.amount = t.orig_balance_before                            as is_full_drain
from {{ ref('stg_paysim__transactions') }} t
