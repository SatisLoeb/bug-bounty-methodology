---
name: mtpelerin-target-state
description: "Mt Pelerin (Immunefi) — F1 RESOLVED: confirmed, fixed, first-reporter, severity High (not Critical) by project discretion. Reward pending, dollar amount not yet confirmed."
metadata:
  node_type: memory
  type: project
  originSessionId: 1ffbe24f-565a-4629-b7b5-f780bfc907a5
  modified: 2026-08-14T16:39:41.212Z
---

Mt Pelerin bug bounty (Immunefi only, slug `mtpelerin`). Swiss regulated VASP; non-custodial Bridge
Wallet + fiat on/off-ramp. In-scope web assets: `app.mtpelerin.com` (the widget, fresh scope added
2026-08-12) + `www.mtpelerin.com` (marketing, low value). Payout structure: `Critical: Data theft`,
`High: Data deletion` on the public scope page — **but see the correction below, this table is NOT a
mechanical binary switch.** Full history/evidence: `~/Desktop/BlackBox/mtpelerin/` (README indexes
everything); lifecycle mirror `~/Desktop/BUGS/mtpelerin-audit/`.

## F1 — RESOLVED 2026-08-13
Session Bearer-token exfiltration: `app.mtpelerin.com`'s widget attaches the logged-in user's session
JWT to any request whose URL contains the substring `mtpelerin`/`smex`/`localhost` (a request
interceptor gate meant for internal calls), and the `addrcb`/`txcb` callback URL params — attacker-
controlled, taken straight from the widget's query string — go through that same interceptor
unvalidated. One click on "Add address" ships the victim's access token to an attacker host that
merely contains one of those substrings. Proven end-to-end live: positive capture (real JWT
exfiltrated), negative baseline (127.0.0.1 vs localhost — same account/flow, only the substring
differs, proves the interceptor is the sole gate), and a self-replay (captured token →
`api.mtpelerin.com/persons/findOne` → 200 with live KYC/profile data; no token → 401).

Submitted as Immunefi report **#88293** (by @MalikX31). Mt Pelerin (anthonyg) **confirmed valid,
reproduced against source, fixed and deployed to production**. Was the **first reporter** — a
near-simultaneous independent duplicate arrived shortly after and does not get rewarded. **Severity
set to High, not the submitted Critical** — project's call (this program is self-triaged, no Immunefi
triage layer, so this is final absent a formal dispute). Reward dollar figure not yet stated.

**The severity argument, and why it was accepted rather than disputed:** Mt Pelerin's rationale was
verified against source (not just the bundle), cited nothing that contradicted the original report,
and was clearly good-faith (explicit non-invocation of the phishing/social-engineering exclusion —
"we agree with your scope reasoning" — plus credit for self-disclosing that `checkAccess()` blocks
third-party embedding). Their case: no passive/stored/reflected vector (attacker must individually
deliver a crafted link), the leak fires only on one specific button's click handler (not on page load
or navigation), the exposed credential is access-token-only (never the refresh token) and capped at a
4h window with no renewal, and there's no embedding-based path to scale. Every one of those facts was
already self-disclosed in the original report — nothing new, nothing contested. Compared explicitly to
reflected XSS: same delivery shape, materially lower exploitability (no code execution, bounded
credential, several further deliberate victim actions required). On reflection this held up on the
merits, not just as something to concede gracefully — recommended accepting rather than relitigating.

## The corrected lesson (worth carrying to other self-triaged Immunefi programs)
Earlier in this engagement I read the program's public "Impacts in Scope" page — exactly two rows,
`Critical: Data theft` / `High: Data deletion`, no visible interaction qualifier on the Data theft row
— as a **mechanical binary**: an impact either matches the Data-theft label (pays Critical) or it
doesn't (pays nothing), with no partial-credit tier, since there's no separate qualified-disclosure
High row the way some other Immunefi programs structure it. **This outcome disproves that reading.**
Mt Pelerin classified F1's impact as "Data theft" (agreeing the label is correct) while still paying it
at High severity — meaning severity and impact-category are judged on TWO independent axes internally,
even though the public page only visibly names one combination per row. The two-row page is
illustrative of each category's typical/ceiling case, not an exhaustive enumeration that locks reward
tier to impact-type alone. **For any self-triaged program (no Immunefi triage layer), assume the
project retains real within-category severity discretion even when the public scope page looks like a
flat binary table** — don't commit to "no fallback tier exists" as a structural fact from the public
page alone.

## Status / next step
`outcome:fixed` in OUTCOMES.jsonl, reward amount TBD. Nothing further to chase unless the user wants to
ask Mt Pelerin for the exact dollar figure, or unless a reply/question arrives on report #88293.
Suspended harnesses H1 (SameSite)/H2 (`_handoff` reuse)/H4 (merchant `_ctkn` config) were never followed
up — low priority now that F1 is resolved, only worth reopening if this program gets revisited for a
new finding. See `~/Desktop/BlackBox/mtpelerin/SUSPENDED-HARNESS.md`.

See [[recevability-gate-before-poc]], [[report-no-self-devaluation]], [[measure-before-asserting-in-reports]].
