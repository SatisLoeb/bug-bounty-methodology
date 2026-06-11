# Chain Proof Gate — Mandatory Before Auth/Credential/Signature Submissions

**Purpose:** Catch incomplete attack chains before submission. Specifically targets the class of findings where the chain has a "does the server accept this?" step that is tempting to skip.

**Rule:** For every finding in the class auth-bypass / hardcoded-credential / signature-forge / JWT-token / session-hijack / IDOR-write / password-reset / account-binding, this gate is MANDATORY before submission. No exceptions.

**Reference incident:** WEEX-002 (2026-04-13). Draft was ready to submit with `I deliberately did not present the forged JWT to Zendesk Messenger`. A one-line user question ("on a pas confirmé que le jwt est accepté") caught the gap. Ethical acceptance test with fictitious external_id returned HTTP 200 + `authenticated:true` + permanent appUser creation. Severity jumped Medium/Informative → Critical. Same day, Phemex R2 was marked Informative for the exact same missing-proof pattern.

---

## Finding Metadata

```
Finding ID:     [PROTOCOL-NNN]
Protocol:       [name]
Class:          [ ] auth-bypass       [ ] hardcoded-credential
                [ ] signature-forge   [ ] JWT-token
                [ ] session-hijack    [ ] IDOR-write
                [ ] password-reset    [ ] account-binding
Severity claimed: [Critical / High / Medium / Low]
Draft path:     [path/to/draft.md]
```

---

## Stage 1: Hedge Phrase Scan (mechanical)

Run this grep on the draft. Any match = chain incomplete, proceed to Stage 2.

```bash
grep -nE \
  "I did not test|\
I deliberately did not|\
inferred from|\
would access|\
would authenticate|\
would receive|\
deliberately not executed|\
not executed because|\
strongly indicates|\
architectural analysis suggests|\
documented .* protocol, not from testing|\
not confirmed whether|\
I stopped at|\
I did not attempt|\
the final link .* is inferred|\
not tested against|\
could not verify|\
assumed to be accepted" \
  "$DRAFT_PATH"
```

**One-liner for direct use:**

```bash
grep -nE "I did not test|I deliberately did not|inferred from|would access|would authenticate|would receive|deliberately not executed|not executed because|strongly indicates|architectural analysis suggests|documented .* protocol, not from testing|not confirmed whether|I stopped at|I did not attempt|the final link .* is inferred|not tested against|could not verify|assumed to be accepted" "$DRAFT_PATH"
```

**Outcome:**

| Matches | Verdict |
|---------|---------|
| 0 matches | PROCEED to Stage 3 (sanity check) |
| ≥1 match | STOP — chain incomplete, proceed to Stage 2 |

**Important:** The absence of matches does not mean the chain is complete. It means the draft does not contain obvious hedge language. Always run Stage 3 as final sanity check.

---

## Stage 2: Ethical Variant Generator

The hedge exists because a "real" test would touch real user data. For every auth class, an ethical variant exists that proves the chain without touching anyone real. Pick the matching pattern below and execute it.

### Class: JWT / token / signature forge

**The trap:** "I cannot forge a JWT for user X because that would access user X's data."

**The ethical variant:** Forge with a **fictitious external_id / subject / userId**. Almost every JWT-based system (Zendesk Messenger, Auth0, Firebase Auth, Intercom, Clerk, Supabase, AWS Cognito, custom HS256) creates a new account record if the subject is unknown. Acceptance of the forged JWT is proved by the server returning 200 and creating the fictitious user record — no real user touched.

**Test template:**
```bash
# 1. Forge JWT with fictitious external_id
node forge.js "test-research-$(date +%Y-%m-%d)-${RESEARCHER}"

# 2. Replay against the auth endpoint
curl -sS -o /tmp/resp.json -w "HTTP_STATUS=%{http_code}\n" \
  '<target auth endpoint>' \
  -H 'authorization: Bearer <forged_jwt>' \
  -H 'content-type: application/json' \
  --data-raw '<minimal body>'

# 3. Verify response
cat /tmp/resp.json | jq .
```

