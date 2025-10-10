#!/usr/bin/env python3
# viz_bench_combo.py
# Composite chart over S1..S10:
#   - Bars (primary Y): mean Shared Hit Blocks (JSONB vs REL)
#   - Lines (secondary Y): p95 latency (ms) — separate lines for JSONB and REL
# Source: bench_results.csv. Excludes 'unindexed'.

import argparse, os, re
import numpy as np
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt

# ---------------- Style ----------------
def apply_style(dpi: int = 300, base_font: int = 9):
    mpl.rcParams.update({
        # typography / figure
        "font.size": base_font,
        "axes.titlesize": base_font + 1,
        "axes.labelsize": base_font,
        "xtick.labelsize": base_font - 1,
        "ytick.labelsize": base_font - 1,
        "legend.fontsize": base_font - 1,
        "figure.dpi": dpi,
        "savefig.dpi": dpi,
        "savefig.bbox": "tight",
        # axes / grid
        "axes.spines.top": True,
        "axes.spines.right": False,  # primary axes: right spine off (secondary has own)
        "axes.grid": True,
        "grid.alpha": 0.25,
        "grid.linestyle": (0, (2, 2)),
        # lines
        "lines.linewidth": 1.2,
        "errorbar.capsize": 0,
    })

# grayscale-safe
BAR_FILL = {"jsonb": "#4a4a4a", "rel": "#000000"}
LINE_COLOR = {"jsonb": "#5a5a5a", "rel": "#101010"}
LINE_STYLE = {"jsonb": "-", "rel": "-"}
MARKER = {"jsonb": "o", "rel": "s"}

# -------------- Helpers --------------
def infer_engine_indexing(label: str):
    if not isinstance(label, str):
        return None, None
    t = label.strip().lower()
    eng = "jsonb" if "jsonb" in t else ("rel" if "rel" in t else None)
    idx = "unindexed" if "unindexed" in t else ("indexed" if "indexed" in t else None)
    return eng, idx

def numeric_variant_key(v: str):
    m = re.match(r"^S(\d+)", str(v))
    return (0, int(m.group(1))) if m else (1, str(v))

def p95(series: pd.Series) -> float:
    x = pd.to_numeric(series, errors="coerce").dropna().values
    return float(np.percentile(x, 95)) if x.size else np.nan

