#!/usr/bin/env python3
"""
test_superiority.py

Hypothesis: relational (rel_indexed) is at least Δ faster than jsonb (jsonb_indexed)
for each scenario (variant) at large N by comparing execution_ms.

We compare paired runs (matching variant, run_no) and test:
    H0: E[ log(rel/jsonb) ] >= ln(1-Δ)
    H1: E[ log(rel/jsonb) ] <  ln(1-Δ)

Default Δ = 0.20  (i.e., ≥20% faster => rel/jsonb ≤ 0.8 => log-ratio ≤ ln(0.8))
One-sided t-test per variant and overall. Uses SciPy if available; otherwise
falls back to a normal approximation.

DB connection:
- Taken from environment variables with defaults:
    PGHOST=127.0.0.1
    PGPORT=5433
    PGDATABASE=ledgerdb
    PGUSER=postgres
    PGPASSWORD=postgres
- Optional --dsn overrides everything.

Usage example:
  python test_superiority.py \
    --label-rel   "N=1000000 rel_indexed" \
    --label-jsonb "N=1000000 jsonb_indexed" \
    --alpha 0.05 --delta 0.20 --image
"""

import os
import math
import argparse
import urllib.parse as urlparse
import pandas as pd
from sqlalchemy import create_engine, text

# Try SciPy for t CDF; fall back to normal CDF if not available
try:
    from scipy.stats import t as student_t  # type: ignore
    HAVE_SCIPY = True
except Exception:
    HAVE_SCIPY = False

# Matplotlib for optional image output
import matplotlib.pyplot as plt


def normal_cdf(z: float) -> float:
    # one-sided CDF for standard normal
    from math import erf
    return 0.5 * (1.0 + erf(z / math.sqrt(2.0)))


def build_engine_from_env(dsn_override: str | None = None):
    """
    Build a SQLAlchemy engine either from --dsn or from env vars
    with safe defaults.
    """
    if dsn_override:
        return create_engine(dsn_override, future=True)

    host = os.getenv("PGHOST", "127.0.0.1")
    port = int(os.getenv("PGPORT", "5433"))
    db   = os.getenv("PGDATABASE", "ledgerdb")
    user = os.getenv("PGUSER", "postgres")
    pwd  = os.getenv("PGPASSWORD", "postgres")

    # URL-quote in case of special chars
    user_q = urlparse.quote_plus(user)
    pwd_q  = urlparse.quote_plus(pwd)

    dsn = f"postgresql+psycopg2://{user_q}:{pwd_q}@{host}:{port}/{db}"
    return create_engine(dsn, future=True)


def assert_table(engine, fqname="bench.results"):
    q = text("SELECT to_regclass(:fq) IS NOT NULL AS ok;")
    with engine.connect() as conn:
        ok = pd.read_sql(q, conn, params={"fq": fqname}).iloc[0]["ok"]
    if not ok:
        raise SystemExit(
            f"Missing table {fqname}. Create it and populate with bench.run_suite_for_size(...)."
        )


def fetch_pairs(engine, label_rel: str, label_jsonb: str) -> pd.DataFrame:
    """
    Return paired rows for each (variant, run_no): rel_ms, jsonb_ms, and log_ratio=ln(rel/jsonb).
    """
    sql = text("""
    WITH r AS (
      SELECT variant, run_no, execution_ms AS ms
      FROM bench.results
      WHERE label = :rel
    ),
    j AS (
      SELECT variant, run_no, execution_ms AS ms
      FROM bench.results
      WHERE label = :jsonb
    )
    SELECT r.variant, r.run_no, r.ms AS rel_ms, j.ms AS jsonb_ms,
           CASE WHEN r.ms > 0 AND j.ms > 0 THEN LN(r.ms / j.ms) END AS log_ratio
    FROM r JOIN j USING(variant, run_no)
    ORDER BY r.variant, r.run_no;
    """)
    with engine.connect() as conn:
        df = pd.read_sql(sql, conn, params={"rel": label_rel, "jsonb": label_jsonb})
    # Drop any rows with null or non-finite log_ratio
    df = df[pd.to_numeric(df["log_ratio"], errors="coerce").notnull()].copy()
    return df


def one_sided_t_pvalue(sample, mu0=0.0, alternative="less"):
    """
    One-sample t-test p-value for H1: mean < mu0 (or > mu0).
    Returns (t_stat, df, p_value).
    If SciPy is missing, use normal approximation.
    """
    import numpy as np
    x = np.asarray(sample, dtype=float)
    x = x[np.isfinite(x)]
    n = x.size
    if n < 2:
        return float("nan"), 0, float("nan")

    mean = float(x.mean())
    sd = float(x.std(ddof=1))
    if sd == 0.0:
        # All identical; t is +/- inf if mean != mu0, else 0
        t = -float("inf") if (mean < mu0 and alternative == "less") else (
            float("inf") if (mean > mu0 and alternative == "greater") else 0.0
        )
        p = 0.0 if abs(t) == float("inf") else 1.0
        return t, n - 1, p

    se = sd / math.sqrt(n)
    t_stat = (mean - mu0) / se
    df = n - 1
    if HAVE_SCIPY:
        if alternative == "less":
            p = float(student_t.cdf(t_stat, df))
        else:  # greater
            p = float(1.0 - student_t.cdf(t_stat, df))
    else:
        # Normal approximation
        if alternative == "less":
            p = normal_cdf(t_stat)
        else:
            p = 1.0 - normal_cdf(t_stat)
    return t_stat, df, p


