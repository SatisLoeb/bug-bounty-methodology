---
name: debridge-immunefi-gate-manual-poke-null
description: deBridge (Immunefi $200k) legacy Gate — 4 seams manual-poked to executed NULL; DLN out-of-scope; Rule-5 found an undeployed isContract fix (known/OOS)
metadata: 
  node_type: memory
  type: project
  originSessionId: ca8b34fa-8fd2-45f5-86fb-0070e17b52af
  modified: 2026-08-27T22:20:14.394Z
---

deBridge Immunefi program ($200k max, PoC-required, live since Jan-2022). Scope = **legacy deBridgeGate contracts only** (90 assets = 13 contracts × 7 chains: ETH/BSC/MATIC/HECO/ARBI/AVAX/FTM). **DLN (DlnSource/DlnDestination, the current product + real volume) is NOT in scope** (grep-confirmed; `github.com/debridge-finance/dln-contracts`, own audits). Real TVL ~$1.94M (DeFiLlama), Critical ceiling ~$194K. "Last Updated" genuinely today (`updatedDate` field) but no new assets/DLN → metadata refresh, not fresh ore.

**Manual poke (apparatus-off, no-hypothesis, DEPLOYED code) of the 4 crown-jewel seams → executed NULL:**
- **send→submissionId→claim→SignatureVerifier→CallProxy:** submissionId binds every exec field on BOTH sides (`_publishSubmission` vs `getSubmissionIdFrom` diffed line-by-line); `flags` committed → MULTI_SEND/PROXY_WITH_SENDER/SEND_HASHED_DATA not mutable by a 3rd-party claimer; `isHashedData` source/dest asymmetry consistent; SignatureVerifier dedups on ecrecovered ADDRESS (malleability-safe); live config minConf=8, requiredOraclesCount=0.
- **_send:** lock/burn (`_amount−totalFee`) == dest mint (committed+executionFee) byte-verified; fee-on-transfer handled via received-real-amount; normalize rounds DOWN (protocol-favorable).
- **deployNewAsset:** new deToken minter = Gate only; mint only via signed claim; no abi.encodePacked collision (single dynamic arg after fixed uint256); deployId signed with excessConfirmations; unimagined inputs (nativeChainId==getChainId, CREATE2 grind) dead-end at revert.

**Rule-5 divergence FOUND (the one real deployed≠audited gap):** deployed CallProxy `0xbd3d657ae87671ec6f8d6272a9f431a7c4a9b6f8` = **v423, pre-commit-a542b0b, LACKS the `_destination.isContract()` guard** the team added Nov-2022 with a "possible asset loss" comment — never deployed in 4 years. Gate IS post-a542b0b (selector `6ea9cec9` sendMessage present). **But NOT submittable:** funds route to signed receiver/fallback; the only asset-loss is self-inflicted (native transfer to a non-contract receiver → ETH stuck); and the fix is PUBLIC → known-issue/OOS. No untrusted-reachable payable theft.

**Verdict: NULL-COÛTEUX, RE-SOURCE.** Legacy Gate = fortress on the poked surfaces (4.5yr audited), TVL-capped, DLN OOS → no in-scope fresh ore. Demonstrated [[feedback-version-match-is-not-code-match-use-selector-discriminator]] + the manual-poke-beats-apparatus doctrine. NOTE: the `blackbox/` workspace clone vanished mid-session (env reset?); memory + OUTCOMES persisted (outside blackbox); re-clone debridge-contracts-v1 to scratchpad if resuming. Relates to [[feedback-depth-is-an-edge-only-where-ore-remains]], [[protocol-fortress-null-hunt]].
