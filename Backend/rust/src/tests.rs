use super::*;
use axum::{
    body::{to_bytes, Body},
    http::Request,
};
use serde_json::{json, Value};
use tower::ServiceExt;

// These generated credentials are independent of any local .env account.
fn credentials() -> TestCredentials {
    let mut bytes = [0_u8; 4];
    getrandom::fill(&mut bytes).unwrap();
    TestCredentials {
        phone: "+919876543210".into(),
        otp: format!("{:06}", u32::from_le_bytes(bytes) % 1_000_000),
    }
}

fn test_config(credentials: &TestCredentials) -> Config {
    config_with(&[
        ("APP_ENV", "test"),
        ("AUTH_TEST_ENABLED", "true"),
        ("AUTH_TEST_PHONE", &credentials.phone),
        ("AUTH_TEST_OTP", &credentials.otp),
    ])
    .unwrap()
}

fn config_with(values: &[(&str, &str)]) -> Result<Config, String> {
    Config::from_lookup(|key| {
        values
            .iter()
            .find(|(name, _)| *name == key)
            .map(|(_, value)| value.to_string())
            .or_else(|| match key {
                "DATABASE_URL" => {
                    Some("postgresql://test:test@localhost/facepay_test?sslmode=require".into())
                }
                "EXPECTED_DATABASE_NAME" => Some("facepay_test".into()),
                _ => None,
            })
    })
}

fn verification(challenge_id: &str, otp: &str) -> VerifyRequest {
    VerifyRequest {
        challenge_id: challenge_id.to_owned(),
        otp: otp.to_owned(),
    }
}

fn api_request(method: Method, path: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(path)
        .header(header::CONTENT_TYPE, "application/json")
        .body(Body::from(body.to_string()))
        .unwrap()
}

async fn response_json(response: Response) -> Value {
    let bytes = to_bytes(response.into_body(), 4096).await.unwrap();
    serde_json::from_slice(&bytes).unwrap()
}

#[test]
fn configuration_defaults_fail_closed_and_test_mode_requires_explicit_safe_configuration() {
    let config = config_with(&[]).unwrap();
    assert!(config.test_credentials.is_none());
    assert_eq!(config.bind_addr.to_string(), "127.0.0.1:8080");
    assert_eq!(
        config_with(&[("PORT", "10000")])
            .unwrap()
            .bind_addr
            .to_string(),
        "0.0.0.0:10000"
    );
    assert!(config_with(&[("PORT", "not-a-port")]).is_err());
    assert!(config_with(&[("PORT", "0")]).is_err());
    for app_env in ["production", "staging", "", "DEVELOPMENT"] {
        assert!(config_with(&[("APP_ENV", app_env), ("AUTH_TEST_ENABLED", "true")]).is_err());
    }
    assert!(config_with(&[("APP_ENV", "test"), ("AUTH_TEST_ENABLED", "true")]).is_err());
    assert!(config_with(&[("APP_ENV", "test"), ("AUTH_TEST_ENABLED", "TRUE")]).is_err());
    assert!(config_with(&[
        ("APP_ENV", "test"),
        ("AUTH_TEST_ENABLED", "true"),
        ("BIND_ADDR", "0.0.0.0:8080")
    ])
    .is_err());
    assert!(config_with(&[
        ("APP_ENV", "test"),
        ("AUTH_TEST_ENABLED", "true"),
        ("AUTH_TEST_PHONE", "bad"),
        ("AUTH_TEST_OTP", "bad")
    ])
    .is_err());
    assert!(config_with(&[
        ("APP_ENV", "production"),
        ("AUTH_TEST_PHONE", "unused"),
        ("AUTH_TEST_OTP", "unused")
    ])
    .unwrap()
    .test_credentials
    .is_none());
}

