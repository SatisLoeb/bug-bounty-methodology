# Financial Systems & Banking API — Hunt Methodology

Systematic methodology for vulnerability research on financial APIs, banking systems, and payment infrastructure. Three operational tracks: fintech bounty hunting, Open Banking/PSD2 compliance testing, and shared infrastructure zero-day research.

Prerequisites: Existing pipeline operational (CRITICAL-HUNT, DEFI-FULLSTACK, JWT-ARSENAL, PIPELINE-EXPANSION, ZERO-DAY-HUNTING-SPEC Domains 1-12).

Legal framework: All testing within authorized bug bounty programs, sandbox environments, or against open-source libraries. No unauthorized testing against live banking systems.

## Strategic Context

The financial sector pays 3-10x more per finding than DeFi/crypto bounty programs for equivalent severity. A critical auth bypass on a DeFi protocol pays $10K-$50K on Immunefi. The same class of bug on a fintech pays $15K-$100K+ on HackerOne/Bugcrowd. The attack surface is larger (APIs, mobile apps, payment flows, compliance logic), the competition is lower (most top bounty hunters focus on web/cloud, not finance-specific logic), and the regulatory pressure (PSD2, PCI-DSS, SOX) means companies CAN'T dismiss valid findings.

Your existing tooling translates directly:

- JWT Arsenal → SCA token validation, OAuth2 flows, session management
- DEFI-FULLSTACK checklist → fintech API surface analysis (same patterns: unauth endpoints, IDOR, key management)
- ZERO-DAY-HUNTING parsers (D1/D9) → ISO 20022 XML parsing, SWIFT message parsing, payment message format bugs
- Cross-chain messaging (§3.5) → inter-bank messaging, payment initiation flows

---

## Track 1: Fintech & Neobank Bounty Programs

### 1.1 Target Map — Active Programs

| Target | Platform | Scope | Reward Range | Priority |
|--------|----------|-------|-------------|----------|
| Revolut | Intigriti (VDP) | Web, API, mobile | VDP (no guaranteed payout) | P2 |
| N26 | HackerOne | Web, API, mobile | $100-$10K+ | P1 |
| Monzo | Intigriti | Web, API, mobile | Rewards available | P1 |
| Wise (TransferWise) | Bugcrowd | Web, API, mobile | $100-$15K | P1 |
| Cash App (Block) | HackerOne | Web, API, mobile | $100-$15K | P1 |
| Mercury | HackerOne | Web, API, mobile | $500-$10K | P1 |
| Brex | HackerOne | Web, API, mobile | $500-$10K | P1 |
| Ramp | HackerOne | Web, API | $500-$10K | P1 |
| Stripe | HackerOne | API, dashboard, libs | $500-$25K+ | P1 |
| Plaid | HackerOne | API, Link, SDKs | $250-$10K | P1 |
| Adyen | HackerOne | API, dashboard, plugins | Varies | P1 |
| Square (Block) | HackerOne | Web, API, mobile | $250-$15K | P1 |
| Coinbase | HackerOne | Web, API, mobile | $200-$50K+ | P1 |
| PayPal | HackerOne | Web, API, mobile | $100-$30K | P1 |
| Robinhood | HackerOne | Web, API, mobile | $250-$15K | P1 |
| Chime | HackerOne | Web, API, mobile | Varies | P2 |
| SoFi | HackerOne | Web, API, mobile | Varies | P2 |
| KOHO | HackerOne | Web, API, mobile | Varies | P2 |
| Modern Treasury | HackerOne | API | Varies | P2 |
| Fireblocks | Bugcrowd | MPC, API | $500-$50K+ | P1 |

### 1.2 Fintech-Specific Hunt Checklist

#### §FIN-1: Payment Flow Logic Bugs

```
# === These bugs don't exist in DeFi — they're unique to traditional finance ===

# 1. Race condition in balance checks
# Pattern: check balance → approve → debit
# Attack: send two concurrent transactions that both pass the balance check
# Result: double-spend (overdraft)

# 2. Currency conversion rounding
# Pattern: convert $100.005 → rounds to $100.01 or $100.00?
# Attack: thousands of micro-transactions exploiting rounding direction
# Result: accumulate rounding errors

# 3. Negative amount handling
# Pattern: transfer(-$100) → does the API reject, or does it credit the sender?
# Variants: -0, -0.001, -MAX_INT, NaN, Infinity, "100", 100.999999999999

# 4. Fee bypass
# Pattern: transaction below fee threshold, or fee calculated on wrong amount
# Attack: split large transfer into N small transfers below fee threshold
# Result: avoid transaction fees

# 5. Scheduled payment manipulation
# Pattern: schedule payment → modify amount/recipient before execution
# Attack: TOCTOU between schedule and execution

# 6. Partial settlement exploitation
# Pattern: payment partially settles (debited but not credited)
# Attack: trigger error after debit, before credit → funds in limbo
# Result: potential double-credit on retry
```

