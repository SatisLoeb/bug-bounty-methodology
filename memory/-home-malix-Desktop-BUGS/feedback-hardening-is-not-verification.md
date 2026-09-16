---
name: feedback-hardening-is-not-verification
description: Iterative hardening of a report does not find factual errors in it; a mechanical pre-submission pass does
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dee528a0-0d9e-4bc1-b625-4ce067702e36
  modified: 2026-08-05T05:04:45.756Z
---

On TruFin F-1 (2026-08-05) a report was hardened over six operator review rounds — every round
removed a real overclaim, and by the end I wrote "prêt à envoyer". A mechanical pre-submission
verification then found **three verifiable falsehoods still in it**, plus a title that overclaimed:

1. Paragraph one said the PoC output was "from a re-run this morning, after I rebuilt the wasm" —
   the wasm was 6 days old. Checkable by any triager with `stat`.
2. The severity argument attributed "theft of gas" and "unbounded gas consumption" to the
   program's Medium tier. Neither is listed. Mis-citing their own scope page while arguing tiers.
3. The preflight cited a "10% of funds" reward clause that had been **deleted from the program
   page 6 days earlier**.
4. The PoC made the pinned validator the DEFAULT validator (single-validator harness); mainnet
   separates them, so "freeze all vault withdrawals" was not what was executed. Title reduced to
   "99.91% of vault stake".

**Why:** hardening rounds attack the ARGUMENT (is this claim too strong?). They never re-check the
FACTS the argument rests on, because those were verified once, early, and then went stale — program
pages change, artifacts age, live state drifts. Two days between discovery and submission was
enough for the stake figures to drift 0.1% and for the reward clause to be deleted.

**How to apply:** before ANY submission, run a mechanical pass that is separate from the argument
review: (a) re-read every live number at a fresh block and anchor it; (b) re-fetch the program
page and diff scope/impacts/rewards against what the draft asserts; (c) `stat` every artifact the
draft claims freshness for; (d) re-run the PoC from clean and diff its output against the pasted
block; (e) compare the harness topology against mainnet topology before trusting the title.
Fan-out agents are RELIABLE for exactly this — it is mechanical checking, not verdict-forming —
which is the complement to [[feedback-agent-fanout-recreates-audit-blindspot]]: use them to CLOSE
when the question is checkable, use them for BREADTH otherwise, never for the verdict itself.

Related: [[feedback-verify-before-working-no-theater]], [[trufin-immunefi-injective-unbonding-freeze]].

**Tooling bug found in passing:** `~/arsenal/audit-lifecycle/bin/init-target.sh` dies with SIGPIPE
(exit 141) on large workspaces — `find ... | head -1` in the timebox block under `set -e`. It
silently never writes the `init:` marker, so every downstream lifecycle gate stays blocked. Fix is
`-print -quit` or `|| true` on that pipeline.
