-- Ensure a superuser role `postgres` exists with the password `postgres`,
-- and make sure the `ledgerdb` database exists and is owned by that role.
-- Idempotent: safe to run multiple times.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
    CREATE ROLE postgres
      WITH LOGIN
           SUPERUSER
           CREATEDB
           CREATEROLE
           REPLICATION
           INHERIT
           PASSWORD 'postgres';
  ELSE
    ALTER ROLE postgres
      WITH LOGIN
           SUPERUSER
           CREATEDB
           CREATEROLE
           REPLICATION
           INHERIT
           PASSWORD 'postgres';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'ledgerdb') THEN
    EXECUTE 'CREATE DATABASE ledgerdb OWNER postgres';
  END IF;
END
$$;

ALTER DATABASE ledgerdb OWNER TO postgres;