- [ ] Race condition on concurrent transfers tested (same account, two simultaneous debits)
- [ ] Negative/zero/boundary amounts tested on ALL payment endpoints
- [ ] Currency rounding — direction consistent? Exploitable via micro-transactions?
- [ ] Fee calculation — can fees be avoided by splitting transactions?
- [ ] Scheduled payment TOCTOU — can params change between schedule and execution?
- [ ] Partial settlement — what happens on error mid-transaction? Retry behavior?

#### §FIN-2: Account & Identity Verification Bypass

```
# === KYC/AML verification logic is often bypassable ===

# 1. KYC state machine manipulation
# States: UNVERIFIED → PENDING → VERIFIED → RESTRICTED
# Attack: can you reach VERIFIED without completing verification?
# Check: access funds/features before KYC completion

# 2. Identity document bypass
# Pattern: upload document → OCR/human review → approve
# Attack: modified document that passes automated checks but not human review
# Or: skip document upload, directly set status via API

# 3. Phone/email verification bypass
# Pattern: request OTP → enter OTP → verified
# Attack: OTP bruteforce (no rate limit), OTP reuse, expired OTP accepted

# 4. Address verification bypass
# Pattern: enter address → receive mail → confirm code
# Attack: any address accepted, or confirmation not required for transactions

# 5. Multi-account creation
# Pattern: one identity → one account (regulatory requirement)
# Attack: create multiple accounts with slight identity variations
# Impact: money laundering, bonus abuse, referral fraud
```

- [ ] KYC state transitions — can UNVERIFIED users access restricted features?
- [ ] Document upload — is the endpoint auth'd? Can status be set directly via API?
- [ ] OTP validation — rate limited? Reusable? Expired OTPs accepted?
- [ ] Multi-account — can same identity create multiple accounts?
- [ ] **OIDC identity binding** — if "Sign in with Google/Microsoft/Apple" exists, decode the id_token JWT: does the app use `sub` (stable, unique per provider = SAFE) or `email` (recyclable = ATO via email recycling)? If email → account takeover when email is reassigned (employee leaves, email recycled to new person). 2-min check. High-priority on healthcare/fintech/enterprise targets. Ref: OpenID Connect Core §5.7, RFC 7519 §4.1.2

#### §FIN-3: Card & Virtual Card Exploitation

```
# === Virtual card issuance and management ===

# 1. Card number prediction
# Pattern: sequential BIN + sequential card numbers
# Check: are virtual card numbers predictable?

# 2. CVV/CVC bypass
# Pattern: some merchants don't require CVV
# Attack: use leaked card number without CVV

# 3. Card limit bypass
# Pattern: daily/monthly spending limits
# Attack: multiple concurrent transactions before limit check propagates

# 4. Frozen card bypass
# Pattern: card frozen → transactions should fail
# Attack: pre-authorized recurring charges, or subscription charges on frozen card

# 5. Virtual card creation abuse
# Pattern: create unlimited virtual cards
# Attack: create cards, use for free trials, dispute charges
```

- [ ] Card number entropy — are virtual card numbers predictable?
- [ ] Card limits — concurrent transactions bypass daily limits?
- [ ] Frozen card — recurring/pre-authorized charges still go through?
- [ ] Virtual card creation — rate limited? Unlimited creation possible?

#### §FIN-4: Notification & Confirmation Manipulation

```
# === Silent transaction execution ===

# 1. Push notification suppression
# Pattern: transaction triggers push notification to account holder
# Attack: can attacker suppress the notification? (API call to disable notifications before tx)

# 2. Email confirmation bypass
# Pattern: large transaction requires email confirmation
# Attack: modify amount to below threshold, or intercept/suppress confirmation

# 3. Transaction history manipulation
# Pattern: completed transactions visible in history
# Attack: IDOR to view OTHER users' transaction history

# 4. Statement generation injection
# Pattern: PDF/CSV statement generation
# Attack: inject content into statement via transaction description (XSS, formula injection)
```

