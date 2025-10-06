#!/usr/bin/env python3
# viz_single_run.py
# Small-multiples by scenario (S1..S10). 2–4 labels (jsonb/rel, indexed/unindexed).
# Figure: 2 columns × 5 rows (S1..S10). Each subplot is a grouped bar chart for the chosen metric.
# Style controls mirror viz_scaling.py: --column, --rowheight, --ratio, --ylabel.
# Default behavior:
#   - No per-subplot y-axis label (so 'p95_ms' won't appear on the sides)
#   - Double-column width unless --ratio is provided
#   - Very narrow bars

import argparse, os, re, sys
import numpy as np
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

ALL_METRICS = ["p50_ms","p95_ms","avg_ms","sum_shared_reads","sum_shared_hits"]

# Grid geometry fixed for S1..S10
COLS, ROWS = 2, 5

# ----------------------- Print-friendly style -----------------------

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

# Grayscale-safe fills (hatching distinguishes unindexed)
SERIES_FILL = {
    "jsonb_indexed":   "#303030",  # dark gray
    "jsonb_unindexed": "#8c8c8c",  # lighter gray
    "rel_indexed":     "#000000",  # black
    "rel_unindexed":   "#bfbfbf",  # medium-light gray
    "jsonb":           "#4d4d4d",  # fallback if no idx hint
    "rel":             "#1a1a1a",
}
HATCH_MAP = {
    "jsonb_indexed":   "",
    "jsonb_unindexed": "//",
    "rel_indexed":     "",
    "rel_unindexed":   "//",
    "jsonb":           "",
    "rel":             "",
}
LEGEND_LABEL = {
    "jsonb_indexed":   "JSONB (indexed)",
    "jsonb_unindexed": "JSONB (unindexed)",
    "rel_indexed":     "REL (indexed)",
    "rel_unindexed":   "REL (unindexed)",
    "jsonb":           "JSONB",
    "rel":             "REL",
}

# Scenario metadata (optional SQL exemplars)
SCENARIO_META_BASE = {
    "S1":  ("Equality + Numeric Inequality",
            "SELECT id FROM inv_jsonb WHERE (payload->>'indexed_text_1')='A' AND ((payload->>'indexed_number_1')::numeric)>100",
            "SELECT id FROM inv_rel   WHERE indexed_text_1='A' AND indexed_number_1>100"),
    "S2":  ("LIKE Prefix Search",
            "SELECT id FROM inv_jsonb WHERE (payload->>'indexed_text_2') LIKE 'INV00012%'",
            "SELECT id FROM inv_rel   WHERE indexed_text_2 LIKE 'INV00012%'"),
    "S3":  ("Substring Contains (ILIKE/trigram)",
            "SELECT id FROM inv_jsonb WHERE (payload->>'indexed_text_3') ILIKE '%priority%'",
            "SELECT id FROM inv_rel   WHERE indexed_text_3 ILIKE '%priority%'"),
    "S4":  ("Timestamp Range",
            "SELECT id FROM inv_jsonb WHERE (payload->>'indexed_timestamp_1')>='2025-01-01T00:00:00.000Z' AND (payload->>'indexed_timestamp_1')<'2025-02-01T00:00:00.000Z'",
            "SELECT id FROM inv_rel   WHERE indexed_timestamp_1>='2025-01-01 00:00:00+00' AND indexed_timestamp_1<'2025-02-01 00:00:00+00'"),
    "S5":  ("Array AND (must contain both)",
            "SELECT id FROM inv_jsonb WHERE (payload->'indexed_text_array_1') @> '[\"aml\",\"priority\"]'",
            "SELECT id FROM inv_rel   WHERE indexed_text_array_1 @> ARRAY['aml','priority']"),
    "S6":  ("Array OR (any overlap)",
            "SELECT id FROM inv_jsonb WHERE (payload->'indexed_text_array_1') @> '[\"aml\"]' OR (payload->'indexed_text_array_1') @> '[\"priority\"]'",
            "SELECT id FROM inv_rel   WHERE indexed_text_array_1 && ARRAY['aml','priority']"),
    "S7":  ("Multi-key AND (2 keys)",
            "SELECT id FROM inv_jsonb WHERE payload @> '{\"indexed_text_1\":\"A\",\"indexed_boolean_1\":true}'",
            "SELECT id FROM inv_rel   WHERE indexed_text_1='A' AND indexed_boolean_1=true"),
    "S8":  ("Multi-key AND (3 keys)",
            "SELECT id FROM inv_jsonb WHERE payload @> '{\"indexed_text_1\":\"A\",\"indexed_boolean_1\":true,\"indexed_number_1\":100}'",
            "SELECT id FROM inv_rel   WHERE indexed_text_1='A' AND indexed_boolean_1=true AND indexed_number_1=100"),
    "S9":  ("OR Across Keys",
            "SELECT id FROM inv_jsonb WHERE payload @> '{\"indexed_text_1\":\"A\"}' OR payload @> '{\"indexed_boolean_1\":true}'",
            "SELECT id FROM inv_rel   WHERE indexed_text_1='A' OR indexed_boolean_1=true"),
    "S10": ("Top-N by Timestamp Within Group",
            "SELECT id FROM inv_jsonb WHERE (payload->>'indexed_text_1')='A' ORDER BY (payload->>'indexed_timestamp_1')",
            "SELECT id FROM inv_rel   WHERE indexed_text_1='A' ORDER BY indexed_timestamp_1"),
}

