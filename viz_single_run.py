#!/usr/bin/env python3
# Small-multiples by scenario (S1..S10). 2–4 labels (jsonb/rel, indexed/unindexed).
# Linear axes. Strong colors, hatching for unindexed, N in title (templateable),
# per-bar numeric labels, vertical SQL examples, AND percentage labels vs JSONB baselines.

import argparse, os, re, sys, math
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

# ---- Global font tweaks (slightly bigger, consistent) ----
plt.rcParams.update({
    "font.size": 11,         # base font
    "axes.titlesize": 14,    # subplot titles
    "axes.labelsize": 12,    # axis labels
    "xtick.labelsize": 11,
    "ytick.labelsize": 11,
    "legend.fontsize": 11,
})

ALL_METRICS = ["p50_ms","p95_ms","avg_ms","sum_shared_reads","sum_shared_hits"]

# Vivid palette. Unindexed gets hatching.
SERIES_COLOR = {
    "jsonb_indexed":   "#0a7a0a",  # deep green
    "jsonb_unindexed": "#33cc66",  # bright green
    "rel_indexed":     "#a01515",  # deep red
    "rel_unindexed":   "#ff5959",  # bright red
    "jsonb":           "#1e8b1e",  # fallbacks if no idx hint
    "rel":             "#b22222",
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

# ---- Scenario metadata: human titles + BASE (indexed) examples ----
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
            "SELECT id FROM inv_jsonb WHERE (payload->>'indexed_text_1')='A' ORDER BY (payload->>'indexed_timestamp_1') DESC LIMIT 50",
            "SELECT id FROM inv_rel   WHERE indexed_text_1='A' ORDER BY indexed_timestamp_1 DESC LIMIT 50"),
}

# ---------- Load + basic helpers ----------
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
    """jsonb_indexed/jsonb_unindexed/rel_indexed/rel_unindexed or fallback jsonb/rel."""
    if not isinstance(label, str):
        return "unknown"
    t = label.lower()
    engine = "jsonb" if re.search(r"\bjsonb\b", t) else ("rel" if re.search(r"\brel\b", t) else None)
    idx = None
    if re.search(r"\bunindexed\b", t):   # IMPORTANT: unindexed first
        idx = "unindexed"
    elif re.search(r"\bindexed\b", t):
        idx = "indexed"
    if engine and idx:
        return f"{engine}_{idx}"
    if engine:
        return engine
    return "unknown"

def shorten_label_for_tick(label: str) -> str:
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

def numeric_family_sort_key(fam: str) -> tuple:
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

# ---------- Title helpers (N formatting) ----------
def parse_n_from_filename(path: str) -> int | None:
    base = os.path.basename(path)
    nums = re.findall(r"(\d{4,})", base)
    if not nums:
        return None
    return max(int(x) for x in nums)

def normalize_n(n_str: str) -> int | None:
    if not n_str:
        return None
    digits = re.sub(r"[^\d]", "", n_str)
    return int(digits) if digits else None

def format_n(n_val: int | None, sep: str = "keep", original: str | None = None) -> str | None:
    if n_val is None:
        return original
    if sep == "keep" and original:
        return original
    if sep == "comma":
        return f"{n_val:,}"
    if sep == "space":
        s = f"{n_val:,}"
        return s.replace(",", " ")
    if sep == "none":
        return str(n_val)
    return str(n_val)

def resolve_N_for_title(labels: list[str], file_path: str, arg_n: str | None, n_sep: str) -> str | None:
    if arg_n:
        n_int = normalize_n(arg_n)
        return format_n(n_int, n_sep, original=arg_n)
    n_int = parse_n_from_filename(file_path)
    return format_n(n_int, n_sep, original=None)

# ---------- Examples + formatting ----------
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

def format_metric_value(metric: str, val: float) -> str:
    if not np.isfinite(val):
        return "—"
    if metric.endswith("_ms"):
        return f"{val:.1f} ms"
    if "reads" in metric or "hits" in metric:
        try:
            return f"{int(round(val)):,}"
        except Exception:
            return f"{val:.0f}"
    return f"{val:.2f}"

# ---------- Percentage label helpers (vs JSONB baselines) ----------
def compute_baselines(keys: list[str], vals: list[float]) -> dict:
    """
    Determine JSONB baselines present in this subplot:
      - 'jsonb_indexed'  baseline for indexed comparison
      - 'jsonb_unindexed' baseline for unindexed comparison
    """
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