- [ ] Transaction notifications — can they be suppressed via API?
- [ ] Confirmation thresholds — can they be bypassed by amount manipulation?
- [ ] Transaction history IDOR — can you view other users' transactions?
- [ ] Statement injection — CSV formula injection via transaction descriptions?

### 1.3 Fintech Hunt Workflow

For each fintech target:

```
1. RECON (30 min)
   → Tech stack detection (DEFI-FULLSTACK §F0)
   → Mobile app decompilation (API endpoint discovery)
   → API documentation discovery (public docs, OpenAPI specs)

2. AUTH ANALYSIS (60 min)
   → JWT-ARSENAL checks on auth tokens
   → OAuth2 flow analysis (authorization code, PKCE, token exchange)
   → SCA (Strong Customer Authentication) bypass testing
   → Session management (concurrent sessions, session fixation)

3. API SURFACE (60 min)
   → DEFI-FULLSTACK §F1 (endpoint discovery, auth classification)
   → GraphQL introspection (if applicable)
   → IDOR on all resource endpoints (accounts, transactions, cards, users)
   → Rate limiting on sensitive operations (transfers, card creation, OTP)

4. PAYMENT LOGIC (90 min)
   → §FIN-1 payment flow bugs
   → §FIN-3 card exploitation
   → Race conditions on balance-affecting operations
   → Currency/amount edge cases

5. IDENTITY & KYC (30 min)
   → §FIN-2 verification bypass
   → Multi-account creation
   → Feature access before KYC completion

6. INFRASTRUCTURE (30 min)
   → DEFI-FULLSTACK §F3 (DNS, WAF, debug endpoints)
   → PIPELINE-EXPANSION §F3.4-3.7 (RPC, WebSocket, metadata)
   → Mobile app secrets (hardcoded keys, certificate pinning bypass)

7. Kill Gate → Pre-Flight → Submit
```

**Total: 5-8h per target**

---

## Track 2: Open Banking / PSD2 API Security

### 2.0 Rationale

PSD2 (and the upcoming PSD3/PSR) REQUIRES banks to expose APIs for account information (AISP) and payment initiation (PISP). These APIs handle real money and real customer data. The spec is complex, implementations vary wildly between banks, and compliance is legally mandated (penalties up to €5M or 4% of annual turnover for non-compliance).

The attack surface: every bank in the EU/EEA must have an Open Banking API. Most implemented the minimum viable product. The spec has ambiguities that lead to exploitable inconsistencies between implementations.

### 2.1 Open Banking API Standards

| Standard | Region | Spec | Key Endpoints |
|----------|--------|------|---------------|
| Berlin Group NextGenPSD2 | EU/EEA | nextgenspecs.org | /v1/accounts, /v1/payments, /v1/consents |
| UK Open Banking | UK | openbanking.org.uk | /open-banking/v3.1/aisp/accounts, /pisp/payments |
| STET PSD2 | France | stet.eu | /v1/accounts, /v1/payment-requests |
| Polish API | Poland | polishapi.org | /v2_1.1/accounts, /v2_1.1/payments |
| Slovak Banking API | Slovakia | slovensko.digital | Similar to Berlin Group |
| CBI Globe | Italy | cbiglobe.com | Italian standard, Berlin Group-based |

### 2.2 Open Banking Vulnerability Taxonomy

| Pattern ID | Name | Mechanism | Impact | PSD2 Reference |
|-----------|------|-----------|--------|---------------|
| OB-001 | Consent scope escalation | TPP requests consent for accounts → gets access to all accounts | Unauthorized data access | Art. 67(2)(d) |
| OB-002 | Consent not expiring | Consent should expire after 90 days → doesn't | Persistent unauthorized access | RTS Art. 10(2) |
| OB-003 | SCA downgrade | SCA bypassed or downgraded to single factor | Auth bypass on payments | RTS Art. 4 |
| OB-004 | Dynamic linking failure | Payment amount/payee not cryptographically linked to auth code | Payment modification post-auth | RTS Art. 5 |
| OB-005 | IBAN validation bypass | Payee IBAN not validated → payment to wrong account | Misdirected payments | PSD2 Art. 88 |
| OB-006 | Rate limit bypass on AIS | Account information not rate-limited → full scraping | Mass data exfiltration | RTS Art. 36 |
| OB-007 | Certificate validation bypass | eIDAS/QWAC cert not validated → unauthorized TPP access | Impersonation of regulated TPP | RTS Art. 34 |
| OB-008 | Fallback interface abuse | Screen scraping fallback activated unnecessarily | Auth credential exposure | RTS Art. 33 |
| OB-009 | Payment status manipulation | Payment status can be modified or replayed | Double payment, cancellation | PSD2 Art. 80 |
| OB-010 | Cross-TPP data leakage | Data consented to TPP-A accessible by TPP-B | Privacy violation, data breach | GDPR Art. 5(1)(b) |

