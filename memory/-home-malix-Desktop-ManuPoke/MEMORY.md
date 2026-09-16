# Memory index

## 🔴 LIVE — needs operator action (read the file before acting)
- [Royco Day (Cantina $30k)](project-royco-day-intake.md) — **MEASURED NULL on surviving in-scope impacts (last day 2026-08-17). Don't re-audit w/o NEW surface.** Only finding = entrypoint reentrancy, SUBMITTED but OOS by Aug-11 PR#24 fix (grandfathered), under likelihood appeal = the one live lever. Scope narrow (funds-to-non-whitelisted / permanent-lock only); no whitelist in code, blacklist screening complete, NAV conserved. 8-finder sweep + full manual read converged null; the one real mechanism (JT-IL grace erasure) is OOS+by-design. [[feedback-findings-die-on-the-actor-not-the-mechanism]]
- [Abercrombie & Fitch H1 intake](project-abercrombie-fitch-h1-intake.md) — **CLOSED 2026-07-29, NO payable finding, nothing submitted. Don't reopen without a NEW surface.** Scope = **4 BARE hostnames, NO wildcard** ⇒ `*.anfcorp.com` estate OOS. Android bridge cluster PROVEN in smali (substring allowlist + dead compensating rewrite + no host check → `"Android"` bridge → ~50 routes) but **delivery REFUTED by 5 executed trials**; the open redirect that would have supplied it **does not exist** — `redirectUrl` is validated on the document-nav path (control `/shop/bag` survives, `https://` and `//` rewritten). Emulator+patched-APK harness reusable (`anf_poc`, sslip.io = no root). Cap $4k, ~5% pay. ~/Desktop/BUGS/anf-2026. [[feedback-carveout-does-not-prove-wildcard]]
- [Wolt HackerOne intake](project-wolt-hackerone-intake.md) — **GO-NARROW, 2026-07-29, NOT engaged.** 17 assets not 7 (`*.wolt.com` + 4 Tier-1 apps). "0 resolved" = 6-day queue NOT freshness (suspended Intigriti predecessor ate 862 subs; both gag disclosure ⇒ dedup-by-zero not executable). Seam = single-issuer JWT → ~30 hand-written service edges, no OIDC doc, `aud:[]` client-supplied at mint. Marker header `X-HackerOne-Research` MANDATORY. ~/Desktop/BUGS/wolt-2026. [[feedback-report-count-distribution-picks-the-asset]]
- [ozzydz.com = DIRECT CLIENT](project-ozzydz-direct-client.md) — **report DRAFTED 2026-07-26, NOT delivered.** Pre-launch static landing (Hostinger, FR/EN/AR). Value = site-says-X/does-not-X: 6 forms `action="#"` → 100% lead loss; privacy policy asserts collection that doesn't happen; DMARC p=none + SPF missing their MX; `ozzydz.dz` free. `.git` 403 = VCS-name rule NOT a repo. ~/Desktop/ManuPoke/ozzydz-fresh. [[feedback-payable-impact-not-just-theft]]
- [1win F-004 postback SSRF](project-1win-postback-ssrf.md) — **SUBMITTED 2026-07-26 → CLOSED DUPLICATE #3643826. $0. Program now 2-for-2 on duped HIGHs (F-001 dup #3328634 too) ⇒ SATURATED, don't re-engage on surface-cleanliness alone.** The "0 reports" on `1w.run` counted RESOLVED not submitted; asset added 2026-02 = 5 months open. Only live axis = **B-001 APK builder: the `verificationStatus`/`apkAvailable` gate is a PRODUCT gate, testable in ONE request**; `jobId` authz separately OPEN. ~/Desktop/BUGS/1win-audit. [[feedback-report-count-distribution-picks-the-asset]]
- [StackingDAO ststxbtc double-count](project-stackingdao-stbtc-double-count.md) — **DEAD CHANNEL: program REMOVED from Immunefi 2026-07-26 → no payable venue. Do NOT propose firing it.** Finding real+PoC-proven (escaped-guard, 2× yield + reserve DoS); disclosure-only value. ~/Desktop/BUGS/stackingdao-2026.
- [Aurora Launchpad rollback desync](project-aurora-launchpad-withdraw-rollback.md) — **REAL in 0.5.1 but FIXED in 0.6.0 (#98) → DEAD, don't submit blind.** NEAR/Calyx stale-snapshot → over-allocation. Only payable = live 0.5.1 w/ TVL. [[feedback-diff-forward-to-head-not-just-scope-changelog]]
- [Perena/Bankineco #83 = REJECTED 2×, CLOSED](project-perena-bankineco-intake.md) — junior instant-unstake "stale share_price"; loss-acceptance trusted-signer-gated (`losses_accepted=0`). Don't relitigate. [[feedback-model-accounting-invariant-not-economic-ideal]]
- [Injective #134 BFF authz = REJECTED 3× + mod-escalation CONFIRMED-DEAD](project-injective-134-bff-authz-not-patched.md) — `granterAddress` mints `sub=victim` off MsgBatchUpdateOrders grant. Path still LIVE 2026-07-24. Cantina mod escalated to team+client 2026-07-27 → identical "non-issue". BOTH venues exhausted, no payable path. Don't re-appeal, don't re-ping mod, don't relitigate.
- [Kuru CLOB+AMM-vault (Monad)](project-kuru-monad-intake.md) — **vault EXECUTED-NULL (PoC), RE-SOURCE.** Conservation held EXACTLY (net 0); deposit sandwich = −90k. ~/Desktop/ManuPoke/kuru-fresh. [[feedback-invariant-that-passes-is-not-a-finding]]
- [Doppler Rehype F-01 = Cantina #784 REJECTED](project-doppler-rehype-intake.md) — **closed on POLICY ("deployer responsibility"); mechanism conceded. Don't relitigate.** Root cause = the ACTOR.
- [Morpho bounty (Cantina $2.5M)](project-morpho-intake.md) — **RE-ENGAGE ONLY ON *MIDNIGHT***. 2 findings WITHDRAWN ($0). 27-audit fortress. ⚠ Scope pre-writes the Doppler killer ⇒ hunt ESCAPED-guard only. ~/Desktop/BUGS/morpho-*.

## Nulls / fortresses (don't re-audit)
- [Decentraland Immunefi ($500k) full engagement](project-decentraland-immunefi-full-engagement.md) — **BOTH scopes EXHAUSTED by own surface-by-surface audit (18 SC surfaces + web). #87537 = the one WIN (Confirmed Crit, pending pay, HOLD-don't-poke).** Web seam hardened program-wide (6 backends → crypto-middleware 6.3.0, diff-forward killed the folded-key sibling). SC fortress; only F2 (Estate operator-persist, Low+dup). CreditsManager cashout = actor-trap (bounded-by-credit). Fetched Bid/Rentals/Names/Vesting source (not cloned) via standalone repos + Blockscout. ~/Desktop/BUGS/decentraland-immunefi-audit. [[feedback-diff-forward-to-head-not-just-scope-changelog]]
- [Granite oracle xseam (Stacks $100k)](project-granite-oracle-xseam-null.md) — MEASURED NULL. HEAD=Pyth-Lazer UNSHIPPED; deployed=Pyth-Core; decoder=Trust-Machines stock. Fetch DEPLOYED source before depth. RE-SOURCE (web frontend only fresh, off SC-edge). [[feedback-commit-anchored-scope-pays-deployment-impact]]
- [sBTC upshift seam (Stacks $250k)](project-sbtc-upshift-seam-null.md) — MEASURED NULL, 10 kills. Emily=non-authoritative cache, re-derive-on-own-node uniform; reorg races OOS (miner-coop ≥3-6 blk). RE-SOURCE. WSTS+Clarity-core undrilled/saturated. [[feedback-findings-die-on-the-actor-not-the-mechanism]]
- [Horizen ZenStaker](project-horizen-zenstaker-executed-null.md) — EXECUTED-NULL → NO-GO. Wrapper over audited Tally Staker; 358 new lines, principal safe BY CONSTRUCTION. [[feedback-measure-state-delta-over-audited-base-at-intake]]
- [Hermetica hBTC (Stacks)](project-hermetica-hbtc-intake.md) — **NEAR-MISS, DON'T SUBMIT = PERENA #83 REDUX (actor-trap).** PoC passes but BUILT the state = the tell. Run the ACTOR gate BEFORE PoC. [[feedback-findings-die-on-the-actor-not-the-mechanism]]
- [Zest Protocol V2 (Stacks)](project-zest-v2-intake.md) — HARDENED FORTRESS every payable axis → RE-SOURCE. ~12 executed kills; residual OOS-walled. Clarity+Hiro tooling retained. [[reference-stacks-bugbounty-landscape-2026-07]]
- [Treehouse tETH](project-treehouse-teth-intake.md) — PROVEN-then-KILLED by prior art (team's OWN audit repo, WatchPug EtherFi WP-I4). Grep vendor audit repo BEFORE PoC.
- [LI.FI (EIP-2535 diamond)](project-lifi-intake-oos-gutted.md) — SC scope OOS-GUTTED → RE-SOURCE; EV = web/API (li.quest). Fund facets = pass-throughs to external settlers.
- [Circle xReserve F-01 + Gateway](project-circle-xreserve-f01-drain.md) — KILLED. Reserve-drain seam real but devs document it off-chain-mitigated ⇒ known-issue. Gateway null.
- [Circle CCTP Solana V2](project-cctp-solana-v2-executed-null.md) — hand-verified NULL. Deployed==HEAD. [[feedback-check-prior-audits-and-competitions-at-intake]]
- [Ammalgam DLEX](project-ammalgam-fresh-executed-null.md) — EXECUTED-NULL (7 fork artifacts). Killer: live externalLiquidity ≈310× internal. [[feedback-trigger-reachability-is-payability-gate]]
- [Berachain staking-pools](project-berachain-staking-pools-intake.md) — EXHAUSTED → NULL. Triggers unreachable: no slashing + 72h gate > 27.4h CL arrival. [[feedback-window-finding-measure-both-bounds]]
- [OnRe Solana reinsurance](project-onre-solana-executed-null.md) — Immunefi $100k. Core CLEAN; front-run REFUTED on-chain.
- [Olympus DAO](project-olympus-immunefi-executed-null.md) — $3.33M theft-only fortress → NO-GO. Conservation-dead. [[feedback-check-prior-audits-and-competitions-at-intake]]
- [Flare FAssets FXRP](project-flare-fassets-executed-null.md) — near-fortress xseam NULL. consumed-once proven; 4 writers balanced.
- [Superform v2-periphery](project-superform-v2periphery-executed-null.md) — xseam NULL. Every PPS move funnels ONE `_validateStrategyState`.
- [OKX program](project-okx-smartwallet-executed-null.md) — EXECUTED-NULL. 8/8 seams KILL; Boost-Solana double-claim REFUTED.
- [Meteora DBC/DAMM-v2](project-meteora-dbc-damm-intake.md) — fortress NULL. Top lead FP [[feedback-anchor-access-control-attribute]].
- [STBL](project-stbl-fortress-executed-null.md) — RWA tranching fortress NULL. Cyfrin 0-High.
- [Midas Solana](project-midas-solana-executed-null.md) — gate-passed NULL. 5 crown jewels pierced; 1 defect OOS.
- [Loopscale /solfork](project-loopscale-solfork-intake.md) — CORE EXECUTED-NULL, CLOSED. **DON'T re-open.**
- [Across svm_spoke](project-across-svmspoke-intake.md) — on-chain CORE fortress. Spoof = OFF-CHAIN relayer.
- [Jupiter SC allocation](project-jupiter-bounty-sc-allocation.md) — Lend/JupUSD fortress; freshest = JupUSD-as-JLP RedStone-$1 vs oracle.
- [Arcadia Finance](project-arcadia-fortress-executed-null.md) — 10-audit fortress EXECUTED-NULL. 10 surfaces + 3 seams REFUTED.
- [Rheo/Very Liquid Vaults](project-rheo-veryliquid-intake.md) — EXECUTED-NULL. Fresh surfaces null, core 10-audit fortress.
- [Symbiotic RWA-layer](project-symbiotic-rwa-layer-oos.md) — adapter-freeze = HARDENING not payable. No reachable trigger → DON'T SUBMIT.
- [Valantis STEX](project-valantis-stex-fortress.md) — 4-audit fortress NO-GO. stHYPE rebase 1:1 conserved.
- [Stackup Keystore](project-stackup-keystore-fortress.md) — 428-swept fortress SKIP. Flagged seam resolved #26/#38.
- [Makina bridge/AUM](project-makina-bridge-aum-exhausted.md) — executed-NULL untrusted. Build FOUNDRY_PROFILE=ir.
- [Boros on-chain core](project-boros-onchain-core-3vein-null.md) — 3-vein null. RE-SOURCE to off-chain relayer.
- [Mezo NUKE triage](project-mezo-nuke-triage.md) — musd=Liquity-fork, mezod=Cosmos-EVM. 0 theft.
- [Cronos VVS](project-cronos-vvs-bounty-fork-graveyard.md) — fork graveyard NO-GO. 6 Veno decompiled, 0 survivors.
- [Phantom on-chain](project-phantom-onchain-noncustom.md) — non-custom (spl-stake-pool / Token-2022). RE-SOURCE off-chain.
- [Injective Peggy + oracle-lens](project-injective-peggy-exhausted.md) — exhausted; deployed==C4-audited. WATCH: re-engage only when v1.20.0 deploys 0x67 EVM precompile live.
- [USDai/sUSDai](project-usdai-intake.md) — C1 PROVEN but OOS. Killed by exclusion clause 1 [[feedback-read-both-or-clauses-in-exclusions]].
- [Push Chain DualDefense](project-push-chain-dualdefense.md) — closed. F-A01 SVM unbacked-mint Crit (3 PoCs), F-B01 TSS drain High, both operator-gated.

## Landscape / references
- [Stacks landscape (post-StackingDAO)](reference-stacks-bugbounty-landscape-2026-07.md) — Zest V2 fortress-null; Granite $100k but KYC-WALL; Stacks-L1 = consensus wrong-edge. Immunefi `/scope/` not WebFetch-able → use `/information/`.
- [Nado = Vertex fork](project-nado-vertex-fork-intake.md) — **EXECUTED-NULL FORTRESS-FORK.** HackenProof $500k Ink. Oracle-freeread DEAD (Vertex sequencer-price). Residual = OffchainExchange diff (low EV). [[feedback-oracle-replay-refute-first-reflex-fix]]
- [NEAR Intents re-pointed-lens](project-near-intents-repointed-lens-intake.md) — HackenProof $500k. cross-standard/WebAuthn replay REFUTING at core. Residual: pubkey→signer_id binding + 4 unread adapters. NOT exhausted. [[feedback-oracle-replay-refute-first-reflex-fix]]
- [Cantina /solfork-vein targets](reference-cantina-solfork-targets-2026-07-21.md) — pump.fun $500k dup-gated; Perena $25k done.
- [Fresh-target solfork niche](reference-landscape-solfork-niche-2026-07-21.md) — 18-cand; Loopscale=null, 2nd Metric/Zynk.
- [Landscape scan 2026-07-21](reference-landscape-scan-2026-07-21.md) — 33-agent. Tier-1: Hermetica hBTC, Stackup, Midas. [[feedback-check-prior-audits-and-competitions-at-intake]]
- [Cantina /nuke triage 2026-07](project-cantina-nuke-triage-2026-07.md) — top fresh EVM = Makina/Rheo/Boros; mega=diff-only.
- [Arsenal vs Immunefi SC Top-10 map](reference-arsenal-vs-immunefi-top10-coverage-map.md) — DEEP: V02/V06 math + V04 authz. Refute-only: V03 oracle + V05 replay.

## Feedback — hunting discipline
- [D-DUP gate: asset DWELL before depth](feedback-ddup-gate-asset-dwell-before-depth.md) — **the gate stack judges if a finding is GOOD; none checks if it's FIRST.** Blocking pre-engagement check: dwell (`date_added`, ≥60d ⇒ presumed already filed) + executed prior-art sweep + obviousness rank. Killed 1win F-004 retroactively (dwell 158d, rank-1 surface). A template in `findings/` is NOT a gate that ran — grep its artifact for the target name.
- [Measure the STATE delta over the audited base at intake](feedback-measure-state-delta-over-audited-base-at-intake.md) — wrapper targets: count new money-path state + by-construction vs by-check, BEFORE depth. Near-zero new state = near-zero payable surface.
- [Rabat-joie triager judges, doesn't rewrite](feedback-rabat-joie-triager-judges-not-rewrites.md) — killjoy = deliver VERDICT + downgrade angles then STOP; don't edit the operator's report.
- [Consult operator BUGS corpus first](feedback-consult-operator-bugs-corpus-first.md) — grep ~/Desktop/BUGS for prior kill BEFORE re-deriving; hunt seam not classes.
- [Report-count distribution picks the asset](feedback-report-count-distribution-picks-the-asset.md) — **CORRECTED 2026-07-29: the count is RESOLVED reports = queue latency, NOT freshness.** Rank by `date_added DESC` first; window is WEEKS not months. 1win duped on BOTH the 91% asset and the "0-report" one ⇒ a dup is a calendar outcome, not a skill outcome.
- [Check prior audits + competitions at INTAKE](feedback-check-prior-audits-and-competitions-at-intake.md) — every "fresh" pick was MORE audited than scanned. Grep audits/, prior contests, subs-vs-paid.
- [Diff FORWARD to HEAD, not just scope changelog](feedback-diff-forward-to-head-not-just-scope-changelog.md) — dup-check by diffing tag→HEAD + newer tags; a later `fix:` naming your bug = dead. Only survivor = live vulnerable deploy.
- [Map severity to program's OWN rubric](feedback-map-severity-to-program-rubric.md) — pull defs verbatim FIRST, map to their clause; under-claim symmetric to overclaim.
- [Read BOTH "or"-clauses in exclusions](feedback-read-both-or-clauses-in-exclusions.md) — broad first clause swallows the finding before the narrow one opens. Record verbatim.
- [Dedup defense = reproducible negative-space](feedback-dedup-as-reproducible-negative-space.md) — cite audited commit + grep-count=0 + quote scope enumeration. Triager re-runs your zero.
- [Under downgrade, pivot to defender's OWN artifacts](feedback-under-downgrade-pivot-to-defenders-own-artifacts.md) — when they attack your most-interpretable leg, re-anchor on the leg backed by THEIR own prod txs/keeper/state, which they can't requalify.
- [Trigger-reachability is the payability gate](feedback-trigger-reachability-is-payability-gate.md) — real mechanism w/o REACHABLE adverse trigger = hardening. Green PoC proves propagation not reachability.
- [A window has TWO bounds — measure both](feedback-window-finding-measure-both-bounds.md) — window/race finding ⇒ MEASURE both bounds at substrate. TELL: PoC injects/withholds a value = the unmeasured bound. [[feedback-trigger-reachability-is-payability-gate]]
- [Model the ACCOUNTING invariant, not the economic ideal](feedback-model-accounting-invariant-not-economic-ideal.md) — write the invariant as the protocol's booked/accepted-state promise; explicit accept/book gates DEFINE the boundary. Killed Perena #83.
- [NO-GO ≠ no payable bug — impact-ledger first](feedback-payable-impact-not-just-theft.md) — sweep perma-freeze/insolvency/gov-takeover/griefing/liveness/deanon before NO-GO.
- [Today-impact before PoC](feedback-today-impact-before-poc.md) — check live reachability+value (one cast call) BEFORE PoC. Q5b gate.
- [Manual poke is a mandatory bracket](feedback-manual-poke-mandatory-bracket.md) — apparatus-OFF poke FIRST (one input, zero machinery); skills package AFTER.
- [Corpus isn't 100% — poke finds unnamed surface](feedback-corpus-not-100-percent-poke-finds-unnamed-surface.md) — bug is an indirection OUTSIDE the corpus. Poke=discovery FIRST.
- [Hunt, don't narrate EV](feedback-hunt-dont-narrate-ev.md) — HUNT high-EV now, don't list as to-do.
- [Tool-complete → stop polishing](feedback-tool-complete-stop-polishing.md) — a probe hardened past its payable target is DONE. Go execute a vein you CAN run.
- [Model window actors at day one](feedback-model-window-actors-day-one.md) — accumulate-a-position finding: ask FIRST if a rational MEV/liquidator profitably resets it.
- [Model manipulation cost before crediting TWAP](feedback-model-manipulation-cost-before-crediting-twap-finding.md) — execute attacker's slippage COST not just payoff; gate opening ≠ finding. (ONLY move-a-price.)
- [Oracle/replay refute-first reflex fix](feedback-oracle-replay-refute-first-reflex-fix.md) — cost-free/off-chain checklist BEFORE manip-cost/nonce gate; re-aim manip at single-pool oracles, nonce at off-chain signers. Mostly MEDIUM.
- [Replicate protocol check before claiming extraction](feedback-replicate-protocol-check-before-claiming-extraction.md) — value raw internal-fn output the protocol's way + replicate the guard.
- [Execute the central link](feedback-execute-the-central-link.md) — proving the two ENDS = hand-assembly; run the REAL middle component + assert the linking artifact.
- [Invariant-that-passes is not a finding](feedback-invariant-that-passes-is-not-a-finding.md) — green invariant = fortress-proving; construct the theft + observe the delta.
- [Mechanism conceded, finding dies anyway](feedback-findings-die-on-the-actor-not-the-mechanism.md) — TRIANGLE: actor≠victim ∧ actor≠authority-over-damaged ∧ creates+HOLDS state. **Absent-guard dies on "configure it right"; prefer ESCAPED-guard.** TELL: PoC BUILDS the state = built.
- [Never generalize a revert-claim from ONE call shape](feedback-never-generalize-a-revert-claim-from-one-call-shape.md) — sweep exact-in/out × both directions × dust/whale vs a CONTROL twin; model whose balance the guard reads. Flipped Doppler F-01.
- [Separate and attribute, don't amalgamate](feedback-separate-and-attribute-not-amalgamate.md) — never bundle two effects as one; characterize loss on ALL external paths first.
- [Commit-anchored scope pays deployment-impact](feedback-commit-anchored-scope-pays-deployment-impact.md) — devnet-only = fact about today's balances, not a severity cap. Verify HEAD==scope-commit.
- [Research landscape before build decision](feedback-research-landscape-before-build-decision.md) — extending tooling? map+verify option space FIRST.

## Skills / tooling notes
- [NUKE static-barrage skill](project-nuke-static-barrage-skill.md) — `nuke <target>` auto-detects eco → signals.md; `nuke diff` post-audit-drift.
- [Halmos bounded-proof skill](project-halmos-bounded-proof-skill.md) — `hprove`/`/halmos` fuzz→Halmos→Certora; refuses vacuous green.
- [Halmos NIA wall → decompose into ceil lemmas](halmos-nia-wall-decompose-ceils.md) — yices/z3 timeout on AMM mulDiv; prove constant-denom ceil legs, compose sqrt.
- [NUKE Rust toolchain-pin gotcha](project-nuke-rust-toolchain-pin-gotcha.md) — CosmWasm/Solana pins break cargo-audit/deny/geiger; NUKE forces RUSTUP_TOOLCHAIN=default.
