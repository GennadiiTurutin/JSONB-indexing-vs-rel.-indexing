\set ON_ERROR_STOP on
\echo 'Seeding :ROWS rows into inv_rel and inv_jsonb...'

-- Default if not provided: 100000
\if :{?ROWS}
\else
  \set ROWS 100000
\endif

-- Optional: stable pseudo-randomness per session
-- SELECT setseed(0.42);

CALL bench.seed_both(:'ROWS');

\echo 'Seed complete.'
