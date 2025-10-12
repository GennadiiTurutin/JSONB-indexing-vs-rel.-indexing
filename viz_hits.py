#!/usr/bin/env python3
# viz_hits.py
# Composite chart over S1..S10 (variants) for a SINGLE dataset size (default N=1,000,000):
#   - Bars (primary Y): mean Shared Hit Blocks — JSONB (indexed) vs REL (indexed)
#   - Lines (secondary Y): mean latency (ms) — JSONB (indexed) vs REL (indexed)
# Source: bench_results.csv (from EXPLAIN ANALYZE runs). Unindexed rows are excluded.

import argparse, os, re
import numpy as np
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt

# ---------------- Style (grayscale / print-friendly) ----------------
def apply_style(dpi: int = 300, base_font: int = 9):
    mpl.rcParams.update({
        "font.size": base_font,
        "axes.titlesize": base_font + 1,
        "axes.labelsize": base_font,
        "xtick.labelsize": base_font - 1,
        "ytick.labelsize": base_font - 1,
        "legend.fontsize": base_font - 1,
        "figure.dpi": dpi,
        "savefig.dpi": dpi,
        "savefig.bbox": "tight",
        # Axes/grid
        "axes.spines.top": True,
        "axes.spines.right": False,     # primary axis only
        "axes.grid": True,
        "grid.alpha": 0.30,
        "grid.linestyle": (0, (2, 2)),
        # Lines
        "lines.linewidth": 1.3,
        "errorbar.capsize": 0,
    })

# Bars (white + hatch so it's b/w safe)
BAR_FILL   = {"jsonb": "#ffffff", "rel": "#ffffff"}
BAR_HATCH  = {"jsonb": "", "rel": "///"}

# Lines (distinct styles/markers for B/W)
LINE_COLOR = {"jsonb": "#404040", "rel": "#000000"}
LINE_STYLE = {"jsonb": "-", "rel": (0, (4, 2))}
MARKER     = {"jsonb": "o", "rel": "s"}

# ---------------- Helpers ----------------
def infer_engine_indexing(label: str):
    """Return (engine, indexing) from a label string; engine in {jsonb, rel}."""
    if not isinstance(label, str):
        return None, None
    t = label.strip().lower()
    eng = "jsonb" if "jsonb" in t else ("rel" if "rel" in t else None)
    idx = "unindexed" if "unindexed" in t else ("indexed" if "indexed" in t else None)
    return eng, idx

def parse_n_from_label(label: str) -> float | None:
    """Extract N from 'label' e.g. 'N=1000000 jsonb_indexed' or 'N=1,000,000 rel_indexed'."""
    if not isinstance(label, str):
        return None
    m = re.search(r"\bN\s*=\s*([\d,]+)\b", label, flags=re.IGNORECASE)
    if not m:
        return None
    return float(m.group(1).replace(",", ""))

def numeric_variant_key(v: str):
    m = re.match(r"^S(\d+)", str(v))
    return (0, int(m.group(1))) if m else (1, str(v))

def as_1d(arr_like, n: int) -> np.ndarray:
    try:
        a = np.asarray(arr_like, dtype=float)
    except Exception:
        a = np.array([], dtype=float)
    if a.ndim == 0:
        val = a if np.isfinite(a) else np.nan
        return np.full(n, val, dtype=float)
    if a.ndim > 1:
        a = a.ravel()
    if a.size == n:
        return a.astype(float, copy=False)
    if a.size == 1:
        return np.full(n, a.item(), dtype=float)
    return np.full(n, np.nan, dtype=float)

# ---------------- IO + Aggregation ----------------
def load_and_filter(csv_path: str, target_n: float) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    df.columns = [c.strip().lower() for c in df.columns]

    # engine/indexing
    eng_idx = df["label"].apply(infer_engine_indexing)
    df["engine"] = [e for e, _ in eng_idx]
    df["indexing"] = [i for _, i in eng_idx]

    # parse N from label and filter to requested size
    df["n_rows"] = df["label"].apply(parse_n_from_label)
    df = df[(df["n_rows"].notna()) & (df["n_rows"] == float(target_n))]

    # only indexed jsonb/rel
    df = df[(df["engine"].isin(["jsonb", "rel"])) & (df["indexing"] == "indexed")].copy()

    # ensure numeric
    for col in ("execution_ms", "shared_hits"):
        if col not in df.columns:
            df[col] = np.nan
        df[col] = pd.to_numeric(df[col], errors="coerce")

    if "variant" not in df.columns:
        raise SystemExit("bench CSV must contain a 'variant' column (e.g., S1_expr_eq_num).")

    if df.empty:
        raise SystemExit(f"No rows found for N={int(target_n):,} with indexed JSONB/REL.")

    return df

