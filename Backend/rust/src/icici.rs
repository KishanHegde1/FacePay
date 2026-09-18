//! Offline ICICI UPI 2 contracts, based on UPI20.pdf pages 5-9, 20-23 and 46-50.
//! No transport, credentials, bank verification or payment authorization is enabled.
//! Confirm the gateway contract with ICICI before connecting these types to routes.
use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const UAT_BASE_URL: &str = "https://apibankingonesandbox.icicibank.com/api/v1/upi2/";

#[derive(Clone, Copy)]
pub enum DiscoveryOperation {
    ListAccountProvider,
    ListAccounts,
}

impl DiscoveryOperation {
    pub fn uat_url(self) -> String {
        format!(
            "{UAT_BASE_URL}{}",
            match self {
                Self::ListAccountProvider => "ListAccountProvider",
                Self::ListAccounts => "ListAccounts",
            }
        )
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum ContractError {
    InvalidRequest,
    InvalidResponse,
    ProviderRejected,
}

/// Values must come from the authenticated user's bank-approved device flow.
/// No Debug implementation: mobile/device identifiers must not enter logs.
#[derive(Serialize)]
pub struct DiscoveryRequest {
    mobile: String,
    #[serde(rename = "device-id")]
    device_id: String,
    #[serde(rename = "seq-no")]
    sequence: String,
    #[serde(rename = "channel-code")]
    channel_code: String,
    #[serde(rename = "account-provider", skip_serializing_if = "Option::is_none")]
    account_provider: Option<String>,
}

impl DiscoveryRequest {
    /// Basic format checks only. The table specifies a 35-character sequence,
    /// but examples contain 32. Require the bank-confirmed sequence policy in
    /// the future transport; do not generate/replace NPCI transaction IDs here.
    pub fn new(
        mobile: &str,
        device_id: &str,
        sequence: &str,
        channel_code: &str,
        account_provider: Option<&str>,
    ) -> Result<Self, ContractError> {
        if mobile.len() != 10
            || !mobile.bytes().all(|b| b.is_ascii_digit())
            || !alphanumeric(device_id, 255)
            || !alphanumeric(sequence, 35)
            || channel_code.is_empty()
            || channel_code.len() > 15
            || !channel_code.bytes().all(|b| b.is_ascii_alphabetic())
            || account_provider.is_some_and(|id| {
                id.is_empty() || id.len() > 20 || !id.bytes().all(|b| b.is_ascii_digit())
            })
        {
            return Err(ContractError::InvalidRequest);
        }
        Ok(Self {
            mobile: mobile.into(),
            device_id: device_id.into(),
            sequence: sequence.into(),
            channel_code: channel_code.into(),
            account_provider: account_provider.map(str::to_owned),
        })
    }
}

fn alphanumeric(value: &str, max: usize) -> bool {
    !value.is_empty() && value.len() <= max && value.bytes().all(|b| b.is_ascii_alphanumeric())
}

#[derive(Deserialize)]
struct Envelope {
    success: bool,
    response: i64,
    #[serde(rename = "MobileAppData")]
    data: Value,
}

fn successful_data(body: &[u8]) -> Result<Value, ContractError> {
    // Local parsing limits; transport must also limit the streamed response.
    if body.len() > 256 * 1024 {
        return Err(ContractError::InvalidResponse);
    }
    let envelope: Envelope =
        serde_json::from_slice(body).map_err(|_| ContractError::InvalidResponse)?;
    if !envelope.success || envelope.response != 0 {
        return Err(ContractError::ProviderRejected);
    }
    // Page 9 states stringified JSON; rendered examples show a JSON object.
    match envelope.data {
        Value::String(text) => {
            serde_json::from_str(&text).map_err(|_| ContractError::InvalidResponse)
        }
        object @ Value::Object(_) => Ok(object),
        _ => Err(ContractError::InvalidResponse),
    }
}

#[derive(Deserialize, Serialize)]
pub struct AccountProvider {
    pub id: String,
    #[serde(rename = "reg-mob-format")]
    pub registration_format: String,
    #[serde(rename = "account-provider")]
    pub name: String,
}

/// Never hard-code provider IDs: use the values returned by this operation.
pub fn parse_account_providers(body: &[u8]) -> Result<Vec<AccountProvider>, ContractError> {
    let data = successful_data(body)?;
    let providers: Vec<AccountProvider> = serde_json::from_value(
        data.pointer("/details/providers")
            .cloned()
            .ok_or(ContractError::InvalidResponse)?,
    )
    .map_err(|_| ContractError::InvalidResponse)?;
    if providers.iter().any(|p| {
        p.id.is_empty()
            || p.id.len() > 20
            || !p.id.bytes().all(|b| b.is_ascii_digit())
            || p.name.trim().is_empty()
            || p.name.len() > 255
            || !matches!(p.registration_format.as_str(), "FORMAT1" | "FORMAT2")
    }) {
        return Err(ContractError::InvalidResponse);
    }
    Ok(providers)
}

/// Raw account data stays on the backend. In particular accRefNumber may be
/// account-number-like, so it is NOT assumed to be a safe opaque DB reference.
/// Discovery does not prove consent, ownership or successful account linking.
#[derive(Deserialize)]
pub struct DiscoveredAccount {
    account: String,
    #[serde(rename = "accRefNumber")]
    account_reference: String,
    ifsc: String,
    name: String,
    #[serde(rename = "CredsAllowed")]
    credentials_allowed: Value,
}

#[derive(Serialize)]
pub struct AccountDisplay {
    pub masked_account_number: String,
    pub account_holder_name: String,
    pub ifsc: String,
}

impl DiscoveredAccount {
    pub fn display(&self) -> AccountDisplay {
        let suffix: String = self
            .account
            .chars()
            .rev()
            .take(4)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect();
        AccountDisplay {
            masked_account_number: format!("•••• {suffix}"),
            account_holder_name: self.name.clone(),
            ifsc: self.ifsc.clone(),
        }
    }

    /// Sensitive provider value; only for a future bank-approved verification flow.
    pub fn account_reference(&self) -> &str {
        &self.account_reference
    }
    pub fn credentials_allowed(&self) -> &Value {
        &self.credentials_allowed
    }
}

pub fn parse_accounts(body: &[u8]) -> Result<Vec<DiscoveredAccount>, ContractError> {
    let data = successful_data(body)?;
    let accounts: Vec<DiscoveredAccount> = serde_json::from_value(
        data.pointer("/details/accounts")
            .cloned()
            .ok_or(ContractError::InvalidResponse)?,
    )
    .map_err(|_| ContractError::InvalidResponse)?;
    if accounts.iter().any(|a| {
        a.account.len() < 4
            || a.account.len() > 255
            || !a
                .account
                .bytes()
                .all(|b| b.is_ascii_digit() || matches!(b, b'X' | b'x' | b'*'))
            || !a.account.as_bytes()[a.account.len() - 4..]
                .iter()
                .all(u8::is_ascii_digit)
            || a.account_reference.is_empty()
            || a.account_reference.len() > 255
            || a.ifsc.len() != 11
            || !a.ifsc.bytes().all(|b| b.is_ascii_alphanumeric())
            || a.name.trim().is_empty()
            || a.name.len() > 255
            || !a.credentials_allowed.is_object()
    }) {
        return Err(ContractError::InvalidResponse);
    }
    Ok(accounts)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    fn envelope(data: Value, stringified: bool) -> Vec<u8> {
        serde_json::to_vec(&json!({"success":true,"response":0,"MobileAppData":
            if stringified { Value::String(data.to_string()) } else { data }}))
        .unwrap()
    }
    #[test]
    fn discovery_uses_pdf_field_names_and_only_uat_urls() {
        let request = DiscoveryRequest::new(
            "9876543210",
            "testdevice1",
            "TST0123456789abcdef0123456789abcdef",
            "FacePay",
            Some("42"),
        )
        .unwrap();
        let json = serde_json::to_value(request).unwrap();
        assert_eq!(json["account-provider"], "42");
        assert_eq!(json["device-id"], "testdevice1");
        assert!(json.get("MobileNumber").is_none());
        assert_eq!(
            DiscoveryOperation::ListAccounts.uat_url(),
            format!("{UAT_BASE_URL}ListAccounts")
        );
        let request =
            DiscoveryRequest::new("9876543210", "testdevice1", "testsequence", "FacePay", None)
                .unwrap();
        assert!(serde_json::to_value(request)
            .unwrap()
            .get("account-provider")
            .is_none());
        assert!(DiscoveryRequest::new("+919876543210", "device", "seq", "FacePay", None).is_err());
        assert!(
            DiscoveryRequest::new("9876543210", "device", "seq", "FacePay", Some("ICICI")).is_err()
        );
    }
    #[test]
    fn providers_support_object_and_stringified_json_without_static_ids() {
        let data = json!({"details":{"providers":[{"id":"42","reg-mob-format":"FORMAT1","account-provider":"Test Bank"}]}});
        for stringified in [false, true] {
            let result = parse_account_providers(&envelope(data.clone(), stringified)).unwrap();
            assert_eq!(result[0].id, "42");
        }
        assert!(parse_account_providers(&envelope(json!({"details":{"providers":[{"id":"42","reg-mob-format":"UNKNOWN","account-provider":"Test"}]}}), false)).is_err());
    }
    #[test]
    fn success_flag_alone_never_means_bank_success() {
        for (success, response) in [(true, 91), (true, 12), (false, 0)] {
            let body = serde_json::to_vec(&json!({"success":success,"response":response,"MobileAppData":{"details":{"providers":[]}}})).unwrap();
            assert!(matches!(
                parse_account_providers(&body),
                Err(ContractError::ProviderRejected)
            ));
        }
        assert!(parse_account_providers(b"{}").is_err());
        assert!(parse_account_providers(&vec![b' '; 256 * 1024 + 1]).is_err());
    }
    #[test]
    fn account_display_excludes_reference_credentials_and_full_number() {
        for stringified in [false, true] {
            let body = envelope(
                json!({"details":{"accounts":[{"account":"123456789012","accRefNumber":"sensitiveReference","ifsc":"TEST0000001","name":"Test User","CredsAllowed":{"Child":[]}}]}}),
                stringified,
            );
            let accounts = parse_accounts(&body).unwrap();
            let display = serde_json::to_string(&accounts[0].display()).unwrap();
            assert!(display.contains("9012"));
            for sensitive in ["123456789012", "sensitiveReference", "CredsAllowed"] {
                assert!(!display.contains(sensitive));
            }
        }
        assert!(parse_accounts(&envelope(json!({"details":{"accounts":[{"account":"invalid","accRefNumber":"ref","ifsc":"TEST0000001","name":"Test","CredsAllowed":{}}]}}), false)).is_err());
        assert!(parse_accounts(&envelope(json!({"details":{}}), false)).is_err());
    }
}
