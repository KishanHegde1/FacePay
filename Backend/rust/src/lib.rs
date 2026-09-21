use std::{
    collections::HashMap,
    env,
    net::SocketAddr,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use axum::{
    extract::{rejection::JsonRejection, DefaultBodyLimit, Path, State},
    http::{header, HeaderMap, HeaderValue, Method, StatusCode, Uri},
    response::{IntoResponse, Response},
    routing::{delete, get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use subtle::ConstantTimeEq;
use tower_http::{cors::CorsLayer, set_header::SetResponseHeaderLayer};

mod database;
mod hdfc;
pub mod icici;
use database::Profile;

const CHALLENGE_TTL: Duration = Duration::from_secs(300);
const RESEND_DELAY: Duration = Duration::from_secs(30);
const MAX_ATTEMPTS: u8 = 5;

/// Test credentials are intentionally neither Debug nor Serialize.
#[derive(Clone)]
struct TestCredentials {
    phone: String,
    otp: String,
}

#[derive(Clone)]
pub struct Config {
    pub bind_addr: SocketAddr,
    origins: Vec<HeaderValue>,
    test_credentials: Option<TestCredentials>,
    // These fields are deliberately excluded from Debug/Serialize and error text.
    database_url: String,
    expected_database_name: String,
    firebase_web_api_key: Option<String>,
    hdfc_config: hdfc::HdfcConfig,
}

impl Config {
    pub fn from_env() -> Result<Self, String> {
        Self::from_lookup(|key| env::var(key).ok())
    }

    fn from_lookup(lookup: impl Fn(&str) -> Option<String>) -> Result<Self, String> {
        let database_url = lookup("DATABASE_URL")
            .filter(|value| !value.trim().is_empty())
            .ok_or("DATABASE_URL is required. Add your Neon connection URL to the local .env; there is no in-memory fallback.")?;
        let expected_database_name = lookup("EXPECTED_DATABASE_NAME")
            .map(|value| value.trim().to_owned())
            .filter(|value| !value.is_empty() && value != "YOUR_DATABASE_NAME")
            .ok_or(
                "EXPECTED_DATABASE_NAME is required and must match the database selected in Neon.",
            )?;
        let firebase_web_api_key = lookup("FIREBASE_WEB_API_KEY")
            .map(|value| value.trim().to_owned())
            .filter(|value| !value.is_empty());
        let hdfc_config = hdfc::HdfcConfig::from_lookup(|key| lookup(key))?;
        database::connection_options(&database_url)?;
        let app_env = lookup("APP_ENV").unwrap_or_else(|| "production".into());
        if !matches!(app_env.as_str(), "development" | "test" | "production") {
            return Err("APP_ENV must be development, test, or production.".into());
        }
        // Render supplies PORT for each web service. Local development retains
        // the loopback default unless BIND_ADDR is explicitly configured.
        let bind_addr: SocketAddr =
            match lookup("BIND_ADDR").filter(|value| !value.trim().is_empty()) {
                Some(value) => value
                    .parse()
                    .map_err(|_| "BIND_ADDR must be an IP address and port.")?,
                None => match lookup("PORT").filter(|value| !value.trim().is_empty()) {
                    Some(value) => {
                        let port: u16 = value
                            .parse()
                            .map_err(|_| "PORT must be a valid TCP port.")?;
                        if port == 0 {
                            return Err("PORT must be a valid TCP port.".into());
                        }
                        SocketAddr::from(([0, 0, 0, 0], port))
                    }
                    None => "127.0.0.1:8080"
                        .parse()
                        .expect("local development bind address is valid"),
                },
            };
        let enabled = match lookup("AUTH_TEST_ENABLED").as_deref().unwrap_or("false") {
            "true" => true,
            "false" => false,
            _ => return Err("AUTH_TEST_ENABLED must be true or false.".into()),
        };
        let test_credentials = if enabled {
            if !matches!(app_env.as_str(), "development" | "test") {
                return Err("Test authentication requires APP_ENV=development or test.".into());
            }
            if !bind_addr.ip().is_loopback() {
                return Err(
                    "Development test authentication must bind to a loopback address.".into(),
                );
            }
            let phone = lookup("AUTH_TEST_PHONE")
                .and_then(|value| normalize_phone(&value))
                .ok_or("AUTH_TEST_PHONE must contain a valid Indian test phone number.")?;
            let otp = lookup("AUTH_TEST_OTP")
                .filter(|value| valid_otp(value))
                .ok_or("AUTH_TEST_OTP must contain exactly six ASCII digits.")?;
            Some(TestCredentials { phone, otp })
        } else {
            None
        };
        let raw_origins = lookup("FRONTEND_ORIGINS")
            .unwrap_or_else(|| "http://localhost:5173,http://127.0.0.1:5173".into());
        let mut origins = Vec::new();
        for origin in raw_origins
            .split(',')
            .map(str::trim)
            .filter(|x| !x.is_empty())
        {
            let uri: Uri = origin
                .parse()
                .map_err(|_| "Invalid FRONTEND_ORIGINS entry.")?;
            let host = uri
                .host()
                .ok_or("Each frontend origin must include a host.")?;
            let local_host = matches!(host, "localhost" | "127.0.0.1" | "[::1]" | "::1");
            let allowed_scheme = if local_host {
                matches!(uri.scheme_str(), Some("http") | Some("https"))
            } else if matches!(app_env.as_str(), "development" | "test") {
                false
            } else {
                uri.scheme_str() == Some("https")
            };
            if !allowed_scheme
                || uri.query().is_some()
                || !matches!(uri.path(), "" | "/")
                || origin.ends_with('/')
                || uri.authority().is_some_and(|a| a.as_str().contains('@'))
            {
                return Err(
                    "FRONTEND_ORIGINS must contain exact origins without paths or wildcards. Development accepts localhost only; production accepts HTTPS origins."
                        .into(),
                );
            }
            origins.push(HeaderValue::from_str(origin).map_err(|_| "Invalid frontend origin.")?);
        }
        if origins.is_empty() {
            return Err("Configure at least one exact FRONTEND_ORIGINS entry.".into());
        }
        Ok(Self {
            bind_addr,
            origins,
            test_credentials,
            database_url,
            expected_database_name,
            firebase_web_api_key,
            hdfc_config,
        })
    }
}

fn normalize_phone(phone: &str) -> Option<String> {
    let input = phone.trim();
    let digits = input.strip_prefix("+91").unwrap_or(input);
    if digits.len() == 10
        && digits.bytes().all(|b| b.is_ascii_digit())
        && matches!(digits.as_bytes()[0], b'6'..=b'9')
    {
        Some(format!("+91{digits}"))
    } else {
        None
    }
}

fn valid_otp(value: &str) -> bool {
    value.len() == 6 && value.bytes().all(|byte| byte.is_ascii_digit())
}

fn opaque_id() -> Result<String, ApiError> {
    let mut bytes = [0_u8; 32];
    getrandom::fill(&mut bytes).map_err(|_| ApiError::unavailable())?;
    Ok(bytes.iter().map(|byte| format!("{byte:02x}")).collect())
}

fn token_hash(token: &str) -> [u8; 32] {
    Sha256::digest(token.as_bytes()).into()
}

#[derive(Clone, Serialize)]
struct User {
    id: String,
    phone: String,
    name: Option<String>,
    email: Option<String>,
}

impl From<Profile> for User {
    fn from(profile: Profile) -> Self {
        Self {
            id: profile.id,
            phone: profile.mobile_no,
            name: profile.name,
            email: profile.email,
        }
    }
}

struct Challenge {
    phone: String,
    expires_at: Instant,
    attempts: u8,
}

#[derive(Default)]
struct Store {
    challenges: HashMap<String, Challenge>,
    last_request: HashMap<String, Instant>,
}

impl Store {
    fn cleanup(&mut self, now: Instant) {
        self.challenges.retain(|_, value| value.expires_at > now);
        self.last_request
            .retain(|_, time| now.duration_since(*time) < RESEND_DELAY);
    }

    fn issue(&mut self, phone: String, now: Instant) -> Result<ChallengeResponse, ApiError> {
        self.cleanup(now);
        if let Some(previous) = self.last_request.get(&phone) {
            let remaining = RESEND_DELAY.saturating_sub(now.duration_since(*previous));
            return Err(ApiError::rate_limited(
                "rate_limited",
                "Please wait before requesting another code.",
                remaining.as_secs() + 1,
            ));
        }
        let challenge_id = opaque_id()?;
        // Resending invalidates the previous challenge, even when its OTP is correct.
        self.challenges.retain(|_, value| value.phone != phone);
        self.last_request.insert(phone.clone(), now);
        self.challenges.insert(
            challenge_id.clone(),
            Challenge {
                phone,
                expires_at: now + CHALLENGE_TTL,
                attempts: 0,
            },
        );
        Ok(ChallengeResponse {
            challenge_id,
            expires_in: CHALLENGE_TTL.as_secs(),
            retry_after: RESEND_DELAY.as_secs(),
            delivery: "development_test",
        })
    }

    fn verify(
        &mut self,
        input: VerifyRequest,
        credentials: &TestCredentials,
        now: Instant,
    ) -> Result<String, ApiError> {
        let challenge = self
            .challenges
            .get_mut(&input.challenge_id)
            .ok_or_else(ApiError::invalid_otp)?;
        if challenge.expires_at <= now {
            self.challenges.remove(&input.challenge_id);
            return Err(ApiError::new(
                StatusCode::UNAUTHORIZED,
                "challenge_expired",
                "This code has expired. Request a new code.",
            ));
        }
        if challenge.attempts >= MAX_ATTEMPTS {
            return Err(ApiError::rate_limited(
                "attempt_limit",
                "Too many attempts. Request a new code after the resend timer.",
                RESEND_DELAY.as_secs(),
            ));
        }
        challenge.attempts += 1;
        if !valid_otp(&input.otp)
            || !bool::from(input.otp.as_bytes().ct_eq(credentials.otp.as_bytes()))
            || challenge.phone != credentials.phone
        {
            return if challenge.attempts >= MAX_ATTEMPTS {
                Err(ApiError::rate_limited(
                    "attempt_limit",
                    "Too many attempts. Request a new code after the resend timer.",
                    RESEND_DELAY.as_secs(),
                ))
            } else {
                Err(ApiError::invalid_otp())
            };
        }
        let phone = challenge.phone.clone();
        // Consume before yielding to the database so concurrent requests cannot replay it.
        self.challenges.remove(&input.challenge_id);
        self.cleanup(now);
        Ok(phone)
    }
}

#[derive(Clone)]
struct AppState {
    config: Config,
    store: Arc<Mutex<Store>>,
    pool: PgPool,
    // Reuse one connection pool for Firebase instead of creating a new client
    // and TLS connection pool for every sign-in request.
    firebase_http: reqwest::Client,
    hdfc: hdfc::HdfcClient,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct RequestOtp {
    phone: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct VerifyRequest {
    challenge_id: String,
    otp: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct FirebaseTokenRequest {
    id_token: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct FaceEnrollmentRequest {
    device_id: String,
    liveness_method: String,
}

#[derive(Serialize)]
struct FaceEnrollmentResponse {
    enrolled: bool,
}

#[derive(Deserialize)]
struct FirebaseLookup {
    users: Vec<FirebaseUser>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct FirebaseUser {
    phone_number: Option<String>,
}

#[derive(Serialize)]
struct ChallengeResponse {
    challenge_id: String,
    expires_in: u64,
    retry_after: u64,
    delivery: &'static str,
}

#[derive(Serialize)]
struct TokenResponse {
    access_token: String,
    token_type: &'static str,
    expires_in: Option<u64>,
    user: User,
}

#[derive(Serialize)]
struct UserResponse {
    user: User,
}

#[derive(Serialize)]
struct ProfileResponse {
    profile: Profile,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct ProfilePatch {
    name: String,
    email: Option<String>,
}

impl ProfilePatch {
    fn validate(self) -> Result<Self, ApiError> {
        let name = self.name.trim().to_owned();
        if !(2..=80).contains(&name.chars().count()) || name.chars().any(char::is_control) {
            return Err(ApiError::new(
                StatusCode::BAD_REQUEST,
                "invalid_name",
                "Enter a name between 2 and 80 characters.",
            ));
        }
        let email = self
            .email
            .map(|value| value.trim().to_owned())
            .filter(|value| !value.is_empty());
        if let Some(value) = &email {
            let options = email_address::Options {
                minimum_sub_domains: 2,
                ..Default::default()
            };
            if value.len() > 254
                || value.chars().any(char::is_control)
                || value.contains('<')
                || value.contains('>')
                || email_address::EmailAddress::parse_with_options(value, options).is_err()
            {
                return Err(ApiError::new(
                    StatusCode::BAD_REQUEST,
                    "invalid_email",
                    "Enter a valid email address or leave it blank.",
                ));
            }
        }
        Ok(Self { name, email })
    }
}

#[derive(Debug)]
struct ApiError {
    status: StatusCode,
    code: &'static str,
    message: &'static str,
    retry_after: Option<u64>,
}

impl ApiError {
    fn new(status: StatusCode, code: &'static str, message: &'static str) -> Self {
        Self {
            status,
            code,
            message,
            retry_after: None,
        }
    }
    fn unavailable() -> Self {
        Self::new(StatusCode::SERVICE_UNAVAILABLE, "auth_unavailable", "SMS sign-in is not configured. Only an explicitly enabled development test number can sign in.")
    }
    fn firebase_unavailable() -> Self {
        Self::new(
            StatusCode::SERVICE_UNAVAILABLE,
            "firebase_unavailable",
            "Phone sign-in is being set up. Please try again shortly.",
        )
    }
    fn firebase_invalid() -> Self {
        Self::new(
            StatusCode::UNAUTHORIZED,
            "firebase_verification_failed",
            "We could not verify this phone sign-in. Please request a new code.",
        )
    }
    fn unauthorized() -> Self {
        Self::new(
            StatusCode::UNAUTHORIZED,
            "unauthorized",
            "Your session is no longer valid. Please sign in again.",
        )
    }
    fn database_unavailable(_: sqlx::Error) -> Self {
        Self::new(
            StatusCode::SERVICE_UNAVAILABLE,
            "database_unavailable",
            "The profile service is temporarily unavailable. Please try again.",
        )
    }
    fn invalid_otp() -> Self {
        Self::new(
            StatusCode::UNAUTHORIZED,
            "invalid_otp",
            "The code or challenge is invalid. Please try again.",
        )
    }
    fn invalid_request(_: JsonRejection) -> Self {
        Self::new(
            StatusCode::BAD_REQUEST,
            "invalid_request",
            "Provide the required fields in a JSON request body.",
        )
    }
    fn hdfc_not_ready() -> Self {
        Self::new(
            StatusCode::SERVICE_UNAVAILABLE,
            "hdfc_sandbox_setup_required",
            "HDFC sandbox verification is being configured. Please try again later.",
        )
    }
    fn rate_limited(code: &'static str, message: &'static str, retry_after: u64) -> Self {
        Self {
            status: StatusCode::TOO_MANY_REQUESTS,
            code,
            message,
            retry_after: Some(retry_after),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let mut error = serde_json::json!({ "code": self.code, "message": self.message });
        if let Some(retry_after) = self.retry_after {
            error["retry_after"] = retry_after.into();
        }
        let mut response =
            (self.status, Json(serde_json::json!({ "error": error }))).into_response();
        if let Some(value) = self
            .retry_after
            .and_then(|n| HeaderValue::from_str(&n.to_string()).ok())
        {
            response.headers_mut().insert(header::RETRY_AFTER, value);
        }
        response
    }
}

/// Startup requires the configured database and validates its identity before DDL.
pub async fn initialize(config: Config) -> Result<Router, String> {
    let pool = database::connect_and_migrate(&config).await?;
    Ok(router(config, pool))
}

fn router(config: Config, pool: PgPool) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(config.origins.clone())
        .allow_methods([Method::GET, Method::POST, Method::PATCH, Method::DELETE])
        .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION])
        .max_age(Duration::from_secs(600));
    let hdfc = hdfc::HdfcClient::new(config.hdfc_config.clone());
    let state = AppState {
        config,
        store: Arc::new(Mutex::new(Store::default())),
        pool,
        firebase_http: reqwest::Client::new(),
        hdfc,
    };
    Router::new()
        .route("/health", get(health))
        .route("/auth/request-otp", post(request_otp))
        .route("/auth/verify-otp", post(verify_otp))
        .route("/auth/firebase", post(verify_firebase))
        .route("/auth/me", get(me))
        .route("/auth/logout", post(logout))
        .route("/profile", get(get_profile).patch(patch_profile))
        .route(
            "/face-enrollment",
            get(get_face_enrollment).post(register_face_enrollment),
        )
        .route("/api/bank/hdfc/otp/generate", post(hdfc_schema_required))
        .route("/api/bank/hdfc/otp/validate", post(hdfc_schema_required))
        .route("/api/bank/hdfc/accounts", post(hdfc_schema_required))
        .route("/api/bank/hdfc/accounts/link", post(hdfc_schema_required))
        .route("/api/bank/accounts", get(list_linked_bank_accounts))
        .route(
            "/api/bank/accounts/{id}",
            delete(unlink_linked_bank_account),
        )
        .fallback(|| async {
            ApiError::new(
                StatusCode::NOT_FOUND,
                "not_found",
                "This endpoint does not exist.",
            )
        })
        .method_not_allowed_fallback(|| async {
            ApiError::new(
                StatusCode::METHOD_NOT_ALLOWED,
                "method_not_allowed",
                "This HTTP method is not supported.",
            )
        })
        .layer(DefaultBodyLimit::max(1024))
        .layer(cors)
        .layer(SetResponseHeaderLayer::overriding(
            header::CACHE_CONTROL,
            HeaderValue::from_static("no-store"),
        ))
        .with_state(state)
}

async fn health(State(state): State<AppState>) -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "ok",
        "authentication": if state.config.test_credentials.is_some() { "development_test" } else { "production" }
    }))
}

async fn request_otp(
    State(state): State<AppState>,
    input: Result<Json<RequestOtp>, JsonRejection>,
) -> Result<Json<ChallengeResponse>, ApiError> {
    let Json(input) = input.map_err(ApiError::invalid_request)?;
    let phone = normalize_phone(&input.phone).ok_or_else(|| {
        ApiError::new(
            StatusCode::BAD_REQUEST,
            "invalid_phone",
            "Enter a valid 10-digit Indian mobile number.",
        )
    })?;
    let credentials = state
        .config
        .test_credentials
        .as_ref()
        .ok_or_else(ApiError::unavailable)?;
    if phone != credentials.phone {
        return Err(ApiError::unavailable());
    }
    // Never send, log, or return the development OTP.
    state
        .store
        .lock()
        .map_err(|_| ApiError::unavailable())?
        .issue(phone, Instant::now())
        .map(Json)
}

async fn verify_otp(
    State(state): State<AppState>,
    input: Result<Json<VerifyRequest>, JsonRejection>,
) -> Result<Json<TokenResponse>, ApiError> {
    let Json(input) = input.map_err(ApiError::invalid_request)?;
    let credentials = state
        .config
        .test_credentials
        .as_ref()
        .ok_or_else(ApiError::unavailable)?;
    let phone = state
        .store
        .lock()
        .map_err(|_| ApiError::unavailable())?
        .verify(input, credentials, Instant::now())?;
    let access_token = opaque_id()?;
    let profile = database::sign_in(&state.pool, &phone, &access_token).await?;
    Ok(Json(TokenResponse {
        access_token,
        token_type: "Bearer",
        expires_in: None,
        user: profile.into(),
    }))
}

async fn verify_firebase(
    State(state): State<AppState>,
    input: Result<Json<FirebaseTokenRequest>, JsonRejection>,
) -> Result<Json<TokenResponse>, ApiError> {
    let Json(input) = input.map_err(ApiError::invalid_request)?;
    if input.id_token.len() > 16_384 || input.id_token.trim().is_empty() {
        return Err(ApiError::firebase_invalid());
    }
    let api_key = state
        .config
        .firebase_web_api_key
        .as_deref()
        .ok_or_else(ApiError::firebase_unavailable)?;
    // Firebase validates the ID token over HTTPS and returns only the account
    // associated with that token for this Firebase project's API key.
    let response = state
        .firebase_http
        .post("https://identitytoolkit.googleapis.com/v1/accounts:lookup")
        .query(&[("key", api_key)])
        .json(&serde_json::json!({ "idToken": input.id_token }))
        .send()
        .await
        .map_err(|_| ApiError::firebase_unavailable())?;
    if !response.status().is_success() {
        return Err(ApiError::firebase_invalid());
    }
    let lookup: FirebaseLookup = response
        .json()
        .await
        .map_err(|_| ApiError::firebase_unavailable())?;
    let phone = lookup
        .users
        .into_iter()
        .next()
        .and_then(|user| user.phone_number)
        .and_then(|phone| normalize_phone(&phone))
        .ok_or_else(ApiError::firebase_invalid)?;
    let access_token = opaque_id()?;
    let profile = database::sign_in(&state.pool, &phone, &access_token).await?;
    Ok(Json(TokenResponse {
        access_token,
        token_type: "Bearer",
        expires_in: None,
        user: profile.into(),
    }))
}

fn bearer_token(headers: &HeaderMap) -> Result<&str, ApiError> {
    let token = headers
        .get(header::AUTHORIZATION)
        .and_then(|header| header.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .filter(|token| token.len() == 64 && token.bytes().all(|byte| byte.is_ascii_hexdigit()))
        .ok_or_else(ApiError::unauthorized)?;
    Ok(token)
}

async fn me(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<UserResponse>, ApiError> {
    let token = bearer_token(&headers)?;
    let profile = database::authenticated_profile(&state.pool, token).await?;
    Ok(Json(UserResponse {
        user: profile.into(),
    }))
}

async fn logout(State(state): State<AppState>, headers: HeaderMap) -> Result<StatusCode, ApiError> {
    let token = bearer_token(&headers)?;
    // Idempotent logout does not reveal whether a well-formed token existed.
    database::logout(&state.pool, token).await?;
    Ok(StatusCode::NO_CONTENT)
}

async fn get_profile(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ProfileResponse>, ApiError> {
    let profile = database::authenticated_profile(&state.pool, bearer_token(&headers)?).await?;
    Ok(Json(ProfileResponse { profile }))
}

async fn patch_profile(
    State(state): State<AppState>,
    headers: HeaderMap,
    input: Result<Json<ProfilePatch>, JsonRejection>,
) -> Result<Json<ProfileResponse>, ApiError> {
    let token = bearer_token(&headers)?;
    let Json(patch) = input.map_err(ApiError::invalid_request)?;
    let patch = patch.validate()?;
    let profile = database::update_profile(&state.pool, token, patch).await?;
    Ok(Json(ProfileResponse { profile }))
}

async fn get_face_enrollment(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<FaceEnrollmentResponse>, ApiError> {
    let enrolled = database::face_enrolled(&state.pool, bearer_token(&headers)?).await?;
    Ok(Json(FaceEnrollmentResponse { enrolled }))
}

async fn register_face_enrollment(
    State(state): State<AppState>,
    headers: HeaderMap,
    input: Result<Json<FaceEnrollmentRequest>, JsonRejection>,
) -> Result<Json<FaceEnrollmentResponse>, ApiError> {
    let token = bearer_token(&headers)?;
    let Json(input) = input.map_err(ApiError::invalid_request)?;
    if input.liveness_method != "two_blink_v1"
        || input.device_id.len() != 64
        || !input.device_id.bytes().all(|byte| byte.is_ascii_hexdigit())
    {
        return Err(ApiError::new(
            StatusCode::BAD_REQUEST,
            "invalid_face_enrollment",
            "Face setup could not be verified. Complete the blink check again.",
        ));
    }
    let device_id_hash = Sha256::digest(input.device_id.as_bytes());
    database::register_face_enrollment(
        &state.pool,
        token,
        device_id_hash.as_slice(),
        &input.liveness_method,
    )
    .await?;
    Ok(Json(FaceEnrollmentResponse { enrolled: true }))
}

/// These FacePay routes are intentionally installed now so Flutter only ever
/// talks to FacePay. They do not accept or send a provider body until HDFC's
/// exact OAuth/OTP/CASA schemas are available in the project.
async fn hdfc_schema_required(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    database::authenticated_profile(&state.pool, bearer_token(&headers)?).await?;
    // Keep the same response whether HDFC credentials are absent or present.
    // This avoids exposing integration configuration to a signed-in user.
    let _configured = state.hdfc.sandbox_configured();
    Err(ApiError::hdfc_not_ready())
}

#[derive(Serialize)]
struct LinkedBankAccountsResponse {
    accounts: Vec<database::LinkedBankAccount>,
}

async fn list_linked_bank_accounts(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<LinkedBankAccountsResponse>, ApiError> {
    let accounts = database::linked_bank_accounts(&state.pool, bearer_token(&headers)?).await?;
    Ok(Json(LinkedBankAccountsResponse { accounts }))
}

async fn unlink_linked_bank_account(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<StatusCode, ApiError> {
    if id.len() != 64 || !id.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(ApiError::new(
            StatusCode::NOT_FOUND,
            "bank_account_not_found",
            "This bank account is no longer available.",
        ));
    }
    let removed =
        database::unlink_linked_bank_account(&state.pool, bearer_token(&headers)?, &id).await?;
    if !removed {
        return Err(ApiError::new(
            StatusCode::NOT_FOUND,
            "bank_account_not_found",
            "This bank account is no longer available.",
        ));
    }
    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests;