def summarize_variant(group_df: pd.DataFrame, delta: float, alpha: float):
    """
    For a single variant: test mean(log_ratio) < ln(1 - delta)
    Return dict with stats.
    """
    import numpy as np
    target = math.log(1.0 - delta)  # ln(0.8) for delta=0.2
    logs = group_df["log_ratio"].to_numpy(dtype=float)
    n = int(np.isfinite(logs).sum())
    mean = float(np.nanmean(logs)) if n else float("nan")
    t, df, p = one_sided_t_pvalue(logs, mu0=target, alternative="less")
    success = (p < alpha) if math.isfinite(p) else False
    return {
        "n_pairs": n,
        "mean_log_ratio": mean,
        "geomean_ratio": math.exp(mean) if math.isfinite(mean) else float("nan"),
        "threshold_ratio": (1.0 - delta),
        "t_stat": t,
        "df": df,
        "p_value": p,
        "passes": success,
    }


# ------------------ Image rendering helpers ------------------

def _format_p(p: float) -> str:
    if not math.isfinite(p):
        return "nan"
    if p < 1e-4:
        return f"{p:.1e}"
    return f"{p:.4f}"


def _human_pct(x: float) -> str:
    if not math.isfinite(x):
        return "nan"
    sign = "+" if x >= 0 else ""
    return f"{sign}{x:.1f}%"

def render_image_table(out_df, delta: float, alpha: float,
                       out_path: str = "superiority_results.png",
                       dpi: int = 200,
                       base_width: float = 12.0,
                       row_height_in: float = 0.90,   # << taller rows
                       header_fontsize: int = 11,
                       body_fontsize: int = 9,
                       title_fontsize: int = 16,
                       subtitle_fontsize: int = 10) -> None:
    """
    Monochrome, spacious table:
      - Taller rows via figure height + cell height + extra padding
      - Smaller fonts inside table
      - Black & white only (no color fills)
    """
    import math
    import matplotlib.pyplot as plt
    import pandas as pd

    df = out_df.copy()
    df["improvement_pct"] = (1.0 - df["geomean_ratio"]) * 100.0

    cols = [
        "variant", "n_pairs",
        "geomean_ratio", "improvement_pct",
        "threshold_ratio", "t_stat", "df", "p_value", "passes"
    ]
    show = df[cols].copy()

    def _fmt(x): return f"{x:.4f}" if math.isfinite(x) else "nan"
    def _fmt_pct(x):
        if not math.isfinite(x): return "nan"
        sign = "+" if x >= 0 else ""
        return f"{sign}{x:.1f}%"
    def _fmt_p(p):
        if not math.isfinite(p): return "nan"
        return f"{p:.1e}" if p < 1e-4 else f"{p:.4f}"

    show["geomean_ratio"]   = show["geomean_ratio"].map(_fmt)
    show["improvement_pct"] = show["improvement_pct"].map(_fmt_pct)
    show["threshold_ratio"] = (1.0 - delta)
    show["threshold_ratio"] = show["threshold_ratio"].map(lambda x: f"{x:.2f}")
    show["t_stat"]          = show["t_stat"].map(lambda x: f"{x:.3f}" if math.isfinite(x) else "nan")
    show["p_value"]         = show["p_value"].map(_fmt_p)
    show["passes"]          = show["passes"].map(lambda b: "PASS" if bool(b) else "FAIL")

    col_labels = ["Variant", "Pairs", "GeoMean ratio (rel/jsonb)", "REL faster (Δ%)",
                  "Target ratio", "t", "df", "p-value", "Decision"]
    cell_text = show.values.tolist()

    # Monochrome: no pass/fail coloring
    nrows = len(cell_text)
    fig_w = base_width
    fig_h = max(3.0, row_height_in * (nrows + 3))  # scale height by number of rows

    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    ax.axis("off")

    title = "Rel vs JSONB Superiority Test (one-sided)"
    subtitle = f"Target: rel/jsonb ≤ {1.0 - delta:.2f} (≥{int(delta*100)}% faster), α = {alpha}"
    ax.text(0.5, 1.05, title, ha="center", va="bottom",
            fontsize=title_fontsize, fontweight="bold", transform=ax.transAxes, color="black")
    ax.text(0.5, 1.01, subtitle, ha="center", va="bottom",
            fontsize=subtitle_fontsize, color="black", transform=ax.transAxes)

    # Wider first/ratio columns; all black edges, white faces
    col_widths = [0.26, 0.08, 0.20, 0.13, 0.10, 0.08, 0.05, 0.10, 0.10]

    tbl = ax.table(cellText=cell_text,
                   colLabels=col_labels,
                   colWidths=col_widths,
                   cellLoc="center",
                   loc="upper center")

    # Smaller fonts
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(body_fontsize)

    # Header styling (monochrome)
    for j in range(len(col_labels)):
        cell = tbl[0, j]
        cell.set_facecolor("white")
        cell.set_edgecolor("black")
        cell.set_linewidth(1.2)
        cell.get_text().set_fontsize(header_fontsize)
        cell.get_text().set_weight("bold")
        cell.PAD = 0.08  # more vertical padding

    # Body styling: white cells, black grid, extra padding, taller cells
    # The table uses normalized axes coords; tweak height explicitly.
    for i in range(1, nrows + 1):
        for j in range(len(col_labels)):
            cell = tbl[i, j]
            cell.set_facecolor("white")
            cell.set_edgecolor("black")
            cell.set_linewidth(0.8)
            cell.PAD = 0.10                    # << extra inner space
            cell.set_height(0.08)              # << taller cells
            # Left-align first column; right-align numbers
            if j == 0:
                cell._loc = "w"
            elif j in (1, 2, 3, 4, 5, 6, 7):
                cell._loc = "e"

    # Emphasize OVERALL row only via bold text + heavier border (still monochrome)
    overall_idx = df.index[df["variant"] == "__OVERALL__"]
    if len(overall_idx):
        i = int(overall_idx[0]) + 1
        for j in range(len(col_labels)):
            cell = tbl[i, j]
            cell.get_text().set_weight("bold")
            cell.set_linewidth(1.4)

    # Monochrome footnote
    ax.text(0.0, -0.06,
            "Decision = PASS if one-sided t-test p < α for H1: E[log(rel/jsonb)] < ln(1−Δ). "
            "Δ% = (1 − geomean_ratio)×100.",
            ha="left", va="top", fontsize=9, color="black", transform=ax.transAxes)

    plt.subplots_adjust(top=0.80, bottom=0.18, left=0.05, right=0.98)
    fig.savefig(out_path, dpi=dpi, bbox_inches="tight", pad_inches=0.6)
    plt.close(fig)


