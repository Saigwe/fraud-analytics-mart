-- Mean absolute deviation (MAD) from Benford per type, graded with Nigrini's first-digit thresholds.
select
    tx_type,
    sum(transactions)   as transactions,
    avg(abs_deviation)  as mad,
    case
        when avg(abs_deviation) < 0.006 then 'close conformity'
        when avg(abs_deviation) < 0.012 then 'acceptable conformity'
        when avg(abs_deviation) < 0.015 then 'marginal conformity'
        else 'nonconformity'
    end                 as conformity
from {{ ref('rpt_benford_first_digit') }}
group by 1
