use std::{str::FromStr, time::Duration};

use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::{
    postgres::{PgConnectOptions, PgPoolOptions, PgSslMode},
    ConnectOptions, PgPool,
};

use crate::{opaque_id, token_hash, ApiError, Config, ProfilePatch};

const MIGRATION: &str = include_str!("../migrations/001_profile_auth.sql");

#[derive(Clone, Serialize, sqlx::FromRow)]
pub(crate) struct Profile {
    pub id: String,
    pub name: Option<String>,
    pub mobile_no: String,
    pub email: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

pub(crate) fn connection_options(value: &str) -> Result<PgConnectOptions, String> {
    let parsed =
        url::Url::parse(value).map_err(|_| "DATABASE_URL must be a PostgreSQL connection URL.")?;
    if !matches!(parsed.scheme(), "postgres" | "postgresql")
        || parsed.host_str().is_none()
        || parsed.username().is_empty()
        || parsed.path().trim_matches('/').is_empty()
        || parsed.fragment().is_some()
    {
        return Err(
            "DATABASE_URL must explicitly include PostgreSQL user, host, and database.".into(),
        );
    }
    let ssl_mode = match parsed
        .query_pairs()
        .find(|(key, _)| key == "sslmode")
        .map(|(_, value)| value.into_owned())
        .as_deref()
    {
        Some("require") => PgSslMode::Require,
        Some("verify-ca") => PgSslMode::VerifyCa,
        Some("verify-full") => PgSslMode::VerifyFull,
        _ => {
            return Err(
                "DATABASE_URL must explicitly use sslmode=require or stronger for Neon.".into(),
            )
        }
    };
    // Do not forward driver errors, which can contain connection details.
    let options =
        PgConnectOptions::from_str(value).map_err(|_| "DATABASE_URL could not be parsed.")?;
    Ok(options.ssl_mode(ssl_mode).disable_statement_logging())
}

pub(crate) fn verify_database_name(actual: &str, expected: &str) -> Result<(), String> {
    if actual == expected {
        Ok(())
    } else {
        Err("Database name mismatch. No migration was run. Check EXPECTED_DATABASE_NAME against your selected Neon database.".into())
    }
}

pub(crate) async fn connect_and_migrate(config: &Config) -> Result<PgPool, String> {
    let options = connection_options(&config.database_url)?;
    let pool = PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(Duration::from_secs(10))
        .connect_with(options)
        .await
        .map_err(|_| "Could not connect to the configured database. Check the local connection settings; no migration was run.")?;

    // This is the first application query. DDL is unreachable before this check.
    let actual: String = sqlx::query_scalar("SELECT current_database()")
        .fetch_one(&pool)
        .await
        .map_err(|_| "Could not verify database identity. No migration was run.")?;
    if let Err(error) = verify_database_name(&actual, &config.expected_database_name) {
        pool.close().await;
        return Err(error);
    }

    let mut transaction = pool
        .begin()
        .await
        .map_err(|_| "Could not begin the database setup transaction.")?;
    // The SQL migration also checks the name, protecting SQL Editor setup too.
    sqlx::query("SELECT set_config('facepay.expected_database_name', $1, true)")
        .bind(&config.expected_database_name)
        .execute(&mut *transaction)
        .await
        .map_err(|_| "Could not set the migration database guard.")?;
    sqlx::raw_sql(MIGRATION).execute(&mut *transaction).await
        .map_err(|_| "Profile/session schema setup failed. The setup transaction was rolled back; check the database role and schema compatibility.")?;
    transaction
        .commit()
        .await
        .map_err(|_| "Could not commit the profile/session schema setup.")?;
    Ok(pool)
}

pub(crate) async fn sign_in(pool: &PgPool, phone: &str, token: &str) -> Result<Profile, ApiError> {
    let id = opaque_id()?;
    let mut transaction = pool.begin().await.map_err(ApiError::database_unavailable)?;
    let profile = sqlx::query_as::<_, Profile>(
        "INSERT INTO facepay.profiles (id, mobile_no) VALUES ($1, $2)
         ON CONFLICT (mobile_no) DO UPDATE SET mobile_no = EXCLUDED.mobile_no
         RETURNING id, name, mobile_no, email, created_at, updated_at",
    )
    .bind(id)
    .bind(phone)
    .fetch_one(&mut *transaction)
    .await
    .map_err(ApiError::database_unavailable)?;
    sqlx::query("INSERT INTO facepay.auth_sessions (token_hash, profile_id) VALUES ($1, $2)")
        .bind(token_hash(token).as_slice())
        .bind(&profile.id)
        .execute(&mut *transaction)
        .await
        .map_err(ApiError::database_unavailable)?;
    transaction
        .commit()
        .await
        .map_err(ApiError::database_unavailable)?;
    Ok(profile)
}

pub(crate) async fn authenticated_profile(pool: &PgPool, token: &str) -> Result<Profile, ApiError> {
    sqlx::query_as::<_, Profile>(
        "SELECT p.id, p.name, p.mobile_no, p.email, p.created_at, p.updated_at
         FROM facepay.profiles p
         JOIN facepay.auth_sessions s ON s.profile_id = p.id
         WHERE s.token_hash = $1",
    )
    .bind(token_hash(token).as_slice())
    .fetch_optional(pool)
    .await
    .map_err(ApiError::database_unavailable)?
    .ok_or_else(ApiError::unauthorized)
}

pub(crate) async fn update_profile(
    pool: &PgPool,
    token: &str,
    patch: ProfilePatch,
) -> Result<Profile, ApiError> {
    // Ownership comes exclusively from the session hash, never a client profile ID.
    sqlx::query_as::<_, Profile>(
        "UPDATE facepay.profiles p SET name = $2, email = $3, updated_at = now()
         FROM facepay.auth_sessions s
         WHERE s.profile_id = p.id AND s.token_hash = $1
         RETURNING p.id, p.name, p.mobile_no, p.email, p.created_at, p.updated_at",
    )
    .bind(token_hash(token).as_slice())
    .bind(patch.name)
    .bind(patch.email)
    .fetch_optional(pool)
    .await
    .map_err(ApiError::database_unavailable)?
    .ok_or_else(ApiError::unauthorized)
}

pub(crate) async fn logout(pool: &PgPool, token: &str) -> Result<(), ApiError> {
    sqlx::query("DELETE FROM facepay.auth_sessions WHERE token_hash = $1")
        .bind(token_hash(token).as_slice())
        .execute(pool)
        .await
        .map_err(ApiError::database_unavailable)?;
    Ok(())
}

pub(crate) async fn face_enrolled(pool: &PgPool, token: &str) -> Result<bool, ApiError> {
    let enrolled = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM facepay.face_enrollments e JOIN facepay.auth_sessions s ON s.profile_id = e.profile_id WHERE s.token_hash = $1)",
    )
    .bind(token_hash(token).as_slice())
    .fetch_one(pool)
    .await
    .map_err(ApiError::database_unavailable)?;
    Ok(enrolled)
}

pub(crate) async fn register_face_enrollment(
    pool: &PgPool,
    token: &str,
    device_id_hash: &[u8],
    liveness_method: &str,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        "INSERT INTO facepay.face_enrollments (profile_id, device_id_hash, liveness_method)
         SELECT s.profile_id, $2, $3 FROM facepay.auth_sessions s WHERE s.token_hash = $1
         ON CONFLICT (profile_id) DO UPDATE SET device_id_hash = EXCLUDED.device_id_hash, liveness_method = EXCLUDED.liveness_method, updated_at = now()",
    )
    .bind(token_hash(token).as_slice())
    .bind(device_id_hash)
    .bind(liveness_method)
    .execute(pool)
    .await
    .map_err(ApiError::database_unavailable)?;
    if updated.rows_affected() != 1 {
        return Err(ApiError::unauthorized());
    }
    Ok(())
}
