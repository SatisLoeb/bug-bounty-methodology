---
name: project-lifi-intake-oos-gutted
description: "LI.FI (lifinance/contracts, EIP-2535 diamond, 48 facets) — SC scope OOS-gutted + fully-audited fortress; EV = web/API (li.quest) where prior 2026-07-05 HARNESS-SUSPENDU lives"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1cddd5e1-a775-4c40-bc31-1244e19cbfd8
---

**LI.FI** — cross-chain aggregation, EIP-2535 diamond, 48 facets (bridge+DEX). Repo github.com/lifinance/contracts, src/* in scope. Website+webapp also in scope: scan.li.fi, li.fi, portal.li.fi, li.quest/*. Fresh clone ~/Desktop/ManuPoke/lifi-fresh/repo (HEAD 07d9674). Core SC payout $100k-$1M Crit (capped 10% of impacted). Prior engagement 2026-07-05 = the ORIGIN of the HARNESS-SUSPENDU terminal verdict (surface reachable but needed out-of-band capability = test-env/creds/session; solo read, no specifics recorded).

**INTAKE VERDICT: SC scope = OOS-GUTTED FORTRESS → RE-SOURCE on-chain. Real EV = web/API (li.quest).**

The KILLER OOS clauses (why on-chain SC is thin):
- **"Self-Crafted Calldata Risks OOS"** — contracts designed for BACKEND-generated calldata; manual calldata that bypasses protocol-level safety checks (intentionally excluded for gas) = OOS. **This kills LI.FI's CLASSIC attack class** — arbitrary swap/bridge calldata → approve/transferFrom drain = the exact 2022 ($600k) + 2024 ($10M) incident class. Now explicitly OOS.
- **"Idle Fund Access in LiFiDiamond OOS"** — diamond not meant to hold funds; moving residual/dust = expected.
- **Every facet is AUDITED** (auditLog.json + auditedContracts mapping; LI.FI process mandates audit-per-facet pre-deploy). No unaudited-fresh-facet gap. 48/48 tracked.
- **Fund-holding facets are PASS-THROUGHS to EXTERNAL settlers**: LiFiIntentEscrowFacet(V2) → external OIF Input Settler (deposits on behalf of user w/ user as refund addr); RelayDepositoryFacet → Relay depository; ReceiverOIF periphery. The escrow doesn't rest in the diamond → third-party (OOS) or pass-through.
- **Impact bar HUGE**: Crit = 50-100% of DAILY total user transfers across ALL EVM chains; Med = 0.5-20%. A single-user theft won't clear the % bar unless systemic.
- Third-party protocol issues OOS; acknowledged-audit-issues OOS; Lightchaser OOS; reentrancy-with-safeguards OOS.

Net: the payable on-chain surface = a bug harming users via NORMAL backend calldata (not self-crafted) that is calldata-INDEPENDENT (fee/refund/deposit logic on every flow) AND systemic enough to clear the % bar AND not already audited. Extremely thin given 48/48 audited + main class OOS.

**Where the EV actually is (consistent w/ track record + prior engagement):** the WEB/API scope — li.quest/* (Crit $10-25k), scan.li.fi, portal.li.fi. The prior 2026-07-05 engagement found a reachable-but-out-of-band-suspended surface there (needed a test session/creds it lacked). Per PROTOCOLE-CHASSE (28 SC-core fortresses → 0 paid; the only payout + 100% acks came from web/API/off-chain), LI.FI's payable vein is the backend/API (route generation, quote signing, the calldata-generation the SC OOS explicitly trusts). Needs the upshift/web methodology + a test env (LI.FI offers "test environment upon request").

DON'T spin a deep SC facet swarm (low-EV: OOS + fully-audited). If re-engaging: (a) request a test env, run the web/API (upshift lens) on li.quest quote/route/calldata-gen — the SC trusts backend calldata, so a backend that emits attacker-favorable calldata = the seam the SC OOS can't cover; (b) the ONE on-chain residual worth a look = a NON-calldata fee/refund/positive-slippage path shared across facets (e.g. LibAsset/refundExcessNative/fee collection) that harms users on the normal flow. [[feedback-default-posture-thief-not-fortress-prover]]
