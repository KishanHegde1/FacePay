-- In Neon, select the intended branch AND database first.
-- Configured for the selected neondb database.
-- This creates only the FacePay profile and login-session tables. No sample users.
BEGIN;
SELECT set_config('facepay.expected_database_name', 'neondb', true);

DO $$
DECLARE expected text := current_setting('facepay.expected_database_name', true);
BEGIN
    IF expected IS NULL OR expected = '' OR expected = 'YOUR_DATABASE_NAME'
       OR current_database() <> expected THEN
        RAISE EXCEPTION 'Database guard failed. No FacePay schema changes were made.';
    END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS facepay;

CREATE TABLE IF NOT EXISTS facepay.profiles (
    id text PRIMARY KEY CHECK (id ~ '^[0-9a-f]{64}$'),
    name varchar(80) NULL CHECK (name IS NULL OR (char_length(name) >= 2 AND name = btrim(name))),
    mobile_no varchar(13) NOT NULL UNIQUE CHECK (mobile_no ~ '^\+91[6-9][0-9]{9}$'),
    email varchar(254) NULL CHECK (email IS NULL OR (char_length(email) > 0 AND email = btrim(email))),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS facepay.auth_sessions (
    token_hash bytea PRIMARY KEY CHECK (octet_length(token_hash) = 32),
    profile_id text NOT NULL REFERENCES facepay.profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS auth_sessions_profile_id_idx ON facepay.auth_sessions(profile_id);
COMMIT;