#[test]
fn cors_configuration_enforces_exact_environment_appropriate_origins() {
    for origin in [
        "*",
        "http://localhost.evil.test:5173",
        "http://localhost:5173/app",
        "http://localhost:5173/",
        "http://localhost:5173?x=1",
        "http://user@localhost:5173",
        "null",
        "",
    ] {
        assert!(
            config_with(&[("FRONTEND_ORIGINS", origin)]).is_err(),
            "Accepted unsafe origin: {origin}"
        );
    }
    assert!(config_with(&[(
        "FRONTEND_ORIGINS",
        "http://localhost:5173,http://127.0.0.1:5173,http://[::1]:5173"
    )])
    .is_ok());
    assert!(config_with(&[("FRONTEND_ORIGINS", "https://facepay.example.com")]).is_ok());
    assert!(config_with(&[("FRONTEND_ORIGINS", "http://facepay.example.com")]).is_err());
    assert!(config_with(&[
        ("APP_ENV", "development"),
        ("FRONTEND_ORIGINS", "https://facepay.example.com"),
    ])
    .is_err());
}

#[test]
fn phone_normalization_accepts_only_indian_mobile_shapes() {
    assert_eq!(
        normalize_phone("9876543210").as_deref(),
        Some("+919876543210")
    );
    assert_eq!(
        normalize_phone(" +919876543210 ").as_deref(),
        Some("+919876543210")
    );
    for input in [
        "",
        "1234567890",
        "+19876543210",
        "+91987654321",
        "98765 43210",
        "९८७६५४३२१०",
    ] {
        assert!(normalize_phone(input).is_none());
    }
}

#[test]
fn resend_is_throttled_and_rotates_the_previous_challenge() {
    let credentials = credentials();
    let mut store = Store::default();
    let now = Instant::now();
    let first = store.issue(credentials.phone.clone(), now).unwrap();
    let error = store
        .issue(credentials.phone.clone(), now + Duration::from_secs(1))
        .err()
        .unwrap();
    assert_eq!(error.code, "rate_limited");
    assert!(error.retry_after.is_some());
    let next_time = now + RESEND_DELAY;
    let second = store.issue(credentials.phone.clone(), next_time).unwrap();
    assert_ne!(first.challenge_id, second.challenge_id);
    assert_eq!(store.challenges.len(), 1);
    assert_eq!(
        store
            .verify(
                verification(&first.challenge_id, &credentials.otp),
                &credentials,
                next_time
            )
            .err()
            .unwrap()
            .code,
        "invalid_otp"
    );
    assert!(store
        .verify(
            verification(&second.challenge_id, &credentials.otp),
            &credentials,
            next_time
        )
        .is_ok());
}

#[test]
fn challenge_is_single_use() {
    let credentials = credentials();
    let mut store = Store::default();
    let now = Instant::now();
    let challenge = store.issue(credentials.phone.clone(), now).unwrap();
    assert_eq!(
        store
            .verify(
                verification(&challenge.challenge_id, &credentials.otp),
                &credentials,
                now
            )
            .unwrap(),
        credentials.phone
    );
    assert_eq!(
        store
            .verify(
                verification(&challenge.challenge_id, &credentials.otp),
                &credentials,
                now
            )
            .err()
            .unwrap()
            .code,
        "invalid_otp"
    );
}
#[test]
fn expired_challenge_cannot_create_a_session() {
    let credentials = credentials();
    let mut store = Store::default();
    let now = Instant::now();
    let challenge = store.issue(credentials.phone.clone(), now).unwrap();
    let error = store
        .verify(
            verification(&challenge.challenge_id, &credentials.otp),
            &credentials,
            now + CHALLENGE_TTL,
        )
        .err()
        .unwrap();
    assert_eq!(error.code, "challenge_expired");
    assert!(store.challenges.is_empty());
}