def aggregate(df: pd.DataFrame) -> pd.DataFrame:
    g = df.groupby(["variant", "engine"], dropna=True)
    out = g.agg(
        n=("execution_ms", "size"),
        mean_ms=("execution_ms", "mean"),
        shared_hits_mean=("shared_hits", "mean"),
    ).reset_index()
    out = out.sort_values(["variant", "engine"], key=lambda s: s.map(numeric_variant_key))
    return out

# ---------------- Plot ----------------
def fmt_hits(v: float) -> str:
    if not np.isfinite(v): return "—"
    try:
        return f"{int(round(v)):,}"
    except Exception:
        return f"{v:.0f}"

def fmt_ms(v: float) -> str:
    if not np.isfinite(v): return "—"
    return f"{v:.3f}" if v < 1 else f"{v:.1f}"

def plot_combo(summary: pd.DataFrame, title: str, out_base: str,
               barwidth: float = 0.16, show_value_labels: bool = False):
    engines = ["jsonb", "rel"]
    variants = sorted(summary["variant"].unique().tolist(), key=numeric_variant_key)

    piv_hits = summary.pivot(index="variant", columns="engine", values="shared_hits_mean").reindex(variants)
    piv_mean = summary.pivot(index="variant", columns="engine", values="mean_ms").reindex(variants)

    for e in engines:
        if e not in piv_hits.columns: piv_hits[e] = np.nan
        if e not in piv_mean.columns: piv_mean[e] = np.nan
    piv_hits = piv_hits[engines]
    piv_mean = piv_mean[engines]

    x = np.arange(len(variants), dtype=float)

    y_hits_jsonb = as_1d(piv_hits["jsonb"].values, len(x))
    y_hits_rel   = as_1d(piv_hits["rel"].values,   len(x))
    y_mean_jsonb = as_1d(piv_mean["jsonb"].values, len(x))
    y_mean_rel   = as_1d(piv_mean["rel"].values,   len(x))

    fig, ax = plt.subplots(figsize=(max(9.5, 0.7 * len(variants) + 6), 4.8))

    # Bars: Shared Hit Blocks (primary Y)
    bw = float(barwidth)
    b_jsonb = ax.bar(x - bw/2, y_hits_jsonb, width=bw,
                     label="Shared Hits — JSONB (indexed)",
                     color=BAR_FILL["jsonb"], edgecolor="black", linewidth=0.7,
                     hatch=BAR_HATCH["jsonb"])
    b_rel   = ax.bar(x + bw/2, y_hits_rel,   width=bw,
                     label="Shared Hits — REL (indexed)",
                     color=BAR_FILL["rel"],   edgecolor="black", linewidth=0.7,
                     hatch=BAR_HATCH["rel"])

    ax.set_ylabel("Shared Hit Blocks (mean)")
    ax.set_xticks(x, variants, rotation=0)
    ax.grid(True, axis="y", alpha=0.30)

    # Primary axis starts at 0
    hits_max = np.nanmax([np.nanmax(y_hits_jsonb), np.nanmax(y_hits_rel)])
    if not np.isfinite(hits_max): hits_max = 1.0
    ax.set_ylim(0.0, hits_max * 1.10)
    ax.axhline(0.0, color="#000000", linewidth=0.8)

    # Secondary axis: mean latency lines
    ax2 = ax.twinx()
    ax2.spines["right"].set_visible(True)

    l_jsonb, = ax2.plot(
        x, y_mean_jsonb,
        linestyle=LINE_STYLE["jsonb"], marker=MARKER["jsonb"],
        markersize=4.0, linewidth=1.3, color=LINE_COLOR["jsonb"],
        label="Mean latency — JSONB (indexed)"
    )
    l_rel,   = ax2.plot(
        x, y_mean_rel,
        linestyle=LINE_STYLE["rel"], marker=MARKER["rel"],
        markersize=4.0, linewidth=1.3, color=LINE_COLOR["rel"],
        label="Mean latency — REL (indexed)"
    )
    ax2.set_ylabel("Mean latency (ms)")

    # Secondary axis starts at 0 (shared baseline)
    mean_max = np.nanmax([np.nanmax(y_mean_jsonb), np.nanmax(y_mean_rel)])
    if not np.isfinite(mean_max): mean_max = 1.0
    ax2.set_ylim(0.0, mean_max * 1.10)

    # Title & legend (no overlap)
    ax.set_title(title if title else "Shared Hits (bars) + Mean latency (lines)", pad=18)
    # Reserve top space for legend and title
    # (tight_layout will respect this reserved rectangle)
    fig.tight_layout(rect=[0, 0, 1, 0.90])
    # Centered legend above the axes, below the figure top
    h1, lbl1 = ax.get_legend_handles_labels()
    h2, lbl2 = ax2.get_legend_handles_labels()
    fig.legend(h1 + h2, lbl1 + lbl2,
               loc="upper center", bbox_to_anchor=(0.5, 0.97),
               frameon=False, ncol=2)

    # Optional value labels
    if show_value_labels:
        for bar in list(b_jsonb) + list(b_rel):
            h = bar.get_height()
            if np.isfinite(h):
                ax.text(bar.get_x() + bar.get_width() / 2, h * 1.01, fmt_hits(h),
                        ha="center", va="bottom", fontsize=8)
        for i, v in enumerate(y_mean_jsonb):
            if np.isfinite(v):
                ax2.text(x[i], v * 1.02, fmt_ms(v),
                         ha="center", va="bottom", fontsize=8)
        for i, v in enumerate(y_mean_rel):
            if np.isfinite(v):
                ax2.text(x[i], v * 1.02, fmt_ms(v),
                         ha="center", va="bottom", fontsize=8)

    # Save
    fig.savefig(out_base + ".pdf")
    fig.savefig(out_base + ".png", dpi=350)
    plt.close(fig)

