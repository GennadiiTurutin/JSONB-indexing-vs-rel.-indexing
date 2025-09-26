#!/usr/bin/env python3
# viz_scaling.py (fixed)
# Cross-size scaling plots from multiple performance_run_<N>.xlsx files.
# One FIGURE PER METRIC; inside each figure, small-multiples: one subplot per scenario.
# X-axis = N (rows), lines = series (jsonb/rel × indexed/unindexed).
# Colors: JSONB green, REL red. Linestyle: indexed solid, unindexed dashed.
# Figure-level legend shows all series.

import argparse, os, re, glob, math
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ALL_METRICS = ["p50_ms","p95_ms","avg_ms","sum_shared_reads","sum_shared_hits"]

# Colors by engine
ENGINE_COLOR = {
    "jsonb": "#0a7a0a",  # deep green
    "rel":   "#a01515",  # deep red
}
# Linestyle by indexing
INDEX_STYLE = {
    "indexed":   "-",   # solid
    "unindexed": "--",  # dashed
}
# Markers for clarity
MARKER = {
    ("jsonb","indexed"):   "o",
    ("jsonb","unindexed"): "o",
    ("rel","indexed"):     "s",
    ("rel","unindexed"):   "s",
}

def parse_size_from_filename(path: str) -> int | None:
    m = re.search(r"performance_run_(\d+)\.xlsx$", os.path.basename(path))
    return int(m.group(1)) if m else None

def parse_size_from_label(label: str) -> int | None:
    if not isinstance(label, str):
        return None
    m = re.search(r"\bN\s*=\s*([\d,]+)\b", label)
    if not m:
        return None
    return int(m.group(1).replace(",", ""))

def parse_engine_indexing(label: str) -> tuple[str|None, str|None]:
    """
    Parse engine and indexing from label like:
      'N=1000000 jsonb_indexed' or 'N=1000 rel_unindexed'
    Robust to extra spaces/case; uses regex with word boundaries.
    """
    if not isinstance(label, str):
        return None, None
    l = label.strip().lower()
    m = re.search(r"\b(jsonb|rel)_(unindexed|indexed)\b", l)
    if m:
        eng, idx = m.group(1), m.group(2)
        return eng, idx
    # Fallback (token based) if regex fails
    tokens = set(l.replace("=", " ").replace(",", " ").split())
    eng = "jsonb" if "jsonb" in tokens else ("rel" if "rel" in tokens else None)
    # IMPORTANT: check 'unindexed' before 'indexed'
    idx = "unindexed" if "unindexed" in tokens else ("indexed" if "indexed" in tokens else None)
    return eng, idx

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
    df["series"]   = df.apply(lambda r: f"{r['engine']}_{r['indexing']}" if pd.notna(r["engine"]) and pd.notna(r["indexing"]) else "unknown", axis=1)
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
    for col in ["sum_shared_reads","sum_shared_hits"]:
        if col not in out.columns:
            out[col] = np.nan
    return out

def scenario_family(variant: str) -> str:
    if not isinstance(variant, str):
        return "Other"
    m = re.match(r"^(S\d+)", variant)
    return m.group(1) if m else "Other"

def family_sort_key(fam: str) -> tuple[int,int|str]:
    m = re.match(r"^S(\d+)$", fam)
    return (0, int(m.group(1))) if m else (1, fam)

def choose_series(indexing: str) -> list[str]:
    if indexing == "indexed":
        return ["jsonb_indexed","rel_indexed"]
    if indexing == "unindexed":
        return ["jsonb_unindexed","rel_unindexed"]
    return ["jsonb_indexed","rel_indexed","jsonb_unindexed","rel_unindexed"]

def parse_scale(scale: str) -> tuple[bool,bool]:
    scale = scale.lower()
    if scale in ("xylog","xlogylog"): return True, True
    if scale == "xlog":  return True, False
    if scale == "ylog":  return False, True
    return False, False  # default linear

def fam_title(fam: str) -> str:
    names = {
        "S1":"Equality + Numeric Inequality",
        "S2":"LIKE Prefix Search",
        "S3":"Substring Contains (trigram)",
        "S4":"Timestamp Range",
        "S5":"Array AND (contain both)",
        "S6":"Array OR (overlap)",
        "S7":"Multi-key AND (2 keys)",
        "S8":"Multi-key AND (3 keys)",
        "S9":"OR across keys",
        "S10":"Top-N by timestamp",
    }
    return names.get(fam, fam)

