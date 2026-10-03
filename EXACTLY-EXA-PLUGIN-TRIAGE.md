# TARGET: Exactly "Exa App" plugin family | PLATFORM: Immunefi | DATE: 2026-10-03
## Posture: GENERATE-FIRST. Verdict: GO. Headline = P8 (mechanism PoC'd, NOT self-fixed).

UPDATE after PoC phase (honest):
- P1 (WETH proposal non-consumption) is REAL in deployed v1.0.0 but is ALREADY FIXED in the public
  repo by commit 1a27efd "consume weth withdraw proposal" (the WETH callHash bit `& ~1` -> `| 1`).
  The fix is NOT deployed on Optimism (live contract still vulnerable), but a triager comparing
  deployed-vs-repo will very likely rule it KNOWN / self-reported => low submission viability. Do not
  lead with it.
- P8 (calldata-parsing differential) is CONFIRMED: the core primitive is PoC'd on solc 0.8.26 + a JS
  EVM (poc/exactly-p8/). It is present in BOTH deployed v1.0.0 AND repo HEAD (NOT self-fixed). This is
  now the headline.
- Survives at HEAD (not self-fixed), hence viable: P8, P7, P2, P3, P4. Self-fixed: P1.

SCOPE: Immunefi "Assets in Scope" is Optimism-only and includes the account-abstraction plugins the
first pass missed. Source = exactly/mobile (deployed v1.0.0, commit 5a152148, 2025-04-08). The lending
core verdict (NO-GO, dups) stands separately in EXACTLY-SCOPE-TRIAGE.md.

IN-SCOPE (Optimism, verified source via Immunefi Instascope export):
  ExaPlugin 0x3d73…47f3e | ProposalManager 0x6817…c8338 | IssuerChecker 0x59a6…feb3a
  WebAuthnOwnerPlugin 0x8f49…84ca0 | Refunder 0xd5f8…dd228
Dependencies (reachable via Primacy of Impact, not in the in-scope contract list):
  swapper = 0x1231DEB6…F4EaE (LI.FI Diamond, executes arbitrary routes)
  collector 0x3a73…eFc5 | keeper (KEEPER_ROLE) 0xcDdB…c04e | flashLoaner = Balancer V2 Vault
  account impl = alchemyplatform/modular-account @ c81e7122 (ERC-6900 v0.7, ERC-4337 v0.6);
  modular-account-libs v0.7.1; webauthn-owner-plugin @ 9c0c38b.

AUDIT COVERAGE (dup): Quantstamp only (WebAuthn Jul-24; Exa plugin Mar-25 on commit b262356 =
plugin@0.0.3, an ANCESTOR of the deployed v1.0.0; update Oct-25 on the 1.1.0 line NOT deployed on OP).
Deployed v1.0.0 sits in a version gap: audited on an earlier version, later fixes/audits cover
undeployed code. Thin vs the 6-firm lending core => Low/Med dup on this surface.

## ACCESS-CONTROL MODEL (verified from pluginManifest + runtimeValidationFunction)
- Each user = ERC-6900 modular account; owner = passkey/ECDSA (WebAuthnOwnerPlugin).
- All 12 ExaPlugin execution fns have preUserOpValidationHooks = PRE_HOOK_ALWAYS_DENY => never callable
  via a 4337 userOp. collect*/proposeRepay/poke are RUNTIME_VALIDATION_KEEPER (keeper direct call only);
  propose/swap are SELF (owner self-call); executeProposal/setProposalNonce are KEEPER_OR_SELF.
- Fund authority = KEEPER + an ISSUER EIP-712 sig over Collection(account, amount, uint40 timestamp)
  ONLY — it binds neither operation, market, maturity, maxRepay, maxAmountIn, nor swap route.
- THE security feature: ProposalManager imposes a delay (1s..1h) on collateral-decreasing ops so a
  compromised owner/passkey cannot instantly drain — the user gets a reaction window. Defeating this
  delay is the central vulnerability class below.