# ----------------------- Load + helpers -----------------------

def load_summary(xlsx_path: str) -> pd.DataFrame:
    df = pd.read_excel(xlsx_path, sheet_name="summary")
    df.columns = [c.strip().lower() for c in df.columns]
    for c in ALL_METRICS:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    return df

def ensure_metric_columns(df: pd.DataFrame):
    for col in ["sum_shared_reads","sum_shared_hits"]:
        if col not in df.columns:
            df[col] = pd.NA

def infer_key_from_label(label: str) -> str:
    """Return jsonb_indexed/jsonb_unindexed/rel_indexed/rel_unindexed or fallback jsonb/rel/unknown."""
    if not isinstance(label, str):
        return "unknown"
    t = label.lower()
    engine = "jsonb" if re.search(r"\bjsonb\b", t) else ("rel" if re.search(r"\brel\b", t) else None)
    idx = None
    if re.search(r"\bunindexed\b", t):   # IMPORTANT: check 'unindexed' first
        idx = "unindexed"
    elif re.search(r"\bindexed\b", t):
        idx = "indexed"
    if engine and idx:
        return f"{engine}_{idx}"
    if engine:
        return engine
    return "unknown"

def shorten_tick(label: str) -> str:
    k = infer_key_from_label(label)
    mapping = {
        "jsonb_indexed":   "jsonb\nidx",
        "jsonb_unindexed": "jsonb\nno-idx",
        "rel_indexed":     "rel\nidx",
        "rel_unindexed":   "rel\nno-idx",
        "jsonb":           "jsonb",
        "rel":             "rel",
        "unknown":         label,
    }
    return mapping.get(k, label)

def family_of_variant(variant: str) -> str:
    if not isinstance(variant, str):
        return "Other"
    m = re.match(r"^(S\d+)", variant)
    return m.group(1) if m else "Other"

def numeric_family_sort_key(fam: str):
    m = re.match(r"^S(\d+)$", fam)
    return (0, int(m.group(1))) if m else (1, fam)

def filter_by_label_substring(df: pd.DataFrame, substr: str) -> pd.DataFrame:
    m = df["label"].str.contains(substr, case=False, na=False)
    out = df[m].copy()
    if out.empty:
        labels = sorted(df["label"].dropna().unique().tolist())
        print(f"No rows match: {substr}\nAvailable labels:")
        for lb in labels:
            print("  -", lb)
        sys.exit(1)
    return out

