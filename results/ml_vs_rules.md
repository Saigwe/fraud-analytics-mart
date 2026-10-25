# Model vs rules

Test window: steps 501+ | TRANSFER and CASH_OUT only | 124,630 transactions, 2,652 fraud | train 2,645,779 rows

| Method | Alerts | Precision | Recall |
|---|---|---|---|
| Production rules (C01 + C02) | 2,640 | 100.0% | 99.5% |
| All six controls | 72,390 | 3.6% | 99.6% |
| Incumbent (isFlaggedFraud) | 10 | 100.0% | 0.4% |
| Model, same alert budget as production rules (top 2,640) | 2,640 | 99.9% | 99.4% |
| Model, score >= 0.5 | 2,646 | 99.9% | 99.7% |

Model average precision (area under the precision-recall curve): 0.998. Run time 4s.
