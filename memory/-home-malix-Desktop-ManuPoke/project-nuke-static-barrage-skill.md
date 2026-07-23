---
name: project-nuke-static-barrage-skill
description: NUKE skill — local static-analysis barrage that fuses tool output into a triage surface; MULTI-ECOSYSTEM as of 2026-07-14 (EVM Slither+Aderyn+Semgrep · Rust/CosmWasm+Solana cargo-* · Go/Cosmos golangci+govulncheck+codeql), non-EVM ships a CURATED fund-theft negative-space worklist; the mechanical layer under the cognitive arsenal.
metadata: 
  node_type: memory
  type: project
  originSessionId: a62cfad9-335c-409f-86e0-a0898ae7594a
---

Built `~/.claude/skills/nuke/` on 2026-07-13. It is the MECHANICAL execution layer beneath the
operator's cognitive skills — it runs the local scanners and fuses them; it does not hunt or decide.

What it does: `nuke <target>` (also `~/.claude/skills/nuke/scripts/nuke.sh`, symlinked to
`~/.local/bin/nuke`) fires **Slither + Aderyn + Semgrep(Decurity solidity/security rules)** in
parallel → `aggregate.py` fuses them into `<target>/.nuke/<ts>/{signals.md,signals.json,TRIAGE.md}`
with cross-tool **corroboration** (★ = how many engines agree on a locus) and the **negative space**
(vuln classes NO tool flagged = the author's blind spot to hunt by hand). Zero network by default
(local rules, OPSEC-safe); `--online-rules` adds the Semgrep registry. `nuke selftest` proves it on a
bundled vulnerable fixture (3★ on reentrancy + delegatecall). Also installed: aderyn 0.6.8, semgrep
1.169.0 (invoked with `-j 1` — semgrep-core segfaults -11 under internal parallelism), 42 Decurity
security rules, medusa (vendor/bin), and Pashov skills /solidity-auditor /x-ray /fizz (the optional
LLM agent-hunt layer).

**intake bridge (v1.2):** every barrage also emits `nuke-digest.md` next to signals.json (via
scripts/digest.py; `nuke digest [workdir|target]` to regen). It maps detected/corroborated classes
(concrete leads file:line) + the negative space to RANKED veins (/extract /power /darkside /upshift),
with a priority-ordered class→vein map (specific vulns like reentrancy/delegatecall/tx.origin win over
co-located generic arith/erc20 keywords). `/intake` reads it in a new "Phase 0 — NUKE hook" to pre-fill
its Classification + Corpus-ROUTE + RECOMMENDED-SKILL(S) — a prior grounded in what the code contains,
refined by (not replacing) the corpus. Still U-1: digest suggests, intake briefs, operator launches.

**Diff mode (v1.1):** `nuke diff <base>[..<head>] [repo] [--window N]` = post-audit-drift focus.
Analyzers still compile the whole project (Slither needs the compilation unit); Semgrep is scoped to
changed files; the triage surface is filtered to the patch lines (git --unified=0 → exact changed
lines, default window ±0). signals.md gets two buckets: 🎯 DANS LE PATCH (priority) vs 🕓 pré-existant
(context). Signals are partitioned in/out of diff BEFORE clustering so a cluster never straddles the
patch boundary. Line filtering assumes the working tree matches the HEAD side of the range.

**Why:** the arsenal was all cognitive/veine skills + reporting; there was no skill that actually
drives the static toolchain and folds raw output into the hunt. NUKE fills that, respecting the
operator's laws.

**First real run (2026-07-13, DVD, v1.2.1):** ran clean on Damn Vulnerable DeFi (53 contracts,
Foundry) — 1416 signals → 438 clusters, 54 high on real bug loci (NaiveReceiver msg-value-multicall,
UnstoppableVault controlled-delegatecall, SelfiePool arbitrary-send). Two gotchas fixed: (1) a
shallow clone missing git submodules made aderyn fail (import not found) → nuke.sh now runs
`git submodule update --init` before the barrage when libs are missing; (2) the digest vein-ranking
was polluted by ~286 info signals defaulting to /darkside → digest.py now routes only on medium+ or
corroborated clusters. Also learned: ★★★ (all-3-tool) corroboration is RARE on real code (tools
anchor at slightly different lines); ★★ is the normal strong signal — don't expect ★★★ like the
compact selftest fixture.

**Multi-écosystème (v2.0, 2026-07-14 — built from the verified survey wf_2151c1bb-dbc):** `nuke <target>`
now auto-detects the ecosystem (step 0) and fires the right barrage; the fusion/clustering/corroboration/
negative-space engine is shared. Detection: foundry/hardhat/.sol→**evm**; Cargo.toml+cosmwasm-std→
**cosmwasm**; Cargo.toml+anchor-lang/solana-program→**solana**; go.mod+cosmos-sdk/cometbft→**cosmos-go**;
Move.toml→move; Scarb.toml→cairo. Barrages: Rust = cargo-audit(--no-fetch, OPSEC) + cargo-deny + clippy
(→SARIF via clippy-sarif, else rustc-json fallback) + geiger + a MANDATORY `[profile.release]
overflow-checks` read (its ABSENCE is a finding, not a note) [+ solana-lints Dylint + Decurity rust
semgrep for solana]; Go = golangci-lint + govulncheck + gitleaks + nilaway + opengrep(ToB go rules) +
codeql(opt-in NUKE_CODEQL=1). **SARIF is the normalization spine** — a generic `load_sarif` in
aggregate.py maps golangci/govulncheck/osv/gitleaks/opengrep/codeql/clippy; per-tool JSON adapters for
cargo-audit/deny/geiger/clippy-fallback/solana-lints/sec3/nilaway. **The KEY design: on non-EVM no
scanner sees fund-theft classes, so `references/negative-space.json` ships a CURATED worklist** (21
cosmwasm / 23 cosmos-go / 22 solana), each class = severity+money-path+tell+vein; `aggregate.py
--ecosystem <eco>` renders it in signals.md's 🕳️ section and it prints EVEN WITH ZERO TOOLS INSTALLED
(the worklist IS the deliverable). digest.py routes on the curated `vein` (bridge→/power, IBC→/upshift,
authz→/power…). **Move/Cairo: NUKE refuses to fake a barrage** (1 weak tool) → routes to formal/Prover
(aptos move prove; Aegis/Horus+snforge). OPSEC gates: network SCA (govulncheck/osv) only with
--online-rules; sec3/radar(Docker) + codeql opt-in. `scripts/setup.sh` installs the non-EVM arsenal +
clones ToB semgrep-rules + primes the RustSec advisory-db. `nuke selftest` now also asserts the 3
non-EVM maps render. EVM path byte-unchanged (selftest still 3★ reentrancy). Directly serves the
Cosmos-heavy portfolio (Injective CosmWasm swap, Push universalClient Go/Rust, Peggy Go bridge).

**Non-EVM VERIFIED (v1.2.2, 2026-07-14):** the multi-ecosystem code was implemented but never actually
run — first real non-EVM barrage exposed a crash: `aggregate.py` did `neg_space.get('label')` on None
for ecosystems WITHOUT a curated worklist (rust-generic / go-generic / move / cairo) → fusion crashed.
Fixed with `(neg_space or {}).get(...)`. The prior selftest missed it because it only tested the
curated-worklist RENDER (direct aggregate on cosmwasm/cosmos-go/solana, which all HAVE a neg_space
entry) — never the real cargo/go barrage + SARIF-fusion path. Now `nuke selftest` runs a REAL rust
barrage on a bundled `selftest/rust/` fixture (clippy→SARIF, overflow-checks finding, no-crash assert)
+ the EVM fixture moved to `selftest/evm/` so ecosystem detection doesn't cross-contaminate (a
Cargo.toml at maxdepth 2 was making the EVM selftest dir detect as rust). Lesson: untested code is
broken code — the non-EVM path shipped with a crash that only a real run caught.

