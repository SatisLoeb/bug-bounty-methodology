---
name: ev-gate-check-program-responsiveness-not-just-severity
description: "EV/Step-0 gate must weigh program responsiveness (sponsor engagement, time-to-pay), not just severity ceiling × TVL"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 64c38798-56f9-47f6-a77c-e98422231f3e
---

`EV = severity × p_bounty`. A high severity ceiling is worthless if `p_bounty ≈ 0` because the sponsor is checked out and findings sit "In review" unresolved.

**The sharper rule — VALIDATOR ≠ PAYER, and `p_bounty` is gated by the PAYER:** on a managed platform (Cantina/Sherlock/C4) the platform may VALIDATE a finding independently, but the **sponsor/client FUNDS and RELEASES the reward.** A disengaged sponsor with an active, capable platform still yields `p_bounty ≈ 0` because the money never moves — "Cantina can validate without us" does NOT restore EV when dYdX is the one who pays and is checked out (~1 yr to release, if ever). Don't let "the platform decides independently" talk you back off a park; the binding constraint is *who cuts the check and how fast*, which sits upstream of the bug entirely.

**Why:** On 2026-06-24 I ran intake→wide on dYdX (a $1M–$5M-ceiling Cantina program) and went straight to surface allocation + a probe-posture question WITHOUT first checking program health. The operator interrupted with a Cantina-Discord screenshot of the dYdX team saying *"we don't do bug bounty any more… nobody has time."* I first parked, then a Cantina-core reply ("if escalated, sponsor's input is needed, else Cantina") tempted me to UN-park to a conditional GO — the operator corrected again: *Cantina validates but dYdX pays, and dYdX will take a year* → DROP. Step-0 "abandoned/unresponsive → WARNING" is not TVL+contact-exists; it is **payer engagement + time-to-PAY**.

**How to apply:** In intake/wide Step-0, BEFORE allocating depth, gather a payment-responsiveness signal — recent **PAID** reports (not just "triaged"/"In review"), median time-to-PAYMENT, who FUNDS/RELEASES the reward (platform escrow vs sponsor-funded-on-demand), and any public sponsor statement about engagement. If the *payer* is disengaged — even with a fully capable validator — PARK/DROP regardless of severity ceiling or validation authority, and say so up front before proposing surfaces. See [[dydx-bounty-sponsor-disengaged]], [[doctrine-surgical-reports-fight-to-the-end]].
