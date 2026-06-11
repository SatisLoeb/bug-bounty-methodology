# Contact Research Checklist — Finding Security Contacts

## Priority Order for Contact Discovery

Follow this order. Stop at the first successful high-confidence contact.

### Priority 1: security.txt (RFC 9116)

```
CHECK: https://<domain>/.well-known/security.txt
CHECK: https://<domain>/security.txt
```

**What to extract:**
- `Contact:` — email or URL
- `Encryption:` — PGP key URL
- `Preferred-Languages:` — language for report
- `Policy:` — vulnerability disclosure policy URL
- `Expires:` — if expired, contact may be stale

**If found:** Use exactly as specified. This is the protocol's declared security channel.

### Priority 2: SECURITY.md in Repository

```bash
# Check common locations
gh api repos/<org>/<repo>/contents/SECURITY.md --jq '.download_url' 2>/dev/null
gh api repos/<org>/<repo>/contents/.github/SECURITY.md --jq '.download_url' 2>/dev/null
gh api repos/<org>/<repo>/contents/docs/SECURITY.md --jq '.download_url' 2>/dev/null
```

**What to extract:**
- Reporting instructions
- Preferred contact method
- PGP key or keyserver reference
- Expected response time
- Scope information

### Priority 3: security@ Email

```
TRY: security@<domain>
TRY: security@<org>.io
TRY: security@<org>.com
```

**Verification:** Check MX records to confirm email is deliverable:
```bash
dig MX <domain>
```

**Risk:** May not be actively monitored. Send with read receipt or follow up after 7 days.

### Priority 4: Bug Bounty Platform (Contact Channel Only)

Even if you're not submitting through the platform, bounty program pages often list:
- Security team contact info
- Preferred disclosure channels
- Response time commitments

**Check:**
- Immunefi program page → "Contact" or "Security" section
- HackerOne program → security policy
- Bugcrowd program → disclosure terms

**Use the contact info found, not the platform's submission form.**

### Priority 5: PGP Key Discovery

```bash
# Search public keyservers
gpg --keyserver hkps://keys.openpgp.org --search-keys "<org> security"
gpg --keyserver hkps://keyserver.ubuntu.com --search-keys "<org>"

# Check GitHub for PGP keys
gh api users/<username>/gpg_keys --jq '.[].raw_key'

# Check Keybase
# WebSearch: "site:keybase.io <org>"
```

### Priority 6: Signal / Keybase

Look for:
- Keybase usernames in SECURITY.md or team pages
- Signal numbers in security documentation
- Matrix rooms for security discussions

### Priority 7: On-Chain Message (Last Resort)

If all other methods fail, send a small transaction with a message:

```
Method: Send 0.0001 ETH to protocol's deployer/admin address
Input data: UTF-8 encoded message requesting secure contact
```

**WARNING:** This is public. Keep the message minimal:
```
Security vulnerability found. Please provide secure contact. [your-email]
```

**Risk:** Adversaries see this too. Only use as absolute last resort.

---

## Contact Selection Template

After discovering contacts, fill this template:

```
╔══════════════════════════════════════════════════╗
║  CONTACT CARD: [Protocol Name]                    ║
╠══════════════════════════════════════════════════╣
║  Primary:   [method] - [detail]                   ║
║  PGP:       [Yes → fingerprint] / [No]            ║
║  Backup:    [method] - [detail]                   ║
║  Language:  [Preferred language]                   ║
║  Response:  [Expected time based on history]      ║
╚══════════════════════════════════════════════════╝
```

## Communication Channel Decision Tree

```
PGP key available?
├── YES → Send PGP-encrypted email to security contact
│         Attach your PGP public key for reply encryption
│         Subject line: "[Security Vulnerability] [Component] — [Severity]"
│
└── NO → Signal/Keybase available?
    ├── YES → Send initial contact via Signal/Keybase
    │         Request encrypted email channel for full report
    │
    └── NO → Email available?
        ├── YES → Send minimal initial email:
        │         "Security vulnerability found in [component].
        │          Please provide a secure channel for full disclosure.
        │          Severity: [High/Critical]. Timeline: 90 days."
        │         Do NOT include full details in unencrypted email.
        │         Wait for secure channel before sending report.
        │
        └── NO → On-chain message (last resort)
                 Minimal message requesting contact
```

## Initial Contact Email Template

### With PGP (Full Disclosure)

```
Subject: [Security Vulnerability] [Type] in [Component] — [Severity] (CVSS [X.X])

Hi [Protocol] Security Team,

I've identified a [severity] vulnerability in [component] (deployed at [address]).

[Full report attached / inline below]

Disclosure timeline:
- Discovery: [date]
- This disclosure: [today]
- Planned public disclosure: [today + 90 days]

I'm happy to extend the timeline if a fix is actively in progress.

My PGP key: [fingerprint]

Best,
[Researcher name/handle]
```

### Without PGP (Initial Contact Only)

```
Subject: [Security Vulnerability] [Severity] issue found — requesting secure channel

Hi [Protocol] Security Team,

I've identified a [severity] security vulnerability in [component name] that affects
[brief impact — 1 sentence, no technical details].

I'd like to disclose the full details through a secure channel. Could you provide:
- A PGP key for encrypted email, OR
- A Signal/Keybase contact, OR
- Your preferred secure disclosure method

Severity: [High/Critical/Medium]
Estimated CVSS: [X.X]
Timeline: 90-day coordinated disclosure from today ([date])

Best,
[Researcher name/handle]
[contact email]
```

## Follow-Up Schedule

| Day | Action |
|-----|--------|
| 0 | Send initial disclosure |
| 7 | If no response: resend to backup contact |
| 14 | If no response: try alternative channel (Discord DM to core dev, etc.) |
| 30 | Send 30-day reminder |
| 60 | Send 60-day reminder with publication warning |
| 75 | Final reminder: "Publication in 15 days unless actively working on fix" |
| 90 | Publish (or extend if fix is in active progress) |

## Documentation Requirements

**For every disclosure, maintain:**

1. **Timestamps** — Date/time of every communication
2. **Email hashes** — SHA-256 of sent emails (proves content at time of sending)
3. **Git commits** — PoC and report committed with dated signature
4. **Screenshots** — Contact discovery evidence
5. **Read receipts** — If available

**Why:** If the team patches silently without credit or bounty, you need proof of prior art. Also protects against "we found it independently" claims.

```bash
# Hash your disclosure email for timestamping
sha256sum disclosure-email.md >> disclosure-hashes.txt
git add disclosure-hashes.txt && git commit -S -m "Timestamp disclosure hash for [protocol]"
```
