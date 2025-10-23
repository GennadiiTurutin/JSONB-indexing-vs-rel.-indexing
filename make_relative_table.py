import argparse
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import re

REQUIRED = {"variant","jsonb_ind","jsonb_unind","rel_ind","rel_unind"}

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
    m = re.match(r"^S(\d+)", str(v))
    return (0, int(m.group(1))) if m else (1, str(v))

def build_table(df: pd.DataFrame, round_to: int = 0) -> pd.DataFrame:
    df = df.copy()
    # normalize headers to lowercase for lookups
    df.columns = [c.lower() for c in df.columns]

    missing = sorted(REQUIRED - set(df.columns))
    if missing:
        raise ValueError(f"CSV missing required columns: {missing}\nFound: {list(df.columns)}")

    # Compute REL% of JSONB (internal only; not displayed)
    rel_idx_pct   = df.apply(lambda r: pct_or_nan(r["rel_ind"],   r["jsonb_ind"]),   axis=1)
    rel_unidx_pct = df.apply(lambda r: pct_or_nan(r["rel_unind"], r["jsonb_unind"]), axis=1)

    # Notes (displayed)
    df["indexed_note"]   = rel_idx_pct.apply(lambda p: speed_note(p, round_to))
    df["unindexed_note"] = rel_unidx_pct.apply(lambda p: speed_note(p, round_to))

    # Sort naturally by variant if present
    if "variant" in df.columns:
        df = df.sort_values("variant", key=lambda s: s.map(numeric_variant_key))

    # Final visible columns ONLY (drop REL% columns)
    out = df[["variant", "indexed_note", "unindexed_note"]].rename(columns={
        "variant": "Variant",
        "indexed_note": "Indexed",
        "unindexed_note": "Unindexed",
    })
    return out

def render_table_image(
    table_df: pd.DataFrame,
    out_path: str,
    title: str = "",
    dpi: int = 180,
    base_width: float = 9.0,
    row_height_in: float = 0.85,
    header_fontsize: int = 12,
    body_fontsize: int = 10,
    title_fontsize: int = 16,
    scale: float = 1.5,              # scale all font sizes (e.g., 1.5 = 150%)
    header_height: float | None = None,  # absolute header cell height (table coords); if None, derived
    header_factor: float = 1.35      # multiplier over body cell height when header_height is None
):
    """
    Render a 3-column table (Variant | Indexed | Unindexed) to an image.
    - All text bold.
    - `scale` uniformly scales fonts.
    - Header row height can be set explicitly via `header_height`, or derived
      as `header_factor * BODY_H` if `header_height` is None.
    """

    # ---- Scale fonts & breathing room ----
    header_fontsize = int(round(header_fontsize * scale))
    body_fontsize   = int(round(body_fontsize   * scale))
    title_fontsize  = int(round(title_fontsize  * scale))
    row_height_in   = row_height_in * (1.0 + 0.10 * (scale - 1.0))  # gentle increase with larger fonts

    # ---- Figure size scales with rows ----
    nrows = len(table_df)
    fig_w = base_width
    fig_h = max(3.0, row_height_in * (nrows + 3))

    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    ax.axis("off")

    # ---- Column labels / cell text ----
    col_labels = list(table_df.columns)  # ["Variant","Indexed","Unindexed"]
    cell_text  = table_df.values.tolist()
    ncols      = len(col_labels)

    # ---- Column widths for 3 columns ----
    col_widths = [0.30, 0.35, 0.35]

    tbl = ax.table(
        cellText=cell_text,
        colLabels=col_labels,
        colWidths=col_widths,
        cellLoc="center",
        loc="upper center",
    )

    # Make ALL text bold (header + body)
    # for cell in tbl.get_celld().values():
    #     cell.get_text().set_fontweight("bold")

    # Fonts
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(body_fontsize)

    # ---- Dimensions in table coordinates ----
    BODY_H = 0.085  # height for body cells (works well with default fonts)
    HEADER_H = header_height if header_height is not None else BODY_H * header_factor

    # ---- Header styling & height ----
    for j in range(ncols):
        cell = tbl[0, j]
        cell.set_facecolor("white")
        cell.set_edgecolor("black")
        cell.set_linewidth(1.2)
        cell.get_text().set_fontsize(header_fontsize)
        cell.PAD = 0.14  # extra padding for header
        cell.set_height(HEADER_H)

    # ---- Body cells ----
    for i in range(1, nrows + 1):
        for j in range(ncols):
            cell = tbl[i, j]
            cell.set_facecolor("white")
            cell.set_edgecolor("black")
            cell.set_linewidth(0.8)
            cell.PAD = 0.10
            cell.set_height(BODY_H)
            # left-align variant; center notes
            cell._loc = "w" if j == 0 else "c"

    # ---- Title ----
    if title:
        ax.text(
            0.5, 1.03, title,
            ha="center", va="bottom",
            fontsize=title_fontsize, fontweight="bold",
            transform=ax.transAxes, color="black"
        )

    # Slightly more headroom if header is tall
    top_margin = 0.88 if HEADER_H <= BODY_H * 1.2 else 0.86
    plt.subplots_adjust(top=top_margin, bottom=0.06, left=0.06, right=0.98)

    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=dpi, bbox_inches="tight", pad_inches=0.6)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser(description="Generate a PNG table image of REL vs JSONB speed notes (3 columns).")
    ap.add_argument("--csv", required=True,
                    help="Input CSV (variant,jsonb_ind,jsonb_unind,rel_ind,rel_unind[,family])")
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
