# HDFC sandbox account verification

## Current status

FacePay has a **disabled-by-default HDFC sandbox boundary**. It does not yet
call HDFC, generate an HDFC OTP, validate an HDFC OTP, fetch CASA details, or
write a linked account. The exact request and response schemas needed for
those actions were not supplied, and FacePay must not guess them.

Flutter communicates only with the FacePay Rust backend. No HDFC base URL,
client ID, client secret, token, or bank request is present in the Flutter
application.

The known HDFC sandbox base URL is validated server-side when configuration is
enabled:

`https://api-tryitout-uat.hdfcbank.com`

## Backend configuration

Keep `HDFC_ENV=disabled` in normal development and deployment until the
required documentation is available. The Rust service accepts `HDFC_ENV` only
as `disabled` or `sandbox`.

To prepare a sandbox deployment after HDFC provides credentials, store these
values as Render secret environment variables, never in Git or Flutter:

```text
HDFC_ENV=sandbox
HDFC_BASE_URL=https://api-tryitout-uat.hdfcbank.com
HDFC_CLIENT_ID=...
HDFC_CLIENT_SECRET=...
```

Configuration alone does not enable provider traffic. The protected HDFC
routes return a safe `503 hdfc_sandbox_setup_required` response until the
documented request contracts are implemented.

## Required HDFC documents before implementation

Please obtain these from HDFC's sandbox portal or integration contact:

1. OAuth token request contract: method body format, `grant_type`, required
   headers, credential placement, token response fields, expiry and errors.
2. OTP generation request contract: required body fields, headers, consent or
   customer fields, correlation/reference field, resend policy, TTL and errors.
3. OTP validation request contract: required OTP and reference fields, success
   condition, returned temporary authorisation/reference values, expiry and
   errors.
4. CASA request contract: required authorisation, headers and request body,
   plus exact response fields for the account reference, account number,
   account type, holder name and provider customer reference.
5. Any signing, mTLS certificate, partner ID, IP allow-list, consent, device
   binding, test credentials, rate limits, and permitted sandbox test data.

Do not send client secrets, private keys, OTPs, or real account data in chat.

## Data handling and account ownership

`facepay.linked_bank_accounts` stores only a provider-issued opaque account
reference and a masked account number after a successful server-side
verification. It does not store an OTP, full account number, access token, or
raw HDFC response. Each list and unlink operation is scoped by the FacePay
session in the SQL query; one user cannot read or remove another user's link.

The backend response intentionally excludes the provider reference. Flutter
only receives safe display fields such as the masked account number.

## Planned implementation after HDFC supplies the contracts

1. Implement the OAuth, OTP generation, OTP validation and CASA adapters in
   Rust only, using the exact HDFC schemas.
2. Add per-profile rate limits and short-lived server-side verification state.
3. Verify the response, mask the account number on the server, and save the
   provider-issued reference in a transaction.
4. Connect the existing Bank Link screen to that verified flow and label it as
   HDFC Sandbox while running in UAT.
5. Add contract tests that use only HDFC-approved sandbox fixtures.
