//! HDFC sandbox boundary.
//!
//! This module deliberately does not construct OAuth, OTP, or CASA requests
//! yet. The current project has endpoint names but not HDFC's required JSON
//! fields, grant type, headers, or response contracts. Sending guessed fields
//! to a financial provider would be unsafe. Add those exact schemas here only
//! from the HDFC sandbox documentation supplied for this FacePay application.

use url::Url;

const SANDBOX_HOST: &str = "api-tryitout-uat.hdfcbank.com";

#[derive(Clone)]
pub(crate) enum HdfcConfig {
    Disabled,
    Sandbox(HdfcSandboxCredentials),
}

/// Never derive Debug or Serialize for this type: it contains a client secret.
#[derive(Clone)]
pub(crate) struct HdfcSandboxCredentials {
    #[allow(dead_code)]
    base_url: Url,
    #[allow(dead_code)]
    client_id: String,
    #[allow(dead_code)]
    client_secret: String,
}

impl HdfcConfig {
    pub(crate) fn from_lookup(lookup: impl Fn(&str) -> Option<String>) -> Result<Self, String> {
        match lookup("HDFC_ENV").as_deref().unwrap_or("disabled") {
            "disabled" => Ok(Self::Disabled),
            "sandbox" => {
                let raw_url = required(&lookup, "HDFC_BASE_URL")?;
                let base_url =
                    Url::parse(&raw_url).map_err(|_| "HDFC_BASE_URL must be a valid HTTPS URL.")?;
                if base_url.scheme() != "https"
                    || base_url.host_str() != Some(SANDBOX_HOST)
                    || base_url.query().is_some()
                    || base_url.fragment().is_some()
                    || !base_url.username().is_empty()
                    || base_url.password().is_some()
                    || !matches!(base_url.path(), "" | "/")
                {
                    return Err(
                        "HDFC_BASE_URL must be the exact HDFC sandbox origin over HTTPS; production endpoints are not enabled."
                            .into(),
                    );
                }
                Ok(Self::Sandbox(HdfcSandboxCredentials {
                    base_url,
                    client_id: required(&lookup, "HDFC_CLIENT_ID")?,
                    client_secret: required(&lookup, "HDFC_CLIENT_SECRET")?,
                }))
            }
            _ => Err("HDFC_ENV must be disabled or sandbox.".into()),
        }
    }
}

fn required(lookup: &impl Fn(&str) -> Option<String>, key: &str) -> Result<String, String> {
    lookup(key)
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty())
        .ok_or_else(|| format!("{key} is required when HDFC_ENV=sandbox."))
}

/// Holds provider configuration only. OAuth-token caching and temporary OTP
/// references will be added after HDFC supplies their response contract.
#[derive(Clone)]
pub(crate) struct HdfcClient {
    _http: reqwest::Client,
    config: HdfcConfig,
}

impl HdfcClient {
    pub(crate) fn new(config: HdfcConfig) -> Self {
        Self {
            _http: reqwest::Client::new(),
            config,
        }
    }

    pub(crate) fn sandbox_configured(&self) -> bool {
        match &self.config {
            HdfcConfig::Disabled => false,
            HdfcConfig::Sandbox(credentials) => {
                // Reading the validated origin here also ensures the
                // credentials stay encapsulated in this backend-only module.
                let _validated_origin = &credentials.base_url;
                true
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sandbox_requires_only_the_documented_environment_values() {
        let disabled = HdfcConfig::from_lookup(|_| None).unwrap();
        assert!(matches!(disabled, HdfcConfig::Disabled));
        assert!(HdfcConfig::from_lookup(|key| match key {
            "HDFC_ENV" => Some("sandbox".into()),
            "HDFC_BASE_URL" => Some("https://api-tryitout-uat.hdfcbank.com".into()),
            "HDFC_CLIENT_ID" => Some("sandbox-client".into()),
            "HDFC_CLIENT_SECRET" => Some("sandbox-secret".into()),
            _ => None,
        })
        .is_ok());
    }

    #[test]
    fn rejects_non_sandbox_urls_and_incomplete_settings() {
        assert!(HdfcConfig::from_lookup(|key| match key {
            "HDFC_ENV" => Some("sandbox".into()),
            "HDFC_BASE_URL" => Some("https://bank.example.test".into()),
            "HDFC_CLIENT_ID" | "HDFC_CLIENT_SECRET" => Some("value".into()),
            _ => None,
        })
        .is_err());
        assert!(HdfcConfig::from_lookup(|key| match key {
            "HDFC_ENV" => Some("sandbox".into()),
            _ => None,
        })
        .is_err());
    }
}
