---
name: feedback-version-match-is-not-code-match-use-selector-discriminator
description: A matching version() between source and deployed does NOT prove same code — a commit can change logic without bumping version; discriminate by function-selector presence in the deployed bytecode
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ca8b34fa-8fd2-45f5-86fb-0070e17b52af
  modified: 2026-08-27T22:19:46.144Z
---

Rule-5 (deployed ≠ source) has a trap: checking `version()` source-vs-deployed is necessary but NOT sufficient. A commit can change contract logic (even 100+ lines) WITHOUT bumping the version constant. deBridge (2026-08-27): commit `a542b0b` changed `DeBridgeGate.sol` by ~195 lines AND removed obsolete logic, but left `version()` at 421 — so `version()==421` on both sides did not prove the deployed Gate matched HEAD.

**The discriminator technique that resolves it:** pick a function the suspect commit ADDED or REMOVED, compute its 4-byte selector (`cast sig "f(types)"`), and grep the deployed runtime bytecode (`cast code <impl>`) for it. Presence/absence of that selector places the deployed code on one side of the commit. (deBridge: `a542b0b` "added sendMessage" → `cast sig "sendMessage(uint256,bytes,bytes)"` = `6ea9cec9` → PRESENT in deployed Gate bytecode → deployed is POST-a542b0b → HEAD trace valid. Meanwhile the CallProxy `version()`=423 was genuinely pre-a542b0b, confirming a MIXED deployment: Gate upgraded, CallProxy frozen.)

**Corollary — MIXED-cadence deployments are a real seam.** Contracts behind separate proxies upgrade on separate cadences. deBridge deployed a post-fix Gate but a pre-fix CallProxy (missing the `isContract()` guard added with a "possible asset loss" comment, unfixed 4 years). "Nobody owns the seam between upgrade cadences" is a genuine hunting angle — BUT verify the resulting gap is (a) untrusted-reachable payable and (b) not publicly-known/fixed before valuing it. Here it was neither (funds route to signed receiver/fallback; the fix is public → OOS known-issue).

**How to apply:** on any upgradeable target, after `version()` check, ALSO selector-diff the deployed bytecode against source for any function the relevant commits touched; get the EIP-1967 impl (`cast storage <proxy> 0x360894...2bbc`) and read/verify the impl actually deployed, not the proxy address the scope lists (deBridge scope listed a stale Gate impl; the live proxy pointed elsewhere). Relates to [[feedback-verify-before-working-no-theater]], [[gmtrade-gmx-solana-deployed-build-baseline]], [[feedback-scope-asset-dates-are-not-build-dates]].