---

## CANDIDATE FINDINGS

### P1 [REAL in deployed, but SELF-FIXED in public repo => low viability] WETH withdraw/redeem proposals never consume their nonce
STATUS: fixed by commit 1a27efd "consume weth withdraw proposal" (bit0 `& ~1` -> `| 1`), in the repo/
1.1.0 line but NOT deployed on Optimism. Live v1.0.0 is vulnerable, yet the public fix makes this
known/self-reported => expect a known-issue rejection. Keep only as a secondary/defense-in-depth note.
Root cause: `ExaPlugin._withdraw` (ExaPlugin.sol:803-838), for the EXA_WETH branch, sets
`callHash = keccak256(...) & ~bytes32(uint256(1))` (bit0=0) and routes the market withdraw/redeem to
`address(this)` (the plugin) to unwrap WETH->ETH. In `ProposalManager._preExecutionMarketCheck`
(ProposalManager.sol:149-165) the withdraw/redeem branch sees `receiver == plugin` (holds PROPOSER_ROLE)
and `_checkCallHash` returns `shouldConsume = bit0 = false` => it `return`s BEFORE `shiftProposal`, the
ONLY nonce-consumer (PM.sol:83-88, 152/162, 205). `executeProposal` (ExaPlugin.sol:140-160) never
advances the nonce itself. => A matured EXA_WETH WITHDRAW or REDEEM proposal is NEVER consumed.
Impacts (increasing precondition):
  (a) IN-SCOPE regardless: the proposal stays at `nextNonce` and bricks the queue head — every later
      proposal (repay/roll/withdraw) on that account is unreachable until a KEEPER_OR_SELF
      `setProposalNonce` skip. Reachable in NORMAL operation (any user doing a WETH withdrawal). DoS.
  (b) keeper-conditioned: a keeper can re-call `executeProposal(nextNonce)` repeatedly, each time
      withdrawing `proposal.amount` WETH to the stored receiver => forced unwind of the user's WETH.
  (c) owner-key-conditioned: an attacker with the owner key proposes a tiny WETH withdraw to their own
      receiver, waits <=1h once, then drains ALL free WETH by repeated execution — defeating the delay.
  reach: REACHABLE (confirmed). value: High. dup: Low. edge-fit: High.
  Note: executeProposal is not nonReentrant; _withdraw does `receiver.safeTransferETH` (ExaPlugin.sol:837)
  => a contract receiver can reenter (not required for the drain).
  PoC (Foundry, OP fork): propose small EXA_WETH WITHDRAW; warp past delay; call executeProposal twice;
  assert second call succeeds (nonce not advanced) and WETH leaves twice; assert a subsequent unrelated
  proposal cannot be executed (queue bricked). THIS IS THE SUBMISSION-GRADE CANDIDATE.

