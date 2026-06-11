# Open Banking Security Hunt Checklist
## PSD2 / NextGenPSD2 / UK OB / STET
## Version: 1.0 — 2026-03-08

---

## Regulatory Framework Reference

### PSD2 (Directive 2015/2366)
- **Article 97**: SCA required for: (a) online account access, (b) electronic payment, (c) any remote action with risk of fraud
- **Article 98**: Delegated to RTS for SCA and secure communication

### RTS for SCA (Commission Delegated Regulation 2018/389)
- **Article 4**: Authentication code — must be linked to amount + payee for payments
- **Article 5**: Dynamic linking — the auth code SHALL be specific to (a) amount, (b) payee. If either changes, auth code is invalidated
- **Article 6**: Independence of elements — compromise of one factor must not compromise another
- **Article 7**: Multi-purpose devices — if device is used for both possession and display, risk mitigation required
- **Article 9**: Transaction monitoring — real-time fraud analysis on every payment
- **Article 10**: Exemptions — contactless ≤€50, trusted beneficiaries, recurring with same amount, low-value (<€30 cumulative <€150), secure corporate, TRA
- **Article 22**: Dedicated interface — ASPSP must offer an interface for TPPs (AIS/PIS)
- **Article 30**: Contingency mechanism — if dedicated API fails, fallback to modified customer direct access
- **Article 33**: eIDAS certificates — QWAC for secure communication, QSeal for data integrity
- **Article 34**: Transaction and data integrity

### EBA Guidelines
- **EBA/GL/2018/07**: Conditions for SCA exemptions
- **EBA/Op/2020/10**: Obstacles to account access under PSD2
- **EBA Opinion 2023/02**: Issues around SCA implementation

---

## §OB-0: Reconnaissance & Sandbox Setup

### OB-0.1: Developer Portal Enumeration
```
# Common developer portal patterns
https://developer.{bank}.{tld}
https://sandbox.{bank}.{tld}
https://api.{bank}.{tld}
https://openbanking.{bank}.{tld}
https://psd2.{bank}.{tld}
https://tpp.{bank}.{tld}
https://xs2a.{bank}.{tld}  # Berlin Group standard name
```

### OB-0.2: API Standard Detection
- **Berlin Group NextGenPSD2**: `/v1/consents`, `/v1/accounts`, `/v1/payments/sepa-credit-transfers`
- **UK Open Banking**: `/open-banking/v3.1/`, `/account-access-consents`, `/domestic-payments`
- **STET**: `/stet/psd2/v1.4/`, `/payment-requests`, `/accounts`
- **Polish API**: `/v2_1.1/`, `/accounts/v2_1.1/`
- **Custom/hybrid**: Check OpenAPI/Swagger spec

### OB-0.3: Sandbox Registration
```bash
# Register for sandbox access (most are free, instant)
# Get test certificates (sandbox eIDAS QWAC/QSeal)
# Get sandbox OAuth2 client credentials
# Get test PSU (Payment Service User) credentials
# Document the sandbox base URL and auth flow
```

### OB-0.4: Certificate Handling
```bash
# Most sandboxes provide test certificates or accept self-signed
# Production requires eIDAS QWAC from a QTSP
# Check if sandbox validates certificates AT ALL

# Test with no certificate
curl -s https://sandbox.api.{bank}/v1/accounts

# Test with self-signed certificate
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 1 -nodes -subj '/CN=test'
curl -s --cert cert.pem --key key.pem https://sandbox.api.{bank}/v1/accounts

# Test with expired certificate
# Test with certificate for different organization
```

---

## §OB-1: Authentication & Authorization

### OB-1.1: OAuth2 Flow Analysis
```
grep -i "grant_type\|response_type\|authorization_code\|client_credentials\|implicit"
```

**Check:**
- [ ] Authorization Code flow with PKCE?
- [ ] Implicit flow disabled? (MUST be for PSD2)
- [ ] Client credentials flow scope restrictions?
- [ ] Refresh token rotation?
- [ ] Token lifetime (access token should be ≤15 min for payments)
- [ ] Token binding to PSU session?

### OB-1.2: Consent Management
```bash
# Create consent
POST /v1/consents
{
  "access": {
    "accounts": [{"iban": "DE89370400440532013000"}],
    "balances": [{"iban": "DE89370400440532013000"}],
    "transactions": [{"iban": "DE89370400440532013000"}]
  },
  "recurringIndicator": true,
  "validUntil": "2027-12-31",
  "frequencyPerDay": 4,
  "combinedServiceIndicator": false
}
```