#[test]
fn five_bad_attempts_lock_challenge_even_for_the_correct_code() {
    let credentials = credentials();
    let mut store = Store::default();
    let now = Instant::now();
    let challenge = store.issue(credentials.phone.clone(), now).unwrap();
    for attempt in 1..=MAX_ATTEMPTS {
        let error = store
            .verify(
                verification(&challenge.challenge_id, "invalid"),
                &credentials,
                now,
            )
            .err()
            .unwrap();
        assert_eq!(
            error.code,
            if attempt == MAX_ATTEMPTS {
                "attempt_limit"
            } else {
                "invalid_otp"
            }
        );
    }
    assert_eq!(
        store
            .verify(
                verification(&challenge.challenge_id, &credentials.otp),
                &credentials,
                now
            )
            .err()
            .unwrap()
            .code,
        "attempt_limit"
    );
    let next = store
        .issue(credentials.phone.clone(), now + RESEND_DELAY)
        .unwrap();
    assert!(store
        .verify(
            verification(&next.challenge_id, &credentials.otp),
            &credentials,
            now + RESEND_DELAY
        )
        .is_ok());
}

#[tokio::test]
async fn disabled_mode_and_nonallowlisted_phone_cannot_authenticate() {
    let credentials = credentials();
    let disabled = router(config_with(&[]).unwrap(), lazy_pool());
    let response = disabled
        .clone()
        .oneshot(api_request(
            Method::POST,
            "/auth/request-otp",
            json!({"phone": credentials.phone}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(
        response_json(response).await["error"]["code"],
        "auth_unavailable"
    );
    let response = disabled
        .oneshot(api_request(
            Method::POST,
            "/auth/verify-otp",
            json!({"challenge_id": "unused", "otp": credentials.otp}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let response = router(test_config(&credentials), lazy_pool())
        .oneshot(api_request(
            Method::POST,
            "/auth/request-otp",
            json!({"phone": "+916123456789"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
}

#[tokio::test]
async fn invalid_json_phones_and_missing_bearer_get_structured_errors() {
    let credentials = credentials();
    let app = router(test_config(&credentials), lazy_pool());
    for body in [
        json!({}),
        json!({"phone": 123}),
        json!({"phone": credentials.phone, "unexpected": true}),
    ] {
        let response = app
            .clone()
            .oneshot(api_request(Method::POST, "/auth/request-otp", body))
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        assert_eq!(
            response_json(response).await["error"]["code"],
            "invalid_request"
        );
    }
    let response = app
        .clone()
        .oneshot(api_request(
            Method::POST,
            "/auth/request-otp",
            json!({"phone": "bad"}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        response_json(response).await["error"]["code"],
        "invalid_phone"
    );
    let response = app
        .oneshot(
            Request::builder()
                .uri("/auth/me")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn oversized_body_is_rejected_before_authentication() {
    let credentials = credentials();
    let response = router(test_config(&credentials), lazy_pool())
        .oneshot(api_request(
            Method::POST,
            "/auth/request-otp",
            json!({"phone": "9".repeat(2048)}),
        ))
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        response_json(response).await["error"]["code"],
        "invalid_request"
    );
}

#[tokio::test]
async fn cors_returns_only_the_exact_configured_frontend_origin() {
    let credentials = credentials();
    let app = router(test_config(&credentials), lazy_pool());
    for origin in [
        "http://localhost:5173",
        "https://untrusted.example",
        "http://localhost:5174",
    ] {
        let request = Request::builder()
            .method(Method::OPTIONS)
            .uri("/auth/request-otp")
            .header(header::ORIGIN, origin)
            .header(header::ACCESS_CONTROL_REQUEST_METHOD, "POST")
            .header(header::ACCESS_CONTROL_REQUEST_HEADERS, "content-type")
            .body(Body::empty())
            .unwrap();
        let response = app.clone().oneshot(request).await.unwrap();
        if origin == "http://localhost:5173" {
            assert_eq!(
                response.headers()[header::ACCESS_CONTROL_ALLOW_ORIGIN],
                origin
            );
        } else {
            assert!(response
                .headers()
                .get(header::ACCESS_CONTROL_ALLOW_ORIGIN)
                .is_none());
        }
        assert!(response
            .headers()
            .get(header::ACCESS_CONTROL_ALLOW_CREDENTIALS)
            .is_none());
    }
}

fn lazy_pool() -> PgPool {
    sqlx::postgres::PgPoolOptions::new()
        .connect_lazy("postgresql://test:test@localhost/facepay_test")
        .unwrap()
}

#[test]
fn database_guard_and_tls_are_required() {
    assert!(Config::from_lookup(|_| None).is_err());
    assert!(database::verify_database_name("neondb", "facePay").is_err());
    assert!(database::verify_database_name("neondb", "neondb").is_ok());
    assert!(database::connection_options("postgresql://test:test@localhost/test").is_err());
}

#[test]
fn profile_validation_trims_and_rejects_bad_values() {
    let patch = ProfilePatch {
        name: "  Test Member  ".into(),
        email: Some("  user@example.com  ".into()),
    }
    .validate()
    .unwrap();
    assert_eq!(patch.name, "Test Member");
    assert_eq!(patch.email.as_deref(), Some("user@example.com"));
    for name in ["", "a", "a\nb"] {
        assert!(ProfilePatch {
            name: name.into(),
            email: None
        }
        .validate()
        .is_err());
    }
    assert!(ProfilePatch {
        name: "Valid Name".into(),
        email: Some("bad".into())
    }
    .validate()
    .is_err());
    assert!(serde_json::from_value::<ProfilePatch>(
        json!({"name":"Valid Name", "mobile_no":"+919876543210"})
    )
    .is_err());
}

#[tokio::test]
#[ignore = "Explicit live Neon smoke test; creates and removes one isolated test profile"]
async fn live_neon_profile_roundtrip() {
    dotenvy::dotenv().ok();
    let config = Config::from_env().expect("Local configuration required");
    let pool = database::connect_and_migrate(&config).await.unwrap();
    let token = opaque_id().unwrap();
    let suffix: String = token
        .bytes()
        .take(9)
        .map(|b| char::from(b'0' + b % 10))
        .collect();
    let phone = format!("+919{suffix}");
    let exists: bool =
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM facepay.profiles WHERE mobile_no = $1)")
            .bind(&phone)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(!exists, "Test phone collision; rerun");
    let initial = database::sign_in(&pool, &phone, &token).await.unwrap();
    let outcome: Result<(), ApiError> = async {
        let updated = database::update_profile(
            &pool,
            &token,
            ProfilePatch {
                name: "Profile integration test".into(),
                email: Some("profile-test@example.com".into()),
            }
            .validate()?,
        )
        .await?;
        assert_eq!(updated.mobile_no, phone);
        let reloaded = database::authenticated_profile(&pool, &token).await?;
        assert_eq!(reloaded.name.as_deref(), Some("Profile integration test"));
        assert_eq!(reloaded.email.as_deref(), Some("profile-test@example.com"));
        assert!(database::update_profile(
            &pool,
            &opaque_id()?,
            ProfilePatch {
                name: "Wrong owner".into(),
                email: None
            }
        )
        .await
        .is_err());
        database::logout(&pool, &token).await?;
        assert!(database::authenticated_profile(&pool, &token)
            .await
            .is_err());
        let next_token = opaque_id()?;
        let next = database::sign_in(&pool, &phone, &next_token).await?;
        assert_eq!(next.id, initial.id);
        assert_eq!(next.name, reloaded.name);
        Ok(())
    }
    .await;
    sqlx::query("DELETE FROM facepay.profiles WHERE id = $1 AND mobile_no = $2")
        .bind(&initial.id)
        .bind(&phone)
        .execute(&pool)
        .await
        .unwrap();
    pool.close().await;
    outcome.unwrap();
}