### 2.3 Open Banking Hunt Checklist

#### §OB-1: Sandbox Discovery & Access

```bash
# Most banks provide sandbox environments for TPP testing
# These sandboxes often have weaker security than production
# AND sometimes connect to real or near-real data

# Discovery
for bank in "developer.{bank}" "sandbox.{bank}" "api.{bank}" "openbanking.{bank}" "psd2.{bank}" "xs2a.{bank}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://${bank}/" 2>/dev/null)
  [ "$code" != "000" ] && echo "$code https://${bank}/"
done

# Check if sandbox requires registration/cert or is open
curl -s "https://sandbox.api.{bank}/v1/accounts" -H "Accept: application/json" | head -20
```

- [ ] Sandbox URL discovered and accessible
- [ ] Sandbox auth — open access, or requires TPP registration?
- [ ] Sandbox data — test data only, or leaked real data?
- [ ] Sandbox → production boundary — same API structure? Same auth mechanism? Weaker controls?

#### §OB-2: Consent Management Testing

```
# === Consent is the core security mechanism in Open Banking ===

# 1. Create consent with minimal scope
# POST /v1/consents
# Body: {"access": {"accounts": [{"iban": "DE89370400440532013000"}]}}
# Expected: consent for ONE account

# 2. Test scope escalation
# After consent: GET /v1/accounts
# Expected: only consented account returned
# Bug: ALL accounts returned → OB-001

# 3. Test consent expiry
# Create consent → wait 90+ days → try to use
# Expected: rejected
# Bug: still works → OB-002

# 4. Test consent revocation
# DELETE /v1/consents/{consentId}
# Then: GET /v1/accounts with same consent
# Expected: rejected
# Bug: still works → consent revocation not enforced

# 5. Test consent ID enumeration
# Consent IDs: sequential (IDOR) or random?
# GET /v1/consents/{incrementedId}
# Expected: 403 (not your consent)
# Bug: 200 with another TPP's consent data → IDOR

# 6. Test consent for different PSU (Payment Service User)
# Consent created by PSU-A → use token to access PSU-B's accounts
# Expected: rejected
# Bug: cross-user access → critical auth bypass
```

- [ ] Consent scope — strictly limited to consented resources?
- [ ] Consent expiry — enforced after 90 days?
- [ ] Consent revocation — immediately effective?
- [ ] Consent ID — random (secure) or sequential (IDOR)?
- [ ] Cross-PSU access — consent for user A can't access user B?

#### §OB-3: SCA (Strong Customer Authentication) Testing

```
# === SCA is the regulatory requirement for 2FA ===
# Two of: knowledge (password), possession (phone), inherence (biometric)
# Dynamic linking: auth code must be tied to amount + payee

# 1. SCA bypass — single factor accepted
# Initiate payment → only password required (no second factor)
# Expected: second factor always required for payments
# Bug: SCA missing → OB-003

# 2. SCA downgrade via User-Agent
# Change User-Agent to indicate old browser/device
# Some implementations fall back to weaker auth for "compatibility"

# 3. Dynamic linking verification
# Initiate payment for €100 to IBAN-A → get SCA code
# Modify payment to €1000 to IBAN-B → submit same SCA code
# Expected: rejected (code linked to original amount+payee)
# Bug: accepted → OB-004

# 4. SCA exemption abuse
# PSD2 allows SCA exemptions for:
# - Transactions < €30 (up to 5 consecutive or €100 cumulative)
# - Recurring payments (same amount, same payee)
# - Trusted beneficiaries
# Attack: abuse exemptions to avoid SCA on large transactions

# 5. SCA replay
# Capture valid SCA response → replay for different transaction
# Expected: SCA response is one-time-use
# Bug: replayable → auth bypass
```

- [ ] SCA always required for payments above exemption threshold?
- [ ] Dynamic linking — SCA code tied to specific amount + payee?
- [ ] SCA exemption — can exemptions be abused to bypass SCA?
- [ ] SCA replay — one-time use enforced?
- [ ] Trusted beneficiary — can attacker add themselves as trusted?

#### §OB-4: Payment Initiation Security

