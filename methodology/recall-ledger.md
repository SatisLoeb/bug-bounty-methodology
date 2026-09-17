# Recall Ledger — the missing loss term (2026-09-17)

**What this is.** The method's loss function had only a precision term (don't submit a bad finding). Its
trivial optimum is the empty set: reject everything → precision perfect, recall zero, nothing penalizes
recall. This ledger is the **recall term with teeth**. It exists to make my NO-GOs *wrong visibly* — the
opposite of a monument to prudence. It is a MEASUREMENT organ, not a filter (it emits no accept/reject; it
records what I abandoned and later confronts it with reality).

**The invisible error it targets.** A false NO-GO — abandoning a real bug — leaves no corpse by construction.
You cannot measure the bug you did not look for. The only external signal that a NO-GO was false is: **someone
else finds a bug on a target you recalled.** So this ledger records, per NO-GO, the *specific attack-hypotheses
I generated and killed*, and cross-checks them against public findings on those same targets. A hit is a
**recall-corpse**, of two species:
- **generation-gap** — the found bug is a hypothesis I NEVER generated → I was missing a *generator* → feeds a
  win-seed / a new generative organ (this is the signal the whole reframe needs).
- **gate-error** — a hypothesis I DID generate but killed wrongly → a gate needs re-calibration (a normal corpse).

## Discipline (per NO-GO, non-negotiable)
1. A NO-GO is not admissible as "I found nothing." It is admissible only with a **kill-list**: the concrete
   attack-hypotheses generated, and the executed artifact that killed each. "Absence of a positive attempt" is
   not a NO-GO; it is an un-hunted surface. (This gives the NO-GO a cost: you must have *generated* to recall.)
2. Append the row here at NO-GO time. The memory file holds the narrative; this holds the falsifiable kill-list.
3. Cross-check on a cadence (`recall-check.sh` prints the worklist): for each open row, scan
   reports.immunefi.com / competition results (Cantina, Sherlock, Code4rena) / cat-2 disclosures for a finding
   on that target. Honest limit: most findings are private → signal is sparse. Sparse > zero, and it is the ONLY
   recall signal that exists.
4. On a hit → move the row to **Recall Corpses**, classify generation-gap vs gate-error, and name the generator
   or gate it implicates. That is the output that feeds the generative spine.

---

## Open NO-GO rows (target · date · kill-list = hypotheses generated & how each died · flip-condition)

| target | date | kill-list (generated → killed by) | flip |
|---|---|---|---|
| Euler EPO ([[euler-epo-drift-nogo]]) | 2026-09 | nanosecond oracle-adapter drift → 1e9 conversion is fail-safe (executed); evk-periphery vector → OOS except Securitize | fresh consensus FIP / new adapter that fails unsafe |
| Pareto Credit ([[pareto-credit-nogo]]) | 2026-09 | NAV-split extraction → all 3 monotranche lastNAVBB=0, no split surface; deposit/APR0 timing → executed-fair; PR#111 default-vein → HEAD-only, reverts on deployed | M1 TVL>~$500k OR allowAAWithdraw flips OR impl 0x8016e6 on a high-TVL vault |
| Pendle Boros ([[boros-evmfork-nogo]]) | 2026-09 | theft-math → permissioned; mark-rate manip → risk-accepted; unpriv surface → clean (evmfork) | new core logic |
| TermMax ([[termmax-termstructure-nogo-saturated]]) | 2026-09 | badDebt / gt-theft / slippage → covered by ~150-finding audit + 19 paid reports (fresh-slice closed) | a NEW money-path asset |
| infiniFi ([[infinifi-delta-nogo]]) | 2026-09 | High/Crit on enabled assets → USDC/RLUSD only, YieldSharing V3 gated, zap router-whitelisted | Outland position grows |
| Sky ([[sky-fresh-surface-audit]]) | 2026-09 | diamond-PAU facet vectors → form-null in prod (Grove PAU empty), not audited @scope-commit; core+RateLimits → OOS | async/AMM facets funded |
| Filecoin ([[filecoin-immunefi-nogo]]) | 2026-09 | hardened core; only seam-meets-high = go-f3 F3↔EC | fresh consensus FIP |
| Pyth ([[pyth-network-audit]]) | 2026-09 | SC/oracle → fortress; web seam → static Vercel SPA, no /api/XSS surface; #2 cool_off=0 on-chain | new on-chain consumer of the drifted value |
| Lombard EVM+Solana ([[project-lombard-finance-audit]]) | 2026-09-17 | P1 bridge↔Bascule → supply-neutral/OOS; P4 epoch-freeze → retryable; P7 cross-lang decode → round-trip-hash canonicalizes; A1 deployed drift → defense-in-depth, consortium-gated | new Mailbox handler / impl upgrade (fresh-surface-watch) |
| Coinbase venue ([[coinbase-venue-exhausted]]) | 2026-09-17 | 6 targets, 0 findings: spend-permissions P2 (cross-chain replay→Solady live-rebuild, batch-uniq→documented, nonce→2^64); recovery-signer/echo/eip7702/commerce/flywheel all fortress | a NEW Coinbase-deployed contract |
| Strata ([[strata-immunefi-resource-only-critical-pays]]) | 2026-09 | deployed periphery → clean; AccountingLib+RoundingGuard → not deployed ($0) | Critical anchored to deployed bytecode / AccountingLib deploys |

