# 3-minute walkthrough: Payments Fraud & Continuous-Audit Mart

A timed script for a Loom recording of about 3 minutes (screen plus camera bubble, 1080p). Say it in your own words; the lines are a guide, not a teleprompter.

**Open these tabs before you press record:** README, dbt/models, results/ml_vs_rules.md, docs/design_doc.md, GitHub Actions.

| Time | On screen | What to say |
|---|---|---|
| 0:00–0:20 | Portfolio card, then the README title | Fraud teams run rules nobody measures. I built six audit controls as dbt models over 6.36 million mobile-money transactions and scored each one. The two I'd keep catch 99.4% of fraud at 89.8% precision. |
| 0:20–0:45 | README intro and the Data section | At a Big Four firm I built internal-audit and risk-indicator analytics for tier-1 banks. This rebuilds that control testing on PaySim, a public simulated dataset. No client data is used. |
| 0:45–1:10 | README architecture, then the controls in `dbt/models` | Each control is a model. Each one is scored for precision and recall against the fraud label, and gets a production, review or retired status with the reason recorded. |
| 1:10–1:35 | The exceptions queue and its snapshot | Analysts get one queue with severity, evidence and review status. A dbt snapshot keeps the history of every review decision as an audit trail. |
| 1:35–2:00 | `results/ml_vs_rules.md` | On a later time window the model never saw, gradient boosting only matches the two rules. So the explainable rules stay. |
| 2:00–2:30 | The control performance table in Numbers | The simple over-200k transfer rule would raise 409k alerts at 0.7% precision. A balance check raised 1.18 million alerts for 20 frauds, so it was retired. Answer-key tests prove the planted mule chains are caught. |
| 2:30–2:45 | `docs/design_doc.md`, the options table | The decision I'd defend in an interview: Measure every control against the label before it earns analyst time, and make any model beat the rules on the same alert budget. |
| 2:45–3:00 | Back to the README top | For a bank or fintech, that means review capacity goes to controls that find fraud, and noisy rules are visible and retired. The repo, numbers and design doc are linked under the video. |

## Recording checklist
- Close email, chat and notifications. Zoom the browser to 125% so code is readable.
- Run `make fixture-all` once before recording, so CI-style output is fresh if you show it.
- Keep to one take per section; Loom lets you trim. Aim for 2:45 to 3:10.
- Show real numbers on screen as you say them; never estimate on camera.
- Say "synthetic" out loud wherever the README labels data as synthetic.

## After recording
1. Copy the Loom share link.
2. In `README.md`, replace the roadmap line with `- [x] [3-minute Loom walkthrough](<your Loom link>)` and add the link under the title.
3. Add the link to this project's card on saigwe.github.io.
