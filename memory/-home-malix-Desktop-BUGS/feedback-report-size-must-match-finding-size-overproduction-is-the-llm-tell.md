---
name: feedback-report-size-must-match-finding-size-overproduction-is-the-llm-tell
description: "Over-production IS the LLM tell — match report size to finding size; the anti-LLM verdict is set by the FIRST post and is sticky, chill can't rescue an over-produced opener"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 80451fba-0d45-4f5b-9930-3e67b9befdae
---

The operator wants "over-explaining / LLM-assisted" avoided **at all costs** — it is the single thing that discredits a report. The failure mode is NOT bad voice, it is **OVER-PRODUCTION**: turning a small finding into a big artifact. A multi-table, multi-section, CVSS-9.8 advisory for what is really a one-line hardening nit reads as machine-generated on contact, no matter how clean the prose.

**Why:** py_webauthn #265 / cbor2 advisories (Mar 2026). The original report (CVSS 9.8, markdown tables of downstream "blast radius amplifiers", Impact/Details/PoC/CVSS/References sections, enumerated equivalence classes) was a textbook LLM artifact for a finding that is, at bottom, "cbor2 collapses bool/int map keys and `parse_cbor` doesn't reject it." The maintainer (MasterKale, also the SimpleWebAuthn author) read-and-re-read the thread and still flagged "seemingly LLM-assisted over-explaining is overstating the problem." Critically: that verdict was set by the FIRST post (the 9.8 advisory) and was STICKY — a later chill-voiced follow-up that stripped severity entirely did NOT remove the tag, because the first impression already classified the whole thread. And even that follow-up was too long for the triviality (several code blocks + two corrections + a background paragraph for a one-line fix). The fix still landed (PR #285), but the LLM stain was permanent.

**How to apply:**
1. **Size the report to the finding.** A hardening nit = 5 lines: one-sentence mechanism, a 3-line repro, one-line suggested fix. NO tables, NO CVSS theater, NO enumerated downstream-impact sections, NO "blast radius" language. The over-structured advisory template is itself the tell — `report-nerve`'s full scaffolding is for a real Critical with a chain, not for a parser quirk.
2. **The first post is load-bearing and irreversible for the LLM verdict.** You win or lose the anti-LLM read on the opener. `chill` styles voice but cannot rescue an opener that is structurally over-produced (tables + 9.8 + sections). Get the SIZE right before the voice.
3. **When in doubt, ship less.** For low-payoff hardening / endpoint-compromise-only findings, a terse GitHub issue beats a formal advisory — and never attach a CVSS to something whose real impact is "encourages good data practices."
4. **Don't add text to a thread already tagged LLM.** More follow-up = more surface; a one-line close or silence is better than another thorough paragraph.

Counterweight/related: [[feedback-apparatus-is-packaging-not-discovery]] (sophistication of the apparatus REDUCES quality — same disease on the report side), the `chill` skill (voice only, not size), [[doctrine-surgical-reports-fight-to-the-end]] (surgical = minimal + exact, not exhaustive).
