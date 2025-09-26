#!/usr/bin/env python3
"""
comparison.py

Compare JSONB (indexed) vs Relational (indexed) by scenario across dataset sizes,
using p95 latency from bench.results.

Metrics (choose with --metric):
  - ratio:          jsonb_p95 / rel_p95          (plotted on log Y)
  - pct (slowdown): ((jsonb_p95/rel_p95)-1)*100  (plotted on symlog Y)

Positive pct = JSONB slower; negative pct = JSONB faster.
"""

import os
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine, text

# -------------------- Connection --------------------
PGHOST     = os.getenv("POSTGRES_HOST", "127.0.0.1")
PGPORT     = int(os.getenv("POSTGRES_PORT", "5433"))
PGDATABASE = os.getenv("POSTGRES_DB", "ledgerdb")
PGUSER     = os.getenv("POSTGRES_USER", "postgres")
PGPASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")

ENGINE = create_engine(
    f"postgresql+psycopg://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{PGDATABASE}",
    pool_pre_ping=True,
)

# -------------------- SQL (p95, indexed only) --------------------
SQL = text("""
WITH base AS (
  SELECT
    (regexp_match(label, '^N=([0-9]+) '))[1]::bigint AS n_rows,
    variant AS scenario,
    CASE
      WHEN label ILIKE '%jsonb_indexed%' THEN 'jsonb_indexed'
      WHEN label ILIKE '%rel_indexed%'   THEN 'rel_indexed'
      ELSE NULL
    END AS design,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY execution_ms) AS p95_ms
  FROM bench.results
  WHERE label LIKE 'N=%'
    AND (label ILIKE '%jsonb_indexed%' OR label ILIKE '%rel_indexed%')
  GROUP BY 1,2,3
),
pivot AS (
  SELECT
    n_rows,
    scenario,
    MAX(p95_ms) FILTER (WHERE design='jsonb_indexed') AS jsonb_p95_ms,
    MAX(p95_ms) FILTER (WHERE design='rel_indexed')   AS rel_p95_ms
  FROM base
  GROUP BY 1,2
)
SELECT
  n_rows,
  scenario,
  jsonb_p95_ms,
  rel_p95_ms,
  (jsonb_p95_ms / NULLIF(rel_p95_ms,0))               AS ratio,
  ((jsonb_p95_ms / NULLIF(rel_p95_ms,0)) - 1.0) * 100 AS slowdown_pct
FROM pivot
ORDER BY scenario, n_rows;
""")

# -------------------- Plotting --------------------
def autoscale_y(values: np.ndarray, pad_frac: float = 0.2, min_span: float = 10.0):
    vals = np.asarray(values, dtype=float)
    vals = vals[np.isfinite(vals)]
    if vals.size == 0:
        return None
    lo, hi = np.percentile(vals, [5, 95])
    span = max(min_span, hi - lo)
    pad  = max(10.0, span * pad_frac)
    return (lo - pad, hi + pad)

def plot_lines(df: pd.DataFrame, metric: str, out_path: str, dpi=180, ylim_arg=None):
    # pivot by scenario over sizes
    col = "ratio" if metric == "ratio" else "slowdown_pct"
    pivot = df.pivot_table(index="n_rows", columns="scenario", values=col)

    fig, ax = plt.subplots(figsize=(10, 6))
    for scen in pivot.columns:
        y = pivot[scen].dropna()
        ax.plot(pivot.index, y, marker='o', label=scen)

    ax.set_xscale("log")
    ax.grid(True, which='both', linestyle=':')

    if metric == "ratio":
        ax.set_yscale("log")
        ax.axhline(1.0, linestyle='--', linewidth=1)  # parity
        ax.set_ylabel("JSONB / Relational (p95, ratio; log scale)")
        ax.set_title("JSONB (indexed) vs Relational (indexed) — Ratio by Scenario (p95)")
    else:
        # percent slowdown; use symlog so near-0 is readable but tails don't crush
        ax.set_yscale('symlog', linthresh=5)  # linear for |y|<=5, log outside
        ax.axhline(0.0, linestyle='--', linewidth=1)  # 0% parity
        ax.set_ylabel("JSONB slower than Relational (%, p95)")
        ax.set_title("JSONB (indexed) vs Relational (indexed) — Slowdown by Scenario (p95)")

    ax.set_xlabel("Dataset size (rows)")
    ax.legend(loc="best", fontsize=8, ncol=2)

    # Y limits
    if ylim_arg:
        try:
            lo, hi = [float(x.strip()) for x in ylim_arg.split(",")]
            ax.set_ylim(lo, hi)
        except Exception:
            pass
    else:
        if metric == "pct":
            lim = autoscale_y(df["slowdown_pct"].values)
            if lim: ax.set_ylim(*lim)

    fig.tight_layout()
    fig.savefig(out_path, dpi=dpi)
    print(f"Saved {out_path}")

# -------------------- Main --------------------
def parse_args():
    ap = argparse.ArgumentParser(
        description="Plot JSONB-vs-Relational (indexed) comparison across sizes using p95."
    )
    ap.add_argument("--dsn", default=None,
                    help="Optional SQLAlchemy DSN; otherwise POSTGRES_* env vars are used.")
    ap.add_argument("--metric", choices=["ratio","pct"], default="ratio",
                    help="Plot 'ratio' (jsonb/rel, log Y) or 'pct' (percent slowdown, symlog Y).")
    ap.add_argument("--out", default=None, help="Output PNG path (auto-chosen if omitted).")
    ap.add_argument("--dpi", type=int, default=180, help="Image DPI.")
    ap.add_argument("--ylim", type=str, default=None,
                    help="Optional Y-limits as 'min,max'.")
    return ap.parse_args()

def main():
    args = parse_args()

    eng = create_engine(args.dsn, pool_pre_ping=True) if args.dsn else ENGINE
    df = pd.read_sql(SQL, eng)
    if df.empty:
        print("No data found. Ensure bench.results has both jsonb_indexed and rel_indexed runs.")
        return

    out = args.out or ("jsonb_vs_rel_ratio_p95.png" if args.metric == "ratio"
                       else "jsonb_slowdown_pct_p95.png")
    plot_lines(df, metric=args.metric, out_path=out, dpi=args.dpi, ylim_arg=args.ylim)

if __name__ == "__main__":
    main()