**Attack vectors:**
- [ ] Can consent scope be escalated after creation? (request `accounts` → modify to include `balances`)
- [ ] Can consent `validUntil` exceed 180 days? (PSD2 max for AIS recurring consent = 180 days)
- [ ] Can `frequencyPerDay` exceed 4? (Berlin Group default limit)
- [ ] Can consent for account A be used to access account B? (IDOR)
- [ ] Can TPP A's consent token be used by TPP B? (token confusion)
- [ ] Is consent revocation immediate? Or is there a cache window?
- [ ] Can a revoked consent's access token still work?
- [ ] Does consent reference specific IBANs or is it wildcard "allAccounts"?

### OB-1.3: Scope Escalation
```bash
# Request AIS-only consent, then try PIS operations
# Request read-only, then try write operations
# Request single account, then try listing all accounts

# Berlin Group: scopes in consent
# UK OB: permissions in account-access-consent
# STET: roles (AISP, PISP, CBPII)
```

### OB-1.4: Certificate Validation (Article 33 RTS)
```bash
# QWAC validation checks:
# 1. Is the certificate a valid eIDAS QWAC?
# 2. Is the organizationIdentifier (OID 2.5.4.97) checked?
# 3. Does the ASPSP verify the TPP's NCA registration?
# 4. Does the ASPSP check the PSD2 roles in the certificate?
#    - PSP_AI (Account Information)
#    - PSP_PI (Payment Initiation)
#    - PSP_IC (Card-Based Payment Instrument Issuing)
#    - PSP_AS (Account Servicing)

# Attack: Use AISP certificate to initiate payment (PIS)
# Attack: Use revoked/expired certificate
# Attack: Use certificate from different TPP
# Attack: Omit certificate entirely on production-like endpoint
```

---

## §OB-2: Account Information Service (AIS)

### OB-2.1: IDOR on Account Access
```bash
# Get accounts for PSU-1, then try accessing PSU-2's accounts
GET /v1/accounts/{account-id-of-other-user}
GET /v1/accounts/{account-id}/balances
GET /v1/accounts/{account-id}/transactions

# Try sequential IDs, UUIDs with modified bytes, etc.
# Note: Berlin Group uses resourceId, UK OB uses AccountId
```

### OB-2.2: Transaction Data Leakage
```bash
# Check date range limits
GET /v1/accounts/{id}/transactions?dateFrom=2020-01-01&dateTo=2026-12-31

# Check if pagination leaks data
GET /v1/accounts/{id}/transactions?_page=0&_size=10000

# Check if transaction details include sensitive counterparty info
# (name, IBAN, address of counterparty)
```

### OB-2.3: Balance Enumeration
```bash
# Check all balance types
GET /v1/accounts/{id}/balances
# Types: closingBooked, expected, authorised, openingBooked, interimAvailable
# Some banks expose internal balance types not meant for TPPs
```

### OB-2.4: Account List Beyond Consent
```bash
# If consent grants access to 1 account, can you list all accounts?
GET /v1/accounts
# Should only return consented accounts, not full list
```

---

## §OB-3: SCA Bypass (CRITICAL — Article 97 PSD2 / Articles 4-6 RTS)

### OB-3.1: Missing SCA on Payment Initiation
```bash
# Initiate payment and check if SCA is actually required
POST /v1/payments/sepa-credit-transfers
{
  "debtorAccount": {"iban": "DE89370400440532013000"},
  "instructedAmount": {"currency": "EUR", "amount": "100.00"},
  "creditorAccount": {"iban": "DE75512108001245126199"},
  "creditorName": "Merchant",
  "remittanceInformationUnstructured": "Test payment"
}

# Response should include scaRedirect or scaOAuth URL
# If payment is created with status "ACSP" or "ACSC" without SCA → CRITICAL
```

