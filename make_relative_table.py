#!/usr/bin/env python3
# make_relative_table_image.py
# Create a table image summarizing REL vs JSONB:
#   - "REL faster by X%" or "JSONB faster by Y%" for indexed/unindexed
#   - Also shows raw REL as % of JSONB (rounded)
#
# Input CSV must have columns:
#   variant,jsonb_indexed,jsonb_unindexed,rel_indexed,rel_unindexed[,family]
#
# Example:
#   python make_relative_table_image.py \
#       --csv ./viz_single_1mi_grouped/p95_ms_wide.csv \
#       --out ./viz_single_1mi_grouped/relative_table.png \
#       --title "Relative p95 latency — N=1,000,000" \
#       --dpi 180

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

REQUIRED = {"variant","jsonb_indexed","jsonb_unindexed","rel_indexed","rel_unindexed"}

def pct_or_nan(num, den):
    if den is None or not np.isfinite(den) or den <= 0:
        return np.nan
    if num is None or not np.isfinite(num) or num <= 0:
        return 0.0
    return 100.0 * (num / den)

def speed_note(rel_pct: float, round_to: int = 0) -> str:
    """rel_pct = REL as % of JSONB baseline (100=same)."""
    if not np.isfinite(rel_pct):
        return "—"
    delta = 100.0 - rel_pct
    if round_to is not None:
        delta = round(delta, round_to)
    if delta > 0:
        return f"REL faster by {delta:.0f}%"
    elif delta < 0:
        return f"JSONB faster by {abs(delta):.0f}%"
    else:
        return "Parity"

def numeric_variant_key(v: str):
    # Sort S1..S10 naturally; fallback = string
    import re
    m = re.match(r"^S(\d+)", str(v))
    return (0, int(m.group(1))) if m else (1, str(v))

def build_table(df: pd.DataFrame, round_to: int = 0) -> pd.DataFrame:
    df = df.copy()
    df.columns = [c.lower() for c in df.columns]

    # Compute REL% of JSONB
    df["rel_indexed_pct"]   = df.apply(lambda r: pct_or_nan(r["rel_indexed"], r["jsonb_indexed"]), axis=1)
    df["rel_unindexed_pct"] = df.apply(lambda r: pct_or_nan(r["rel_unindexed"], r["jsonb_unindexed"]), axis=1)

    # Notes
    df["indexed_note"]   = df["rel_indexed_pct"].apply(lambda p: speed_note(p, round_to))
    df["unindexed_note"] = df["rel_unindexed_pct"].apply(lambda p: speed_note(p, round_to))

    # Pretty percentages for display (whole % by default)
    df["rel_indexed_pct_disp"]   = df["rel_indexed_pct"].map(lambda x: f"{x:.0f}%" if np.isfinite(x) else "—")
    df["rel_unindexed_pct_disp"] = df["rel_unindexed_pct"].map(lambda x: f"{x:.0f}%" if np.isfinite(x) else "—")

    # Sort naturally by variant if present
    if "variant" in df.columns:
        df = df.sort_values("variant", key=lambda s: s.map(numeric_variant_key))

    # Final visible columns
    out = df[[
        "variant",
        "indexed_note",
        "unindexed_note",
        "rel_indexed_pct_disp",
        "rel_unindexed_pct_disp",
    ]].rename(columns={
        "variant": "Variant",
        "indexed_note": "Indexed",
        "unindexed_note": "Unindexed",
        "rel_indexed_pct_disp": "REL% of JSONB (idx)",
        "rel_unindexed_pct_disp": "REL% of JSONB (no-idx)",
    })
    return out

def render_table_image(table_df: pd.DataFrame, out_path: str, title: str = "",
                       dpi: int = 180, base_width: float = 12.0,
                       row_height_in: float = 0.85,
                       header_fontsize: int = 12, body_fontsize: int = 10,
                       title_fontsize: int = 16):
    # Figure size scales with rows
    nrows = len(table_df)
    fig_w = base_width
    fig_h = max(3.0, row_height_in * (nrows + 3))

    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    ax.axis("off")

    # Column labels / cell text
    col_labels = list(table_df.columns)
    cell_text = table_df.values.tolist()

    # Reasonable column widths
    col_widths = [0.18, 0.24, 0.24, 0.17, 0.17]

    tbl = ax.table(
        cellText=cell_text,
        colLabels=col_labels,
        colWidths=col_widths,
        cellLoc="center",
        loc="upper center",
    )

    # Fonts
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(body_fontsize)

    # Header styling (simple monochrome)
    for j in range(len(col_labels)):
        cell = tbl[0, j]
        cell.set_facecolor("white")
        cell.set_edgecolor("black")
        cell.set_linewidth(1.2)
        cell.get_text().set_fontsize(header_fontsize)
        cell.get_text().set_weight("bold")
        cell.PAD = 0.08

    # Body cells
    for i in range(1, nrows + 1):
        for j in range(len(col_labels)):
            cell = tbl[i, j]
            cell.set_facecolor("white")
            cell.set_edgecolor("black")
            cell.set_linewidth(0.8)
            cell.PAD = 0.10
            cell.set_height(0.085)
            # left-align variant; right-align percentages; center notes
            if j == 0:
                cell._loc = "w"
            elif j in (3, 4):
                cell._loc = "e"
            else:
                cell._loc = "c"

    # Title
    if title:
        ax.text(0.5, 1.03, title, ha="center", va="bottom",
                fontsize=title_fontsize, fontweight="bold", transform=ax.transAxes, color="black")

    plt.subplots_adjust(top=0.88, bottom=0.06, left=0.04, right=0.98)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=dpi, bbox_inches="tight", pad_inches=0.6)
    plt.close(fig)

def main():
    ap = argparse.ArgumentParser(description="Generate a PNG table image of REL vs JSONB speed notes.")
    ap.add_argument("--csv", required=True,
                    help="Input CSV (variant,jsonb_indexed,jsonb_unindexed,rel_indexed,rel_unindexed[,family])")
    ap.add_argument("--out", default="relative_table.png", help="Output PNG path")
    ap.add_argument("--title", default="", help="Optional image title (e.g., 'Relative p95 latency — N=1,000,000')")
    ap.add_argument("--dpi", type=int, default=180, help="Image DPI (default 180)")
    ap.add_argument("--round", type=int, default=0, help="Round percentage deltas to this many decimals (default 0)")
    args = ap.parse_args()

    df = pd.read_csv(args.csv)
    table_df = build_table(df, round_to=args.round)
    render_table_image(table_df, out_path=args.out, title=args.title, dpi=args.dpi)

    # Also print to console for quick copy/paste
    print(table_df.to_string(index=False))

if __name__ == "__main__":
    main()
