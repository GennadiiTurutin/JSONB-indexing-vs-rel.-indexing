#!/usr/bin/env python3
# viz_scaling.py
# One FIGURE PER METRIC; inside each figure, small-multiples: one subplot per scenario.
# Grid: 2 columns × 5 rows (S1..S10).
# X-axis = Rows (N), lines = series (jsonb/rel × indexed/unindexed).
# Style: grayscale-safe, solid vs dashed lines, distinct markers,
#        95% CI bands, vector export (PDF), figure-level legend.
#
# Defaults:
#   - y-axis label removed from each subplot (use --ylabel figure or --ylabel per-axis to change)
#   - double-column width preset unless --ratio is provided

import argparse, os, re, glob
import numpy as np
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ALL_METRICS = ["p50_ms", "p95_ms", "avg_ms", "sum_shared_reads", "sum_shared_hits"]

# Grid geometry (fixed)
COLS, ROWS = 2, 5

def apply_style(dpi: int = 300, base_font: int = 9):
    """Set print-friendly defaults suitable for figures."""
    mpl.rcParams.update({
        # fonts
        "font.size": base_font,
        "axes.titlesize": base_font + 1,
        "axes.labelsize": base_font,
        "xtick.labelsize": base_font - 1,
        "ytick.labelsize": base_font - 1,
        "legend.fontsize": base_font - 1,
        # lines / grid
        "lines.linewidth": 1.2,
        "axes.grid": True,
        "grid.alpha": 0.25,
        "grid.linestyle": (0, (2, 2)),
        # save/fig
        "figure.dpi": dpi,
        "savefig.dpi": dpi,
        "savefig.bbox": "tight",
    })

# Grayscale-safe colors (do not rely on hue alone)
ENGINE_COLOR = {
    "jsonb": "#303030",  # dark gray
    "rel":   "#000000",  # black
}
# Linestyle by indexing (solid vs dashed)
INDEX_STYLE = {
    "indexed":   "-",             # solid
    "unindexed": (0, (4, 2)),     # dashed
}
# Distinct markers
MARKER = {
    ("jsonb", "indexed"):   "o",
    ("jsonb", "unindexed"): "o",
    ("rel",   "indexed"):   "s",
    ("rel",   "unindexed"): "s",
}

# ----------------------- Parsing helpers -----------------------

def parse_size_from_filename(path: str):
    m = re.search(r"performance_run_(\d+)\.xlsx$", os.path.basename(path))
    return int(m.group(1)) if m else None

def parse_size_from_label(label: str):
    if not isinstance(label, str):
        return None
    m = re.search(r"\bN\s*=\s*([\d,]+)\b", label)
    if not m:
        return None
    return int(m.group(1).replace(",", ""))

def parse_engine_indexing(label: str):
    """
    Parse engine and indexing from label like:
      'N=1000000 jsonb_indexed' or 'N=1000 rel_unindexed'
    """
    if not isinstance(label, str):
        return None, None
    l = label.strip().lower()
    m = re.search(r"\b(jsonb|rel)_(unindexed|indexed)\b", l)
    if m:
        eng, idx = m.group(1), m.group(2)
        return eng, idx
    # Fallback token-based
    tokens = set(re.split(r"[\s=,]+", l))
    eng = "jsonb" if "jsonb" in tokens else ("rel" if "rel" in tokens else None)
    idx = "unindexed" if "unindexed" in tokens else ("indexed" if "indexed" in tokens else None)
    return eng, idx

# ----------------------- IO -----------------------

def load_one(path: str) -> pd.DataFrame:
    size = parse_size_from_filename(path)
    df = pd.read_excel(path, sheet_name="summary")
    df.columns = [c.strip().lower() for c in df.columns]

    # derive size if missing
    if size is None and "label" in df.columns and len(df):
        size = parse_size_from_label(df["label"].iloc[0])
    df["size"] = size

    # parse engine/indexing/series from label
    eng_idx = df["label"].apply(parse_engine_indexing)
    df["engine"]   = [e for e, _ in eng_idx]
    df["indexing"] = [i for _, i in eng_idx]
    df["series"]   = df.apply(
        lambda r: f"{r['engine']}_{r['indexing']}" if pd.notna(r["engine"]) and pd.notna(r["indexing"]) else "unknown",
        axis=1
    )
    return df

