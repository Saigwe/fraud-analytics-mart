"""README chart from results/ml_vs_rules.md (written by the ml step on the real PaySim data).
Usage: python charts/make_charts.py [results/ml_vs_rules.md]"""
import re
import sys
from pathlib import Path

import style as st

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "results" / "ml_vs_rules.md"
OUT = ROOT / "docs" / "charts"

md = SRC.read_text(encoding="utf-8")
rows = []
for line in md.splitlines():
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if line.startswith("|") and len(cells) == 4 and cells[0] != "Method" and not set(cells[0]) <= set("-: "):
        rows.append((cells[0], float(cells[1].replace(",", "")), float(cells[2].rstrip("%")) / 100, float(cells[3].rstrip("%")) / 100))
test = re.search(r"([\d,]+) transactions, ([\d,]+) fraud", md)
short = {"Production rules (C01 + C02)": "Two production rules", "All six controls": "All six controls",
         "Incumbent (isFlaggedFraud)": "Incumbent flag", "Model, same alert budget as production rules (top 2,640)":
         "Model, same alert budget", "Model, score >= 0.5": "Model, score ≥ 0.5"}

f, (a1, a2) = st.plt.subplots(1, 2, figsize=(8, 3.4), dpi=150, sharey=True)
names = [short.get(r[0], r[0]) for r in rows]
y = range(len(rows))
colors = [st.S[0] if "rules" in n.lower() and "six" not in n.lower() else st.S[2] if n.startswith("Model") else st.MUTED for n in names]
a1.barh(list(y), [r[3] for r in rows], color=colors, height=0.6)
for i, r in enumerate(rows):
    a1.text(r[3] + 0.01, i, f"{r[3]:.1%}", va="center", fontsize=8.5, color=st.TEXT2)
a1.set_yticks(list(y), names)
a1.invert_yaxis()
a1.set_xlim(0, 1.18)
a1.set_xticks([0, 0.25, 0.5, 0.75, 1.0])
st.fmt(a1, "x", "pct")
a2.barh(list(y), [r[1] for r in rows], color=colors, height=0.6)
a2.set_xscale("log")
for i, r in enumerate(rows):
    a2.text(r[1] * 1.15, i, f"{r[1]:,.0f}", va="center", fontsize=8.5, color=st.TEXT2)
a2.set_xlim(5, max(r[1] for r in rows) * 12)
a2.xaxis.set_major_formatter(st.FuncFormatter(lambda v, _: f"{v:,.0f}"))
for ax in (a1, a2):
    ax.grid(axis="y", visible=False)
    ax.grid(axis="x", visible=True)
st.head(a1, "Fraud caught (recall)", f"Later time window: {test.group(2)} frauds in {test.group(1)} transactions", flush=True)
st.head(a2, "Alerts raised (log scale)", "Two rules match the model with the same alerts")
st.save(f, OUT / "rules_vs_model.png")
print(f"wrote charts to {OUT}")