# ------------------ Main ------------------

def main():
    ap = argparse.ArgumentParser(description="Test if rel_indexed is ≥Δ faster than jsonb_indexed with one-sided tests.")
    ap.add_argument("--label-rel", required=True, help='Exact label for relational runs, e.g. "N=1000000 rel_indexed"')
    ap.add_argument("--label-jsonb", required=True, help='Exact label for jsonb runs, e.g. "N=1000000 jsonb_indexed"')
    ap.add_argument("--delta", type=float, default=0.20, help="Target speedup fraction (default 0.20 => 20%% faster)")
    ap.add_argument("--alpha", type=float, default=0.05, help="Significance level (default 0.05)")
    ap.add_argument("--dsn", default=None, help="Optional SQLAlchemy DSN; if omitted, uses PG* env vars with defaults")

    # Image options
    ap.add_argument("--image", action="store_true",
                    help="If set, render a nicely formatted PNG summary image.")
    ap.add_argument("--image-path", default="superiority_results.png",
                    help="Path to save the image (PNG). Default: superiority_results.png")
    ap.add_argument("--image-dpi", type=int, default=180,
                    help="Image DPI for the PNG. Default: 180")

    args = ap.parse_args()

    eng = build_engine_from_env(args.dsn)
    assert_table(eng, "bench.results")

    df = fetch_pairs(eng, args.label_rel, args.label_jsonb)
    if df.empty:
        raise SystemExit("No paired runs found. Check labels and that bench.results is populated.")

    # Per-variant analysis
    out_rows = []
    for variant, g in df.groupby("variant", sort=True):
        stats = summarize_variant(g, delta=args.delta, alpha=args.alpha)
        out = {"variant": variant}
        out.update(stats)
        out_rows.append(out)

    out_df = pd.DataFrame(out_rows).sort_values("variant").reset_index(drop=True)

    # Overall test pooling all pairs across variants
    overall = summarize_variant(df, delta=args.delta, alpha=args.alpha)
    overall_row = {"variant": "__OVERALL__", **overall}
    out_df = pd.concat([out_df, pd.DataFrame([overall_row])], ignore_index=True)

    # Pretty print
    pd.set_option("display.max_columns", None)
    pd.set_option("display.width", 160)
    print("\nRel vs JSONB (ratio = rel/jsonb). Target ratio <= {:.2f} (≥{:.0f}% faster)".format(1.0 - args.delta, args.delta * 100))
    print(out_df.to_string(index=False, float_format=lambda x: f"{x:.4g}"))

    # Save CSV
    out_df.to_csv("./results/superiority_results.csv", index=False)
    print("\nSaved: superiority_results.csv")

    # Optional image
    if args.image:
        try:
            render_image_table(out_df, delta=args.delta, alpha=args.alpha,
                               out_path=args.image_path, dpi=args.image_dpi)
            print(f"Saved image: {args.image_path}")
        except Exception as e:
            print(f"[warn] Could not render image: {e}")


if __name__ == "__main__":
    main()
