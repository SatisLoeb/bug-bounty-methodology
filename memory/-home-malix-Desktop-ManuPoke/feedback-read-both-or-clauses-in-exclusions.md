---
name: feedback-read-both-or-clauses-in-exclusions
description: "When a scope exclusion has two clauses joined by \"or\", the BROADER (usually first) clause can swallow your finding chain/condition-independently — read it in full before betting on the narrower clause's apparent opening."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

Operator scope-check, 2026-07-20 (USDai C1). I built a real, PoC-proven cross-repo insolvency (redirected-repayment
phantom NAV) and was about to submit it, arguing it was in-scope by IMPLICATION: the exclusion said "blacklisting on
non-Arbitrum chain", so I inferred "Arbitrum blacklisting is in-scope." WRONG — I read HALF the exclusion. Full text:
**"Any blacklisting inconsistency or blacklisting on non-source chain (non-Arbitrum chain)"** = TWO exclusions via "or":
clause 1 "Any blacklisting inconsistency" (broad, CHAIN-INDEPENDENT, "any" = all) + clause 2 "blacklisting on non-Arbitrum
chain" (narrow). My finding IS a blacklisting inconsistency (the vault is blacklisted so doesn't receive, but the hook books
as if it did — an inconsistency between blacklist-state and accounting). Clause 1 swallows it regardless of chain. I anchored
on clause 2's apparent opening and never checked whether clause 1 already caught the finding.

**Why:** submitting under a named exclusion = a predictable "out of scope" close that costs signal/reputation and wastes the
whole build. The mechanism being real/proven is irrelevant — a named class exclusion is UPSTREAM of severity, reachability,
and mechanism quality. (This is even cleaner than F1/Symbiotic/Rheo where the kill was reachability/saturation; here the scope
LITERALLY names the class.)

**How to apply (CHECKPOINT 7 — validate scope against the finding BEFORE submitting, and read exclusions in FULL):**
- When an exclusion has clauses joined by "or"/"and", parse EACH clause separately. Check whether the BROADER clause (often
  first, often unqualified with "any"/"all") swallows your finding BEFORE you rely on a narrower clause's apparent opening.
- Do NOT argue in-scope-by-implication ("they excluded X, so not-X is included") until you've confirmed no OTHER, broader
  exclusion clause independently covers your finding.
- Name your finding's CLASS in the program's own words and grep the exclusion list for that class. If the report's killshot
  says "when the vault is blacklisted...", the class is "blacklisting"; if any exclusion contains "blacklisting", you're likely dead.
- Record the exclusion list VERBATIM at intake (not paraphrased) — I had recorded only the second half, which is how the
  mis-read persisted. Paraphrasing a scope clause loses the load-bearing words ("any", "inconsistency").
Related: the scope-check kills BOTH ways [[feedback-trigger-reachability-is-payability-gate]] [[feedback-hunt-dont-narrate-ev]]
[[project-usdai-intake]] [[project-symbiotic-rwa-layer-oos]].
