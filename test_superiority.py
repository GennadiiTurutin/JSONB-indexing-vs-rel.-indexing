#!/usr/bin/env python3
"""
test_superiority_csv.py — Superiority test from per-run CSV (bench_results.csv), filtered to a single N.

Data expected (columns subset):
  id, ts, label, variant, run_no, execution_ms, ...

Filter:
  Keeps only rows whose 'label' contains "N=<value>" matching --n (default 1,000,000).

Goal:
  Test whether relational (rel_indexed) is at least Δ faster than JSONB (jsonb_indexed)
  for each scenario (variant) using per-run execution times.

Hypotheses (one-sided):
  H0: E[ log(rel/jsonb) ] >= ln(1-Δ)
  H1: E[ log(rel/jsonb) ] <  ln(1-Δ)

Pairing:
  Merge rows by (variant, run_no) between the two label groups.

Usage:
  python test_superiority_csv.py \
    --csv bench_results.csv \
    --label-rel "rel_indexed" \
    --label-jsonb "jsonb_indexed" \
    --n 1000000 \
    --delta 0.20 --alpha 0.05 --image
"""

import argparse, math, re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# SciPy is optional; fall back to normal CDF if not installed.
try:
    from scipy.stats import t as student_t  # type: ignore
    HAVE_SCIPY = True
except Exception:
    HAVE_SCIPY = False


# ---------------- Utilities ----------------

def normal_cdf(z: float) -> float:
    from math import erf, sqrt
    return 0.5 * (1.0 + erf(z / sqrt(2.0)))


def parse_n_from_label(label: str):
    if not isinstance(label, str):
        return None
    m = re.search(r"\bN\s*=\s*([\d,]+)\b", label, flags=re.IGNORECASE)
    if not m:
        return None
    try:
        return int(m.group(1).replace(",", ""))
    except Exception:
        return None


def substring_filter(df: pd.DataFrame, col: str, needle: str) -> pd.DataFrame:
    m = df[col].astype(str).str.contains(needle, case=False, na=False)
    out = df[m].copy()
    if out.empty:
        options = sorted(df[col].dropna().unique().tolist())
        sample = "\n  - ".join(options[:25])
        raise SystemExit(
            f"No rows match substring '{needle}' in column '{col}'. "
            f"Here are some example labels:\n  - {sample}"
        )
    return out


def one_sided_t_from_sample(x: np.ndarray, mu0: float, alternative="less"):
    x = np.asarray(x, dtype=float)
    x = x[np.isfinite(x)]
    n = x.size
    if n < 2:
        return float("nan"), 0, float("nan")
    mean = float(x.mean())
    sd = float(x.std(ddof=1))
    if sd == 0.0:
        # If all identical, t is ±inf if mean != mu0, else 0
        t = -float("inf") if (mean < mu0 and alternative == "less") else (
            float("inf") if (mean > mu0 and alternative == "greater") else 0.0
        )
        p = 0.0 if abs(t) == float("inf") else 1.0
        return t, n - 1, p
    se = sd / math.sqrt(n)
    t_stat = (mean - mu0) / se
    df = n - 1
    if HAVE_SCIPY:
        p = float(student_t.cdf(t_stat, df)) if alternative == "less" else float(1.0 - student_t.cdf(t_stat, df))
    else:
        p = normal_cdf(t_stat) if alternative == "less" else (1.0 - normal_cdf(t_stat))
    return t_stat, df, p


def summarize_variant(log_ratios: np.ndarray, delta: float, alpha: float):
    """
    Returns dict of stats for one variant.
    - 'passes' is from the one-sided t-test (requires n>=2)
    - 'point_pass' checks geometric mean ratio vs threshold (works for n>=1)
    """
    target = math.log(1.0 - delta)
    x = np.asarray(log_ratios, dtype=float)
    x = x[np.isfinite(x)]
    n = x.size
    mean = float(np.nanmean(x)) if n else float("nan")
    geor = math.exp(mean) if math.isfinite(mean) else float("nan")

    t, df, p = one_sided_t_from_sample(x, mu0=target, alternative="less")
    stat_pass = (p < alpha) if math.isfinite(p) else False
    point_pass = (geor <= (1.0 - delta)) if math.isfinite(geor) else False
    note = "" if n >= 2 else "Only 1 pair; per-variant t-test undefined (df=0)."

    return {
        "n_pairs": int(n),
        "mean_log_ratio": mean,
        "geomean_ratio": geor,
        "threshold_ratio": (1.0 - delta),
        "t_stat": t,
        "df": df,
        "p_value": p,
        "passes": stat_pass,
        "point_pass": point_pass,
        "note": note,
    }