def collect(files_glob: str) -> pd.DataFrame:
    frames = []
    for p in sorted(glob.glob(files_glob)):
        try:
            d = load_one(p)
            frames.append(d)
        except Exception as e:
            print(f"[warn] skipping {p}: {e}")
    if not frames:
        raise SystemExit(f"No files matched: {files_glob}")
    out = pd.concat(frames, ignore_index=True)
    # normalize optional IO cols
    for col in ["sum_shared_reads", "sum_shared_hits"]:
        if col not in out.columns:
            out[col] = np.nan
    return out

# ----------------------- Scenario helpers -----------------------

def scenario_family(variant: str) -> str:
    if not isinstance(variant, str):
        return "Other"
    m = re.match(r"^(S\d+)", variant)
    return m.group(1) if m else "Other"

def family_sort_key(fam: str):
    m = re.match(r"^S(\d+)$", fam)
    return (0, int(m.group(1))) if m else (1, fam)

def fam_title(fam: str) -> str:
    names = {
        "S1":  "Equality + Numeric Inequality",
        "S2":  "LIKE Prefix Search",
        "S3":  "Substring Contains (trigram)",
        "S4":  "Timestamp Range",
        "S5":  "Array AND (contain both)",
        "S6":  "Array OR (overlap)",
        "S7":  "Multi-key AND (2 keys)",
        "S8":  "Multi-key AND (3 keys)",
        "S9":  "OR across keys",
        "S10": "Top-N by timestamp",
    }
    return names.get(fam, fam)

def choose_series(indexing: str):
    if indexing == "indexed":
        return ["jsonb_indexed", "rel_indexed"]
    if indexing == "unindexed":
        return ["jsonb_unindexed", "rel_unindexed"]
    return ["jsonb_indexed", "rel_indexed", "jsonb_unindexed", "rel_unindexed"]

def parse_scale(scale: str):
    scale = scale.lower()
    if scale in ("xylog", "xlogylog"): return True, True
    if scale == "xlog": return True, False
    if scale == "ylog": return False, True
    return False, False  # default linear

# ----------------------- Plotting -----------------------

def ci_95_from_grouped(grouped, col: str) -> pd.DataFrame:
    """Return mean ± 1.96*SE (approx 95% CI) per group."""
    agg = grouped[col].agg(["mean", "count", "std"]).reset_index()
    # guard zero/one sample
    agg["std"] = agg["std"].fillna(0.0)
    agg["se"] = agg["std"] / np.sqrt(agg["count"].clip(lower=1))
    agg["ci"] = 1.96 * agg["se"]
    return agg

def metric_label(metric: str) -> str:
    """Friendly y-axis label with units."""
    if metric.endswith("_ms"):
        # p95_ms -> p95 (ms)
        base = metric.replace("_ms", "").replace("_", " ")
        return f"{base.upper()} (ms)" if base.lower() in ("p50", "p95", "avg") else f"{metric.replace('_', ' ')} (ms)"
    return metric.replace("_", " ")

