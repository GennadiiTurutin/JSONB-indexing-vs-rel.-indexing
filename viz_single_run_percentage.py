#!/usr/bin/env python3
# relative_per_scenario_grid.py
# One figure (grid of subplots) with all scenarios:
# - For each scenario: 2 groups (Indexed, Unindexed)
#   * JSONB bars fixed at 100%
#   * REL bars shown as % of JSONB and annotated with % and absolute ms
# - Group-level "REL faster/slower by X%" notes
# - Unified legend, optional unified y-limit across subplots

import os, argparse, math
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# ---- Formatting helpers ----
def pct_or_nan(num, den):
    if den is None or not np.isfinite(den) or den <= 0:
        return np.nan
    if num is None or not np.isfinite(num) or num <= 0:
        return 0.0
    return 100.0 * (num / den)

def fmt_ms(x):
    if x is None or not np.isfinite(x):
        return "—"
    if x >= 1000:
        return f"{x:,.0f} ms"
    return f"{x:.3g} ms"

def fmt_pct(x):
    if x is None or not np.isfinite(x):
        return "—"
    return f"{x:.0f}%"

def rel_delta_note(rel_pct):
    if not np.isfinite(rel_pct):
        return ""
    delta = 100.0 - rel_pct
    if delta > 0:
        return f"REL faster by {delta:.0f}%"
    elif delta < 0:
        return f"REL slower by {abs(delta):.0f}%"
    else:
        return "Parity"

def compute_relatives(row):
    j_idx = float(row["jsonb_indexed"]) if pd.notna(row["jsonb_indexed"]) else np.nan
    r_idx = float(row["rel_indexed"])   if pd.notna(row["rel_indexed"])   else np.nan
    j_uix = float(row["jsonb_unindexed"]) if pd.notna(row["jsonb_unindexed"]) else np.nan
    r_uix = float(row["rel_unindexed"])   if pd.notna(row["rel_unindexed"])   else np.nan
    rel_idx_pct = pct_or_nan(r_idx, j_idx)
    rel_uix_pct = pct_or_nan(r_uix, j_uix)
    return (j_idx, r_idx, j_uix, r_uix, rel_idx_pct, rel_uix_pct)

def plot_one_subplot(ax, scen, fam, j_idx, r_idx, j_uix, r_uix,
                     rel_idx_pct, rel_uix_pct, metric_name,
                     jsonb_color="#0a7a0a", rel_color="#a01515",
                     annotate_examples=False):
    groups = ["Indexed", "Unindexed"]
    jsonb_vals = [100.0 if np.isfinite(j_idx) else np.nan,
                  100.0 if np.isfinite(j_uix) else np.nan]
    rel_vals   = [rel_idx_pct, rel_uix_pct]

    jsonb_ms = [j_idx, j_uix]
    rel_ms   = [r_idx, r_uix]

    x = np.arange(len(groups))
    width = 0.34

    b1 = ax.bar(x - width/2, jsonb_vals, width, color=jsonb_color, label="JSONB (baseline = 100%)")
    b2 = ax.bar(x + width/2, rel_vals,   width, color=rel_color,   label="REL (as % of JSONB)")

    # Labels (% and absolute ms)
    def annotate_bar(bar, abs_ms_list):
        for rect, ms in zip(bar, abs_ms_list):
            h = rect.get_height()
            xi = rect.get_x() + rect.get_width() / 2.0
            ax.text(
                xi, h * 1.01 if np.isfinite(h) else 0.02,
                f"{fmt_pct(h if np.isfinite(h) else np.nan)}\n({fmt_ms(ms)})",
                ha="center", va="bottom", fontsize=9.5,
                bbox=dict(facecolor="white", alpha=0.75, edgecolor="none", boxstyle="round,pad=0.20")
            )

    annotate_bar(b1, jsonb_ms)
    annotate_bar(b2, rel_ms)

    # ---- Place “REL faster/slower …” directly above the REL bar ----
    # Find the REL bars' centers/heights
    rel_bar_centers = [rect.get_x() + rect.get_width()/2 for rect in b2]
    rel_bar_heights = [rect.get_height() for rect in b2]
    notes           = [rel_delta_note(rel_idx_pct), rel_delta_note(rel_uix_pct)]

    for xi, hi, note in zip(rel_bar_centers, rel_bar_heights, notes):
        if not note or not np.isfinite(hi):
            continue
        ax.text(
            xi, hi * 1.06, note,  # closer to the bar
            ha="center", va="bottom", fontsize=10.5,
            bbox=dict(facecolor="white", alpha=0.75, edgecolor="none", boxstyle="round,pad=0.20")
        )

    ax.set_xticks(x, groups)
    ax.set_ylabel(f"{metric_name}: REL as % of JSONB (lower is better)")

    pretty_scen = str(scen)
    title_bits = [f"{pretty_scen} — Relative {metric_name}"]
    if fam and fam not in pretty_scen:
        title_bits.append(f"({fam})")
    ax.set_title(" ".join(title_bits), pad=4)

    ax.grid(True, axis="y", alpha=0.25)

    # Suggest y max for grid-level scaling
    all_vals = [v for v in jsonb_vals + rel_vals if np.isfinite(v)]
    ymax = max(all_vals) if all_vals else 100.0
    return ymax