def load_and_filter(csv_path: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    df.columns = [c.strip().lower() for c in df.columns]
    eng_idx = df["label"].apply(infer_engine_indexing)
    df["engine"] = [e for e, _ in eng_idx]
    df["indexing"] = [i for _, i in eng_idx]
    # Keep only indexed JSONB/REL
    df = df[(df["engine"].isin(["jsonb", "rel"])) & (df["indexing"] == "indexed")].copy()
    # numeric casts
    for col in ("execution_ms", "shared_hits"):
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df

def aggregate(df: pd.DataFrame) -> pd.DataFrame:
    g = df.groupby(["variant", "engine"], dropna=True)
    out = g.agg(
        n=("execution_ms", "size"),
        p95_ms=("execution_ms", p95),
        shared_hits_mean=("shared_hits", "mean"),
    ).reset_index()
    out = out.sort_values(["variant", "engine"], key=lambda s: s.map(numeric_variant_key))
    return out

# -------------- Plot --------------
def plot_combo(summary: pd.DataFrame, title: str, out_base: str):
    engines = ["jsonb", "rel"]
    variants = sorted(summary["variant"].unique().tolist(), key=numeric_variant_key)

    piv_hits = summary.pivot(index="variant", columns="engine", values="shared_hits_mean").reindex(variants)
    piv_p95  = summary.pivot(index="variant", columns="engine", values="p95_ms").reindex(variants)

    for e in engines:
        if e not in piv_hits.columns: piv_hits[e] = np.nan
        if e not in piv_p95.columns:  piv_p95[e]  = np.nan
    piv_hits = piv_hits[engines]
    piv_p95  = piv_p95[engines]

    x = np.arange(len(variants))
    width = 0.24  # narrower bars (more “scientific” look)

    fig, ax = plt.subplots(figsize=(max(8.8, 0.75*len(variants)+6), 4.6))

    # Bars: Shared Hit Blocks (primary Y)
    b_jsonb = ax.bar(x - width/2, piv_hits["jsonb"].values, width,
                     label="Shared Hits — JSONB (indexed)",
                     color=BAR_FILL["jsonb"], edgecolor="black", linewidth=0.6)
    b_rel   = ax.bar(x + width/2, piv_hits["rel"].values, width,
                     label="Shared Hits — REL (indexed)",
                     color=BAR_FILL["rel"], edgecolor="black", linewidth=0.6)

    ax.set_ylabel("Shared Hit Blocks (mean)")
    ax.set_xticks(x, variants)
    ax.grid(True, axis="y", alpha=0.25)

    # Secondary axis: p95 latency lines
    ax2 = ax.twinx()
    # make secondary spines visible but subtle
    ax2.spines["right"].set_visible(True)
    ax2.plot(x, piv_p95["jsonb"].values, LINE_STYLE["jsonb"],
             marker=MARKER["jsonb"], markersize=4.0, linewidth=1.2,
             color=LINE_COLOR["jsonb"], label="p95 — JSONB (indexed)")
    ax2.plot(x, piv_p95["rel"].values, LINE_STYLE["rel"],
             marker=MARKER["rel"], markersize=4.0, linewidth=1.2,
             color=LINE_COLOR["rel"], label="p95 — REL (indexed)")
    ax2.set_ylabel("p95 (ms)")

    # Titles / legend
    ax.set_title(title if title else "Shared Hits (bars) + p95 latency (lines)")
    handles1, labels1 = ax.get_legend_handles_labels()
    handles2, labels2 = ax2.get_legend_handles_labels()
    fig.legend(handles1 + handles2, labels1 + labels2,
               loc="upper center", bbox_to_anchor=(0.5, 1.02),
               frameon=False, ncol=2)

    # Optional: bar value labels (no n=… as requested)
    def fmt_hits(v):
        return "—" if not np.isfinite(v) else f"{v:.0f}"
    def fmt_p95(v):
        if not np.isfinite(v): return "—"
        return f"{v:.3f}" if v < 1 else f"{v:.1f}"

    for bar in b_jsonb:
        h = bar.get_height()
        if np.isfinite(h):
            ax.text(bar.get_x()+bar.get_width()/2, h*1.01, fmt_hits(h),
                    ha="center", va="bottom", fontsize=8)

    for bar in b_rel:
        h = bar.get_height()
        if np.isfinite(h):
            ax.text(bar.get_x()+bar.get_width()/2, h*1.01, fmt_hits(h),
                    ha="center", va="bottom", fontsize=8)

    # Optional: point value labels for the latency lines
    for i, v in enumerate(piv_p95["jsonb"].values):
        if np.isfinite(v):
            ax2.text(x[i], v*1.01, fmt_p95(v), ha="center", va="bottom", fontsize=8)
    for i, v in enumerate(piv_p95["rel"].values):
        if np.isfinite(v):
            ax2.text(x[i], v*1.01, fmt_p95(v), ha="center", va="bottom", fontsize=8)

    fig.tight_layout()
    fig.savefig(out_base + ".pdf")
    fig.savefig(out_base + ".png", dpi=350)
    plt.close(fig)

def main():
    ap = argparse.ArgumentParser(description="Composite chart: Shared Hit Blocks (bars) + p95 latency (lines). Indexed JSONB vs REL.")
    ap.add_argument("--csv", required=True, help="bench_results.csv")
    ap.add_argument("--outdir", default="viz_bench", help="Output directory")
    ap.add_argument("--title", default="", help="Optional title")
    ap.add_argument("--dpi", type=int, default=300)
    args = ap.parse_args()

    apply_style(dpi=args.dpi, base_font=9)
    os.makedirs(args.outdir, exist_ok=True)

    df = load_and_filter(args.csv)
    if df.empty:
        raise SystemExit("No rows after filtering to indexed JSONB/REL.")
    summary = aggregate(df)

    out_base = os.path.join(args.outdir, "combo_shared_hits_and_p95_by_variant")
    ttl = args.title or "Shared Hits (bars) + p95 latency (lines) — Indexed JSONB vs REL"
    plot_combo(summary, ttl, out_base)

    summary.to_csv(os.path.join(args.outdir, "summary_by_variant.csv"), index=False)
    print(f"Wrote figures and summary to {args.outdir}")

if __name__ == "__main__":
    main()
