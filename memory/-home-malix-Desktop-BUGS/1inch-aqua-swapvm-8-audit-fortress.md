---
name: 1inch-aqua-swapvm-8-audit-fortress
description: "1inch Aqua/SwapVM (Immunefi $100k) — NOT a fresh virgin; 8 audits (OZ 53 findings + Bailsec/Hashlock/Hexens/MixBytes/Nethermind/Theori/Decurity). Fortress-tier, RE-SOURCE."
metadata: 
  node_type: memory
  type: project
  originSessionId: f1a1c109-bacb-4d9a-86f8-2aa9c53f2da9
  modified: 2026-08-15T15:23:25.816Z
---

**1inch Aqua / SwapVM** (Immunefi $100k, Live 11 Jun 2026, triaged, KYC). Repo `github.com/1inch/swap-vm`, scope = latest tag **v1.0.2** (26 Jul 2026, commit 32c687c); clone at `~/Desktop/BUGS/swap-vm`. Aqua = shared-liquidity layer across 13 chains; SwapVM = a bytecode VM for maker swap strategies (opcodes/instructions, `runLoop` interpreter, MakerTraits/TakerTraits bit-packed, XYCSwap/PeggedSwap/Decay/Fee instructions).

**MIS-RANK CORRECTION (2026-08-15):** I pitched Aqua as "fresh virgin seam, low saturation" — FACTUALLY WRONG. It has **8 independent audits** (OpenZeppelin, Bailsec, Hashlock, Hexens, MixBytes, Nethermind, Theori, Decurity). OZ report alone (`openzeppelin.com/news/1inch-aqua-and-swapvm-mvp-v1.0-audit`, final commit b2daef8 = v1.0.0) = **53 findings** (3 Crit / 2 High / 12 Med / 16 Low): ALL Crit/High FIXED, most Med/Low acknowledged-by-design. Fortress-tier. `P(class-bug survives 8 audits) ≈ 0`. **Phase-0 lesson: check audit coverage (count + firms) BEFORE ranking a "fresh" target — a 2-month-old product can be one of the most-audited ever (1inch funded 8).**

**Residual angles (narrow, likely dead):** (1) PeggedSwap/PeggedSwapMath = site of fixed C-01 (precision-loss quadratic solve()) + C-03 (axis-mismatch pool drainage), and the v1.0.0→v1.0.2 delta touches exactly Fee(+81)/PeggedSwap+Math(+42)/Controls(+14)/AquaOpcodes(+5) = audit-fix code (weakest per incomplete-fix playbook) — BUT re-reviewed by 7 post-OZ audits incl. Theori. (2) M-03 `Calldata.slice` underflow (begin>end → arbitrary calldata read) acknowledged-not-fixed "relies on strategy pre-validation" — in-scope only if a TAKER-reachable path (not maker program) drives a negative-width slice. Both low-EV given 8-audit coverage.

**Acknowledged-not-fixed = tombstones** (M-01/M-02 Aqua, M-03 Calldata, M-09/M-10 Fee, L-05/L-06/L-08) — dead by the known-issues OOS clause or dep-OOS. AI-auditor baked into repo (`.agents/skills/solidity-auditor`) → V12-class dupe-risk high.

**Whole 1inch ecosystem = saturated** (SC $500k nulled today [[1inch-immunefi-crosschain-solana-fresh-surface-null]]; Aqua 8-audit; Wallet/Web/Infra/Aqua-Improvement all triaged-mature). **RE-SOURCE off-1inch.** Re-open Aqua ONLY on a new tag with a substantial non-fix delta. Related: [[feedback-depth-is-an-edge-only-where-ore-remains]], [[feedback-audit-acknowledgment-is-a-liability-not-an-asset]], [[protocol-fortress-null-hunt]].