### P8 [HEADLINE — CONFIRMED mechanism, full ProposalManager bypass, NOT self-fixed]
STATUS: core primitive PoC'd (poc/exactly-p8/): solc 0.8.26 follows a non-canonical ABI offset for a
`bytes` param while a fixed-offset reader does not — observed hook=benign / body=evil divergence.
End-to-end chain confirmed by source: account passes raw msg.data to the hook
(UpgradeableModularAccount._preNativeFunction -> _allocateRuntimeCallBuffer(msg.data)); _exec does
target.call(decoded data) (AccountExecutor._exec); ProposalManager._preExecutionMarketCheck returns
(allows) for an unrecognized selector. Present in deployed v1.0.0 AND HEAD.
`ExaPlugin.preExecutionHook` SINGLE (ExaPlugin.sol:495-499) parses the inner call from FIXED offsets:
target = callData[16:36], selector = callData[132:136], data = callData[136:] — assuming the canonical
0x60 offset for `execute`'s `bytes data` arg. The deployed account (alchemyplatform/modular-account
@c81e7122) passes RAW msg.data to the hook (`_preNativeFunction` -> `_allocateRuntimeCallBuffer(msg.data)`
-> `_doPreExecHooks`, UpgradeableModularAccount.sol:471-481,668-688), while `execute(address,uint256,
bytes)` decodes `data` by FOLLOWING the ABI offset pointer at [68:100]. A userOp calling `execute` with a
NON-CANONICAL `data` offset makes the account execute the bytes at the offset target while the hook
validates the benign bytes at fixed [132:136] => ProposalManager sees a harmless call, never consumes a
proposal, and the real malicious market withdraw executes. Full delay bypass.
  reach: conditional — needs (i) Solidity calldata decoder to accept a non-minimal in-bounds offset for a
  single `bytes` param (very likely; confirm with a unit test) and (ii) owner credential (execute is
  owner-gated). value: High. dup: Med. edge-fit: High.
  PoC: unit-test the offset tolerance first; then craft execute calldata with shifted `data` offset,
  benign selector at [132:136], malicious withdraw at the offset target; assert PM not consulted.

### P7 [HIGH lead — account-admin selectors not covered by the delay hook]
ExaPlugin's executionHooks (ExaPlugin.sol:438-459) cover only execute / executeBatch /
executeFromPluginExternal / uninstallPlugin(self). The account's `upgradeToAndCall`,
`installPlugin`, and `updateOwnersPublicKeys` are validated by WebAuthnOwnerPlugin owner-sig ALONE with
NO ExaPlugin pre-exec hook => a compromised owner can swap the account implementation, rotate the victim
out, or install a permissive plugin INSTANTLY, with zero delay. The ProposalManager anti-theft window
does not cover account administration.
  reach: conditional (owner credential + confirm on the deployed account impl that these selectors carry
  no delay hook). value: High. dup: High (known ERC-6900 limitation — likely "owner trusted" pushback).
  edge-fit: Med. Raise as an architecture finding: the delay is advertised to protect against owner/
  passkey compromise, but admin selectors escape it.

### P2 [MED] receiver-binding enforced only for WITHDRAW/REDEEM in the generic withdraw branch
`ProposalManager._checkMarketProposal` (PM.sol:208-218) binds `abi.decode(data,(address))==receiver`
ONLY for WITHDRAW/REDEEM. The withdraw branch (PM.sol:149-159) also accepts CROSS_REPAY/REPAY/SWAP
proposals, for which the receiver is NOT bound. With a matured keeper-authored REPAY/CROSS_REPAY head
(proposeRepay is keeper-gated, routine), a compromised owner can `execute(market, withdraw(amount<=
proposal.amount, attackerReceiver, account))` and redirect up to proposal.amount to an attacker address,
consuming the mismatched-type head. Owner-conditioned; instant (no withdraw-shaped proposal surfaced).
  value: Med. dup: Med. edge-fit: High.

### P3 [HIGH, keeper-conditioned] collectCollateral: keeper authority unbounded by issuer authorization (= earlier C1)
Keeper + any issuer sig for `amount`($1) -> collectCollateral(amount, collateral, maxAmountIn=large,
route=adversarial, sig). Issuer binds only amount (ExaPlugin.sol:186); keeper picks collateral market,
maxAmountIn, and the LiFi route; `_swap` enforces only `amountOut >= amount` (ExaPlugin.sol:750-767);
withdraw bounded only by account shortfall. Keeper drains the gap between maxAmountIn collateral and the
signed amount via a self-serving LiFi route. value: High. dup: Med. edge-fit: High.
  SCOPE CAVEAT: frame as privilege-SEPARATION (keeper ⊄ issuer authority), not "malicious keeper".

