---
name: project-halmos-bounded-proof-skill
description: "Halmos skill built 2026-07-13 — bounded symbolic-proof rung (Foundry fuzz → Halmos → Certora); prove.sh classifies each check_ and refuses to call a vacuous green \"proven\"."
metadata: 
  node_type: memory
  type: project
  originSessionId: a62cfad9-335c-409f-86e0-a0898ae7594a
---

Built `~/.claude/skills/halmos/` on 2026-07-13. Installed halmos 0.3.3 via `uv tool install --python
3.12 halmos` (z3 + yices bundled), on PATH at ~/.local/bin/halmos. Per-project it needs
`forge install a16z/halmos-cheatcodes` + a `halmos-cheatcodes/=lib/halmos-cheatcodes/src/` remapping
(setup.sh does this).

**What it is:** the MIDDLE rung of the guarantee ladder — Foundry fuzz (sample) → **Halmos** (all
paths up to a bound, same Foundry syntax, test_ → check_, concrete inputs → symbolic) → Certora CVL
(only when the property exceeds Halmos). No new language, unlike CVL.

**The runner `prove.sh` (symlinked to ~/.local/bin/hprove)** runs `halmos --json-output` and classifies
each check_ from the real 0.3.x schema (per-test exitcode/num_models/num_paths + the "all paths have
been reverted" warning): exit 0 → PROUVÉ (borné); num_models>0 → CONTRE-EXEMPLE (concrete inputs
printed, a finding candidate); exit 4 / all-reverted → VACUITÉ; other non-zero → INDÉCIS (SMT wall).
It **refuses to call a vacuous green "proven"** — the operationalized twin of
[[feedback-invariant-that-passes-is-not-a-finding]]. A PASS with ≤1 path is flagged as partial-vacuity, and
**`hprove . --canary check_xxx` (v1.1) automates the reachability probe**: it rewrites assert(P)→
assert(false) at the assertion site, reruns Halmos on a renamed+cleaned canary contract, and reports
SITE ATTEIGNABLE (genuine PASS) vs SITE JAMAIS ATTEINT (false green). Verified: real property →
reachable; assertion in a never-true branch → unreachable. Note: canary cleans its stale out/ artifact
(else Halmos re-discovers phantom contracts). `prove.sh selftest` proves the classifier on 4 cases.

**Why:** the promotion ladder in [[project-nuke-static-barrage-skill]] stopped at the executed PoC.
Halmos adds the bounded-proof rung: a candidate that doesn't break in fuzz gets its safety property
re-expressed as a check_ and either proven bounded or broken with a concrete counterexample.

**How to apply:** when a Foundry invariant holds "no counterexample in N runs", propose `/halmos` —
rewrite it test_→check_, `bound()`→`vm.assume()`, run `hprove . --function check_… -vvvvv`. Two traps
(references/pitfalls.md): symbolic-length arrays need FIXED length (svm.createBytes(96,…) /
--array-lengths); and the bound (--loop, array-lengths) IS the hypothesis — write it next to every
"proven" (not ∀n). Wired into NUKE verify.md + routing.md. Solidity/EVM + Vyper; not Rust/Move/Cairo.
