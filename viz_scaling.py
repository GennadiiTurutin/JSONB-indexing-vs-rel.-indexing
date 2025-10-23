#!/usr/bin/env python3
# viz_scaling.py — absolute lines + dashed percent comparison overlay
# One FIGURE PER METRIC; small-multiples 2x5 (S1..S10).
# Left Y: absolute performance (same as before).
# Right Y: dashed line(s) = % difference vs REL: 100*(JSONB/REL - 1).
#   0% = parity, >0% = JSONB slower, <0% = JSONB faster.

import argparse, os, re, glob
import numpy as np
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import matplotlib.ticker as mtick

ALL_METRICS = ["p50_ms", "p95_ms", "avg_ms", "sum_shared_reads", "sum_shared_hits"]
COLS, ROWS = 2, 5

def apply_style(dpi: int = 300, base_font: int = 9):
    mpl.rcParams.update({
        "font.size": base_font,
        "axes.titlesize": base_font + 1,
        "axes.labelsize": base_font,
        "xtick.labelsize": base_font - 1,
        "ytick.labelsize": base_font - 1,
        "legend.fontsize": base_font - 1,
        "lines.linewidth": 1.2,
        "axes.grid": True,
        "grid.alpha": 0.25,
        "grid.linestyle": (0, (2, 2)),
        "figure.dpi": dpi,
        "savefig.dpi": dpi,
        "savefig.bbox": "tight",
    })

# Grayscale-safe palette for absolute lines
ENGINE_COLOR = {"jsonb": "#303030", "rel": "#000000"}
INDEX_STYLE  = {"indexed": "-", "unindexed": (0, (4, 2))}
MARKER       = {("jsonb","indexed"):"o",("jsonb","unindexed"):"o",
                ("rel","indexed"):"s",("rel","unindexed"):"s"}

# Percent overlay (right Y)
PCT_COLOR = "#5a5a5a"
PCT_STYLE = {"indexed": (0, (3, 3)), "unindexed": (0, (6, 3))}
PCT_MARK  = {"indexed": None, "unindexed": None}

# ----------------------- parsing -----------------------

def parse_size_from_filename(path: str):
    m = re.search(r"performance_run_(\d+)\.xlsx$", os.path.basename(path))
    return int(m.group(1)) if m else None

def parse_size_from_label(label: str):
    if not isinstance(label, str): return None
    m = re.search(r"\bN\s*=\s*([\d,]+)\b", label)
    return int(m.group(1).replace(",", "")) if m else None

def parse_engine_indexing(label: str):
    if not isinstance(label, str): return None, None
    l = label.strip().lower()
    m = re.search(r"\b(jsonb|rel)_(unindexed|indexed)\b", l)
    if m: return m.group(1), m.group(2)
    toks = set(re.split(r"[\s=,]+", l))
    eng = "jsonb" if "jsonb" in toks else ("rel" if "rel" in toks else None)
    idx = "unindexed" if "unindexed" in toks else ("indexed" if "indexed" in toks else None)
    return eng, idx

# ----------------------- IO -----------------------

def load_one(path: str) -> pd.DataFrame:
    size = parse_size_from_filename(path)
    df = pd.read_excel(path, sheet_name="summary")
    df.columns = [c.strip().lower() for c in df.columns]
    if size is None and "label" in df.columns and len(df):
        size = parse_size_from_label(df["label"].iloc[0])
    df["size"] = size

    eng_idx = df["label"].apply(parse_engine_indexing)
    df["engine"]   = [e for e,_ in eng_idx]
    df["indexing"] = [i for _,i in eng_idx]
    df["series"]   = df.apply(
        lambda r: f"{r['engine']}_{r['indexing']}" if pd.notna(r["engine"]) and pd.notna(r["indexing"]) else "unknown",
        axis=1
    )
    return df

def collect(files_glob: str) -> pd.DataFrame:
    frames = []
    for p in sorted(glob.glob(files_glob)):
        try:
            frames.append(load_one(p))
        except Exception as e:
            print(f"[warn] skipping {p}: {e}")
    if not frames:
        raise SystemExit(f"No files matched: {files_glob}")
    out = pd.concat(frames, ignore_index=True)
    for col in ["sum_shared_reads", "sum_shared_hits"]:
        if col not in out.columns: out[col] = np.nan
    return out

# ----------------------- helpers -----------------------

def scenario_family(variant: str) -> str:
    if not isinstance(variant, str): return "Other"
    m = re.match(r"^(S\d+)", variant)
    return m.group(1) if m else "Other"

def family_sort_key(fam: str):
    m = re.match(r"^S(\d+)$", fam)
    return (0, int(m.group(1))) if m else (1, fam)