**Acceptance evidence required in report:**
- HTTP status code (200 = accepted, 401/403 = rejected)
- Server-side artifact proving acceptance: created user ID, session token, authenticated flag, etc.
- Echo of the forged identity in the response

### Class: Password reset / account recovery

**The trap:** "I cannot reset user X's password because that would lock them out."

**The ethical variant:** Reset **our own account's password** using the vulnerable flow. If the primitive works (bypass email verification, token prediction, race condition), it works against our account just as well. Credentials flow to us, no one locked out.

### Class: IDOR (write/delete)

**The trap:** "I cannot modify user X's resource because that would damage their data."

**The ethical variant:** Create **two accounts we control** (account A, account B). Exploit IDOR from A against B. Both accounts are ours, both are test data, and the write succeeds identically whether the target is a stranger or a second test account.

### Class: Session hijack / cookie forgery / SSRF to internal auth

**The trap:** "I cannot hijack user X's session because that would access their data."

**The ethical variant:** Both sessions in our control. Hijack from browser A to browser B, both logged into our test accounts. Full chain proven without touching anyone real.

### Class: Hardcoded API key / credential exposure

**The trap:** "I cannot use the leaked key because that would access production data."

**The ethical variant:** Use the key to query **permissioned metadata** (account info, user list on an endpoint that returns mass data, enumeration endpoints) that confirms the key is accepted by the backend. Avoid endpoints that would return specific users' private data. Even a single successful `/me` or `/users?limit=1` proves the key is live.

### Class: File read / path traversal

**The trap:** "I cannot read user X's file because that would expose their private content."

**The ethical variant:** Upload **a file we created** (a marker file with known content) through any legitimate flow, then exploit the path traversal to read it back. Acceptance = we retrieve the exact content we uploaded.

### Class: IDOR (read) on known-public data

**The trap:** Sometimes the endpoint only returns private data. Reading any of it = touching a real user.

**The ethical variant:** If the endpoint returns enumerable collections, read **count only** (pagination `total` or `meta.count`) without fetching individual records. Proves the key is accepted without reading any specific user's data. For numeric ID enumeration, query **our own ID** — if it returns data, the endpoint is accessible; the fact that our own ID works is enough to prove enumeration is possible for any ID.

### Class: The ethical variant does not exist

If **no** ethical variant works for this particular finding class:

1. The finding is not ready for High/Critical. Downgrade to Medium with explicit "impact is architectural, no end-to-end proof attempted for ethical reasons".
2. Remove all hedge phrases from the draft. Replace them with a clear "I did not test this because [specific ethical constraint]" explained in one sentence.
3. Update severity to reflect the missing-impact limitation.
4. This is a safe landing — an acknowledged Medium beats a dismissed High.

---

## Stage 3: Sanity Check

Even if the grep returns 0 matches and you have acceptance evidence, answer these four questions:

1. **Does the report contain a concrete HTTP response (or equivalent: stdout, on-chain event, deployed contract state) showing the vulnerable primitive is ACCEPTED by the intended backend?**
   - YES → proceed
   - NO → the chain is incomplete, return to Stage 2

2. **Could a reviewer replay the proof from the report alone, without additional information from me?**
   - YES → proceed
   - NO → add curl/script/commands so the replay is turnkey

3. **If I am wrong about the chain, what specific evidence from the report would prove me wrong?**
   - I can point to it → proceed
   - I cannot → my evidence is hedged, return to Stage 2

4. **What exactly is NOT proven by this test?**
   - I can state the limitation in one sentence → proceed
   - I am uncertain → my test is not rigorous enough, return to Stage 2

---

## Stage 4: Submission Authorization

**Before filling this section, run the grep command for real against the actual draft file and paste the literal output below. Do not describe the result from memory — the output must be the actual tool result.**