```
# === PISP (Payment Initiation Service Provider) testing ===

# 1. Payment modification after SCA
# POST /v1/payments → SCA → payment created
# PUT /v1/payments/{paymentId} → modify amount/payee AFTER SCA
# Expected: modification rejected after SCA
# Bug: payment modifiable → OB-004

# 2. Payment status polling abuse
# GET /v1/payments/{paymentId}/status
# Rate limit? Can you enumerate payment IDs?
# Can you modify status (e.g., from PENDING to EXECUTED)?

# 3. Batch payment injection
# If batch payments supported:
# POST /v1/bulk-payments
# Add extra payment in batch that wasn't consented

# 4. Duplicate payment detection
# Submit same payment twice rapidly
# Expected: duplicate detected, second rejected
# Bug: both execute → double payment

# 5. IBAN validation
# Submit payment with malformed IBAN
# Expected: validation error
# Bug: payment accepted with invalid IBAN → misdirected funds
```

- [ ] Payment immutable after SCA — no modification allowed?
- [ ] Payment status — read-only? No IDOR?
- [ ] Batch payments — additional payments can't be injected?
- [ ] Duplicate detection — concurrent identical payments caught?
- [ ] IBAN validation — malformed/invalid IBANs rejected?

#### §OB-5: Certificate & TPP Identity Validation

```
# === eIDAS certificates identify TPPs ===

# 1. Certificate validation
# Connect to API without valid eIDAS/QWAC certificate
# Expected: 401/403
# Bug: API accessible without cert → OB-007

# 2. Certificate role validation
# AISP cert used for PISP endpoint (or vice versa)
# Expected: rejected (wrong role)
# Bug: role not checked → unauthorized payment initiation

# 3. Revoked certificate
# Use a certificate that's been revoked (check CRL/OCSP)
# Expected: rejected
# Bug: revoked cert accepted

# 4. Self-signed certificate
# Present self-signed cert claiming to be a regulated TPP
# Expected: rejected (not issued by trusted CA)
# Bug: accepted → impersonate any TPP

# 5. Certificate subject mismatch
# Cert issued to TPP-A, but claim to be TPP-B in headers
# Expected: mismatch detected
# Bug: header value trusted over cert → impersonation
```

- [ ] Certificate required for all API access?
- [ ] Certificate role validated (AISP vs PISP)?
- [ ] Certificate revocation checked (CRL/OCSP)?
- [ ] Self-signed certificates rejected?
- [ ] Subject identity matches cert identity?

### 2.4 Open Banking Hunt Workflow

For each bank's Open Banking API:

```
1. DISCOVERY (15 min)
   → Find sandbox/developer portal
   → Download API documentation (OpenAPI spec if available)
   → Identify standard: Berlin Group, UK OB, STET, custom

2. REGISTRATION (30 min)
   → Register as TPP in sandbox (if required)
   → Obtain test certificates
   → Get sandbox credentials

3. CONSENT TESTING (60 min)
   → §OB-2 consent management full suite
   → Scope escalation, expiry, revocation, IDOR, cross-PSU

4. SCA TESTING (60 min)
   → §OB-3 full SCA test suite
   → Dynamic linking, exemption abuse, replay

5. PAYMENT TESTING (60 min)
   → §OB-4 payment initiation security
   → Modification, duplication, IBAN validation

6. CERTIFICATE TESTING (30 min)
   → §OB-5 certificate validation
   → Role, revocation, self-signed, mismatch

7. INFRASTRUCTURE (30 min)
   → Standard API recon (DEFI-FULLSTACK §F1, §F3)
   → TLS configuration, cipher suites
   → HTTP security headers

8. REPORTING
   → If bank has bounty program → submit through program
   → If no bounty → responsible disclosure to bank security team
   → If compliance violation → option to report to national regulator (NCA)
   → Include PSD2/RTS article references in every report
```

**Total: 4-6h per bank**

---

## Track 3: Shared Financial Infrastructure — Zero-Day Research

### 3.0 Rationale

This is the multiplication model applied to finance. Instead of finding bugs in one fintech, find bugs in the libraries and protocols that ALL fintechs use. A zero-day in Stripe's SDK affects every Stripe merchant. A bug in an ISO 20022 XML parser affects every bank processing SWIFT payments.

### 3.1 Target Map — Shared Infrastructure

#### Payment Processing SDKs & Libraries

