"""Compare a gradient-boosted fraud model with the dbt controls on the same later time window.

- Scope: TRANSFER and CASH_OUT, the only types with fraud in PaySim.
- Time split: train on steps <= --split-step, test on later steps (no shuffling, so no look-ahead).
- Fair comparison: the model gets the same alert budget as the rules (top-k scores, k = number of
  transactions any rule flags in the test window).

Writes results/ml_vs_rules.md and prints the table.

Usage
    python analysis/ml_vs_rules.py --db warehouse/fraud_analytics_mart.duckdb
"""
from __future__ import annotations

import argparse
import time
from pathlib import Path

import duckdb
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import average_precision_score

FEATURES = ["amount", "orig_balance_before", "orig_balance_after", "dest_balance_before", "dest_balance_after",
            "orig_balance_error", "dest_balance_error", "is_full_drain", "hour_of_day", "is_transfer"]
ROOT = Path(__file__).resolve().parents[1]


def precision_recall(flagged: np.ndarray, y: np.ndarray) -> tuple[int, float, float]:
    alerts, tp = int(flagged.sum()), int((flagged & y).sum())
    return alerts, (tp / alerts if alerts else 0.0), (tp / y.sum() if y.sum() else 0.0)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default="warehouse/fraud_analytics_mart.duckdb")
    ap.add_argument("--split-step", type=int, default=500)
    ap.add_argument("--out", default=str(ROOT / "results" / "ml_vs_rules.md"))
    args = ap.parse_args()

    t0 = time.perf_counter()
    with duckdb.connect(args.db, read_only=True) as con:
        df = con.execute("""
            select
                t.step,
                cast(t.amount as double) as amount,
                cast(t.orig_balance_before as double) as orig_balance_before,
                cast(t.orig_balance_after as double) as orig_balance_after,
                cast(t.dest_balance_before as double) as dest_balance_before,
                cast(t.dest_balance_after as double) as dest_balance_after,
                cast(t.orig_balance_error as double) as orig_balance_error,
                coalesce(cast(t.dest_balance_error as double), 0) as dest_balance_error,
                cast(t.is_full_drain as integer) as is_full_drain,
                t.hour_of_day,
                cast(t.tx_type = 'TRANSFER' as integer) as is_transfer,
                t.is_fraud,
                t.is_flagged_by_incumbent,
                e.tx_id is not null as is_rule_flagged,
                coalesce(e.is_production, false) as is_production_rule_flagged
            from gold.fct_transactions t
            left join (
                select x.tx_id, bool_or(c.lifecycle = 'production') as is_production
                from gold.rpt_control_exceptions x
                join ref.control_catalogue c on c.control_id = x.control_id
                group by 1
            ) e on e.tx_id = t.tx_id
            where t.tx_type in ('TRANSFER', 'CASH_OUT')
        """).df()

    train, test = df[df.step <= args.split_step], df[df.step > args.split_step]
    y_train, y_test = train.is_fraud.to_numpy(bool), test.is_fraud.to_numpy(bool)
    if y_train.sum() == 0 or y_test.sum() == 0:
        raise SystemExit("need fraud in both the train and test windows; change --split-step")

    model = HistGradientBoostingClassifier(random_state=0, max_iter=200)
    model.fit(train[FEATURES], y_train)
    scores = model.predict_proba(test[FEATURES])[:, 1]

    production = test.is_production_rule_flagged.to_numpy(bool)
    k = int(production.sum())
    top_k = np.zeros(len(test), bool)
    top_k[np.argsort(-scores)[:k]] = True

    rows = [
        ("Production rules (C01 + C02)",) + precision_recall(production, y_test),
        ("All six controls",) + precision_recall(test.is_rule_flagged.to_numpy(bool), y_test),
        ("Incumbent (isFlaggedFraud)",) + precision_recall(test.is_flagged_by_incumbent.to_numpy(bool), y_test),
        (f"Model, same alert budget as production rules (top {k:,})",) + precision_recall(top_k, y_test),
        ("Model, score >= 0.5",) + precision_recall(scores >= 0.5, y_test),
    ]
    ap_score = average_precision_score(y_test, scores)

    lines = [
        f"Test window: steps {args.split_step + 1}+ | TRANSFER and CASH_OUT only | "
        f"{len(test):,} transactions, {int(y_test.sum()):,} fraud | train {len(train):,} rows",
        "",
        "| Method | Alerts | Precision | Recall |",
        "|---|---|---|---|",
        *[f"| {name} | {alerts:,} | {p:.1%} | {r:.1%} |" for name, alerts, p, r in rows],
        "",
        f"Model average precision (area under the precision-recall curve): {ap_score:.3f}. "
        f"Run time {time.perf_counter() - t0:.0f}s.",
    ]
    text = "\n".join(lines)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(f"# Model vs rules\n\n{text}\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