def plot_metric_grid(df: pd.DataFrame, metric: str, variants: list[str], series_keys: list[str],
                     xlog: bool, ylog: bool, outdir: str, title: str | None):
    fams = sorted({scenario_family(v) for v in variants}, key=family_sort_key)
    cols, rows = 2, 5
    fig, axes = plt.subplots(rows, cols, figsize=(6.4*cols, 4.6*rows), squeeze=False)

    for i, fam in enumerate(fams):
        r, c = divmod(i, cols)
        ax = axes[r][c]
        fam_vars = [v for v in variants if scenario_family(v) == fam]
        sub = df[df["variant"].isin(fam_vars)].copy()

        if ylog:
            sub.loc[sub[metric] <= 0, metric] = np.nan

        # fixed plotting order to keep lines consistent across subplots
        order = ["jsonb_indexed","rel_indexed","jsonb_unindexed","rel_unindexed"]
        for key in order:
            if key not in series_keys:
                continue
            eng, idx = key.split("_", 1)

            color = ENGINE_COLOR.get(eng, "#555555")
            style = INDEX_STYLE.get(idx, "-")
            marker = MARKER.get((eng, idx), "o")

            ksub = sub[(sub["engine"] == eng) & (sub["indexing"] == idx)].copy()
            if ksub.empty:
                continue

            # average over same (size) if multiple rows
            grp = ksub.groupby("size", dropna=True, as_index=False)[metric].mean()
            grp = grp.sort_values("size")
            ax.plot(grp["size"], grp[metric], linestyle=style, color=color, marker=marker,
                    label=f"{eng.upper()} ({idx})", linewidth=2, markersize=5)

        ax.set_title(f"{fam} — {fam_title(fam)}")
        ax.set_xlabel("Rows (N)")
        ax.set_ylabel(metric)
        if xlog: ax.set_xscale("log")
        if ylog: ax.set_yscale("log")
        ax.grid(True, which="both", alpha=0.25)

    # hide empty cells
    for j in range(len(fams), rows*cols):
        r, c = divmod(j, cols)
        axes[r][c].axis("off")

    # -------- Figure-level legend --------
    legend_items, legend_labels = [], []
    for key in ["jsonb_indexed","rel_indexed","jsonb_unindexed","rel_unindexed"]:
        if key not in series_keys:
            continue
        eng, idx = key.split("_", 1)
        proxy = Line2D([0],[0],
                       color=ENGINE_COLOR.get(eng, "#555"),
                       linestyle=INDEX_STYLE.get(idx, "-"),
                       marker=MARKER.get((eng, idx), "o"),
                       linewidth=2.5, markersize=6)
        legend_items.append(proxy)
        style_word = "solid" if INDEX_STYLE.get(idx, "-") == "-" else "dashed"
        legend_labels.append(f"{eng.upper()} ({idx}; {style_word})")

    fig.subplots_adjust(top=0.88, bottom=0.20)
    if legend_items:
        fig.legend(legend_items, legend_labels,
                   loc="lower center", bbox_to_anchor=(0.5, 0.02),
                   ncol=min(4, len(legend_items)), frameon=False)

    suptitle = f"Scaling: {metric}"
    if title:
        suptitle = f"{title} — {suptitle}"
    fig.suptitle(suptitle, y=0.96, fontsize=14)

    fig.tight_layout(rect=[0.02, 0.12, 0.98, 0.88])
    fout = os.path.join(outdir, f"scaling_{metric}.png")
    fig.savefig(fout, dpi=150, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)

def main():
    ap = argparse.ArgumentParser(description="Cross-size scaling charts from performance_run_<N>.xlsx files.")
    ap.add_argument("--glob", default="exports/performance_run_*.xlsx", help="Glob for input Excel files")
    ap.add_argument("--outdir", default="viz_scaling", help="Output directory")
    g = ap.add_mutually_exclusive_group(required=False)
    g.add_argument("--metric",  choices=ALL_METRICS, help="Single metric")
    g.add_argument("--metrics", nargs="+", choices=ALL_METRICS, help="Multiple metrics")
    ap.add_argument("--all", action="store_true", help="Plot all metrics")
    ap.add_argument("--variants", nargs="*", default=[], help="Restrict to these variants (e.g. S1_expr_eq_num S4_ts_range)")
    ap.add_argument("--indexing", choices=["both","indexed","unindexed"], default="both",
                    help="Include indexed+unindexed (default), or only one category")
    ap.add_argument("--scale", choices=["xylin","xlog","ylog","xylog"], default="xylin",
                    help="Axis scale preset (default linear)")
    ap.add_argument("--title", default="", help="Optional title prefix")
    args = ap.parse_args()

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
        sub = df[["size","label","variant","engine","indexing", "series", metric]].copy()
        plot_metric_grid(sub, metric, variants, series_keys, xlog, ylog, args.outdir, args.title or None)

        # Tidy CSV for reference (now with correct series)
        tidy = sub.copy()[["size","series","variant",metric]].sort_values(["variant","series","size"])
        tidy.to_csv(os.path.join(args.outdir, f"scaling_{metric}.csv"), index=False)

    print(f"Saved charts to {args.outdir}")

if __name__ == "__main__":
    main()