| Library | Language | Usage | Downloads | Priority |
|---------|----------|-------|-----------|----------|
| stripe-node | JS/TS | Stripe SDK | 2.5M/wk | P1 |
| stripe-python | Python | Stripe SDK | 1M/wk | P1 |
| @adyen/api-library-* | JS/Java/Python | Adyen SDK | 200K+/wk | P1 |
| square | JS/Python/Ruby | Square SDK | 100K+/wk | P2 |
| braintree | JS/Python/Ruby | Braintree (PayPal) SDK | 300K+/wk | P2 |
| plaid-node / plaid-python | JS/Python | Plaid SDK | 200K+/wk | P1 |
| marqeta | Python | Card issuance API | Growing | P2 |
| gocardless | JS/Python | Direct debit | 50K+/wk | P3 |

#### Payment Message Parsers & Validators

| Library | Language | Format | Usage | Priority |
|---------|----------|--------|-------|----------|
| ISO 20022 XML parsers | Java/C#/.NET | pacs, camt, pain | Every SWIFT-connected bank | P1 |
| python-iso20022 | Python | ISO 20022 messages | Backend processing | P1 |
| MT→MX converters | Various | SWIFT MT↔ISO 20022 | Coexistence period processing | P1 |
| NACHA ACH file parsers | Various | ACH batch format | US domestic payments | P2 |
| BACS/FPS parsers | Various | UK payment formats | UK domestic payments | P2 |
| schwifty | Python | BIC/IBAN validation | 500K+/wk | P2 |
| iban-tools | JS/Ruby | IBAN validation/generation | 100K+/wk | P2 |
| EMV TLV parsers | Various | Card chip data | POS terminals, ATMs | P2 |

#### Authentication & Identity Libraries

| Library | Language | Usage | Priority |
|---------|----------|-------|----------|
| openid-client | JS | OpenID Connect client (used in Open Banking OAuth) | P1 |
| python-jose / PyJWT | Python | JWT in financial APIs | P1 (covered by JWT-ARSENAL) |
| passport-openidconnect | JS | Express OIDC auth | P1 |
| spring-security-oauth2 | Java | Enterprise banking auth | P1 |
| FIDO2/WebAuthn libs | Various | SCA implementations | P1 (covered by D9 cbor-x work) |
| node-forge | JS | PKI/X.509 for eIDAS cert handling | P1 |
| pyOpenSSL / cryptography | Python | Certificate handling in TPP registration | P2 |

#### Core Banking Platforms (Open Source Components)

| Platform | Type | Language | Usage | Priority |
|----------|------|----------|-------|----------|
| Mojaloop | Open-source payment hub | JS/TS | Financial inclusion (Gates Foundation) | P2 |
| Apache Fineract | Core banking system | Java | Microfinance, community banks | P2 |
| Mifos X | Banking platform (on Fineract) | Java | 200+ institutions | P2 |
| Cyclos | Payment platform | Java | Community currencies, mobile banking | P3 |
| Tazama | Transaction monitoring | TS | AML/fraud detection | P2 |

### 3.2 ISO 20022 XML Parser Fuzzing

The entire global banking system is migrating to ISO 20022 XML messaging. Every bank needs XML parsers that handle these messages. XML parsing is historically one of the most vulnerability-rich attack surfaces (XXE, billion laughs, schema confusion).

#### 3.2.1 Attack Surface

```
ISO 20022 message flow:

Sender Bank → [XML Generator] → [SWIFT Network / MI] → [XML Parser] → Receiver Bank
                                                              ↑
                                                    This parser handles
                                                    untrusted XML from
                                                    the network
```

Message types (most common):
- pacs.008: FI to FI Customer Credit Transfer (the main payment message)
- pacs.009: FI Credit Transfer (interbank)
- camt.053: Bank-to-Customer Statement
- camt.054: Bank-to-Customer Debit/Credit Notification
- pain.001: Customer Credit Transfer Initiation

#### 3.2.2 Vulnerability Patterns

| Pattern | Mechanism | Impact | Detection |
|---------|-----------|--------|-----------|
| XXE injection | XML external entity in ISO 20022 message → SSRF/file read | Data exfiltration from bank servers | Inject XXE in RemittanceInformation, etc. |
| Billion laughs | Entity expansion bomb → memory exhaustion | DoS on payment processing | Nested entity definitions |
| Schema confusion | Message claims pacs.008 but contains camt.054 elements | Parser confusion, misrouted payment | Cross-schema element injection |
| Amount overflow | IntrBkSttlmAmt with extreme value → integer overflow | Incorrect payment amount | Boundary values: MAX_DECIMAL, negative, huge exponent |
| IBAN injection | IBAN field contains XML/SQL special characters | Injection in downstream systems | Special chars in IBAN/BIC fields |
| Encoding confusion | UTF-8 BOM, overlong UTF-8, mixed encodings | Parser bypass, data corruption | Encoding edge cases |
| Structured address exploitation | Overlong/malformed structured address data (PSD3 mandatory) | Buffer overflow in legacy systems | Field length boundary testing |

