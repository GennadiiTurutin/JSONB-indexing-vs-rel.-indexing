CREATE OR REPLACE VIEW bench.summary AS
SELECT
  label,
  variant,
  COUNT(*) AS runs,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY execution_ms)::numeric, 3) AS p50_ms,
  ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_ms)::numeric, 3) AS p95_ms,
  ROUND(AVG(execution_ms)::numeric, 3) AS avg_ms,
  SUM(shared_reads) AS sum_shared_reads,
  SUM(shared_hits)  AS sum_shared_hits
FROM bench.results
GROUP BY label, variant
ORDER BY label, variant;