# ---------------- Image rendering ----------------

def render_image_table(out_df: pd.DataFrame, delta: float, alpha: float,
                       out_path: str = "superiority_results.png", dpi: int = 200):
    df = out_df.copy()
    df["improvement_pct"] = (1.0 - df["geomean_ratio"]) * 100.0

    cols = ["variant", "n_pairs", "geomean_ratio", "improvement_pct",
            "threshold_ratio", "t_stat", "df", "p_value", "passes", "point_pass"]
    show = df[cols].copy()

    def _fmt(x):  return f"{x:.4f}" if np.isfinite(x) else "nan"
    def _fmt_pct(x): return ("+" if x >= 0 else "") + f"{x:.1f}%" if np.isfinite(x) else "nan"
    def _fmt_p(p): return (f"{p:.1e}" if p < 1e-4 else f"{p:.4f}") if np.isfinite(p) else "nan"

    show["geomean_ratio"]   = show["geomean_ratio"].map(_fmt)
    show["improvement_pct"] = show["improvement_pct"].map(_fmt_pct)
    show["threshold_ratio"] = show["threshold_ratio"].map(lambda x: f"{x:.2f}")
    show["t_stat"]          = show["t_stat"].map(lambda x: f"{x:.3f}" if np.isfinite(x) else "nan")
    show["p_value"]         = show["p_value"].map(_fmt_p)
    show["passes"]          = show["passes"].map(lambda b: "PASS" if bool(b) else "FAIL")
    show["point_pass"]      = show["point_pass"].map(lambda b: "YES" if bool(b) else "NO")

    col_labels = ["Variant", "Pairs", "GeoMean ratio (rel/jsonb)", "REL faster (Δ%)",
                  "Target ratio", "t", "df", "p-value", "Decision", "Point pass"]
    cell_text = show.values.tolist()

    nrows = len(cell_text)
    fig_w, fig_h = 12.0, max(3.0, 0.90 * (nrows + 3))

    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    ax.axis("off")

    title = "Rel vs JSONB Superiority Test (one-sided)"
    subtitle = f"Target: rel/jsonb ≤ {1.0 - delta:.2f} (≥{int(delta*100)}% faster), α = {alpha}"
    ax.text(0.5, 1.05, title, ha="center", va="bottom", fontsize=16, fontweight="bold", transform=ax.transAxes, color="black")
    ax.text(0.5, 1.01, subtitle, ha="center", va="bottom", fontsize=10, transform=ax.transAxes, color="black")

    col_widths = [0.26, 0.08, 0.20, 0.13, 0.10, 0.08, 0.05, 0.10, 0.10, 0.11]
    tbl = ax.table(cellText=cell_text, colLabels=col_labels, colWidths=col_widths,
                   cellLoc="center", loc="upper center")
    tbl.auto_set_font_size(False); tbl.set_fontsize(9)
    for j in range(len(col_labels)):
        cell = tbl[0, j]; cell.set_facecolor("white"); cell.set_edgecolor("black")
        cell.set_linewidth(1.2); cell.get_text().set_fontsize(11); cell.get_text().set_weight("bold"); cell.PAD = 0.08
    for i in range(1, nrows + 1):
        for j in range(len(col_labels)):
            cell = tbl[i, j]; cell.set_facecolor("white"); cell.set_edgecolor("black")
            cell.set_linewidth(0.8); cell.PAD = 0.10; cell.set_height(0.08)
            if j == 0: cell._loc = "w"
            else: cell._loc = "e"

    # emphasize overall row if present
    overall_idx = df.index[df["variant"] == "__OVERALL__"]
    if len(overall_idx):
        i = int(overall_idx[0]) + 1
        for j in range(len(col_labels)):
            cell = tbl[i, j]; cell.get_text().set_weight("bold"); cell.set_linewidth(1.4)

    ax.text(0.0, -0.06,
            "Decision = PASS if one-sided t-test p < α for H1: E[log(rel/jsonb)] < ln(1−Δ). "
            "'Point pass' ignores variance (n=1 friendly).",
            ha="left", va="top", fontsize=9, color="black", transform=ax.transAxes)

    plt.subplots_adjust(top=0.80, bottom=0.18, left=0.05, right=0.98)
    fig.savefig(out_path, dpi=dpi, bbox_inches="tight", pad_inches=0.6)
    plt.close(fig)