def prepare_matrix_for_metric(df: pd.DataFrame, labels: list[str], metric: str) -> pd.DataFrame:
    frames = []
    for lbl in labels:
        sub = filter_by_label_substring(df, lbl)[["variant", metric]].rename(columns={metric: lbl})
        frames.append(sub)
    mat = frames[0]
    for sub in frames[1:]:
        mat = pd.merge(mat, sub, on="variant", how="inner")
    if mat.empty:
        return mat
    mat["family"] = mat["variant"].apply(family_of_variant)
    return mat

# ----------------------- Title helpers -----------------------

def parse_n_from_filename(path: str):
    base = os.path.basename(path)
    nums = re.findall(r"(\d{4,})", base)
    if not nums:
        return None
    return max(int(x) for x in nums)

def normalize_n(n_str: str):
    if not n_str:
        return None
    digits = re.sub(r"[^\d]", "", n_str)
    return int(digits) if digits else None

def format_n(n_val, sep: str = "keep", original: str | None = None):
    if n_val is None:
        return original
    if sep == "keep" and original:
        return original
    if sep == "comma":
        return f"{n_val:,}"
    if sep == "space":
        return f"{n_val:,}".replace(",", " ")
    if sep == "none":
        return str(n_val)
    return str(n_val)

def resolve_N_for_title(labels: list[str], file_path: str, arg_n: str | None, n_sep: str):
    if arg_n:
        n_int = normalize_n(arg_n)
        return format_n(n_int, n_sep, original=arg_n)
    n_int = parse_n_from_filename(file_path)
    return format_n(n_int, n_sep, original=None)

# ----------------------- Example text helpers -----------------------

def example_for_key(family: str, key: str) -> str:
    meta = SCENARIO_META_BASE.get(family)
    if not meta:
        return ""
    _, j_idx, r_idx = meta
    base = None
    if key.startswith("jsonb"):
        base = j_idx
        if key.endswith("unindexed"):
            base = base.replace("indexed_", "unindexed_")
    elif key.startswith("rel"):
        base = r_idx
        if key.endswith("unindexed"):
            base = base.replace("indexed_", "unindexed_")
    return base or ""

def wrap_vertical(text: str, width: int = 60) -> str:
    t = text.strip()
    if len(t) > width:
        t = t[:width-3] + "..."
    return t

# ----------------------- Label formatting helpers -----------------------

def format_metric_value(metric: str, val: float) -> str:
    """Format labels with thousandths precision for < 1 ms values, and clamp extremely small values."""
    if not np.isfinite(val):
        return "—"
    if metric.endswith("_ms"):
        if val < 0.001:
            return "<0.001 ms"
        if val < 1.0:
            return f"{val:.3f} ms"   # thousandths when < 1 ms
        return f"{val:.1f} ms"       # one decimal otherwise
    if "reads" in metric or "hits" in metric:
        try:
            return f"{int(round(val)):,}"
        except Exception:
            return f"{val:.0f}"
    return f"{val:.2f}"

def compute_baselines(keys: list[str], vals: list[float]) -> dict:
    base = {"jsonb_indexed": None, "jsonb_unindexed": None}
    for k, v in zip(keys, vals):
        if not np.isfinite(v) or v <= 0:
            continue
        kk = (k or "").strip().lower()
        if kk == "jsonb_indexed":
            base["jsonb_indexed"] = float(v)
        elif kk == "jsonb_unindexed":
            base["jsonb_unindexed"] = float(v)
    return base

