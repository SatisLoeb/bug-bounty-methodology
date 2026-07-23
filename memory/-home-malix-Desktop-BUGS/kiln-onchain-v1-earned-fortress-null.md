---
name: kiln-onchain-v1-earned-fortress-null
description: "Kiln On-Chain V1 staking contracts (SC-only bounty $1M crit) — on-chain earned fortress-null 2026-07-05, artifact-backed; live EV only off-chain (OOS of this program)"
metadata: 
  node_type: memory
  type: project
  originSessionId: fb8f7c07-c474-4041-b615-1c35f4e1ff79
---

**Kiln On-Chain V1** staking contracts, SC-only Immunefi-style bounty ($1M Crit / $100k High / $20k Med, $1.5M cap). dApps + validation-infra explicitly OOS. Workspace `~/Desktop/BUGS/kiln-v1-audit/` (BREADTH-MAP.md + breadth/ verdicts). Closed **earned fortress-null (on-chain), 2026-07-05** — artifact-backed, NOT a conceded gate. OUTCOMES id `kiln-onchain-v1-breadth-earned-skip-2026-07-05`.

Deployed ≈ commit `4e178a`. Proxies: StakingContract `0x1e68238c…0270`, CL dispatcher `0xE8EC6F70…34C7`, EL dispatcher `0x72b4C52f…b058`. Audits: Halborn 2022 + Spearbit 2023 (the deployed-code audit) + Spearbit 2025 (audits `d3d77a5f` sanctions/AuthorizedFeeRecipient — **NOT deployed**). ~203 prior submissions; KLN1F001 already dup'd vs REJECTED canonical #47.

**Why null (each an executed artifact):** (1) the one untrusted-reachable **Critical** — uninitialized-proxy front-run of `initialize_1/initCLD/initELD` (no ownership check, only version==0 guard) — is DEAD: live version slots = **2/1/1**, admin `0xCf53…D5F2`. (2) The prior **"dead husk SKIP" premise is FALSIFIED**: `depositsStopped=false`, operator(0) ~**25,909 funded validators** (~829K ETH), globalFee=800bps/operatorFee=0 (operator branch inert). (3) 7/8 residual cells REFUTED_NULL: deposit-data-root byte-canonical (5000-triple differential + 25.9k live validators); read-only reentrancy null (`withdrawn` toggled pre-`.call`, no balance-derived getter); no-permanent-freeze (funded monotonic + removeValidators swap stays unfunded → funded validators permanently `enabled`); dispatch reentrancy self-defeats by balance-conservation; batch griefing trusted-victim-only; pause admin-only. (4) 8th = 5.5.10 untrusted principal over-tax (permissionless `FeeRecipient.withdraw` → 8% on 32-ETH principal when `exitRequested=false`) = **DUP** of Acknowledged Spearbit 5.5.10, attacker-profit-$0, victim self-immunizes. (5) **Intersection matrix conserves** — the singleton-dispatcher cross-root reentrancy (V7×LEAD-01, the conflation LEAD-01 feared) is closed on BOTH dispatchers by `receive()`-reverts + inner-drain-to-0 + outer `treasury.call` overdraw-revert.

**Re-open the on-chain scope ONLY on:** a code delta to `_depositValidator` / the dispatch exemption (CL:74-81) / the storage libs, OR a newly-deployed **uninitialized** Kiln proxy. Otherwise the live EV is OFF the audited Solidity (frontend/API/off-chain orchestration) — OOS of this SC-only program; would need `/upshift` on a program that scopes the off-chain layer.

Method note: this engagement is the origin of [[feedback-agent-fanout-recreates-audit-blindspot]] — the 20-agent breadth/verify fan-out mapped coverage but the composition verdict came from a SOLO continuous seam-trace + intersection matrix. Related: [[feedback-audited-target-hunt-invariant-not-class]], [[protocol-fortress-null-hunt]].