### OB-3.2: SCA Exemption Abuse (Article 10 RTS)
```bash
# Test low-value exemption boundary
# Threshold: <€30 per tx, cumulative <€150 or 5 consecutive
POST /v1/payments/sepa-credit-transfers
{"instructedAmount": {"amount": "29.99"}}  # Should work without SCA
{"instructedAmount": {"amount": "30.00"}}  # Should trigger SCA

# Does the bank enforce cumulative limit?
# Send 5x €29.99 = €149.95 — does the 6th trigger SCA?
# Send amounts that cumulatively exceed €150

# Test trusted beneficiary exemption
# Can you mark any beneficiary as trusted without SCA?

# Test TRA (Transaction Risk Analysis) exemption
# Does the bank apply it correctly based on fraud rates?

# Test recurring payment exemption
# Create recurring consent, then change amount — still exempt?
```

### OB-3.3: SCA Downgrade
```bash
# Start SCA flow, then:
# 1. Skip the redirect step
# 2. Call payment status directly — is it already authorized?
# 3. Use an old/cached authorization code
# 4. Replay a previous SCA response

# Embedded SCA: check if challenge response is validated
POST /v1/payments/{paymentId}/authorisations/{authorisationId}
{"scaAuthenticationData": "000000"}  # Try null/empty/fixed OTP
```

### OB-3.4: SCA Element Independence (Article 6 RTS)
```bash
# Two-factor auth requires: knowledge + possession OR knowledge + inherence
# Check if both factors go through the same channel
# E.g., OTP sent via SMS to same phone used for banking app = violation

# Check if:
# - OTP is sent in-band (same API response) vs out-of-band (SMS/push)
# - Biometric challenge can be replayed
# - App-based SCA can be bypassed by API-only flow
```

### OB-3.5: SCA on Account Access (Article 97(1)(a) RTS)
```bash
# Initial consent creation MUST require SCA
# Check if accessing accounts AFTER consent requires SCA again:
# - First access: SCA required (correct)
# - 90-day re-authentication: Is it enforced?
# - Balance check: Does it trigger SCA? (some exemptions apply)

# AIS 90-day rule:
# PSU must re-authenticate every 90 days for recurring AIS consent
# Check if consent still works after 90 days without re-SCA
```

---

## §OB-4: Dynamic Linking Failure (CRITICAL — Article 5 RTS)

### OB-4.1: Amount Modification After SCA
```bash
# 1. Initiate payment for €10 → complete SCA
# 2. Before confirmation, modify amount to €1000
# 3. Does the payment go through with €1000?

# Test via:
# - Modifying the payment resource between SCA and execution
PUT /v1/payments/{paymentId}
{"instructedAmount": {"amount": "1000.00"}}

# - Race condition: modify while SCA is in progress
# - Replay SCA response from €10 payment on €1000 payment
```

### OB-4.2: Payee Modification After SCA
```bash
# 1. Initiate payment to Merchant-A → complete SCA
# 2. Before confirmation, modify creditor to Attacker-IBAN
# 3. Does the payment go through to Attacker-IBAN?

# The auth code MUST be invalidated if payee changes
# Article 5(2)(b): "the payee of the transaction"
```

### OB-4.3: Dynamic Linking Display Verification
```bash
# When PSU sees the SCA challenge, does it show:
# 1. The exact amount being authorized?
# 2. The exact payee being authorized?
# 3. Are these displayed on a trusted device (not the same channel)?

# If the bank uses redirect SCA:
# Check if the redirect page shows amount/payee clearly
# Check if the redirect page can be modified (XSS in SCA page)
# Check if the redirect URL contains amount/payee as parameters that can be tampered
```

### OB-4.4: Batch Payment Dynamic Linking
```bash
# For batch/bulk payments:
# Does SCA show total amount AND each individual payment?
# Can individual payments be modified after SCA of the batch?

POST /v1/bulk-payments/sepa-credit-transfers
# Authorize batch, then check if individual payments can be altered
```

---

## §OB-5: Payment Initiation Service (PIS) Attacks

### OB-5.1: Payment Status Manipulation
```bash
# Check if payment status can be queried by anyone
GET /v1/payments/{paymentId}/status

# Can you enumerate paymentIds?
# Can you cancel another TPP's payment?
DELETE /v1/payments/{paymentId}
```

### OB-5.2: Currency Confusion
```bash
# Initiate payment with mismatched currencies
POST /v1/payments/sepa-credit-transfers
{
  "instructedAmount": {"currency": "GBP", "amount": "100.00"},  # GBP in SEPA
  "debtorAccount": {"iban": "DE89370400440532013000"}  # EUR account
}

# Does the bank auto-convert? At what rate? Is the PSU informed?
```