# ---------------- CLI ----------------
def main():
    ap = argparse.ArgumentParser(
        description="Composite chart (single dataset size): Shared Hit Blocks (bars) + mean latency (lines) — Indexed JSONB vs REL."
    )
    ap.add_argument("--csv", required=True, help="Path to bench_results.csv")
    ap.add_argument("--outdir", default="viz_bench", help="Output directory (default: viz_bench)")
    ap.add_argument("--title", default="", help="Optional figure title (we will append N=...)")
    ap.add_argument("--dpi", type=int, default=300, help="Figure DPI")
    ap.add_argument("--barwidth", type=float, default=0.16, help="Grouped bar width (default: 0.16)")
    ap.add_argument("--n", type=float, default=1_000_000,
                    help="Dataset size N to include (parsed from label 'N=<value>'); default 1,000,000")
    bl = ap.add_mutually_exclusive_group()
    bl.add_argument("--labels", dest="labels", action="store_true", help="Show numeric labels on bars/points")
    bl.add_argument("--no-labels", dest="labels", action="store_false", help="Hide numeric labels (default)")
    ap.set_defaults(labels=False)

    args = ap.parse_args()
    apply_style(dpi=args.dpi, base_font=9)
    os.makedirs(args.outdir, exist_ok=True)

    df = load_and_filter(args.csv, target_n=args.n)
    summary = aggregate(df)

    out_base = os.path.join(args.outdir, f"combo_shared_hits_and_mean_by_variant_N_{int(args.n)}")
    n_txt = f"N={int(args.n):,}"
    ttl = (args.title + " — " if args.title else "") + f"Shared Hits (bars) + Mean latency (lines) — Indexed JSONB vs REL — {n_txt}"
    plot_combo(summary, ttl, out_base, barwidth=args.barwidth, show_value_labels=args.labels)

    # Save per-figure summary used for plotting
    summary.to_csv(os.path.join(args.outdir, f"summary_by_variant_N_{int(args.n)}.csv"), index=False)
    print(f"Wrote figures and summary to {args.outdir} (filtered to {n_txt})")

if __name__ == "__main__":
    main()