def fam_title(fam: str) -> str:
    names = {
        "S1":"Equality + Numeric Inequality", "S2":"LIKE Prefix Search",
        "S3":"Substring Contains (trigram)", "S4":"Timestamp Range",
        "S5":"Array AND (contain both)", "S6":"Array OR (overlap)",
        "S7":"Multi-key AND (2 keys)", "S8":"Multi-key AND (3 keys)",
        "S9":"OR across keys", "S10":"Top-N by timestamp",
    }
    return names.get(fam, fam)

def choose_series(indexing: str):
    if indexing == "indexed":   return ["jsonb_indexed","rel_indexed"]
    if indexing == "unindexed": return ["jsonb_unindexed","rel_unindexed"]
    return ["jsonb_indexed","rel_indexed","jsonb_unindexed","rel_unindexed"]

def parse_scale(scale: str):
    scale = scale.lower()
    if scale in ("xylog","xlogylog"): return True, True
    if scale == "xlog": return True, False
    if scale == "ylog": return False, True
    return False, False

def ci_95_from_grouped(grouped, col: str) -> pd.DataFrame:
    agg = grouped[col].agg(["mean","count","std"]).reset_index()
    agg["std"] = agg["std"].fillna(0.0)
    agg["se"]  = agg["std"] / np.sqrt(agg["count"].clip(lower=1))
    agg["ci"]  = 1.96 * agg["se"]
    return agg

def metric_label(metric: str) -> str:
    if metric.endswith("_ms"):
        base = metric.replace("_ms","").replace("_"," ")
        return f"{base.upper()} (ms)" if base.lower() in ("p50","p95","avg") else f"{metric.replace('_',' ')} (ms)"
    return metric.replace("_", " ")

# ---- compute % slower vs REL (per indexing category) ----
def compute_pct_vs_rel(sub: pd.DataFrame, metric: str) -> pd.DataFrame:
    """
    Returns a DF indexed by (variant,size,indexing) with columns:
      abs_jsonb, abs_rel, pct_slower
    pct_slower = 100*(jsonb/rel - 1), NaN if missing.
    Uses group mean per (variant,size,engine,indexing).
    """
    grouped = sub.groupby(["variant","size","engine","indexing"], dropna=True)
    abs_agg = ci_95_from_grouped(grouped, metric).rename(columns={"mean":"abs_mean","ci":"abs_ci"})
    piv = abs_agg.pivot_table(index=["variant","size","indexing"], columns="engine",
                              values="abs_mean", aggfunc="first").reset_index()
    piv["abs_jsonb"] = piv.get("jsonb")
    piv["abs_rel"]   = piv.get("rel")
    piv["pct_slower"] = np.where(
        (piv["abs_rel"].notna()) & (piv["abs_rel"] != 0) & (piv["abs_jsonb"].notna()),
        100.0*(piv["abs_jsonb"]/piv["abs_rel"] - 1.0),
        np.nan
    )
    return piv.sort_values(["variant","indexing","size"])

# ---- pretty ticks for log-X ----
def pretty_log_x_ticks(ax, sizes):
    # Major at powers of 10 within range; labels 1k, 10k, 100k, 1M, 10M ...
    if len(sizes) == 0: return
    smin, smax = np.nanmin(sizes), np.nanmax(sizes)
    if smin <= 0: smin = 1
    pmin = int(np.floor(np.log10(smin)))
    pmax = int(np.ceil(np.log10(smax)))
    majors = [10**p for p in range(pmin, pmax + 1)]
    labels = []
    for v in majors:
        if v >= 1_000_000:
            labels.append(f"{int(v/1_000_000)}M")
        elif v >= 1_000:
            labels.append(f"{int(v/1_000)}k")
        else:
            labels.append(str(int(v)))
    ax.set_xticks(majors)
    ax.set_xticklabels(labels)
    ax.xaxis.set_minor_locator(mtick.LogLocator(base=10.0, subs=tuple(range(2, 10)), numticks=12))
    ax.xaxis.set_minor_formatter(mtick.NullFormatter())

# ----------------------- plotting -----------------------