### OB-5.3: Negative/Zero Amount
```bash
POST /v1/payments/sepa-credit-transfers
{"instructedAmount": {"amount": "0.00"}}
{"instructedAmount": {"amount": "-100.00"}}
{"instructedAmount": {"amount": "0.01"}}  # Minimum
{"instructedAmount": {"amount": "999999999.99"}}  # Maximum
{"instructedAmount": {"amount": "100.001"}}  # Extra decimal
```

### OB-5.4: IBAN Validation Bypass
```bash
# Invalid IBAN (bad checksum)
{"creditorAccount": {"iban": "DE00000000000000000000"}}

# IBAN with special characters
{"creditorAccount": {"iban": "DE89 3704 0044 0532 0130 00"}}  # spaces
{"creditorAccount": {"iban": "de89370400440532013000"}}  # lowercase

# Non-SEPA IBAN in SEPA payment
{"creditorAccount": {"iban": "US12345678901234567890"}}
```

### OB-5.5: Duplicate Payment Detection
```bash
# Submit same payment twice rapidly — does it create duplicates?
# Some banks use idempotency keys (X-Request-ID header)
# Check if X-Request-ID is actually enforced
```

---

## §OB-6: API Security Fundamentals

### OB-6.1: Rate Limiting
```bash
# Berlin Group mandates max 4 AIS requests/day without PSU involvement
# Check if this is enforced
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" \
    "https://sandbox.api.{bank}/v1/accounts/$ACCOUNT_ID/balances"
done

# Check if rate limit is per-consent, per-TPP, or per-IP
```

### OB-6.2: Error Message Information Disclosure
```bash
# Invalid account ID
GET /v1/accounts/INVALID_ID
# Does the error reveal internal system names, stack traces, DB info?

# Invalid payment
POST /v1/payments/sepa-credit-transfers
{"debtorAccount": {"iban": "INVALID"}}
# Does the error reveal validation logic, internal IBAN format, etc.?
```

### OB-6.3: Header Injection
```bash
# X-Request-ID manipulation
# PSU-IP-Address header spoofing (Berlin Group requires this)
# PSU-ID header injection (some banks trust this for user identification!)
curl -H "PSU-ID: admin" -H "PSU-IP-Address: 127.0.0.1" \
  "https://sandbox.api.{bank}/v1/accounts"
```

### OB-6.4: API Versioning Exploitation
```bash
# Try old API versions that might have fewer checks
GET /v1/accounts/  # Current
GET /v0/accounts/  # Legacy?
GET /v2/accounts/  # Pre-release?

# Check if deprecated endpoints still work
```

---

## §OB-7: Confirmation of Funds (CBPII)

### OB-7.1: Amount Information Leakage
```bash
# CBPII should only return yes/no for "does this account have ≥ €X?"
# Check if the response leaks the actual balance
POST /v1/funds-confirmations
{
  "cardNumber": "1234567890123456",
  "account": {"iban": "DE89370400440532013000"},
  "instructedAmount": {"currency": "EUR", "amount": "100.00"}
}

# Binary search to determine exact balance:
# €1000 → yes → €5000 → no → €2500 → yes → ...
# If rate limiting is weak (§OB-6.1), balance can be determined precisely
```

---

## §OB-8: Sandbox-to-Production Crossover

### OB-8.1: Shared Infrastructure
```bash
# Check if sandbox and production share:
# - Same certificates
# - Same OAuth2 endpoints
# - Same database (sandbox data = real data?)
# - Same API gateway (different path prefix only)

# Test if sandbox tokens work on production
curl -H "Authorization: Bearer $SANDBOX_TOKEN" https://api.{bank}/v1/accounts

# Test if sandbox credentials work on production OAuth
curl -X POST https://api.{bank}/oauth/token -d "client_id=$SANDBOX_CLIENT_ID&..."
```

### OB-8.2: Test Data That Looks Real
```bash
# Check sandbox data for:
# - Real IBANs (validate against IBAN registry)
# - Real names (cross-reference)
# - Realistic transaction patterns
# - Internal system identifiers
```

---

## §OB-9: Redirect Flow Attacks

### OB-9.1: SCA Redirect Manipulation
```bash
# After PSU completes SCA, bank redirects to TPP's redirect_uri
# Check if redirect_uri is validated (should be pre-registered)

# Open redirect in SCA callback
# State parameter tampering
# Code injection in callback URL
# CSRF on callback endpoint
```

