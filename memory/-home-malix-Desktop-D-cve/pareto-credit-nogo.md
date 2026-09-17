---
name: pareto-credit-nogo
description: "Pareto Credit (Immunefi, Idle epoch credit vaults) = measured NO-GO 2026-09-16; re-arm on impl upgrade"
metadata: 
  node_type: memory
  type: project
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-16T23:44:31.749Z
---

Pareto Credit (Immunefi https://immunefi.com/bug-bounty/pareto/scope/, Ethereum, Idle-Labs/idle-tranches). 3 in-scope epoch credit vaults, senior AA tranche only, USDC: Fasanara (CDO 0xf6223C, impl 0xdd5962, $11.9M), Bastion (0x4462eD, impl 0xf70e98 OLDER, $11.0M), Adaptive (0x14B8E9, impl 0xdd5962, $2.18M). Critical up to $50k (10% funds-at-risk cap NON-binding at these TVLs), High $20k, Med $5k; NO fee, NO KYC, PoC required. Primacy of Impact.

**VERDICT: NO-GO (measured cul-de-sac, hand-verified, 0 fee spent).** Manual bracket + gated fanout (6 finders, executed dirty-number sims). Every unprivileged in-scope money-path in the DEPLOYED bytecode proven fair. Full dossier: ~/Desktop/BUGS/pareto-audit-dossier/ (CANDIDATES.md, deployed/ verified source). Repo clone: ~/Desktop/BUGS/pareto-audit.

**Why (the decisive, hand-verified facts):**
- **All 3 vaults are MONOTRANCHE** — lastNAVBB=0, trancheAPRSplitRatio=100000 (cast-verified). No junior buffer → the entire AA/BB split + loss-socialization code is degenerate → NO misallocation surface. This collapses C1 and the senior/junior class.
- **depositDuringEpoch** enabled only on Bastion (older impl): executed Solidity-exact sim on real chain values, amounts 1wei..5M USDC → existing-holder NAV delta = 0; depositor loses ≤1 atomic unit to floor (protocol-favorable). expectedEpochInterest matches _calcInterest(lastNAVAA) to 1 unit → projection accurate, no dilution. (kills T2/T3.)
- **APR0 flow** (Fasanara live unscaledApr=0): conservation sim holds, each requester ≤ fair pro-rata, dust retained, no theft from stayers, no double-accrual. Devs explicitly test these edges.
- **PR#111 post-default vein (finalizeDefault / IdleCreditVaultWriteOffEscrow / IdleCreditVaultImpliedPrice): HEAD-only, REVERTS on the deployed proxies (cast-verified finalizeDefault → revert), absent from the 939L deployed impl (HEAD=1009L).** Out of DEPLOYED scope (deployed-code-not-head), AND post-default recovery = OOS "borrower default → freezing of funds".
- Structural hardening confirmed: _skimDonatedAssets neutralizes donation/first-depositor inflation; strategy-token _transfer locked unless manager+post-default; strat tokens minted only by CDO 1:1. Contest-farmed (Sherlock 2025-04) + heavily dev-tested; post-contest delta = correctness ADDITIONS, not regressions.
- Prior kills C1 (withdrawal-receipt-vs-default: by-design+OOS), T2, T3 all re-confirmed.

**RE-ARM conditions (this is an ON-CHAIN impl-upgrade watch, NOT the repo drift-watch — the repo already moves; the real trigger is the deployed impl swap on the proxies):**
1. A NEW impl deployed to the in-scope proxies that ADDS finalizeDefault / WriteOffEscrow / ImpliedPrice on-chain (the PR#111 recovery/haircut logic goes live) → re-audit the redistribution math.
2. A junior (BB) tranche funded (lastNAVBB > 0, splitRatio < 100000) → the senior/junior loss-split surface activates → C1/misallocation re-open.
Check via `cast call <proxy> 'lastNAVBB()(uint256)'` + EIP-1967 impl slot (tools/evm-anchor.sh). Applies [[feedback-dedup-per-sink-not-per-class]] + [[feedback-test-in-dirty-numbers]] (both baked into the fanout that ran).

---

## RE-EVAL 2026-09-17 — scope expanded 3→7 vaults; NO-GO HOLDS (re-arm conditions on-chain-confirmed NOT met)

Immunefi Pareto scope updated (Last Updated 16 Sep 2026): now **7 vault families / 27 assets** (each Contract+Strategy+LP+Queue; Queue OOS). The 3 audited (Fasanara/Bastion/Adaptive) plus 4 NEW: **FalconX, RockawayX, M1 Capital, TwoPrime.** Full deployed-pass (cast, ethereum.publicnode.com):

| Vault | CDO proxy | impl | audited-fair? | monotranche | TVL (USDC) | allowAAWithdraw |
|---|---|---|---|---|---|---|
| Fasanara | 0xf6223C…c2D5 | 0xdd5962 | yes | yes (BB=0,split=1e5) | $11.9M | true |
| Bastion | 0x4462eD…D165 | 0xf70e98 | yes | yes | $11.0M | true |
| Adaptive | 0x14B8E9…46E0 | 0xdd5962 | yes | yes | $2.18M | true |
| FalconX | 0x433D5B…be4d | 0xdd5962 | yes | yes | **$150.8M** | true |
| RockawayX | 0x9cF358…0Ec3 | 0xdd5962 | yes | yes | $22.0M | true |
| TwoPrime | 0x338e0a…90d6 | 0xdd5962 | yes | yes | $15k | false |
| **M1 Capital** | 0x7A4E72…1c06 | **0x8016e6f35a4b32a5ea4c3919418039c7daffccaf (NEW)** | **NO** | yes (BB=0,split=1e5) | $254k | false |

**Both written re-arm conditions CONFIRMED NOT MET on-chain:** (1) no impl swap — the 3 old proxies still run 0xdd5962/0xf70e98 (byte-identical to what I proved fair); (2) no funded junior — every one of the 7 is monotranche (lastNAVBB=0, trancheAPRSplitRatio=100000, BB supply=0). FalconX at $150.8M is the SAME proven-fair bytecode → more TVL, no new bug; NO-GO transfers by bytecode identity.

**The ONLY unaudited bytecode in the whole scope = impl `0x8016e6` (IdleCDOEpochVariant, 813L vs old 939L), running on M1 Capital ALONE.** Diff vs 0xdd5962: programmable-borrower feature REMOVED; a **keyring/KYC withdrawal gate ADDED** (`keyring`, `keyringPolicyId`, `keyringAllowWithdraw`; new flag `allowAAWithdrawRequest` split from base `allowAAWithdraw`; `requestWithdraw` gated at 597-604 by allowAAWithdrawRequest + `isWalletAllowed` keyring check). Default/haircut policy UNCHANGED (same "pending receipts not haircut by _lossAmount" comment, still by-design/OOS). `setKeyringParams` is `_checkOnlyOwnerOrManager` → admin-gated (owner/manager-as-actor = OOS). Manual poke: unprivileged path still gated by epoch flags + KYC; no unprivileged freeze/authz seam surfaced in the quick read.

**Verdict: NO-GO holds. The narrow re-arm that fired = "new impl on a NEW vault" (not my two written conditions), but it is MATERIALITY-THROTTLED and not worth firm effort today:** M1 TVL $254k → 10%-funds-at-risk cap ≈ **$25k** ceiling even for a Critical (below $50k max), AND allowAAWithdraw=false (main AA money-path disabled), AND the new code is a refactor of the Sherlock-contest-farmed family I already measured fair. Per [[feedback-no-dubious-low-submissions]] + Maslow guard: don't force a GO because something finally looks fresh.

**CORRECTED re-arm (drift-watch M1 0x7A4E72…1c06 + impl 0x8016e6):** re-arm iff (a) M1 TVL crosses ~$500k (10% cap unbinds → Critical can reach $50k), OR (b) allowAAWithdraw flips true (AA withdrawal money-path opens), OR (c) impl 0x8016e6 gets deployed to a high-TVL vault (an even-newer vault batch already exists at block 25953651, not yet in scope — watch for it). If re-armed, targeted delta-audit of 0x8016e6 ONLY (instant-withdraw path, the allowAAWithdraw-vs-allowAAWithdrawRequest two-flag seam, removed programmable-borrower), NOT a 7-vault fanout (6/7 are proven-fair bytecode = wasted spend).