def plot_metric_grid(df: pd.DataFrame, metric: str, variants: list[str], series_keys: list[str],
                     xlog: bool, ylog: bool, outdir: str, title: str | None,
                     fig_w: float, fig_h: float, dpi: int, ylabel_mode: str = "none"):
    fams = sorted({scenario_family(v) for v in variants}, key=family_sort_key)

    fig, axes = plt.subplots(ROWS, COLS, figsize=(fig_w * COLS, fig_h * ROWS), squeeze=False)

    for i, fam in enumerate(fams):
        r, c = divmod(i, COLS)
        ax = axes[r][c]
        fam_vars = [v for v in variants if scenario_family(v) == fam]
        sub = df[df["variant"].isin(fam_vars)].copy()

        if ylog:
            # enforce positive values for log scale
            sub.loc[sub[metric] <= 0, metric] = np.nan

        # fixed plotting order to keep lines consistent across subplots
        order = ["jsonb_indexed", "rel_indexed", "jsonb_unindexed", "rel_unindexed"]
        for key in order:
            if key not in series_keys:
                continue
            eng, idx = key.split("_", 1)

            color  = ENGINE_COLOR.get(eng, "#000000")
            style  = INDEX_STYLE.get(idx, "-")
            marker = MARKER.get((eng, idx), "o")

            ksub = sub[(sub["engine"] == eng) & (sub["indexing"] == idx)].copy()
            if ksub.empty:
                continue

            # aggregate mean + CI across identical sizes
            grp = ci_95_from_grouped(ksub.groupby("size", dropna=True), metric)
            grp = grp.sort_values("size")

            # line + CI band
            ax.plot(grp["size"], grp["mean"], linestyle=style, color=color, marker=marker,
                    label=f"{eng.upper()} ({idx})", linewidth=1.4, markersize=4.5)
            ax.fill_between(grp["size"], grp["mean"] - grp["ci"], grp["mean"] + grp["ci"],
                            color=color, alpha=0.15, linewidth=0)

        ax.set_title(f"{fam} — {fam_title(fam)}", pad=4)
        ax.set_xlabel("Rows (N)")
        if ylabel_mode == "per-axis":
            ax.set_ylabel(metric_label(metric))
        if xlog: ax.set_xscale("log")
        if ylog: ax.set_yscale("log")
        ax.grid(True, which="both", alpha=0.25)

    # hide empty cells (in case fewer than 10 families)
    for j in range(len(fams), ROWS * COLS):
        r, c = divmod(j, COLS)
        axes[r][c].axis("off")

    # -------- Figure-level legend (outside, bottom-center) --------
    legend_items, legend_labels = [], []
    for key in ["jsonb_indexed", "rel_indexed", "jsonb_unindexed", "rel_unindexed"]:
        if key not in series_keys:
            continue
        eng, idx = key.split("_", 1)
        proxy = Line2D([0], [0],
                       color=ENGINE_COLOR.get(eng, "#000"),
                       linestyle=INDEX_STYLE.get(idx, "-"),
                       marker=MARKER.get((eng, idx), "o"),
                       linewidth=1.6, markersize=5.0)
        legend_items.append(proxy)
        style_word = "solid" if INDEX_STYLE.get(idx, "-") == "-" else "dashed"
        legend_labels.append(f"{eng.upper()} ({idx}; {style_word})")

    plt.subplots_adjust(top=0.88, bottom=0.20)
    if legend_items:
        fig.legend(legend_items, legend_labels,
                   loc="lower center", bbox_to_anchor=(0.5, 0.02),
                   ncol=min(4, len(legend_items)), frameon=False)

    # Optional shared y label
    if ylabel_mode == "figure":
        fig.supylabel(metric_label(metric))

    # Title + layout
    suptitle = f"Scaling: {metric_label(metric)}"
    if title:
        suptitle = f"{title} — {suptitle}"
    fig.suptitle(suptitle, y=0.965, fontsize=11)

    fig.tight_layout(rect=[0.02, 0.12, 0.98, 0.90])

    # Save vector (PDF) + PNG fallback
    base = os.path.join(outdir, f"scaling_{metric}")
    fig.savefig(base + ".pdf")
    fig.savefig(base + ".png", dpi=max(300, dpi))      # high-DPI raster fallback
    plt.close(fig)

# ----------------------- Main -----------------------