## Recall Corpses (grows when I am proven wrong — the anti-prudence section)

**RC-01 · Lombard · 2026-09-17 · species: GENERATION-GAP (narrowness), not a missed tier.**
- **Public findings:** the Lombard Immunefi *competition* (reports.immunefi.com/lombard, IDs 38xxx) — 0 Critical,
  0 High, **6 Medium**, 4 Low, 10 Insight.
- **What my verdict got right (positive recall):** the crowd also found NO Critical/High. My "no payable-for-me
  Crit/High" was not a false-fortress on the tier that matters. And a hypothesis I *did* generate (epoch-rotation
  invalidates in-flight proofs) surfaces only as **Low 38344** — I killed it "retryable/freezes-nothing"; crowd
  rated Low → gate ~calibrated.
- **The corpse:** the 6 Mediums are in surfaces I **never generated one hypothesis against**: ProxyFactory
  DoS/address-hijack (38066), PartnerVault mint-depeg (38335), CLAdapter offchain-data validation (38154),
  cross-chain-transfer DoS (38363), **offchainTokenData interchange between two valid messages (38342)** — a
  P2/P7 message-binding class but on the Chainlink-CCIP path I dismissed, *outside* the consortium round-trip-hash
  I analyzed. I went DEEP on the mint-authorization core (P1/P4/P7) and never ENUMERATED the periphery.
- **Generator it implicates (added to the spine):** **breadth / surface-enumeration** — before going deep on the
  chosen core primitive, enumerate EVERY attack-surface class the target exposes (factory, vault, adapter,
  cross-chain-transfer, non-consortium/off-chain message fields, …) and generate ≥1 hypothesis per surface. Depth
  without breadth is a structural generation-gap. See `generative-spine.md` generator #8.
- **EV caveat (no over-claim):** these are Mediums, now competition-dups (public) and, on Lombard's fee program,
  fee-negative → not lost revenue. The corpse is about *narrow generation*, not a lost payout. Still a real catch:
  the instrument turned an invisible false-narrowness into a named missing generator on its first live run.

*(Open sources still un-checked for the other rows: euler/pareto/pendle/etc. had bounties not comps → no public
comp findings, so the recall signal is silent (not clean) for them. Stacks-I/II attackathons exist on
reports.immunefi.com → check when Granite work resumes.)*

---
*Maintain: a NO-GO without a kill-list is not a NO-GO, it is an un-hunted surface — do not file it here.
The ledger's health metric is not how clean it stays; it is how many recall-corpses it eventually catches.*
