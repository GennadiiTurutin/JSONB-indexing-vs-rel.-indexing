import os
import sys
from datetime import datetime
import pandas as pd
from sqlalchemy import create_engine, text

# ---- connection config (env or defaults) -------------------------------------
PGHOST     = os.getenv("POSTGRES_HOST", "127.0.0.1")
PGPORT     = int(os.getenv("POSTGRES_PORT", "5433"))
PGDATABASE = os.getenv("POSTGRES_DB", "ledgerdb")
PGUSER     = os.getenv("POSTGRES_USER", "postgres")
PGPASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")

SIZES = [1_000, 10_000, 100_000, 1_000_000]
OUTDIR = os.getenv("OUTDIR", "exports")
os.makedirs(OUTDIR, exist_ok=True)

# SQLAlchemy engine (psycopg v3 driver)
ENGINE = create_engine(
    f"postgresql+psycopg://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{PGDATABASE}",
    pool_pre_ping=True,
)

def run_suite(n: int, runs: int = 7, warm: int = 2, clear: bool = True):
    print(f"\n▶ Running suite for N={n:,} ...")
    with ENGINE.begin() as conn:
        conn.execute(
            text("CALL bench.run_suite_for_size(:n, :runs, :warm, :clr)"),
            {"n": n, "runs": runs, "warm": warm, "clr": clear},
        )
    print("   ...done")

def fetch_summary(n: int) -> pd.DataFrame:
    sql = text("""
        SELECT *
        FROM bench.summary
        WHERE label LIKE :lbl
        ORDER BY label, variant
    """)
    return pd.read_sql(sql, ENGINE, params={"lbl": f"N={n} %"})

def fetch_results(n: int) -> pd.DataFrame:
    sql = text("""
        SELECT
          label, variant, run_no, ts,
          execution_ms, shared_reads, shared_hits,
          jsonb_pretty(plan_json) AS plan_text
        FROM bench.results
        WHERE label LIKE :lbl
        ORDER BY variant, run_no
    """)
    df = pd.read_sql(sql, ENGINE, params={"lbl": f"N={n} %"})
    # Excel can't handle tz-aware datetimes: normalize to UTC and drop tz
    if "ts" in df.columns:
        s = pd.to_datetime(df["ts"], utc=True, errors="coerce")
        df["ts"] = s.dt.tz_convert(None)
    return df

def write_excels(n: int, df_summary: pd.DataFrame, df_results: pd.DataFrame):
    perf_path = os.path.join(OUTDIR, f"performance_run_{n}.xlsx")
    plan_path = os.path.join(OUTDIR, f"query_planner_{n}.xlsx")

    with pd.ExcelWriter(perf_path, engine="openpyxl") as xw:
        df_summary.to_excel(xw, index=False, sheet_name="summary")

    with pd.ExcelWriter(plan_path, engine="openpyxl") as xw:
        df_results[["label","variant","run_no","ts","execution_ms","shared_reads","shared_hits"]] \
            .to_excel(xw, index=False, sheet_name="runs")
        df_results[["label","variant","run_no","plan_text"]] \
            .to_excel(xw, index=False, sheet_name="plans")

    print(f"   ✔ Wrote {perf_path}")
    print(f"   ✔ Wrote {plan_path}")

def main():
    try:
        for n in SIZES:
            run_suite(n)
            df_summary = fetch_summary(n)
            df_results = fetch_results(n)
            write_excels(n, df_summary, df_results)
    except Exception as e:
        print("ERROR:", e)
        sys.exit(1)
    print("\nAll done.")

if __name__ == "__main__":
    main()
