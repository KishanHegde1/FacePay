# ICICI UPI integration preparation

## Status

FacePay has offline Rust contracts for ListAccountProvider and ListAccounts.
They are not connected to application routes or Flutter. No ICICI network
request, bank OTP, verified account link, balance inquiry or payment is enabled.
The existing demo bank selection remains explicitly demo. No new package,
Render variable or database migration is required for this preparation.

Source reviewed: the owner's UPI20.pdf, supplied on 18 September 2026.
The four additional numbered PDFs have identical SHA-256 hashes. The PDFs,
rendered review pages and bank credentials are not included in Git.

## Implemented contracts

`Backend/rust/src/icici.rs` provides:

- UAT-only discovery endpoint names and JSON request field mapping from the
  supplied PDF, with basic input-format checks.
- Provider list parsing using returned IDs rather than hard-coded bank IDs.
- Acceptance of MobileAppData as either stringified JSON (the documented
  wire representation) or an object (the rendered sample representation).
- Bank-success checks requiring success=true AND response=0. Pending and
  rejected results do not become successful account discovery.
- Account discovery parsing and a separate display object exposing a masked
  account number, holder name and IFSC. Raw account references and credential
  metadata have no Debug/Serialize implementation and stay backend-side.
- A bounded response parser and offline synthetic contract tests. These fixtures
  are unit-test inputs, not customer records or demo transactions shown in UI.

Discovery is NOT ownership verification or successful linking. Raw accRefNumber
may contain an account-number-like value; do not treat it as an opaque safe
reference or insert it into linked_bank_accounts without the bank-approved
storage contract. No changes to Neon are made by this module.

## Documented flow and dependencies

| Stage | PDF pages | Required integration work |
| --- | --- | --- |
| Device registration | 6-7, 10, 24-25 | NPCI Common Library challenge, GetToken, app registration and secure token lifecycle |
| Bank list and account discovery | 20-23, 46-50 | Authenticated discovery, bank-issued channel code and correct device/sequence values |
| Account linking | 10-11, 43-62 | VPA availability, FORMAT1 OTP or FORMAT2 credentials, ListKeys, Common Library credential capture, RegisterMobileNumber or StoreAccountDetails |
| Balance | 149-154 | Verified bank profile/VPA/account and approved encrypted credential flow |
| Device binding | 203-205 | Bank-approved SMS verification data and device binding lifecycle |
| Payment/status/history | 84 onward, 146-148, 213-217 | Approved payer authorization, durable state, status reconciliation and authenticated history |

Firebase login OTP is separate from issuing-bank account-link OTP. Two blinks
and FacePay's app-installation identifier do not replace bank/NPCI device
binding, SIM verification, Common Library credentials or payment authorization.
Face scanning can later resolve a consented recipient; real payer authorization
must follow the bank-approved flow.

## Obtain from ICICI before enabling traffic

1. A FacePay developer application and its own API key/access to the specific
   UPI APIs. Portal example values are not FacePay integration credentials.
2. Confirmation that the selected program supports FacePay's customer account
   linking and person-to-person payment use case, plus required UAT approval.
3. The current UPI gateway onboarding/authentication document: exact headers,
   encryption envelope, algorithms, certificate/key provisioning, any mTLS,
   signing, OAuth and IP allow-list requirements. Do not reuse HDFC assumptions.
4. Bank-issued channel code, transaction prefix, app/PSP identity and approved
   sandbox/UAT test data. Confirm whether the PDF's UAT URLs are still current
   and whether portal test access permits those endpoints.
5. NPCI Common Library/approved bank SDK, its integration manual and supported
   SDK versions; device/SIM verification and token rotation/reset procedures.
6. Error/timeout/rate-limit and OTP resend policies, consent rules, permitted
   account-reference storage, callback authentication and transaction queries.

ICICI's public developer portal describes application-specific API keys and a
Sandbox -> UAT -> Production journey. UAT and production require bank business
approvals, NDA and other agreements at ICICI's discretion:
https://developer.icicibank.com/

## Contract questions for the bank

The PDF contains inconsistencies that must be resolved against the issued
current API contract before adding the transport or credential-bearing calls:

- The screenshots use MobileNumber, deviceid and channelcode; the PDF discovery
  bodies use mobile, device-id and channel-code. Confirm the gateway variant.
- The sequence table says 35 characters; dummy examples show 32. Page 7 asks for
  a bank-issued three-character prefix. The preparation only checks an ASCII
  alphanumeric maximum of 35, and does not generate or alter sequence values.
- GenerateOTP's table uses account-number; its example uses accountnumber.
- RegisterMobileNumber's table specifies six card digits while its sample has
  four, and table/sample required fields differ.
- Credential sections contain ambiguous on-us plaintext wording and 'To be
  discussed' notes. Do not implement a plaintext PIN/OTP exception from those
  samples or build a custom PIN form/encryption replacement.
- DeviceBinding requires verification-data but its sample omits it.
- MobileAppData is described as a string, though some samples show an object.

## Next implementation after access is issued

Implement the confirmed gateway transport in Rust only; store credentials in
Render secret settings. Obtain mobile identity from the FacePay session, not a
client-selected customer number. Add device-bound, short-lived consent and
verification state with rate limits and duplicate protection. Preserve the same
transaction ID through Common Library capture and the bank request. Do not
blindly retry OTP, linking or payment requests after uncertain timeouts.

Only bank-confirmed verification may create a user-scoped linked account.
Expose masked display fields through the Rust API, then wire Flutter's bank
provider interface to the new flow. Keep sandbox payments labeled and use
approved test accounts; real balances and money movement stay disabled until
approved and tested. Complete failure, ownership, replay and contract checks
before deploying the integration.

## Local verification

From `D:\Face Payment\Backend\rust`:

```powershell
cargo fmt --check
cargo test --offline
cargo build --release --offline
```

These checks do not load local .env, contact ICICI or mutate Neon. A release
build is a compile check, not evidence of live bank access.
