---
name: ssv-network-target-state
description: SSV Network (Immunefi $250k) target state — v2.0.0 staking upgrade measured near-fortress by 11-agent Fable-5 fan-out
metadata: 
  node_type: memory
  type: project
  originSessionId: 551d7a57-267d-4074-be27-d9af35131754
  modified: 2026-08-21T09:31:14.996Z
---

**SSV Network** — Immunefi bug bounty, max $250k, PoC+KYC. In-scope: SSVNetwork proxy `0xDD9B…a4E1` + SSVNetworkViews proxy `0xafE8…66e4` ($10.1M). Both ERC1967Proxy, module-delegatecall arch (fallback→ssvContracts[module]). Source dump: `~/Downloads/foundry-v2-ssvnetwork-2420609d26c3630e/chains/ethereum-1/src/SSVNetworkViews_adeb/project/contracts` (canonical full tree, sol 0.8.24, version "v2.0.0").

**2026-08-21 — MESURÉ near-FORTERESSE, 0 clean payable.** Fresh surface = **v2.0.0 "SSV Staking" upgrade**: liquid staking (stake→cSSV, MasterChef ETH rewards `accEthPerShare`), dual SSV/ETH cluster accounting fork, oracle-quorum Effective-Balance (EB, EIP-7251 MaxEB 32→2048), cSSV transfer hook. Ran 11-agent Fable-5 fan-out (Agent-tool, background, monitored+intervened) across whole surface, all severities.

**Only residues (both weak, by-design-adjacent):**
1. LOW (measured latent, realized=$0): ETH DAO revenue accrued while `totalSupply(cSSV)==0` is permanently locked — `SSVStaking._syncFees` L199-205 folds it into ethDaoBalance/watermark but never credits accEthPerShare; no ETH-DAO withdrawal exists. Mechanism PROVEN by executed Foundry PoC (orphan + control tests vs real SSVStaking via SSVStakingHarness; built the _adeb dump with via_ir + 1-line IERC20 import fix). BUT on-chain reconstruction (Infura archive, v2.0.0 launch block 24,920,727 = 2026-04-20) shows **0 realized**: 2747 FeesSynced events since launch, ZERO with newFeesWei==0 (the zero-supply fingerprint) → cSSV supply never hit 0, buggy branch never executed. NOT attacker-triggerable (requestUnstake burns only caller's own cSSV; can't force global supply→0). Fires only on genuine full-empty wind-down. Deployed==live (~95 ETH ETH-reward pool, 4.23M cSSV staked). Verdict: real correctness bug, no realized loss, low submittability. FeesSynced topic0=0x9386d77e (declared uint256,uint256 NOT uint128).
2. LOW: `removeValidator` (SSVValidators L206-207) attributes only baseline (10000 vUnits) per removed validator, so removing a high-EB (2048) validator overstates clusterEB.vUnits until oracle re-commit → temp over-charge (up to 64×) + withdraw-freeze. Owner-self-inflicted, can't target third party, oracle-staleness-adjacent (near OOS).

**Executed refutations (do NOT re-run):** oracle quorum = fortress (replaceOracle bounds oracleId 1-4 → no N>4 minority quorum; supply cancels in tally; root replay blocked by blockNum==latestCommittedBlock+monotonic+per-cluster staleness+merkle). EB vUnits conservation = balanced across register/remove/liquidate/reactivate/migrate (numeric sim); migrate-phantom-deviation refuted (ethClusters never `delete`d, no SSV-creation path in v2.0.0); unfloored `updateDAOEthVUnits -=` (ProtocolLib L142-150) reachable-null (lockstep symmetric). Earn↔charge mirror HOLDS (40k-seed fuzz, rounding protocol-favorable, 0 drain). Reentrancy = shared guard blocks cross-module (single slot, all delegatecall proxy), all ETH/token exits CEI-clean, no receive/force-feed desync. Storage/upgrade = append-only + all-namespaced, 100% dispatch coverage, reinitializer(3) safe. Dual SSV/ETH parity = no clone divergence. Operator earnings/whitelist (isWhitelisted=view→STATICCALL)/staking-reward-math all closed with traced artifacts.

**Killed false-positive:** cssv agent claimed "permissionless rescueERC20" — WRONG, gated onlyOwner at SSVNetwork.sol L225 wrapper (module-only read missed the proxy dispatch layer). Lesson: SSV access-control lives in SSVNetwork.sol explicit onlyOwner `_delegate` wrappers, NOT in the modules — always check the wrapper. See [[deployed-code-not-head]] [[report-no-self-devaluation]].

**ROI: marginal** — near-fortress, 4 audits' worth of hardening, only Low/by-design residues. RE-SOURCE unless: new ETH-DAO-withdrawal added (would make #1 payable), EB deviation math changes, or a new module deployed. Reopener = check `delete s.ethClusters` ever added, or an oracle-count!=4 config path.