def compose_label_with_percent(key: str, value: float, baselines: dict, metric: str, show_percent: bool = True) -> str:
    abs_txt = format_metric_value(metric, value)
    if not show_percent:
        return abs_txt
    b_idx = baselines.get("jsonb_indexed")
    b_un  = baselines.get("jsonb_unindexed")
    k = (key or "").strip().lower()
    if k == "jsonb_indexed":
        return f"{abs_txt} (100%)"
    if k == "rel_indexed" and b_idx and b_idx > 0:
        p = 100.0 * (value / b_idx); faster = 100.0 - p
        return f"{abs_txt} ({p:.0f}% of JSONB, {faster:.0f}% faster)"
    if k == "jsonb_unindexed":
        return f"{abs_txt} (100%)"
    if k == "rel_unindexed" and b_un and b_un > 0:
        p = 100.0 * (value / b_un); faster = 100.0 - p
        return f"{abs_txt} ({p:.0f}% of JSONB, {faster:.0f}% faster)"
    return abs_txt

# ----------------------- Error bar helper -----------------------

def compute_error(values: np.ndarray, mode: str) -> float:
    v = np.array(values, dtype=float)
    v = v[np.isfinite(v)]
    if v.size <= 1:
        return 0.0
    if mode == "sd":
        return float(np.nanstd(v, ddof=1))
    if mode == "se":
        return float(np.nanstd(v, ddof=1) / np.sqrt(v.size))
    if mode == "ci":
        se = np.nanstd(v, ddof=1) / np.sqrt(v.size)
        return float(1.96 * se)
    return 0.0  # none

# ----------------------- Plotting -----------------------

def metric_label(metric: str) -> str:
    if metric.endswith("_ms"):
        base = metric.replace("_ms", "").replace("_", " ")
        return f"{base.upper()} (ms)" if base.lower() in ("p50", "p95", "avg") else f"{metric.replace('_', ' ')} (ms)"
    return metric.replace("_", " ")