**Saturation filter (v1.3.0, 2026-07-14) — how the operator ACTUALLY uses scans (de-prioritization,
not discovery):** `nuke saturation [workdir|target] --fork <name[,name]> [--shape S]` (scripts/
saturation.py). Saturation is a property of the VEIN, not the repo — a protocol can be ploughed on 11
money-paths and VIRGIN on the 12th. It crosses NUKE's veins (signals.json silent_classes / silent_detail)
with the operator's local corpus `~/Desktop/BUGS/solodit-corpus/{findings.jsonl(22.5k),class-map.json,
protocol-type-index.json}` (+ c4-corpus) and tags each vein **VIERGE** (payable class for the shape but
~0 finding on THIS target/fork-source → the unploughed vein inside a ploughed protocol → dig, carries the
corpus `detection_tell`) vs **LABOURÉE** (findings already exist on this fork → deprioritize). Verified:
Vuln.sol veins × `--fork gmx,fulcrom --shape perp/derivatives` → oracle/price + front-running/mev VIERGE
(0 on fork, 400+ global), signature/replay+flashloan+randomness LABOURÉE (GMXV2 findings). Non-EVM: thin
corpus → all VIERGE = the correct signal to dig, not a failure. Workflow: the filter says *dig*, the hunt
decides. NUKE→corpus class map + a keyword fallback in saturation.py; refine like negative-space.json.
**Wired into the digest (v1.3.1):** `nuke digest <target> --fork <name[,name]> --shape <s>` folds a
`🎯 VEINES VIERGES (corpus-vérifié)` section to the TOP of nuke-digest.md (VIERGE veins + detection_tell,
LABOURÉE demoted); without `--fork` the digest is unchanged (barrage auto-digest unaffected). `intake`
Phase-0 hook now says: lead the dossier with the VIERGE section when present. saturation.py exposes
`compute_saturation(sig, forks, shape, corpus)` so digest.py imports it (no dup).
**Two-column hardening (v1.4.0, from the operator's 3-lies critique):** the naive one-column filter lied
three ways — (1) too-tight vein distance → declares VIERGE a vein whose finding is phrased under another
class → digs a DUP (the costly reject); (2) conflates "nobody looked" with "looked, nothing published"
(findings corpus = positives only); (3) sells false completeness on emergent/seam veins absent from the
canonical fork. Fixes: (1) BROAD collision net (class OR keyword/ident overlap) + default toward
coverage-FP → verdict **SUSPECT** = collision candidates to REFUTE BY READING (never auto-deprioritize),
VIERGE only on zero-collision; (2) `--coverage <audit-scope-file>` = COLUMN 2 → a vein in declared scope
with no finding = **MINÉ-VIDE?** (graveyard, not virgin); VIERGE-RÉEL = intersection of BOTH voids (no
finding AND outside declared scope) — a much smaller/reliable set than "zero Solodit hit"; (3) output +
digest carry the CAVEAT: de-prioritizes the KNOWN, not a map of the territory; the 13th (integration-seam)
vein → /darkside Door-C + /upshift. `nuke digest <t> --fork <n> --shape <s> --coverage <f>`. The corpus
gives collision CANDIDATES to refute, never a "taken/not-taken" verdict.
**Vein-granular hardening (v1.5.0, backtest-judged) — the single root the operator named:** v2 made
COLLISION a retriever (right) but the 3 matchers around it still consumed the CLASS WORD, never the VEIN
→ class-coarse exactly where it had to be fine (dense classes accounting/oracle → one finding put ALL
same-class veins in SUSPECT; EXPAND synonyms hit a huge corpus slice → discriminating power INVERTED:
precise on thin classes, blind on dense = where the repo looks class-guarded and hides virgin veins).
The mechanism that distinguishes stale-oracle from spot-manip lives in the curated `money`+`tell` fields
(grep idents: get_price_no_older_than / total_shares / #[account(zero_copy)]), NOT in `vein` (that's a
routing skill) nor the label (its only token IS the class word). Fixes, all in saturation.py: (1) collision
net feeds the vein's `mech = mech_tokens(money+tell)` and SCALES with corpus density (`dense_cut` = median
class-total, self-calibrating) — dense class demands a SPECIFIC mech match; coarse vein (EVM silent_classes,
no money/tell) falls back to class-level, flagged `resolution: class-only`, NEVER force-tightened (that was
a v3.0 bug: 11/80 false-VIERGE because the label-token fallback = the literal class word, absent from
findings merely TAGGED that class); (2) coverage column uses STRICT `code_tokens` (paths/snake/camel only,
NO prose) on BOTH sides → MINÉ-VIDE? means the scope NAMED the vein's code location, "we reviewed the vault
accounting" no longer nukes every accounting vein; (3) fork-match=0 → LOUD warn (`_fork0_warn`) so a
mis-named fork's all-VIERGE reads as noise not signal; (4) `payable`/novel-label `["other"]` ANNOTATE inside
VIERGE (novel = emergent-seam, sorts FIRST) instead of demoting to a separate rank; also killed the phantom
"other"∈class_net matching "an**other**" in prose. **Backtest is the judge** (scratchpad/backtest_saturation.py,
80 documented (proto,class) pairs + 22 curated Solana veins × 5 real forks, v2-broad vs v3-specific): T1
false-VIERGE 11→0, T2 flips are TRUE virgins (zero-copy/AccountLoader vein untouched by KittenSwap emissions
findings that v2 collided by mere co-class), T3 guard fires. Honest residual: a fork with a huge finding
corpus (RegnumAurum 242) saturates specificity → v3 collapses toward all-SUSPECT — the SAFE direction; the
costly false-VIERGE is closed. Re-run the backtest after any distance-function change.
**v1.5.1 (2 more from the operator's read, one rejected by the backtest):** (a) `dense_cut` gained an
ABSOLUTE FLOOR `dense = global_total >= max(DENSE_FLOOR=25, median)` — "dense" is the absolute property
"enough findings that a class word is noise", NOT "above THIS corpus's median"; on a thin corpus (the
non-EVM slices v3 targets) the median collapses and a class goes dense for global_total≥1-2, so the
specific-ident requirement fires on a 3-finding class → a differently-phrased dup misses the exact ident →
silent false-VIERGE (demonstrated on a synthetic thin corpus: FLOOR=0→VIERGE, FLOOR=25→SUSPECT; inert on
the real solodit corpus where median=303>25, backtest byte-identical). GENERIC expanded (liquidation/premium/
reserve/governance/validator…) so surviving long words are genuinely distinctive. (b) REJECTED by the
backtest: the operator suggested the dense specific-match limit to STRICT code idents (not long words); tried
it, flips exploded 2→16 with FALSE-VIERGE on genuine dups (oracle-staleness vein → VIERGE on a fork that HAS
Pyth findings, because "Pyth"/"maxConf" aren't snake/camel idents and the vein's exact idents differ from the
finding's prose) — T1's coarse-vein recall test doesn't catch it (only curated veins hit that path). Kept
idents+distinctive-words, handled the false-discriminator worry via fuller GENERIC. Lesson: the backtest is
the arbiter even against a correct-sounding suggestion — a stricter distance reintroduced the exact costly
failure the floor exists to kill.

**How to apply:** on any new target, propose `/nuke` FIRST (before deep manual audit) — now works on
EVM AND Rust/CosmWasm/Solana/Go-Cosmos (Move/Cairo → it routes to Prover instead of faking a scan).
It is U-1 compliant — it runs scanners itself but only PROPOSES the next veine (never auto-spawns
/intake /extract /invfuzz /power /darkside /solidity-auditor, never /disclose). A tool hit is a SIGNAL
(un-executed hypothesis), never a finding: promotion requires an EXECUTED PoC — consistent
with [[feedback-invariant-that-passes-is-not-a-finding]], [[feedback-replicate-protocol-check-before-claiming-extraction]],
and the "gate opening ≠ finding" law ([[feedback-model-manipulation-cost-before-crediting-twap-finding]]).
Read the NEGATIVE SPACE section of signals.md before the hit list (maxim 2); on non-EVM it is a curated
fund-theft worklist and IS the deliverable, not the hit list.
