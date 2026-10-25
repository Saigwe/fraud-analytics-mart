-- Benford's law by transaction type: observed vs expected share of each leading digit.
with d as (
    select tx_type, cast(left(cast(cast(floor(amount) as bigint) as varchar), 1) as integer) as digit
    from {{ ref('fct_transactions') }}
    where amount >= 1
),

counts as (
    select tx_type, digit, count(*) as transactions
    from d
    group by 1, 2
)

select
    tx_type,
    digit,
    transactions,
    cast(transactions as double) / sum(transactions) over (partition by tx_type)            as observed_share,
    log10(1 + 1.0 / digit)                                                                   as expected_share,
    abs(cast(transactions as double) / sum(transactions) over (partition by tx_type)
        - log10(1 + 1.0 / digit))                                                            as abs_deviation
from counts
