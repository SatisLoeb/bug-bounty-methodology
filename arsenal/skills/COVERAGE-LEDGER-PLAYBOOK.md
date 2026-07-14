# COVERAGE-LEDGER PLAYBOOK — enumerate every in-scope file so no un-hunted surface hides the theft you're missing

**Shared mandatory gate. Invoked by `firmaudit` (before Phase T verdict) and `darkside` (gate 0.5.6, before any NULL-COÛTEUX close). One source of truth — both skills reference this file, neither duplicates it.** The telos is NOT "prove you looked everywhere so you may declare the target clean"; it is **"don't MISS a theft primitive by leaving a money-exit surface un-hunted."** Same mechanical rigor, inverted goal.

## The defect this fixes (Mezo, 2026-06-11 — the operator's statistical catch)

Seam-first hunting (firmaudit Phase S) and dup-aware prioritization are a STRENGTH — they put immortal depth where the bug is probable. But they have one structural blind spot: **they optimize for "find the bug where it's likely," not for "make sure no surface hides a theft primitive you never hunted."** The result: you deep-beast 8 high-signal surfaces, prove them sound, and close the target — while N other in-scope files were never enumerated, never cocked, never even listed. Nothing in the skills forced you to write down the full file list and confront the gap.

Concretely on Mezo: the prior engagement named 8 surfaces (PCV/bridge/EVM/oracle/EIP-712/refinance/liquidation) and closed it as a no-find. A `find *.sol` showed musd has **20 contracts; 8 were never a named surface** (SortedTroves 500 LOC, HintHelpers 249, GovernableVariables 139, the 4 pools, MUSD token, TokenDeployer = ~1631 uncovered LOC). They got skipped by two reflexes, each individually reasonable and collectively a coverage hole:
- **No seam → not chosen.** The seam-thesis writes off "helper" code (SortedTroves/pools) as having no boundary nobody-owns. Structurally correct for prioritization; wrong as a license to never read it.
- **"Canonical Liquity-fork = high dup → skip."** A dup-PRIOR (where to point depth) silently became a "don't look here" — the difficulty/dup filter dressed as prudence (Rule 40, but applied to SURFACES instead of classes). The dup prior tells you where the deep HOURS go; it never authorizes zero artifact on a fund-moving file.

The operator's statistical frame is the tell: **279 submissions, ~5% real = ~14 correct, ~2-3 valid.** If the cohort finds things and you find nothing, the likeliest cause isn't "I searched my surfaces badly" — it's "I didn't search everywhere, and nothing made me confront the gap." The seam-thesis says where to look FIRST; this ledger guarantees nothing is forgotten LAST. They are complementary: you need both.

## THE LEDGER — mechanical, runs before any NULL-COÛTEUX close

### Step 1 — ENUMERATE every in-scope file (no judgement yet)
Pull the COMPLETE in-scope file list mechanically. Do not pre-filter by "looks trivial."
```bash
# Solidity (per in-scope repo/dir; exclude tests/mocks/interfaces/build/node_modules)
find <scope-dir> -name '*.sol' | grep -ivE 'test|mock|build|node_modules|/interfaces/|/dependencies/|console|echidna|NoOp'
# Go (Cosmos / node)
find <scope-dir> -name '*.go' | grep -ivE '_test\.go|mock|/testutil/' ; ls -d <repo>/x/*/   # the modules
# also: the deployed addresses (see firmaudit § DEPLOYED-LAYER READ PASS) — deployed code is an in-scope surface too
```
Write the full list to `recon/COVERAGE-LEDGER.md`, one row per file, with its LOC.

