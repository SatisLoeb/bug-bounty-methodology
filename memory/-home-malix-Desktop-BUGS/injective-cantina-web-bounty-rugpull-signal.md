---
name: injective-cantina-web-bounty-rugpull-signal
description: "Injective's Cantina-managed web bounty reversed a validated-AND-agreed Medium to Rejected within ~30 min (2026-06-29) — payer-disengagement signal for future Injective web EV."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 67544c7a-96dc-4aa4-8fdc-b4384dfb761e
---

On Helix/Injective #134 (off-chain authz-as-identity account-takeover, Cantina-managed web bounty), the client walked severity High→Medium→Low, then on dispute conceded back to Medium ("we agree this is not a minor UI issue"). The researcher accepted in writing ("Agreed, Medium is fair"). **~30 minutes later the same client reversed the entire validity to Rejected** ("not a valid security issue in its current form ... the attacker must already be the authorized grantee"), re-raising the exact authorized-precondition argument already rebutted in-thread and never contested. A formal dispute (grantee-axis confused-deputy rebuttal) is in progress; outcome still open.

**Why:** an "acknowledged + agreed" tier is NOT a settled outcome on this program — a concession got un-made after acceptance, with no new facts. That is the reversal-after-agreement whipsaw, and on the payer side it reads as disengagement: a program willing to rug-pull a validated, agreed Medium to zero is one where p_bounty is structurally depressed regardless of finding quality. Pairs with [[ev-gate-check-program-responsiveness-not-just-severity]] and [[dydx-bounty-sponsor-disengaged]] (validator≠payer): here the client IS the payer and is the one reneging.

**How to apply:** in Step-0 EV for any future **Injective web/Cantina** target, weight p_bounty DOWN for this whipsaw history; do not treat an Injective "acknowledged/agreed Medium" as bankable until reward is actually banded and released. Operationally: never close a dispute thread graciously the instant they concede (a concession can be un-made) — hold live evidence warm until the reward lands. Update this note when #134 resolves (paid / held-Rejected) to firm or soften the signal. Distinct from [[injective-exchange-firmaudit-parked]] (that was the on-chain exchange firmaudit fortress-null; this is the off-chain web bounty payer behavior).