def plot_metric_grid(df: pd.DataFrame, metric: str, variants: list[str], series_keys: list[str],
                     xlog: bool, ylog: bool, outdir: str, title: str | None,
                     fig_w: float, fig_h: float, dpi: int, ylabel_mode: str = "none",
                     show_pct: bool = True, y2_log: bool = False, show_parity: bool = True):
    fams = sorted({scenario_family(v) for v in variants}, key=family_sort_key)
    fig, axes = plt.subplots(ROWS, COLS, figsize=(fig_w*COLS, fig_h*ROWS), squeeze=False)

    for i, fam in enumerate(fams):
        r, c = divmod(i, COLS)
        ax = axes[r][c]
        fam_vars = [v for v in variants if scenario_family(v) == fam]
        sub = df[df["variant"].isin(fam_vars)].copy()

        if ylog: sub.loc[sub[metric] <= 0, metric] = np.nan

        # --- Absolute layer (left axis) ---
        order = ["jsonb_indexed","rel_indexed","jsonb_unindexed","rel_unindexed"]
        for key in order:
            if key not in series_keys: continue
            eng, idx = key.split("_", 1)
            color, style, marker = ENGINE_COLOR.get(eng,"#000"), INDEX_STYLE.get(idx,"-"), MARKER.get((eng,idx),"o")
            ksub = sub[(sub["engine"]==eng) & (sub["indexing"]==idx)]
            if ksub.empty: continue
            grp = ci_95_from_grouped(ksub.groupby("size", dropna=True), metric).sort_values("size")
            ax.plot(grp["size"], grp["mean"], linestyle=style, color=color, marker=marker,
                    label=f"{eng.upper()} ({idx})", linewidth=1.4, markersize=4.5)
            ax.fill_between(grp["size"], grp["mean"]-grp["ci"], grp["mean"]+grp["ci"],
                            color=color, alpha=0.15, linewidth=0)

        ax.set_title(f"{fam} — {fam_title(fam)}", pad=4)
        ax.set_xlabel("Rows (N)")
        if ylabel_mode == "per-axis": ax.set_ylabel(metric_label(metric))
        if xlog:
            ax.set_xscale("log")
            # make ticks pretty based on all sizes present in this subplot
            pretty_log_x_ticks(ax, sub["size"].values)
        if ylog: ax.set_yscale("log")
        ax.grid(True, which="both", alpha=0.25)

        # --- Percent overlay (right axis): dashed line(s) ---
        if show_pct:
            pct_df = compute_pct_vs_rel(sub[["variant","size","engine","indexing",metric]].rename(columns={metric:metric}), metric)
            ax2 = ax.twinx()
            drew_any = False
            for idx_cat in ["indexed","unindexed"]:
                needed = {f"jsonb_{idx_cat}", f"rel_{idx_cat}"}
                if not needed.issubset(set(series_keys)): continue
                rsub = pct_df[(pct_df["indexing"]==idx_cat) & (pct_df["variant"].isin(fam_vars))]
                if rsub.empty or rsub["pct_slower"].notna().sum()==0: continue
                rsub = rsub.sort_values("size")
                ax2.plot(rsub["size"], rsub["pct_slower"],
                         linestyle=PCT_STYLE[idx_cat], color=PCT_COLOR,
                         marker=PCT_MARK[idx_cat], linewidth=1.5,
                         label=f"% slower (JSONB vs REL, {idx_cat})")
                drew_any = True
            if drew_any:
                if y2_log:
                    ymin = np.nanmin(pct_df["pct_slower"].values)
                    if ymin <= 0:
                        # If using log on a series that crosses/equals 0, keep linear instead
                        pass
                    ax2.set_yscale("log")
                ax2.set_ylabel("% slower than REL")
                if show_parity:
                    ymin, ymax = ax2.get_ylim()
                    ax2.axhline(0.0, color="#8a8a8a", linewidth=1.0, linestyle=(0,(2,2)))
                    ax2.set_ylim(ymin, ymax)

    # Hide unused cells
    for j in range(len(fams), ROWS*COLS):
        r, c = divmod(j, COLS)
        axes[r][c].axis("off")

    # Figure-level legend (absolute + percent proxies)
    legend_items, legend_labels = [], []
    for key in ["jsonb_indexed","rel_indexed","jsonb_unindexed","rel_unindexed"]:
        if key not in series_keys: continue
        eng, idx = key.split("_", 1)
        proxy = Line2D([0],[0], color=ENGINE_COLOR.get(eng,"#000"),
                       linestyle=INDEX_STYLE.get(idx,"-"),
                       marker=MARKER.get((eng,idx),"o"),
                       linewidth=1.6, markersize=5.0)
        legend_items.append(proxy)
        style_word = "solid" if INDEX_STYLE.get(idx,"-")=="-" else "dashed"
        legend_labels.append(f"{eng.upper()} ({idx}; {style_word})")
    # percent proxies
    for idx_cat in ["indexed","unindexed"]:
        needed = {f"jsonb_{idx_cat}", f"rel_{idx_cat}"}
        if needed.issubset(set(series_keys)):
            proxy = Line2D([0],[0], color=PCT_COLOR, linestyle=PCT_STYLE[idx_cat],
                           linewidth=1.6, marker=None)
            legend_items.append(proxy)
            legend_labels.append(f"% slower (JSONB vs REL, {idx_cat})")

    plt.subplots_adjust(top=0.88, bottom=0.20)
    if legend_items:
        fig = plt.gcf()
        fig.legend(legend_items, legend_labels,
                   loc="lower center", bbox_to_anchor=(0.5, 0.02),
                   ncol=min(4, len(legend_items)), frameon=False)

    if ylabel_mode == "figure":
        plt.gcf().supylabel(metric_label(metric))

    suptitle = f"Scaling: {metric_label(metric)}"
    if title: suptitle = f"{title} — {suptitle}"
    plt.gcf().suptitle(suptitle, y=0.965, fontsize=11)
    plt.gcf().tight_layout(rect=[0.02, 0.12, 0.98, 0.90])

    base = os.path.join(outdir, f"scaling_{metric}")
    plt.gcf().savefig(base + ".pdf")
    plt.gcf().savefig(base + ".png", dpi=300)
    plt.close(plt.gcf())