#### 3.2.3 Fuzzing Methodology

```
1. Obtain valid ISO 20022 sample messages:
   - SWIFT MyStandards (public samples)
   - ISO 20022 message definition reports (MDR)
   - Test messages from bank sandbox APIs

2. Build mutation corpus:
   - Valid pacs.008 messages (baseline)
   - Messages with XXE payloads in every text field
   - Messages with billion laughs entities
   - Messages with cross-schema elements
   - Messages with boundary amounts (0, -1, MAX, NaN)
   - Messages with special chars in IBAN/BIC
   - Messages with encoding anomalies

3. Target parsers:
   - Open-source ISO 20022 parsers (Python, Java, .NET)
   - Bank sandbox APIs (send messages, observe behavior)
   - SWIFT Transaction Manager simulation

4. Differential testing:
   - Same message → multiple parsers → compare extracted values
   - Focus: amount, IBAN, party names, dates
   - Divergence = potential vulnerability
```

### 3.3 Payment SDK Webhook Security

Every payment processor uses webhooks to notify merchants of events. Webhook verification is a critical trust boundary.

#### 3.3.1 Webhook Verification Patterns

```bash
# === For each payment SDK, audit webhook verification ===

# Stripe: HMAC-SHA256 of payload with webhook secret
grep -rn "constructEvent\|verifyHeader\|Webhook\.construct" --include="*.js" --include="*.py" --include="*.rb"
# Common bug: developer doesn't call constructEvent() → accepts any webhook

# Adyen: HMAC-SHA256 verification
grep -rn "hmacValidator\|validateHMAC\|Adyen.*webhook" --include="*.js" --include="*.py" --include="*.java"

# PayPal: asymmetric signature verification
grep -rn "verifyWebhookSignature\|PAYPAL-CERT-URL\|transmissionSig" --include="*.js" --include="*.py"
# PayPal-specific: cert URL in header → SSRF if fetched without validation

# Square: signature verification
grep -rn "WebhooksHelper\|isValidWebhookEventSignature" --include="*.js" --include="*.py"

# Generic patterns (developer forgot verification)
grep -rn "webhook\|hook\|callback" --include="*.js" --include="*.py" --include="*.ts" | \
  grep -iv "verify\|signature\|hmac\|validate\|construct"
```

#### 3.3.2 Webhook Attack Patterns

| Attack | Mechanism | Impact |
|--------|-----------|--------|
| Unsigned webhook injection | Send fake webhook without signature | Free goods, fake refunds |
| Webhook replay | Capture valid webhook → replay later | Double-processing of payment |
| Webhook SSRF (PayPal) | PAYPAL-CERT-URL header → merchant fetches URL | Internal network access |
| Timing attack on HMAC | Non-constant-time comparison of signature | Signature forgery via timing oracle |
| Webhook event confusion | Send payment_intent.succeeded for unpaid order | Free goods |
| Webhook idempotency bypass | Same event ID sent twice → both processed | Double-processing |

### 3.4 IBAN/BIC Validation Library Bugs

IBAN validation is implemented by dozens of libraries, and each handles edge cases differently. A validation bypass = misdirected payments.

```
Fuzzing corpus for IBAN validators:
- Valid IBANs (baseline)
- IBAN with wrong checksum
- IBAN with wrong country code
- IBAN with wrong length for country
- IBAN with special characters (\x00, ', ", <, >, &)
- IBAN with Unicode homoglyphs (Cyrillic А instead of Latin A)
- IBAN with leading/trailing whitespace
- IBAN with embedded newlines
- IBAN from non-existent country code
- IBAN at maximum length (34 chars)
- IBAN with lowercase (valid per ISO 13616 but some parsers reject)

Differential testing:
- schwifty (Python) vs iban-tools (JS) vs Apache IBAN4J (Java)
- Same IBAN string → valid/invalid → compare results
- Divergence = one parser accepts what another rejects
```

---

## 3.5 Effort & Roadmap

### Month 1: Quick Wins