def main():
    ap = argparse.ArgumentParser(description="style cross-size scaling charts from performance_run_<N>.xlsx files.")
    ap.add_argument("--glob", default="exports/performance_run_*.xlsx", help="Glob for input Excel files")
    ap.add_argument("--outdir", default="viz_scaling", help="Output directory")

    # Metric selection
    g = ap.add_mutually_exclusive_group(required=False)
    g.add_argument("--metric",  choices=ALL_METRICS, help="Single metric")
    g.add_argument("--metrics", nargs="+", choices=ALL_METRICS, help="Multiple metrics")
    ap.add_argument("--all", action="store_true", help="Plot all metrics")

    # Filtering / styling
    ap.add_argument("--variants", nargs="*", default=[],
                    help="Restrict to these variants (e.g. S1_expr_eq_num S4_ts_range)")
    ap.add_argument("--indexing", choices=["both", "indexed", "unindexed"], default="both",
                    help="Include indexed+unindexed (default), or only one category")
    ap.add_argument("--scale", choices=["xylin", "xlog", "ylog", "xylog"], default="xylin",
                    help="Axis scale preset (default linear)")
    ap.add_argument("--title", default="", help="Optional title prefix")

    # Y-axis label mode (default 'none' to remove per-subplot labels)
    ap.add_argument("--ylabel", choices=["none", "per-axis", "figure"], default="none",
                    help="Y-axis labeling: none (default), per-axis, or figure (shared).")

    ap.add_argument("--dpi", type=int, default=300, help="Figure DPI (PNG fallback)")
    ap.add_argument("--column", choices=["single", "double"], default="double",
                    help="Figure width preset (single ≈ 3.5in, double ≈ 7.2in). Ignored if --ratio is set.")
    ap.add_argument("--rowheight", type=float, default=2.2,
                    help="Row height in inches (reasonable 2.0–2.6)")
    ap.add_argument("--ratio", type=float, default=None,
                    help="Figure aspect ratio as WIDTH/HEIGHT for the whole figure. "
                         "Overrides --column. Example: --ratio 2 makes width = 2 × height.")

    # Proper on/off flags for styling (default ON)
    # group = ap.add_mutually_exclusive_group()
    args = ap.parse_args()

    apply_style(dpi=args.dpi, base_font=9)

    # Base subplot row height
    fig_h_per_row = args.rowheight

    # Compute per-subplot-column width
    if args.ratio is not None:
        # Enforce: TOTAL_WIDTH = ratio * TOTAL_HEIGHT
        # TOTAL_WIDTH  = (fig_w_per_subplot_col * COLS)
        # TOTAL_HEIGHT = (fig_h_per_row * ROWS)
        fig_w_per_subplot_col = args.ratio * (ROWS / COLS) * fig_h_per_row
    else:
        # Use column presets
        if args.column == "single":
            per_col_w = 3.5  # inches
        else:
            per_col_w = 7.2  # inches (double-column width)
        fig_w_per_subplot_col = per_col_w

    os.makedirs(args.outdir, exist_ok=True)
    df = collect(args.glob)
    if df["size"].isna().any():
        print("[warn] Some files/labels lacked N; dropping those rows.")
        df = df.dropna(subset=["size"])

    # Decide metrics
    if args.all:
        metrics = ALL_METRICS
    elif args.metrics:
        metrics = args.metrics
    elif args.metric:
        metrics = [args.metric]
    else:
        metrics = ["p50_ms"]

    # Normalize variants ordering
    df["variant"] = df["variant"].astype(str)
    all_variants = sorted(
        df["variant"].unique().tolist(),
        key=lambda v: (0, int(re.match(r"^S(\d+)", v).group(1))) if re.match(r"^S(\d+)", v) else (1, v)
    )
    variants = args.variants if args.variants else all_variants

    # Which series to show
    series_keys = choose_series(args.indexing)

    # Axis scales
    xlog, ylog = parse_scale(args.scale)

    for metric in metrics:
        if metric not in df.columns:
            print(f"[warn] metric {metric} not found; skipping.")
            continue
        sub = df[["size", "label", "variant", "engine", "indexing", "series", metric]].copy()
        plot_metric_grid(
            sub, metric, variants, series_keys, xlog, ylog,
            outdir=args.outdir, title=(args.title or None),
            fig_w=fig_w_per_subplot_col, fig_h=fig_h_per_row, dpi=args.dpi,
            ylabel_mode=args.ylabel
        )

        # Tidy CSV for reference (now with correct series)
        tidy = sub.copy()[["size", "series", "variant", metric]].sort_values(["variant", "series", "size"])
        tidy.to_csv(os.path.join(args.outdir, f"scaling_{metric}.csv"), index=False)

    print(f"Saved charts (PDF + PNG) to {args.outdir}")

if __name__ == "__main__":
    main()
