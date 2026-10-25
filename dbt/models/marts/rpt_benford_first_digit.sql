-- Benford's law: observed vs expected share of each leading digit of transaction amounts.
with d as (
    select cast(left(cast(cast(floor(amount_usd * 100) as bigint) as varchar), 1) as integer) as digit
    from {{ ref('stg_bronze__transactions') }}
    where amount_usd >= 0.01
)

select
    digit,
    count(*)                                    as transactions,
    1.0 * count(*) / sum(count(*)) over ()      as observed_share,
    log10(1 + 1.0 / digit)                      as expected_share,
    1.0 * count(*) / sum(count(*)) over () - log10(1 + 1.0 / digit) as deviation
from d
group by 1