# ----------------------- main -----------------------

def main():
    ap = argparse.ArgumentParser(description="Scaling charts with absolute lines + dashed percent overlay.")
    ap.add_argument("--glob", default="exports/performance_run_*.xlsx", help="Glob for input Excel files")
    ap.add_argument("--outdir", default="viz_scaling", help="Output directory")

    g = ap.add_mutually_exclusive_group(required=False)
    g.add_argument("--metric",  choices=ALL_METRICS)
    g.add_argument("--metrics", nargs="+", choices=ALL_METRICS)
    ap.add_argument("--all", action="store_true")

    ap.add_argument("--variants", nargs="*", default=[], help="Restrict to variants (e.g. S1_expr_eq_num S4_ts_range)")
    ap.add_argument("--indexing", choices=["both","indexed","unindexed"], default="both")
    ap.add_argument("--scale", choices=["xylin","xlog","ylog","xylog"], default="xylin")
    ap.add_argument("--title", default="")
    ap.add_argument("--ylabel", choices=["none","per-axis","figure"], default="none")

    ap.add_argument("--dpi", type=int, default=300)
    ap.add_argument("--column", choices=["single","double"], default="double")
    ap.add_argument("--rowheight", type=float, default=2.2)
    ap.add_argument("--ratio", type=float, default=None,
                    help="Figure WIDTH/HEIGHT; overrides --column")

    # Right-axis options
    ap.add_argument("--no-pct", dest="pct", action="store_false", help="Disable percent overlay")
    ap.add_argument("--y2log", action="store_true", help="Log scale for percent axis (use with care)")
    ap.add_argument("--no-parity", dest="parity", action="store_false", help="Hide 0% parity line")

    args = ap.parse_args()
    apply_style(dpi=args.dpi, base_font=9)

    fig_h_per_row = args.rowheight
    if args.ratio is not None:
        fig_w_per_subplot_col = args.ratio * (ROWS / COLS) * fig_h_per_row
    else:
        fig_w_per_subplot_col = 3.5 if args.column == "single" else 7.2

    os.makedirs(args.outdir, exist_ok=True)
    df = collect(args.glob)
    if df["size"].isna().any():
        print("[warn] Some files/labels lacked N; dropping those rows.")
        df = df.dropna(subset=["size"])

    if args.all:
        metrics = ALL_METRICS
    elif args.metrics:
        metrics = args.metrics
    elif args.metric:
        metrics = [args.metric]
    else:
        metrics = ["p50_ms"]

    df["variant"] = df["variant"].astype(str)
    all_variants = sorted(
        df["variant"].unique().tolist(),
        key=lambda v: (0, int(re.match(r"^S(\d+)", v).group(1))) if re.match(r"^S(\d+)", v) else (1, v)
    )
    variants    = args.variants if args.variants else all_variants
    series_keys = choose_series(args.indexing)
    xlog, ylog  = parse_scale(args.scale)

    for metric in metrics:
        if metric not in df.columns:
            print(f"[warn] metric {metric} not found; skipping.")
            continue

        sub = df[["size","label","variant","engine","indexing","series",metric]].copy()

        # Export tidy CSV with abs + % slower
        pct = compute_pct_vs_rel(sub.rename(columns={metric:metric}), metric)
        tidy = pct[["variant","size","indexing","abs_rel","abs_jsonb","pct_slower"]]
        tidy.to_csv(os.path.join(args.outdir, f"scaling_{metric}_pct.csv"), index=False)

        plot_metric_grid(
            sub, metric, variants, series_keys,
            xlog, ylog, outdir=args.outdir, title=(args.title or None),
            fig_w=fig_w_per_subplot_col, fig_h=fig_h_per_row, dpi=args.dpi,
            ylabel_mode=args.ylabel,
            show_pct=args.pct, y2_log=args.y2log, show_parity=args.parity
        )

    print(f"Saved charts (PDF+PNG) and percent CSVs to {args.outdir}")

if __name__ == "__main__":
    main()
