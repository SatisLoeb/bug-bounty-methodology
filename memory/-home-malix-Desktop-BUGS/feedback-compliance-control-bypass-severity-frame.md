---
name: feedback-compliance-control-bypass-severity-frame
description: "Severity for a sanctions/compliance-control bypass on a REGULATED issuer is scored on a compliance-exposure frame, not fund-loss"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5a1f3799-a3e4-43cc-9b97-9fc04efa0029
---

When a finding's impact is the DEFEAT OF A COMPLIANCE / SANCTIONS CONTROL (a blocklist/OFAC bypass) rather than a fund movement, do NOT default to the fund-loss frame ("no theft → Medium"). For a regulated, licensed, OFAC-supervised issuer (Circle/USDC, any money-transmitter-licensed stablecoin), the right yardstick is COMPLIANCE-EXPOSURE: regulatory, legal, and reputational exposure. The blocklist is the on-chain enforcement of a LEGAL obligation; USDC reaching a blocklisted address is the exact outcome the license and the OFAC program exist to prevent. The harm is measured in regulatory exposure, not stolen dollars, so a working bypass of the central sanctions control is plausibly HIGH for that issuer even with zero funds moved.

**Why:** my reflex applied the fund-loss frame and stamped Medium ("no theft, sender-side still blocked"). The operator flagged that this is the wrong yardstick for a licensed issuer and artificially caps it — the severity of THIS finding depends on the target's REGULATORY POSTURE, not on the mechanics (which were fully proven). Circle is not a generic DeFi protocol: their OFAC compliance is existential, so defeating their central sanctions control rates higher FOR THEM specifically.

**How to apply:**
- Commit the minimum defensible tier as the floor (fund-loss → Medium) but ARGUE the compliance-exposure ceiling (plausibly High) explicitly in the body. Present BOTH frames; state which one fits a regulated issuer and why.
- Do NOT unilaterally stamp High (over-claiming burns credibility — the Deribit lesson). Keep the honest posture "the regulatory weight is your call, I do not run your compliance program" — but phrase it as a confident statement that the frame is theirs, NOT a grovelling "I'm fine being corrected" self-concession.
- A REMOVAL-OF-A-PROTECTION / control-defeat is a CAPABILITY-class impact (M-H1-002 lineage), not a passive view/read — it earns the depth and supports a higher tier than a leak.
- A SYSTEMIC pattern (the same root defect repeated — e.g. `return`-instead-of-`continue` appearing in 3 sibling functions) supports the TOP of the range: it is a repeated model error, not an isolated slip.
- Identify the target's regulatory posture in Phase 0 / triage so the severity frame is chosen up front, not at draft time.

First applied: Circle Noble F-1 (noble-fiattokenfactory ante blocklist bypass, 2026-06-26). See [[doctrine-surgical-reports-fight-to-the-end]] and [[ev-gate-check-program-responsiveness-not-just-severity]].