```
$ grep -nE "I did not test|I deliberately did not|inferred from|would access|would authenticate|would receive|deliberately not executed|not executed because|strongly indicates|architectural analysis suggests|documented .* protocol, not from testing|not confirmed whether|I stopped at|I did not attempt|the final link .* is inferred|not tested against|could not verify|assumed to be accepted" "$DRAFT_PATH"

[PASTE THE LITERAL OUTPUT HERE. If the command returned nothing, paste "<no output>" so it is clear the grep ran and returned empty.]
```

```
Hedge scan (literal output above): [ ] 0 matches / [ ] matches present (must fix)
Ethical variant used:    [describe]
Acceptance endpoint:     [URL]
HTTP response:           [status]
Server artifact:         [ID / token / flag]
Replayable by reviewer:  [ ] yes / [ ] no
Limitation stated:       [one sentence]

Final verdict: [ ] AUTHORIZED  [ ] BLOCKED  [ ] DOWNGRADED to [new severity]
```

If BLOCKED: do not submit until Stage 2 completes.
If DOWNGRADED: update severity in draft AND in submission form AND remove all hedge phrases that claimed a higher impact.
If AUTHORIZED: proceed to PREFLIGHT-CHECK.md (criterion D7 checks this gate was run).

**Meta-rule:** if the grep output field is filled with text like "I ran the grep and got no matches" instead of an actual `$ grep ...` command invocation + its literal stdout, the gate is not valid. This rule exists because I am capable of hallucinating that the grep ran when it did not. The only defense is requiring the actual tool output to appear in the record.

---

## Gate Exceptions

This gate does NOT apply to:

- **Smart contract findings with forge test PoCs.** The PoC runs against fork mainnet and asserts a state delta. That IS the chain proof.
- **On-chain state reads proving a bug condition is live.** `evm_call` returning the bug condition = on-chain proof.
- **Purely informational findings** (information disclosure with explicit "Low/Informational" severity). These never needed chain proof; severity already reflects limited impact.
- **Findings where the HTTP response IS the impact** (e.g. `/api/users` returning 247 users is the impact itself; no separate "does the server accept the query" stage exists because the question is identical to the answer).

For every other finding touching auth, credential, signature, session, or token, this gate is mandatory.

---

## War Log

| Date | Finding | Before gate | After gate | Δ severity | Δ reward |
|------|---------|-------------|------------|-----------|----------|
| 2026-04-13 | WEEX-002 Zendesk JWT forge | Draft with "I deliberately did not test" | HTTP 200 + authenticated:true + permanent appUser creation proved via fictitious external_id | Medium/Informative → Critical | $0-$500 → $2,500-$10,000 |
| 2026-04-13 | Phemex R2 /assets/transfer via trading key | Submitted WITHOUT chain proof (would require opening leveraged positions with real capital) | N/A — gate did not exist yet | Marked Informative post-submission | +2 rep, $0 |

---

## Anti-Pattern Detection — Phrases That Should Never Ship

If the draft contains any of these exact phrases WITHOUT a Stage 2 acceptance test backing them up, the draft is not submission-ready:

- "I deliberately did not [verb]"
- "I have not confirmed whether"
- "I did not attempt to"
- "inferred from [documentation / protocol / specification]"
- "the architectural analysis suggests"
- "strongly indicates the [X] would be accepted"
- "would authenticate as"
- "would return [success/accept/process]"
- "I stopped at"
- "doing so would require [disrupting / damaging / accessing]"

These phrases are honest — which is good for epistemic precision — but they are also **red flags** that the chain stops short of the server's accept/reject decision. The fix is never to edit them out cosmetically. The fix is to run Stage 2 and replace the hedge with a concrete HTTP response.

Honesty about NOT testing is only acceptable when paired with an ethical constraint that **genuinely** has no workaround. In 2026, for auth/credential findings, a workaround almost always exists.