### Step 2 — CLASSIFY each file's coverage (every row gets one)
For each file, one of:
- **`COVERED+artifact`** — a named surface with an EXECUTED artifact (passing PoC / live read with pasted output / named-and-run disconfirmer). Cite the artifact.
- **`COVERED+seam-null`** — examined, proven sound by the seam/manual loop, with the executed disconfirmer line.
- **`SKIPPED+reason`** — deliberately not dug, with an EXPLICIT reason from the allowed-skip list below. "Looks trivial" / "it's a helper" / "canonical Liquity" are NOT allowed reasons on their own — see Step 3.
- **`UNCOVERED`** — never looked at. **Any `UNCOVERED` row means you have NOT finished hunting — a NULL-COÛTEUX close is illegal while one exists** (an un-hunted surface is exactly where the theft primitive you're missing lives). Either cover it (Step 3) or convert it to a justified `SKIPPED`.

### Step 3 — the SKIP GATE (the part that catches the Mezo hole)
A file may be `SKIPPED` ONLY for a reason that survives this test: *"if a valid finding lived in this file, would this reason explain why I correctly didn't need to read it?"* Allowed skip reasons:
- **Out of scope** — the program scope literally excludes this file/asset (quote the scope line).
- **No fund-moving / no state / no untrusted entry** — confirmed by a 60-second read (NOT by the filename): the file has no external/public state-changing fn reachable by an untrusted actor and moves no value. **You must have OPENED it to assert this.** (A "GasPool / pool" can still have an unbounded approval or a native-BTC re-entrancy — open it.)
- **Pure dependency / library audited upstream** — an unmodified OZ/standard lib (verify it's unmodified: `git diff` vs the published version; a FORKED lib is NOT this).

**NOT allowed as a standalone skip reason** (these are dup-PRIORS, not coverage-clearances):
- "Canonical Liquity/Uniswap/OZ-fork code, high dup" → dup directs WHERE deep hours go; it does NOT clear the file. The Mezo-custom DELTA (interest layer, native-BTC, recovery-mode, EIP-712 graft) re-derived on THIS deployment is exactly where a fork-finding hides ([[feedback_audited_scope_blind_spots_not_just_delta]]). Give the file at least a delta-pass: grep the canonical file for the project's custom additions and read those call sites.
- "It's a helper / trivial / small" → small files hold real bugs (HintHelpers manipulation, a 61-LOC GasPool unbounded approval). LOC ≠ risk.
- "The audits covered it" → audited ≠ exhausted; "Acknowledged" is still live; re-derive under THIS deployment's params.
- "No seam" → the seam-thesis is a depth-AIM, not a coverage-CLEAR. A file with no seam still gets a delta-pass.

### Step 4 — the NULL-COÛTEUX GATE (you haven't finished hunting until this passes)
**A NULL-COÛTEUX close on the TARGET — a rare, expensive failure-to-steal, never a badge — is illegal while any row is `UNCOVERED`, or any `SKIPPED` row's reason is on the not-allowed list.** An un-hunted surface is precisely where the theft primitive you failed to find is hiding, so the ledger is not "proof you looked everywhere to earn a null" — it is the guarantee you did not MISS a money-exit. Before closing, paste the ledger: every file is `COVERED+artifact`, `COVERED+seam-null`, or `SKIPPED+allowed-reason`. If you can't, you have a coverage hole — close it first. The close sentence must be able to say: "I enumerated N in-scope files; M covered with executed artifacts, K skipped for [allowed reasons]; 0 uncovered — no un-hunted surface remains." Then RE-SOURCE to a payable surface rather than re-drill the same saturated core.

## How depth is allocated (this does NOT undo seam-first)
The ledger is a COMPLETENESS gate, not an order. You still:
1. Run Phase S / seam-thesis FIRST → point immortal depth at the highest-signal surfaces (that's where the deep hours go).
2. Give every OTHER in-scope file at minimum a **delta-pass** (open it, grep for the project's custom additions, read the untrusted-reachable state-changers, write one artifact or one justified skip).
The seam gets the depth; the ledger guarantees the rest gets at least an executed look. A 61-LOC pool gets a 5-minute delta-pass, not a deep-beast — but it gets `COVERED`, not silently omitted.

## The one-line rule
**Seam-thesis says where to look FIRST and deepest; the coverage-ledger guarantees no surface was forgotten LAST — no un-hunted file where the theft you missed could live. A NULL-COÛTEUX close requires BOTH: the deep surfaces attacked with executed disconfirmers AND a complete ledger with zero uncovered rows.** Run this before every NULL-COÛTEUX/NO-GO close, on every audited target.