def compose_label_with_percent(key: str, value: float, baselines: dict, metric: str) -> str:
    """
    Build annotation text: absolute metric + percent relative to the proper JSONB baseline.
    - For indexed: JSONB indexed = 100%; show REL indexed as % of JSONB and '% faster'.
    - For unindexed: JSONB unindexed = 100%; show REL unindexed similarly.
    JSONB bars show '100%'.
    """
    abs_txt = format_metric_value(metric, value)
    b_idx = baselines.get("jsonb_indexed")
    b_un  = baselines.get("jsonb_unindexed")
    k = (key or "").strip().lower()

    if k == "jsonb_indexed":
        return f"{abs_txt} (100%)"
    if k == "rel_indexed" and b_idx and b_idx > 0:
        p = 100.0 * (value / b_idx)
        faster = 100.0 - p
        return f"{abs_txt} ({p:.0f}% of JSONB, {faster:.0f}% faster)"

    if k == "jsonb_unindexed":
        return f"{abs_txt} (100%)"
    if k == "rel_unindexed" and b_un and b_un > 0:
        p = 100.0 * (value / b_un)
        faster = 100.0 - p
        return f"{abs_txt} ({p:.0f}% of JSONB, {faster:.0f}% faster)"

    # Fallback (e.g., if a baseline is missing)
    return abs_txt

# ---------- Plotting ----------
def plot_grid_by_family(mat: pd.DataFrame, labels: list[str], metric: str, out_png: str,
                        title: str | None, title_template: str, n_hint: str | None,
                        max_cols: int = 4, show_examples_per_bar: bool = True):
    if mat.empty:
        return

    fams = sorted(mat["family"].unique().tolist(), key=numeric_family_sort_key)
    n = len(fams)
    cols, rows = 2, 5

    # Slightly wider & taller figures
    fig, axes = plt.subplots(rows, cols, figsize=(7.2*cols, 5.2*rows), squeeze=False)

    used_warn = False

    # Figure legend handles (consistent across subplots)
    uniq_keys = []
    for lbl in labels:
        k = infer_key_from_label(lbl)
        if k not in uniq_keys:
            uniq_keys.append(k)
    handles = [Patch(facecolor=SERIES_COLOR.get(k, "#777"),
                     edgecolor=SERIES_COLOR.get(k, "#777"),
                     hatch=HATCH_MAP.get(k, ""),
                     label=LEGEND_LABEL.get(k, k)) for k in uniq_keys]

    for i, fam in enumerate(fams):
        r, c = divmod(i, cols)
        ax = axes[r][c]
        fam_rows = mat[mat["family"] == fam].copy()

        if len(fam_rows) > 1 and not used_warn:
            print(f"[note] Family {fam} has multiple variants; averaging values per label.")
            used_warn = True

        vals, ticks, colors, hatches, keys = [], [], [], [], []
        for lbl in labels:
            v = pd.to_numeric(fam_rows[lbl], errors="coerce").astype(float)
            val = float(np.nanmean(v)) if len(v) else float("nan")
            if not np.isfinite(val):
                val = 0.0
            vals.append(val)
            ticks.append(shorten_label_for_tick(lbl))
            k = infer_key_from_label(lbl)
            keys.append(k)
            colors.append(SERIES_COLOR.get(k, "#777"))
            hatches.append(HATCH_MAP.get(k, ""))

        x = np.arange(len(labels))
        bars = ax.bar(x, vals, color=colors, edgecolor=colors, linewidth=0.6)
        for b, ht in zip(bars, hatches):
            b.set_hatch(ht)

        ymax = max(vals) if len(vals) else 0.0
        if not np.isfinite(ymax) or ymax <= 0:
            ymax = 1.0
        margin = 1.60 if show_examples_per_bar else 1.30
        ax.set_ylim(0, ymax * margin)

        scen_title = SCENARIO_META_BASE.get(fam, ("", "", ""))[0]
        ax.set_title(f"{fam} — {scen_title}", pad=6)

        # ---- Percentage-aware labels (vs JSONB baselines) ----
        baselines = compute_baselines(keys, vals)
        for xi, vi, k in zip(x, vals, keys):
            label_txt = compose_label_with_percent(k, vi, baselines, metric)
            ax.text(
                xi, vi * 1.02, label_txt,
                ha="center", va="bottom", fontsize=11, color="#111",
                bbox=dict(facecolor="white", alpha=0.7, edgecolor="none", boxstyle="round,pad=0.22")
            )
            if show_examples_per_bar:
                ex = example_for_key(fam, k)
                if ex:
                    txt = wrap_vertical(ex, width=95)
                    ax.text(
                        xi, vi * 1.12, txt, rotation=90, va="bottom", ha="center",
                        fontsize=9, color="#111",
                        bbox=dict(facecolor="white", alpha=0.6, edgecolor="none", boxstyle="round,pad=0.22")
                    )

        ax.set_xticks(x, ticks)
        ax.set_ylabel(metric)
        ax.grid(True, axis='y', alpha=0.25)

    # Hide empty cells
    for j in range(n, rows*cols):
        r, c = divmod(j, cols)
        axes[r][c].axis('off')

    # Figure legend and title
    if handles:
        fig.legend(handles=handles, loc="upper center", ncol=len(handles),
                   frameon=False, bbox_to_anchor=(0.5, 1.01))

    tpl = title_template or "{metric} — N={N}"
    if "{N}" in tpl:
        fig_title = tpl.format(metric=metric, N=(n_hint or ""))
    else:
        fig_title = tpl.format(metric=metric, N=(n_hint or ""))

    if title:
        fig_title = f"{title} — {fig_title}"

    fig.suptitle(fig_title, y=0.995, fontsize=16, fontweight="bold")
    fig.tight_layout(rect=[0, 0.03, 1, 0.945])
    fig.savefig(out_png, dpi=170, bbox_inches="tight", pad_inches=0.35)
    plt.close(fig)

