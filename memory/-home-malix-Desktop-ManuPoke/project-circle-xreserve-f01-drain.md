---
name: project-circle-xreserve-f01-drain
description: Circle xReserve F-01 — KILLED/NON-SUBMITTABLE. On-chain CCTP-forwarding reserve-drain seam is REAL (PoC passes as propagation) but devs DOCUMENT it as intentional off-chain-mitigated design (UnexpectedStuckFundsFlow.t.sol); reachability = defeating Circle's out-of-scope off-chain attester. Don't submit.
metadata: 
  node_type: memory
  type: project
  originSessionId: 7156c583-7af7-4e92-807a-9f2dd26bbf35
---

# Circle xReserve F-01 — reserve drain via CCTP forwarding (EXECUTED Critical, PoC PASSES)

**Program:** Circle Immunefi (11 open-source repos, all Critical-eligible). Re-sourced here after Berachain
null + Circle Gateway executed-NULL (Gateway EVM+Solana tight: withdrawal delay + burn-reaches-withdrawing +
minter fully bound: signer/expiry/domain/contract/caller/token/replay; both sides guarded). Pivoted to the
FRESHEST less-swept product: **evm-xreserve-contracts** (added 2026-11-24). Found via **xseam** (the
unguarded-sibling lens). Workspace ~/Desktop/BUGS/circle-2026 (findings/F-01, repos/evm-xreserve-contracts).

## THE BUG (candidate CRITICAL, executed)
xReserve holds pooled USDC on the source chain backing remote USDC-tokens. `withdraw(attestation,sig)`
(permissionless): Phase 1 `gatewayMint` validates+mints; Phase 2 `_processForwarding` (Withdrawal.sol:206-213)
branches: xReserve-forwarding validates its selector (`depositToRemote` only) BUT the **CCTP branch does a raw
`Address.functionCall(tokenMessenger, forwardingCalldata)` with NO selector/param/amount check** = the
unguarded sibling. `forwardingCalldata` is attacker-controlled (embedded in the user's own BurnIntent hook
data; `_validateWithdrawHookDataStructure` checks only magic/version/length, NO amount binding). xReserve
grants `type(uint256).max` approval to both CCTP messengers (TokenSupport.sol:97-100) + holds the reserve
(DepositToRemote.sol:108). ⇒ a 0.001-USDC withdrawal carrying
`depositForBurn(<entire reserve>, attackerDomain, attacker, USDC)` drains ALL depositors' USDC.

## EXECUTED PoC — PASSES
`test/XReserveDrainPoC.t.sol` (standalone, real xReserve logic; mocks only the external GatewayMinter +
CCTP TokenMessenger sink): reserve 1,000,000 USDC → 0.001 after; attacker drained 1,000,000 while
withdrawing 0.001. Run with **standard foundry 1.0.0** (foundry-zksync 1.3.5 can NOT build the repo's
multi-version 0.7.6 CCTP dep — installed std at ~/.foundry/bin/forge.standard-1.0.0; zksync restored as
default). Helper lib/evm-gateway-contracts/XReservePoCBuilder.sol builds the attestation bytes to dodge
foundry's import-string struct type-identity split (@gateway/ vs gateway-internal src/). Original suite in
test_orig2/ (has test_EXPLOIT in reserve/Withdraw.t.sol = full-fidelity w/ real gatewayMint).

## ❌ KILLED — NON-SUBMITTABLE (documented intentional off-chain-mitigated design). DON'T SUBMIT.
Killjoy self-attack + darkside Door-B mining of the devs' OWN tests killed it. The exact seam is documented
as an INTENTIONAL design decision in `test_orig2/integration/UnexpectedStuckFundsFlow.t.sol` (docstring
lines 27-39), verbatim: scenario (3) = "Setting xReserve as recipient for a forwarded withdrawal, but
forwarding [an amount that doesn't match] the minted amount"; "Circle's offchain services are EXPECTED TO
REJECT requests ... if the forwarded amount does not match the minted amount. While on-chain enforcement is
possible, it is costly. Therefore we OPT TO NOT ENFORCE these cases onchain. ... these are EXPECTED behaviors."
⇒ My drain REQUIRES a forwarded-amount ≠ minted-amount mismatch (forward fullReserve while minting 0.001).
The devs delegate exactly that check to xReserve's OWN off-chain multi-party attestation service (NOT the base
Gateway balance-only API my earlier Fact D wrongly reasoned about — that was aimed at the wrong attester and
MISSED this file). The on-chain code behaves exactly as documented/intended.
WHY NON-SUBMITTABLE (all three hold): (1) DOCUMENTED known/accepted-risk → hard known-issue reject; (2)
reachability requires DEFEATING Circle's private off-chain xReserve attester — unverifiable by me, no evidence
it's broken, and almost certainly OUT OF SCOPE (program = smart contracts); (3) submitting = over-claiming a
bypass I never proved (first-maxim violation). My PoC proves PROPAGATION (mismatched attestation → drain), NOT
REACHABILITY (that a mismatched attestation can be signed).
LESSON: the pre-compaction "Fact D SATISFIED / live Critical" was a REACHABILITY OVER-CLAIM built on the base
Gateway docs while the devs' own test file (in-repo, unread until killjoy) documented the off-chain gate that
blocks it. Mine the devs' adversarial/fear tests (darkside Door A/B) BEFORE concluding reachability, and aim
Fact-D at the RIGHT attester. [[feedback-trigger-reachability-is-payability-gate]]
[[feedback-check-prior-audits-and-competitions-at-intake]] [[feedback-consult-operator-bugs-corpus-first]]
On-chain seam (real but non-payable): _processForwarding CCTP branch raw-calls tokenMessenger w/ attacker
calldata + unlimited approval + no on-chain amount binding; PoC test/XReserveDrainPoC.t.sol still PASSES as a
propagation artifact. Kept for the record, not for submission.

## Residual on-chain seams ALSO exhausted (don't re-open) — checked after the drain kill
- REPLAY: airtight on-chain. GatewayMinter._mint → _checkAndMarkTransferSpecHash REVERTS (TransferSpecHashUsed)
  on any reused keccak256(TransferSpec); per-contract EIP-7201 usedHashes map. Pierced 4 sub-angles (salt/hook
  re-hash needs a fresh BACKED attestation = back to off-chain wall; storage namespaced no-split; xReserve does
  NO independent mint, Phase-2 only forwards; destinationCaller consistent). Mints.sol + TransferSpecHashes.sol.
- TAKEOVER/INIT: dead. UpgradeablePlaceholder + reinitializer(2) 2-step; deploy README: proxy-deploy +
  upgradeToAndCall(impl, xReserveInitData) bundled in Create2Factory.deployAndMultiCall (ATOMIC, init carried),
  placeholder owner = factory contract (not front-runnable EOA). No window where initialize(2) is caller-open.
⇒ xReserve on-chain surface EXHAUSTED for theft (drain/replay/takeover all null). RE-SOURCE — other Circle
repos untouched: stablecoin-near (NEAR/Rust), starknet-cctp (Cairo), solana-cctp-contracts (Solana/Rust).
