---
name: submit-bar-reputation-over-fee
description: "On any bug-bounty submit go/no-go, lead with the reputation/quality standard for an attributed researcher, not fee-EV; recommend HOLD on a weak/dup-risk finding regardless of fee size — but never facile-close either."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4a3f4193-6fbd-420c-a4af-5e9e6b7f522d
  modified: 2026-08-25T21:26:41.501Z
---

The user is an attributed independent security researcher with a verifiable track record (CVE-2026-44288/GHSA-q6x5-8v7m-xcrf protobufjs; GHSA-g3qj-j598-cxmq fido2-lib; Cantina @SatisLoeb 1 critical + $10k; Immunefi MalikX31 1 critical + 1 high + $5k). Handles: malix / SatisLoeb / MalikX31 / Xvush / malikb31s.

**The rule:** when deciding whether to SUBMIT a finding, the PRIMARY lens is "does this meet the standard my name should carry?", not the submission fee's EV. A weak or dup-risk finding (e.g. a Medium with a real triager-discretion fold-in into a published known issue) should get a HOLD recommendation **on the merits, stated up front, before and independent of the fee amount**. His reputation is worth far more than a small fee, and on Immunefi a known-issue/dup close is attributable on the profile.

**Why:** I recommended hold on this ENS register-v2 Medium, but I anchored the recommendation on fee-EV (50 USDC, non-refundable — Immunefi fees are NEVER refunded, unlike Cantina). He corrected me: I should have said hold on the reputation/quality standard, because the real downside (a dup close on an established profile) exists at any fee. Anchoring on the fee reads as either "push to submit if the fee were small" or "close by facility" — both wrong.

**How to apply — the balance he wants (this is the hard part, get it right both ways):**
- Do NOT push him to submit "n'importe quoi" — a fold-in-risk / tier-uncertain / dup-exposed finding fails his bar regardless of fee. Lead the go/no-go with the standard, name the reputation downside explicitly, treat the fee as secondary.
- Do NOT go to close/null/"trop dur" by facility either. The default hunting posture stays aggressive: exhaust the vein, never concede a gate/verdict unmeasured (cf. [[playbook-front-load-receivability]], the chasse protocol, nullguard). The correction is about the SUBMIT gate, not the HUNT effort.
- The submit bar for him: clean, distinct root cause, tier honest, and every knowable rejection path (scope/dup/known-issue/materiality) closed with an executed artifact — a finding worthy of a profile that already has a CVE + criticals.
- Immunefi fees are non-refundable (every reject = the full fee lost, flat); Cantina fees are effectively refundable (downside ~0). So the same finding can be "submit on Cantina, hold on Immunefi" — but that's the secondary consideration, after the reputation/standard lens.
