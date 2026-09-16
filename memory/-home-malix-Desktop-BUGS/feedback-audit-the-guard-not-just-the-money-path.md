---
name: feedback-audit-the-guard-not-just-the-money-path
description: "A conserving money-path declared \"robust\" is only half the audit — the GUARD middleware that admits callers to it (captcha/auth/csrf/rate-limit) is a disjoint first-class surface whose failure mode is a control-flow fail-open, not a value bug; grepping a guard ≠ auditing it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6dd4914e-d9f0-4119-8e41-83e3abae0e75
  modified: 2026-08-12T23:09:38.210Z
---

On Rootstock Flyover LPS (2026-08-12) I traced the money-flow exhaustively — pegin/pegout release gates, value conservation, cross-chain LP↔rskj-bridge diff, SPV/crypto, solvency — and declared the whole surface an "exhaustive NULL-COÛTEUX with executed artifacts." The operator then found a **captcha-middleware fail-open** I missed: `captcha.go` writes the below-threshold error but has **no `return`**, so `next.ServeHTTP` runs anyway → unauthenticated captcha-free `acceptQuote` → free liquidity-reservation griefing across every LP. I had **greped** captcha.go (saw the branch) but never **read the middleware body in full** — I stopped at the `acceptAuthenticatedQuote` path and moved on. The operator lined up all 5 rejection branches side-by-side; 4 `return`, 1 doesn't. That side-by-side is the method that found it.

**Why this is the lesson, not "read more carefully":**
- **The guard is DISJOINT from the guarded path.** "The handler conserves value" (what I audited) and "the guard that decides WHO invokes the handler actually enforces" (what I didn't) are two separate audits. A perfectly-conserving money-path + a fail-open guard = anyone reaches the money-path. Auditing the first tells you NOTHING about the second.
- **A guard's failure mode is control-flow, not value.** The bug in an auth/captcha/csrf/rate-limit/signature/allowlist middleware is almost never crypto or arithmetic — it's **write-but-don't-return / missing-return-after-error / `continue`-instead-of-`return` / error-swallowed-in-defer / early-break**. This is the fail-open class, and it lives in the GUARD body, invisible to a money-flow trace.
- **This IS the First Maxim.** `RequiresCaptcha:true` on the route proves the control EXISTS; I trusted it HOLDS without reading its enforcement. "Gate exists → protected" is the exact un-executed hypothesis the maxim forbids. Piercing the gate here = reading the guard's body, not grepping it. An un-read guard is an un-pierced gate.
- **The meta-failure: my NULL was over-claimed because my coverage ledger silently excluded a surface I filed as "plumbing."** I mentally categorized the middleware layer (captcha/session/csrf) as "utility" and never wrote a coverage line for it. A null is only as complete as its ledger; "utility/plumbing/infra" is the category where I hide un-audited surface from myself. On an N-audit target the AXIOM (P(class-bug survives N audits)≈0) applies to what the auditors ACTUALLY covered — a guard in a corner I never verified they covered is not "class-dead," it's un-audited.

**How to apply (mechanical, every engagement):**
1. Enumerate every GUARD on a value/state-mutating path: auth, captcha, csrf, rate-limit, signature-check, allowlist/denylist, pause/state gate, ownership check. Each is a first-class surface, NOT plumbing.
2. **READ each guard's full body** (not grep). Write an explicit coverage line: `<guard>.go: read in full, enforcement verified`. If you only greped it, it's UNAUDITED — say so in the ledger.
3. **Line up ALL rejection/failure branches side-by-side.** Assert every one `return`s / aborts / short-circuits BEFORE the protected call. If N-1 abort and 1 falls through → **fail-open**. Corroborating tell: a success-log/side-effect that also fires on the failure path (here `log.Debugf("Valid captcha solved")` ran on the invalid path).
4. Before writing "money-path robust / NULL-COÛTEUX," check the ledger has a verified line for the GUARD layer, not just the value logic. No guard-coverage line = the null is incomplete, keep going.

Greppable fail-open tells: an `if <bad> { writeError(...) }` block with no `return` on the next line; `http.Error`/`JsonErrorResponse`/`res.status(4xx)` followed by fall-through to the handler; `continue` where siblings `return`; errors logged-then-ignored.

See [[feedback-audited-target-hunt-invariant-not-class]] (the AXIOM is scoped to what auditors covered — a guard I skipped isn't class-dead), [[feedback-verify-before-working-no-theater]] (grep ≠ execution/read), [[rootstock-flyover-offchain-null-couteux]] (the over-claimed null this corrects), [[reachability-is-kill-gate-not-severity-modifier]].
