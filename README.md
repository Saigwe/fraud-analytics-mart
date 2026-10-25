# Payments Fraud & Continuous-Audit Mart

[![CI](https://github.com/Saigwe/fraud-analytics-mart/actions/workflows/ci.yml/badge.svg)](https://github.com/Saigwe/fraud-analytics-mart/actions/workflows/ci.yml)

> Six continuous-audit controls as dbt models over 6.4M mobile-money transactions (PaySim). Each control is scored for precision and recall against the fraud label, the analysts get an exceptions queue with an audit trail, and a gradient-boosted model is compared with the rules on a later, unseen time window.

**Author:** Stanley Igwe, Lead Data (Analytics) Engineer · [Portfolio](https://saigwe.github.io)
**Stack:** Python · dbt Core (unit tests, contracts, snapshots, seeds) · DuckDB · scikit-learn · GitHub Actions
**Status:** 🚧 In progress. The pipeline is built and passes CI on a PaySim-shaped fixture; the full PaySim run is next. See [Roadmap](#roadmap).

Project 14 of my portfolio plan. At a Big Four firm I built internal-audit analytics for tier-1 banks. This repo rebuilds that kind of control testing on public synthetic data; no employer or client data, code or logic is used.

---

## 90-second summary
| | |
|---|---|
| **Problem** | Fraud and audit teams run rules nobody measures. They can't say which controls catch fraud, which only make noise, or whether a model would do better with the same review capacity. |
| **What I built** | Six controls as dbt models, one exceptions table with severity and review status (and SCD2 history), a per-control precision and recall report, Benford's-law conformity, and a time-split model-vs-rules comparison. |
| **Why it matters** | Review capacity goes to the controls that find fraud. Noisy rules are visible and can be retired, and any model has to beat the rules on the same alert budget before it replaces them. |
| **Proof** | Answer-key tests on planted patterns, unit-tested control logic, and an enforced contract on the performance report. See [Numbers](#numbers). |

## Architecture
```mermaid
flowchart LR
  K[PaySim CSV<br/>6.36M rows, Kaggle] -->|ingestion/load_paysim.py| B[(bronze.paysim_transactions)]
  F[tests/fixtures/make_paysim_fixture.py<br/>PaySim-shaped, planted patterns] --> B
  B --> S[stg_paysim__transactions]
  S --> T[fct_transactions<br/>balance errors, drain flag]
  T --> C1[C01 drain] & C2[C02 transfer→cash-out] & C3[C03 balance] & C4[C04 large transfer] & C5[C05 duplicate] & C6[C06 fan-in]
  C1 & C2 & C3 & C4 & C5 & C6 --> E[rpt_control_exceptions<br/>+ reviews seed]
  E --> P[rpt_control_performance<br/>contract enforced]
  E --> H[(snap_exception_status<br/>SCD2 audit trail)]
  T --> BF[rpt_benford_*]
  T & E --> ML[analysis/ml_vs_rules.py]
```

## Controls
| ID | Control | Logic | Severity |
|---|---|---|---|
| C01 | Full balance drain | TRANSFER or CASH_OUT that empties the sender's account | high |
| C02 | Transfer → cash-out chain | TRANSFER and CASH_OUT of the identical amount in the same hour (mule pattern); both legs flagged | high |
| C03 | Sender balance inconsistency | funded sender whose balance change doesn't match the amount (ledger integrity) | medium |
| C04 | Large transfer | TRANSFER above 200,000 (the simple threshold rule) | medium |
| C05 | Duplicate payment | same sender, receiver, type and amount within 2 hours | medium |
| C06 | Fan-in | 4+ different senders transferring to one account in a day | high |

Thresholds are dbt vars, so a reviewer can change one and rebuild. The control catalogue (name, severity, owner) is a seed.

## Data model (gold layer)
| Model | Grain | Purpose |
|---|---|---|
| `fct_transactions` | one row per transaction | typed amounts, sender/receiver balance errors, drain flag, day and hour |
| `ctl_c01` … `ctl_c06` | one row per hit | each control's logic, isolated and unit-testable |
| `rpt_control_exceptions` | control × transaction | the analysts' queue: severity, evidence, review status |
| `snap_exception_status` | exception × status version | SCD2 history of review decisions (audit trail) |
| `rpt_control_performance` | one row per control | alerts, true positives, precision, recall; plus ANY_RULE and the incumbent `isFlaggedFraud` |
| `rpt_benford_first_digit` / `rpt_benford_conformity` | type × digit / type | Benford's-law test with Nigrini's MAD thresholds |

## Tests
- **Answer key (fixture only):** the fixture plants 40 mule chains, 10 duplicate payments and a fan-in account. `assert_planted_patterns_detected` fails if the control built for any of them misses it.
- **Unit tests:**
  - the chain control flags both legs of a same-hour, same-amount pair, and ignores a different hour, a different amount and other types
  - balance errors are zero for consistent rows and signed correctly for CASH_IN
- **Contract:** `rpt_control_performance` has enforced column names and types, so downstream dashboards can't break silently.
- **Business rules:**
  - true positives never exceed alerts
  - precision and recall stay in [0, 1]
  - every control that fires is reported
  - Benford shares sum to 1
- **Generic tests:** keys are unique and not null; control IDs exist in the catalogue; statuses come from an allowed list.

## Numbers
**CI fixture** (20,105 PaySim-shaped rows): `dbt build` 39/39 passing. All 51 planted patterns are found.

| Control | Alerts | Precision | Recall |
|---|---|---|---|
| C01 drain | 80 | 100% | 100% |
| C02 transfer → cash-out | 80 | 100% | 100% |
| C03 balance inconsistency | 3,563 | 0% | 0% |
| Incumbent `isFlaggedFraud` | 4 | 100% | 5% |

The fixture's fraud is planted to fit C01 and C02, so these rows show the plumbing works, not that the controls are good.

**Full PaySim (6.36M rows):** _pending: the run happens once the file is downloaded (see How to run)._ This table will hold per-control precision and recall, Benford conformity by type, and model vs rules on the held-out window.

## How to run
Requires **Python 3.12** (what CI uses) and `make`, or run the commands in the `Makefile` by hand.
```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
make fixture-all   # PaySim-shaped fixture -> dbt build with answer-key tests -> model vs rules (CI)
```
Full data:
1. Download PaySim from [Kaggle](https://www.kaggle.com/datasets/ealaxi/paysim1). A free sign-in is needed.
2. Unzip it to `data/raw/paysim.csv`.
3. Run `make all`.

## Roadmap
- [x] PaySim loader, and a PaySim-shaped fixture with an answer key
- [x] Six controls, exceptions queue with review status and SCD2 snapshot, per-control precision/recall, Benford conformity
- [x] Unit tests, contract, answer-key and business-rule tests; time-split model vs rules
- [ ] Full PaySim run; fill in [Numbers](#numbers) and tune the noisy controls
- [ ] Slim CI: build only modified models and their children (`state:modified+`) against a stored production manifest
- [ ] Semantic layer for exception metrics (alerts, hit rate, time to review)
- [ ] Snowflake or BigQuery run, with runtime and cost
- [ ] Design doc and a 3-minute Loom walkthrough

## Interview topics this project prepares
- Rules vs ML for fraud, and judging both at the same alert budget
- Precision, recall and the cost of false positives in an operations queue
- Benford's law and its limits
- Data contracts, unit tests and answer-key testing in dbt
- SCD2 snapshots for audit trails

## Data and licence
- **PaySim:** E. A. Lopez-Rojas, A. Elmir and S. Axelsson, "PaySim: A financial mobile money simulator for fraud detection", 28th European Modeling and Simulation Symposium (EMSS), 2016. It's a simulation built on aggregated real logs; no real customers. Check the licence on its [Kaggle page](https://www.kaggle.com/datasets/ealaxi/paysim1). The raw file is not committed (`data/` is gitignored).
- **Fixture:** synthetic, fixed seed. It describes no real company or person.
- **Code:** MIT (see `LICENSE`).