# ---------- CLI ----------
def main():
    ap = argparse.ArgumentParser(
        description="Grouped charts by scenario (S1..S10), 2–4 labels (jsonb/rel, indexed/unindexed)."
    )
    ap.add_argument("--file", required=True, help="Path to performance_run_<N>.xlsx (summary sheet)")
    ap.add_argument("--labels", nargs="+", required=True,
                    help="2–4 label substrings (e.g. 'N=100000 jsonb_indexed' 'N=100000 jsonb_unindexed' 'N=100000 rel_indexed' 'N=100000 rel_unindexed')")
    g = ap.add_mutually_exclusive_group(required=False)
    g.add_argument("--metric", choices=ALL_METRICS, help="Single metric")
    g.add_argument("--metrics", nargs="+", choices=ALL_METRICS, help="Multiple metrics")
    ap.add_argument("--all", action="store_true", help="Plot all metrics")
    ap.add_argument("--outdir", default="viz_single_grouped", help="Output directory")
    ap.add_argument("--title", default="", help="Optional extra title prefix")
    ap.add_argument("--title-template", default="{metric} — N={N}",
                    help="Figure title template; use {metric} and {N}. Example: 'N={N} {metric}'")
    ap.add_argument("--n", default=None,
                    help="Override record count for title (e.g. '100000' or '100 000'); otherwise parsed from filename if possible")
    ap.add_argument("--n-sep", choices=["keep","comma","space","none"], default="keep",
                    help="Thousands separator for N (default keep)")
    ap.add_argument("--max-cols", type=int, default=4, help="Max subplot columns (default 4)")
    ap.add_argument("--print-labels", action="store_true", help="List labels in the file and exit")
    ap.add_argument("--no-examples", action="store_true", help="Do not print per-bar SQL examples")
    args = ap.parse_args()

    df = load_summary(args.file)
    ensure_metric_columns(df)

    if args.print_labels:
        labels = sorted(df["label"].dropna().unique().tolist())
        print("Labels in file:")
        for lb in labels:
            print("  -", lb)
        sys.exit(0)

    if len(args.labels) < 2 or len(args.labels) > 4:
        print("Please pass between 2 and 4 --labels.")
        sys.exit(1)

    if args.all:
        metrics = ALL_METRICS
    elif args.metrics:
        metrics = args.metrics
    elif args.metric:
        metrics = [args.metric]
    else:
        metrics = ["p50_ms"]

    os.makedirs(args.outdir, exist_ok=True)

    # Resolve N for title once (from --n or filename)
    n_hint = resolve_N_for_title(args.labels, args.file, args.n, args.n_sep)

    for m in metrics:
        mat = prepare_matrix_for_metric(df, args.labels, m)
        if mat.empty:
            print(f"[warn] No data for metric {m}; skipping.")
            continue
        out_png = os.path.join(args.outdir, f"{m}_grouped.png")
        plot_grid_by_family(
            mat, args.labels, m, out_png,
            args.title or None,
            title_template=args.title_template,
            n_hint=n_hint,
            max_cols=args.max_cols,
            show_examples_per_bar=(not args.no_examples)
        )
        mat.to_csv(os.path.join(args.outdir, f"{m}_wide.csv"), index=False)

    print(f"Saved charts to {args.outdir}")

if __name__ == "__main__":
    main()