### OB-9.2: State Parameter Validation
```bash
# Initiate consent → get redirected to bank for SCA
# After SCA, bank redirects back with ?code=xxx&state=yyy
# Check if state is validated (CSRF protection)
# Check if code can be used multiple times (replay)
# Check if code is bound to the consent (code from consent-A used for consent-B)
```

---

## §OB-10: Berlin Group Specific

### OB-10.1: SCA Approaches
```
Berlin Group supports 3 SCA approaches:
1. REDIRECT: PSU redirected to ASPSP for SCA
2. DECOUPLED: SCA via separate app/device (push notification)
3. EMBEDDED: TPP collects PSU credentials and forwards to ASPSP

EMBEDDED is the most dangerous — if TPP collects password + OTP:
- Check if ASPSP validates that TPP is authorized for embedded SCA
- Check if OTP can be replayed
- Check if session is bound to TPP
```

### OB-10.2: Signing Basket
```bash
# Berlin Group allows "signing baskets" — batch authorization
POST /v1/signing-baskets
{
  "paymentIds": ["payment-1", "payment-2", "payment-3"]
}

# Can you add payments to a basket after SCA?
# Can you include another user's payment in your basket?
```

---

## Submission Strategy

### Regulatory Framing (Non-Dismissable)

When a finding demonstrates a PSD2/RTS violation, frame the report as:

```
## Regulatory Impact

This finding demonstrates a violation of:
- **Article X of Commission Delegated Regulation (EU) 2018/389** (RTS for SCA)
- **Article Y of Directive (EU) 2015/2366** (PSD2)

Under Article 100 of PSD2, the competent National Competent Authority (NCA)
[BaFin/ACPR/DNB/FCA/etc.] has the power to impose administrative penalties
for non-compliance with SCA requirements.

The bank's obligation under Article 97(1) PSD2 is to apply SCA when the
payer [initiates an electronic payment / accesses its account online].
This implementation fails to meet this obligation because [specific reason].
```

### NCA Reference Table

| Country | NCA | Relevant Law |
|---|---|---|
| Germany | BaFin | ZAG (Zahlungsdiensteaufsichtsgesetz) |
| France | ACPR | Code monétaire et financier L.133-44 |
| Netherlands | DNB | Wet op het financieel toezicht |
| Belgium | NBB | Loi relative aux services de paiement |
| Spain | BdE | Ley de servicios de pago |
| Italy | BdI | D.Lgs. 11/2010 |
| Ireland | CBI | S.I. No. 6/2018 |
| UK | FCA | PSRs 2017 (post-Brexit) |
| Sweden | FI | Lag om betaltjänster |
| Poland | KNF | Ustawa o uslugach platniczych |
| Austria | FMA | ZaDiG 2018 |
| Luxembourg | CSSF | Loi du 10 novembre 2009 |
| Finland | Fiva | Maksulaitoslaki |
| Portugal | BdP | RJSPME |

### Payout Expectations

| Finding Class | Severity | Expected Payout |
|---|---|---|
| SCA bypass on payments | CRITICAL | $5K-$25K |
| Dynamic linking failure | CRITICAL | $5K-$20K |
| SCA exemption abuse | HIGH | $2K-$10K |
| Consent scope escalation | HIGH | $2K-$8K |
| IDOR on accounts | HIGH | $2K-$10K |
| Certificate validation bypass | MEDIUM-HIGH | $1K-$5K |
| Information disclosure | LOW-MEDIUM | $500-$2K |
| Sandbox config issues | LOW | $100-$500 |

---

## Quick Start Workflow

```
1. Select target bank with public sandbox + bounty program
2. Register for sandbox (5 min)
3. Get test certs + OAuth credentials (5 min)
4. Run §OB-0 reconnaissance (15 min)
5. Run §OB-3 SCA bypass tests (30 min) ← HIGHEST ROI
6. Run §OB-4 dynamic linking tests (30 min) ← SECOND HIGHEST ROI
7. Run §OB-1 auth/consent tests (30 min)
8. Run §OB-2 AIS IDOR tests (15 min)
9. Run §OB-5 PIS edge cases (15 min)
10. Kill Gate → Pre-flight → Submit
```

**Total per target: 2-3 hours**
**Expected hit rate: 1 in 3 banks has at least one submittable finding**