### P4 [MED, keeper-conditioned] one issuer signature authorizes the most damaging of 4 operations (= earlier C2)
collectCredit/collectDebit/collectCollateral/collectInstallments all gate on the SAME _checkIssuer digest
(ExaPlugin.sol:186,214,224,239); the signed struct has no op-type/maturity/maxRepay/route. A keeper
reinterprets a benign signature as the worst operation. The 4-arg collectCredit hardcodes
maxRepay=type(uint256).max (ExaPlugin.sol:204) — a post-audit-looking widening removing the fee cap.

### P5 [LOW, permissionless] IssuerChecker.check/checkIssuer public, consumes replay slot + emits event before recovery (= earlier C4)
IssuerChecker.sol:33-70 are public, no caller gate; set `collections[account][hash]=true` and emit
`Collected` BEFORE signer recovery. Anyone observing a valid sig (e.g. reverted keeper-tx calldata on OP)
can front-run to burn the slot => genuine card settlement reverts Replay (DoS, self-heals), and a false
`Collected` event can mislead off-chain reconciliation. value: Low.

### P6 [LOW, keeper] setProposalNonce / executeProposal lifecycle griefing across accounts (keeper forward-skip / forced matured execution; recoverable). P9 [MED] executeBatch uninstall+reinstall migration escape, gated by admin allowlist + a try/catch{} fail-open on hasPendingProposals (ExaPlugin.sol:529-532) that contradicts its own "should deny service on revert" comment.

---

## CONFIRMED DEAD (verified — do not spend time)
Issuer sig forge / recover-to-zero (solady reverts; issuer != 0); cross-account replay (account in struct);
double-charge (collections guard, hash keyed on message); cross-chain replay (EIP-712 domain has chainId+
verifyingContract); non-WETH withdraw receiver redirect (bound + consumed); nonce rewind (monotonic);
anonymous/reentrant receiveFlashLoan (double-auth msg.sender==flashLoaner && flashLoaning==keccak(data));
anonymous/keeper poke (acts on caller / deposits to account's own shares); direct EOA plugin calls (inert);
collect pushing account underwater (Market checkShortfall/checkBorrow on-chain); collect receiver forced to
collector; owner userOp self-collect (ALWAYS_DENY + keeper-only runtime); ExaPlugin residual-balance theft
(float nets to 0); ownerless account (EmptyOwnersNotAllowed); owner-set corruption; WebAuthn assertion
forgery (low-s, type/flags/challenge checks); ERC-1271 cross-account/chain replay (domain-bound);
Refunder abuse (funds flow TO user, keeper+issuer+replay-guarded); BORROW_AT_MATURITY-to-collector
non-consume (destination is collector, no theft).

## DECISION: GO (generate-first). Order revised after PoC phase.
1. P8 is the headline: mechanism PoC'd, not self-fixed, full delay bypass. NEXT: end-to-end fork PoC
   (real account+ExaPlugin+Market, crafted execute userOp with non-canonical `data` offset, show a
   delay-free withdraw to an attacker receiver). Blocked here only by toolchain (foundry.paradigm.xyz
   egress-denied); the decisive parser-divergence step is already proven in poc/exactly-p8/.
2. P2 (receiver-binding gap) and P3/P4 (keeper authority) as the next viable candidates — all survive HEAD.
3. P1 demoted to a secondary note (self-fixed). P5/P6/P9 low.

## SCOPE REALITY (no theater)
P1(c), P2, P7, P8 are owner-key-conditioned. Standard Immunefi excludes key compromise — BUT the Exa App's
entire security proposition is the delay protecting users against a compromised passkey. A bypass of that
delay breaks the DOCUMENTED guarantee, so it is a legitimate submission; expect scope debate and frame it
as "defeat of the stated anti-theft control", with P1's queue-brick (a) and keeper-replay (b) and P5 as
the unconditionally-in-scope anchors. P3/P4 hinge on Exactly's keeper-trust stance.

## TIME: ~1 day. Half-day P1 PoC + report. Half-day P8 offset test (+ P7 confirm on the deployed account).
KYC + code PoC required; local fork only, never mainnet/live accounts.