# ---- Grid orchestrator ----
def plot_grid(df, out_png, dpi=170, title_prefix="", metric_name="p95 latency",
              cols=3, same_ylim=True):
    plt.rcParams.update({
        "font.size": 11,
        "axes.titlesize": 13.5,
        "axes.labelsize": 12,
        "xtick.labelsize": 11,
        "ytick.labelsize": 11,
        "legend.fontsize": 11,
    })

    # Ensure required cols (case-insensitive already normalized below)
    required = {"variant","jsonb_indexed","jsonb_unindexed","rel_indexed","rel_unindexed"}
    assert required.issubset(set(df.columns)), f"CSV must include columns: {sorted(required)}"

    # Order scenarios (try S1..S10 numeric)
    def fam_key(v):
        v = str(v)
        import re
        m = re.match(r"^S(\d+)", v)
        return (0, int(m.group(1))) if m else (1, v)
    df_sorted = df.sort_values(by="variant", key=lambda s: s.map(fam_key))

    n = len(df_sorted)
    # rows = math.ceil(n / cols)
    cols, rows = 2, 5
    fig, axes = plt.subplots(rows, cols, figsize=(7.2*cols, 5.2*rows), squeeze=False)

    # Collect ymax for unified scaling if requested
    suggested_ymax = []

    # Draw each scenario
    for i, (_, row) in enumerate(df_sorted.iterrows()):
        r, c = divmod(i, cols)
        ax = axes[r][c]
        scen = row["variant"]
        fam  = row.get("family", "")
        j_idx, r_idx, j_uix, r_uix, rel_idx_pct, rel_uix_pct = compute_relatives(row)
        ymax = plot_one_subplot(ax, scen, fam, j_idx, r_idx, j_uix, r_uix,
                                rel_idx_pct, rel_uix_pct, metric_name)
        suggested_ymax.append(ymax)

    # Hide leftover empty axes
    for j in range(n, rows*cols):
        r, c = divmod(j, cols)
        axes[r][c].axis("off")

    # Unified ylim for consistency (optional)
    if same_ylim and suggested_ymax:
        # a bit of headroom, matching single-plot padding logic
        global_top = max(suggested_ymax) * 1.35
        for i in range(n):
            r, c = divmod(i, cols)
            axes[r][c].set_ylim(0, global_top)

    # Unified legend (once) just below the suptitle
    handles, labels = axes[0][0].get_legend_handles_labels()
    if handles:
        fig.legend(
            handles, labels,
            loc="upper center",
            ncol=len(handles),
            frameon=False,
            bbox_to_anchor=(0.5, 0.97)  # leave room for suptitle above
        )

    # Figure title (higher than legend)
    if title_prefix:
        suptitle = f"{title_prefix} — Relative {metric_name}"
    else:
        suptitle = f"Relative {metric_name}"
    fig.suptitle(suptitle, y=0.995, fontsize=16, fontweight="bold")

    # Reserve vertical space for title+legend
    # (top=0.92 keeps content clear of both)
    fig.tight_layout(rect=[0, 0.02, 1, 0.92])
    os.makedirs(os.path.dirname(out_png) or ".", exist_ok=True)
    fig.savefig(out_png, dpi=dpi, bbox_inches="tight", pad_inches=0.35)
    plt.close(fig)

# ---- CLI ----
def main():
    ap = argparse.ArgumentParser(
        description="One figure with all scenarios (JSONB=100%, REL as % of JSONB) from grouped CSV."
    )
    ap.add_argument("--csv", required=True,
                    help="CSV columns: variant,jsonb_indexed,jsonb_unindexed,rel_indexed,rel_unindexed[,family]")
    ap.add_argument("--out", default="relative_p95/relative_grid_p95.png",
                    help="Output PNG path (default relative_p95/relative_grid_p95.png)")
    ap.add_argument("--dpi", type=int, default=170)
    ap.add_argument("--title-prefix", default="", help="Optional figure title prefix")
    ap.add_argument("--metric-name", default="p95 latency", help="Metric name for axis/title")
    ap.add_argument("--cols", type=int, default=3, help="Number of subplot columns (default 3)")
    ap.add_argument("--same-ylim", action="store_true",
                    help="Force the same y-limit across all subplots")
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    # normalize columns to lower-case to be robust
    df.columns = [c.lower() for c in df.columns]

    plot_grid(df, out_png=args.out, dpi=args.dpi,
              title_prefix=args.title_prefix,
              metric_name=args.metric_name,
              cols=args.cols,
              same_ylim=args.same_ylim)

    print(f"Saved: {args.out}")

if __name__ == "__main__":
    main()