def plot_grid_by_family(mat: pd.DataFrame, labels: list[str], metric: str, out_base: str,
                        title: str | None, title_template: str, n_hint: str | None,
                        examples: bool, show_labels: bool, show_percent: bool,
                        ylabel_mode: str, error_mode: str,
                        fig_w_per_col: float, fig_h_per_row: float):
    if mat.empty:
        return

    fams = sorted(mat["family"].unique().tolist(), key=numeric_family_sort_key)
    n = len(fams)

    fig, axes = plt.subplots(ROWS, COLS, figsize=(fig_w_per_col * COLS, fig_h_per_row * ROWS), squeeze=False)

    # Figure legend handles (consistent across subplots)
    uniq_keys = []
    for lbl in labels:
        k = infer_key_from_label(lbl)
        if k not in uniq_keys:
            uniq_keys.append(k)
    handles = [Patch(facecolor=SERIES_FILL.get(k, "#777"),
                     edgecolor="black",
                     hatch=HATCH_MAP.get(k, ""),
                     label=LEGEND_LABEL.get(k, k)) for k in uniq_keys]

    used_warn = False
    BAR_WIDTH = 0.18  # very narrow bars

    for i, fam in enumerate(fams):
        r, c = divmod(i, COLS)
        ax = axes[r][c]
        fam_rows = mat[mat["family"] == fam].copy()

        if len(fam_rows) > 1 and not used_warn:
            print(f"[note] Family {fam} has multiple variants; averaging values per label and drawing error bars.")
            used_warn = True

        vals, errs, ticks, fills, hatches, keys = [], [], [], [], [], []
        for lbl in labels:
            v = pd.to_numeric(fam_rows[lbl], errors="coerce").astype(float)
            mean_val = float(np.nanmean(v)) if v.size else np.nan
            if not np.isfinite(mean_val):
                mean_val = 0.0
            err_val = compute_error(v.values, error_mode)
            vals.append(mean_val)
            errs.append(err_val)
            ticks.append(shorten_tick(lbl))
            k = infer_key_from_label(lbl)
            keys.append(k)
            fills.append(SERIES_FILL.get(k, "#777"))
            hatches.append(HATCH_MAP.get(k, ""))

        x = np.arange(len(labels))
        bars = ax.bar(x, vals, width=BAR_WIDTH, color=fills, edgecolor="black", linewidth=0.6)
        for b, ht in zip(bars, hatches):
            b.set_hatch(ht)

        if error_mode != "none" and any(e > 0 for e in errs):
            ax.errorbar(x, vals, yerr=errs, fmt="none", ecolor="#111", elinewidth=0.9, capsize=2, capthick=0.9)

        ymax = max(vals) if len(vals) else 0.0
        if not np.isfinite(ymax) or ymax <= 0:
            ymax = 1.0
        margin = 1.42 if examples else 1.25
        ax.set_ylim(0, ymax * margin)

        scen_title = SCENARIO_META_BASE.get(fam, ("", "", ""))[0]
        ax.set_title(f"{fam} — {scen_title}", pad=4)

        if show_labels:
            baselines = compute_baselines(keys, vals)
            for xi, vi, k in zip(x, vals, keys):
                label_txt = compose_label_with_percent(k, vi, baselines, metric, show_percent=show_percent)
                ax.text(
                    xi, vi * 1.02, label_txt,
                    ha="center", va="bottom", fontsize=8.5, color="#111",
                    bbox=dict(facecolor="white", alpha=0.75, edgecolor="none", boxstyle="round,pad=0.20")
                )

        if examples:
            for xi, k, vi in zip(x, keys, vals):
                ex = example_for_key(fam, k)
                if ex:
                    txt = wrap_vertical(ex, width=95)
                    ax.text(
                        xi, vi * 1.12, txt, rotation=90, va="bottom", ha="center",
                        fontsize=8, color="#111",
                        bbox=dict(facecolor="white", alpha=0.60, edgecolor="none", boxstyle="round,pad=0.18")
                    )

        ax.set_xticks(x, ticks)
        if ylabel_mode == "per-axis":
            ax.set_ylabel(metric_label(metric))
        ax.grid(True, axis='y', alpha=0.25)

    for j in range(n, ROWS * COLS):
        r, c = divmod(j, COLS)
        axes[r][c].axis('off')

    if handles:
        fig.legend(handles=handles, loc="lower center", ncol=len(handles),
                   frameon=False, bbox_to_anchor=(0.5, 0.02))

    tpl = title_template or "{metric} — N={N}"
    fig_title = tpl.format(metric=metric, N=(n_hint or ""))
    if title:
        fig_title = f"{title} — {fig_title}"

    if ylabel_mode == "figure":
        fig.supylabel(metric_label(metric))

    fig.suptitle(fig_title, y=0.965, fontsize=11)
    fig.tight_layout(rect=[0.02, 0.06, 0.98, 0.92])

    fig.savefig(out_base + ".pdf")
    fig.savefig(out_base + ".png", dpi=350)
    plt.close(fig)

# ----------------------- CLI -----------------------

