-- Safe to rerun. Set facepay.expected_database_name within this transaction first.
-- The full paste-ready Neon SQL Editor template is ../neon_setup.sql.
DO $$
DECLARE expected text := current_setting('facepay.expected_database_name', true);
BEGIN
    IF expected IS NULL OR expected = '' OR current_database() <> expected THEN
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

-- A device-bound liveness enrollment record. It intentionally contains no
-- face image, landmarks, or unencrypted face template.
CREATE TABLE IF NOT EXISTS facepay.face_enrollments (
    profile_id text PRIMARY KEY REFERENCES facepay.profiles(id) ON DELETE CASCADE,
    device_id_hash bytea NOT NULL CHECK (octet_length(device_id_hash) = 32),
    liveness_method varchar(32) NOT NULL CHECK (liveness_method = 'two_blink_v1'),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- This table receives only a server-validated, provider-issued reference once
-- the documented bank sandbox flow is implemented. It never stores an OTP,
-- full account number, provider token, or raw provider response.
CREATE TABLE IF NOT EXISTS facepay.linked_bank_accounts (
    id text PRIMARY KEY CHECK (id ~ '^[0-9a-f]{64}$'),
    profile_id text NOT NULL REFERENCES facepay.profiles(id) ON DELETE CASCADE,
    bank_name varchar(80) NOT NULL CHECK (char_length(bank_name) > 0 AND bank_name = btrim(bank_name)),
    bank_code varchar(32) NOT NULL CHECK (char_length(bank_code) > 0 AND bank_code = btrim(bank_code)),
    account_reference varchar(512) NOT NULL CHECK (char_length(account_reference) > 0),
    masked_account_number varchar(64) NOT NULL CHECK (char_length(masked_account_number) > 0),
    account_type varchar(64) NULL,
    account_holder_name varchar(160) NULL,
    verification_status varchar(32) NOT NULL CHECK (verification_status = 'verified'),
    provider varchar(64) NOT NULL CHECK (char_length(provider) > 0),
    provider_customer_reference varchar(512) NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, provider, account_reference)
);

CREATE INDEX IF NOT EXISTS linked_bank_accounts_profile_id_idx
    ON facepay.linked_bank_accounts(profile_id);
