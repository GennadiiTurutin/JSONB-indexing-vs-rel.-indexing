\set ON_ERROR_STOP on

-- Examples (comment/uncomment what you want to run now)
CALL bench.run_suite_for_size(1000);
CALL bench.run_suite_for_size(10000);
CALL bench.run_suite_for_size(100000);
-- CALL bench.run_suite_for_size(1000000);
-- CALL bench.run_suite_for_size(10000000);
-- CALL bench.run_suite_for_size(100000000);

-- See summary
SELECT * FROM bench.summary ORDER BY label, variant;