def main():
    ap = argparse.ArgumentParser(
        description="Grouped bar charts by scenario (S1..S10), 2–4 labels (jsonb/rel, indexed/unindexed)."
    )
    ap.add_argument("--file", required=True, help="Path to performance_run_<N>.xlsx (summary sheet)")
    ap.add_argument("--labels", nargs="+", required=True,
                    help="2–4 label substrings (e.g. 'jsonb_indexed' 'jsonb_unindexed' 'rel_indexed' 'rel_unindexed')")

    g = ap.add_mutually_exclusive_group(required=False)
    g.add_argument("--metric", choices=ALL_METRICS, help="Single metric")
    g.add_argument("--metrics", nargs="+", choices=ALL_METRICS, help="Multiple metrics")
    ap.add_argument("--all", action="store_true", help="Plot all metrics")

    ap.add_argument("--outdir", default="viz_single_grouped", help="Output directory")
    ap.add_argument("--title", default="", help="Optional extra title prefix")
    ap.add_argument("--title-template", default="{metric} — N={N}",
                    help="Figure title template; use {metric} and {N}. Example: 'N={N} {metric}'")
    ap.add_argument("--n", default=None,
                    help="Override record count for title (e.g., '100000' or '100 000'); otherwise parsed from filename if possible")
    ap.add_argument("--n-sep", choices=["keep","comma","space","none"], default="keep",
                    help="Thousands separator for N (default keep)")

    # Style & layout (mirrors viz_scaling.py)
    ap.add_argument("--ylabel", choices=["none","per-axis","figure"], default="none",
                    help="Y-axis labeling: none (default), per-axis, or figure (shared)")
    ap.add_argument("--errors", choices=["none","sd","se","ci"], default="ci",
                    help="Error bars from replicates: none, SD, SE, or 95% CI (default)")
    # Per-bar labels toggle
    bl = ap.add_mutually_exclusive_group()
    bl.add_argument("--barlabels", dest="barlabels", action="store_true",
                    help="Show per-bar labels (absolute + % vs JSONB baseline)")
    bl.add_argument("--no-barlabels", dest="barlabels", action="store_false",
                    help="Hide per-bar labels")
    ap.set_defaults(barlabels=True)
    # SQL examples toggle
    ex = ap.add_mutually_exclusive_group()
    ex.add_argument("--examples", dest="examples", action="store_true", help="Show vertical SQL examples per bar")
    ex.add_argument("--no-examples", dest="examples", action="store_false", help="Hide SQL examples")
    ap.set_defaults(examples=False)

    ap.add_argument("--dpi", type=int, default=300, help="Figure DPI (PNG fallback)")
    ap.add_argument("--column", choices=["single","double"], default="double",
                    help="Figure width preset per subplot column (single≈3.5in, double≈7.2in). Ignored if --ratio is set.")
    ap.add_argument("--rowheight", type=float, default=2.2,
                    help="Height per subplot row in inches (reasonable 2.0–2.6)")
    ap.add_argument("--ratio", type=float, default=None,
                    help="Figure aspect ratio as WIDTH/HEIGHT for the whole figure. Overrides --column. Example: --ratio 2")

    args = ap.parse_args()

    apply_style(dpi=args.dpi, base_font=9)

    # Compute per-subplot width to match viz_scaling.py behavior
    fig_h_per_row = args.rowheight
    if args.ratio is not None:
        fig_w_per_col = args.ratio * (ROWS / COLS) * fig_h_per_row
    else:
        fig_w_per_col = 3.5 if args.column == "single" else 7.2

    df = load_summary(args.file)
    ensure_metric_columns(df)

    if len(args.labels) < 2 or len(args.labels) > 4:
        print("Please pass between 2 and 4 --labels.")
        sys.exit(1)

    os.makedirs(args.outdir, exist_ok=True)

    # Metrics to plot
    if args.all:
        metrics = ALL_METRICS
    elif args.metrics:
        metrics = args.metrics
    elif args.metric:
        metrics = [args.metric]
    else:
        metrics = ["p50_ms"]

    # Resolve N for title once (from --n or filename)
    n_hint = resolve_N_for_title(args.labels, args.file, args.n, args.n_sep)

    # Build wide matrix for each metric and plot
    for m in metrics:
        mat = prepare_matrix_for_metric(df, args.labels, m)
        if mat.empty:
            print(f"[warn] No data for metric {m}; skipping.")
            continue
        out_base = os.path.join(args.outdir, f"{m}_grouped")
        plot_grid_by_family(
            mat=mat,
            labels=args.labels,
            metric=m,
            out_base=out_base,
            title=(args.title or None),
            title_template=args.title_template,
            n_hint=n_hint,
            examples=args.examples,
            show_labels=args.barlabels,
            show_percent=True,
            ylabel_mode=args.ylabel,
            error_mode=args.errors,
            fig_w_per_col=fig_w_per_col,
            fig_h_per_row=fig_h_per_row,
        )
        mat.to_csv(os.path.join(args.outdir, f"{m}_wide.csv"), index=False)

    print(f"Saved charts (PDF + PNG) to {args.outdir}")

if __name__ == "__main__":
    main()