| Week | Task | Deliverable |
|------|------|-------------|
| 1 | Set up fintech target list (register on HackerOne/Bugcrowd/Intigriti) | Access to 10+ fintech programs |
| 1 | First fintech hunt using §FIN-1 through §FIN-4 | Initial findings |
| 2 | Open Banking sandbox access (3-5 banks) | Sandbox credentials |
| 2 | §OB-2 consent testing on first 3 banks | Consent vulns |
| 3 | Payment SDK webhook audit (stripe-node, adyen-node) | Webhook verification gaps |
| 3 | IBAN validation differential (schwifty vs iban-tools vs IBAN4J) | Divergence report |
| 4 | ISO 20022 XML parser fuzzer setup | Fuzzer + initial corpus |

### Month 2: Depth

| Week | Task | Deliverable |
|------|------|-------------|
| 5-6 | Deep dive on top 3 fintech targets | Bounty submissions |
| 5-6 | §OB-3 SCA testing on 5 banks | SCA bypass findings |
| 7 | ISO 20022 XML fuzzing campaign (72h continuous) | Parser divergences |
| 7 | Payment SDK lib audit (Stripe SDK internals) | SDK-level vulns |
| 8 | Cross-bank differential on Open Banking APIs | Spec compliance gaps |

### Continuous

- Fintech bounty rotation: 1-2 targets per week
- Open Banking testing: new bank sandbox every 2 weeks
- ISO 20022 fuzzer: continuous background process
- Payment SDK monitoring: new versions → regression test against fuzzer corpus
- OUTCOMES.jsonl tracking with domain=fintech|openbanking|payment_infra

---

## Integration with Existing Pipeline

### New Checklist References

| New Section | Inserted Into | Description |
|-------------|--------------|-------------|
| §FIN-1 through §FIN-4 | DEFI-FULLSTACK (or standalone) | Fintech-specific payment logic, KYC, card, notification checks |
| §OB-1 through §OB-5 | New standalone: OPENBANKING-HUNT-CHECKLIST.md | Open Banking/PSD2 API security checks |
| ISO 20022 fuzzer | ZERO-DAY-HUNTING-SPEC Domain 9 extension | Payment message parser fuzzing |
| Webhook audit | PIPELINE-EXPANSION §F1 extension | Payment webhook verification checks |
| IBAN differential | ZERO-DAY-HUNTING-SPEC Domain 9 extension | Financial format parser fuzzing |

### Kill Gate Extensions

For fintech findings:

- **Q5 (Trigger Feasibility):** Can the bug be triggered with a real account? Sandbox-only bugs have lower value.
- **Q6 (Industry-Known):** Search HackerOne disclosed reports for same platform + vuln class.
- **New Q13: Regulatory Impact** — does this finding violate PSD2/PCI-DSS/SOX? Regulatory violations are harder to dismiss.

### OUTCOMES.jsonl Extensions

```json
{
  "domain": "fintech | openbanking | payment_infra",
  "target_type": "neobank | bank_api | payment_sdk | message_parser",
  "regulatory_reference": "PSD2 Art. X | RTS Art. Y | PCI-DSS Req. Z",
  "platform": "hackerone | bugcrowd | intigriti | direct_disclosure",
  "payment_impact": "fund_theft | data_leak | compliance_violation | fraud_enablement"
}
```

---

## Coverage Matrix — Complete Arsenal with Financial Track

```
DOMAIN                    ATTACK SURFACE                STATUS
───────────────────────────────────────────────────────────────
TARGET HUNTING
  DeFi                    Smart contracts (EVM/Sol/ZK)   OPERATIONAL
  DeFi                    Full-stack (API/frontend/infra) OPERATIONAL
  Web                     Next.js/RSC                    OPERATIONAL
  Auth                    JWT/OAuth2/SAML                OPERATIONAL
  Infra                   Supply chain, proxy, xchain    OPERATIONAL
  Fintech                 Neobank APIs & payment logic   THIS DOCUMENT
  Banking                 Open Banking / PSD2 APIs       THIS DOCUMENT

ZERO-DAY RESEARCH
  Track A (Crypto)        D1-D5: parsers, crypto, AA     OPERATIONAL
  Track B (General)       D6-D12: HTTP, runtime, DB...   ZERO-DAY-SPEC
  Track C (Financial)     Payment SDKs, ISO 20022, IBAN  THIS DOCUMENT
```

Three revenue streams operating in parallel:

1. **DeFi bounties** (direct disclosure) — producing results
2. **Fintech/banking bounties** (HackerOne, Bugcrowd, Intigriti) — NEW
3. **Zero-day CVEs → downstream bounties** (multiplication model) — producing results (5+ confirmed)

The financial track adds a third revenue stream with higher per-finding payouts, broader target availability, and regulatory backing that prevents dismissal.