# ---------------- Core logic ----------------

def main():
    ap = argparse.ArgumentParser(description="One-sided superiority test (rel ≥ Δ faster than jsonb) from bench_results.csv using execution_ms, filtered to a single N.")
    ap.add_argument("--csv", required=True, help="Path to bench_results.csv")
    ap.add_argument("--label-rel",   default="rel_indexed",   help="Substring to select relational rows (default: rel_indexed)")
    ap.add_argument("--label-jsonb", default="jsonb_indexed", help="Substring to select JSONB rows (default: jsonb_indexed)")
    ap.add_argument("--n", type=int, default=1_000_000, help="Only keep rows whose label encodes this N via 'N=<value>' (default 1,000,000)")
    ap.add_argument("--delta", type=float, default=0.20, help="Target speedup fraction Δ (default 0.20)")
    ap.add_argument("--alpha", type=float, default=0.05, help="Significance level α (default 0.05)")
    ap.add_argument("--image", action="store_true", help="Render a PNG summary table")
    ap.add_argument("--image-path", default="superiority_results.png", help="PNG output path")
    ap.add_argument("--image-dpi", type=int, default=180, help="PNG DPI")

    args = ap.parse_args()

    # Load CSV
    df = pd.read_csv(args.csv)
    df.columns = [c.strip().lower() for c in df.columns]

    # Sanity checks
    for must in ("label", "variant", "run_no", "execution_ms"):
        if must not in df.columns:
            raise SystemExit(f"CSV must contain column '{must}'")

    # Filter to N parsed from label
    df["n_rows"] = df["label"].apply(parse_n_from_label)
    df = df[df["n_rows"] == args.n].copy()
    if df.empty:
        raise SystemExit(f"No rows found with N={args.n:,} in labels. "
                         "Make sure labels include 'N=<value>' (e.g., 'N=1000000 rel_indexed').")

    # Keep only rows with positive execution_ms
    df["execution_ms"] = pd.to_numeric(df["execution_ms"], errors="coerce")
    df = df[(df["execution_ms"] > 0) & df["execution_ms"].notna()].copy()
    if df.empty:
        raise SystemExit("No valid rows with positive execution_ms after cleaning.")

    # Select the two groups by substring on 'label'
    rel = substring_filter(df, "label", args.label_rel)[["variant", "run_no", "execution_ms"]].rename(columns={"execution_ms": "rel_ms"})
    jsn = substring_filter(df, "label", args.label_jsonb)[["variant", "run_no", "execution_ms"]].rename(columns={"execution_ms": "jsonb_ms"})

    # Pair by (variant, run_no)
    pairs = pd.merge(rel, jsn, on=["variant", "run_no"], how="inner")
    if pairs.empty:
        raise SystemExit("No paired rows after merging by (variant, run_no). Check label substrings and data consistency.")

    # Compute log ratio log(rel/jsonb); drop any non-finite
    pairs["log_ratio"] = np.where((pairs["rel_ms"] > 0) & (pairs["jsonb_ms"] > 0),
                                  np.log(pairs["rel_ms"] / pairs["jsonb_ms"]), np.nan)
    pairs = pairs[np.isfinite(pairs["log_ratio"])].copy()
    if pairs.empty:
        raise SystemExit("All pairs had non-positive or invalid execution_ms.")

    # Per-variant summaries
    out_rows = []
    for variant, g in pairs.groupby("variant", sort=True):
        stats = summarize_variant(g["log_ratio"].to_numpy(), delta=args.delta, alpha=args.alpha)
        out_rows.append({"variant": variant, **stats})
    out_df = pd.DataFrame(out_rows).sort_values("variant").reset_index(drop=True)

    # Overall (pool all paired log-ratios)
    overall_stats = summarize_variant(pairs["log_ratio"].to_numpy(), delta=args.delta, alpha=args.alpha)
    out_df = pd.concat([out_df, pd.DataFrame([{"variant": "__OVERALL__", **overall_stats}])], ignore_index=True)

    # Print + save
    pd.set_option("display.width", 180)
    print(f"\nRel vs JSONB at N={args.n:,} using metric 'execution_ms' (ratio = rel/jsonb). "
          f"Target ratio ≤ {1.0 - args.delta:.2f} (≥{int(args.delta*100)}% faster)")
    print(out_df.to_string(index=False, float_format=lambda x: f"{x:.4g}"))
    out_df.to_csv("./superiority_results.csv", index=False)
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
