# TARGET: Exactly "Exa App" plugin family | PLATFORM: Immunefi | DATE: 2026-10-03
## Posture: GENERATE-FIRST (candidates for local PoC + responsible disclosure)

SCOPE CORRECTION vs first dossier: the Immunefi "Assets in Scope" table is Optimism-only and
INCLUDES five account-abstraction contracts the first pass did not model: ExaPlugin, ProposalManager,
IssuerChecker, WebAuthnOwnerPlugin, Refunder (added Dec 2025). Source = exactly/mobile. This is the
thin-coverage, high-edge surface. The lending core verdict (NO-GO, dups) stands separately.

IN-SCOPE DEPLOYED (Optimism chain 10), verified source (Immunefi Instascope export):
  ExaPlugin          0x3d73D0fb9e63c49ba8e9cd738964D5E08C047f3e   v1.0.0, commit 5a152148, 2025-04-08
  ProposalManager    0x6817974CA2c354F2FA40d8349b725B5bF81c8338
  IssuerChecker      0x59a644e490e48235adf8ba9b814a4f666c4feb3a
  WebAuthnOwnerPlugin0x8f498c8240E621f8050249D1C2F5f2AAeE484ca0
  Refunder           0xd5f8c9d87b7691449dec453d041d9054e0fdd228
Dependencies (NOT in the in-scope contract list, but reachable under Primacy of Impact):
  swapper  = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE  (LI.FI Diamond — executes arbitrary routes)
  collector= 0x3a73880ff21ABf9cA9F80B293570a3cBD846eFc5
  keeper   = 0xcDdB23654595C224A563f62943D9Ff189138c04e  (KEEPER_ROLE, single hot wallet)
  flashLoaner = Balancer V2 Vault 0xBA12...

AUDIT COVERAGE (dup calibration): Quantstamp ONLY — WebAuthn plugin (Jul-24: 1 Med/2 Low/5 Info),
Exa plugin (Mar-25: 3 High/3 Med/5 Low, all fixed, on commit b262356 = plugin@0.0.3, an ANCESTOR of
the v1.0.0 bump), update (Oct-25: 1 Info). Deployed v1.0.0 is POST the Mar-25 audited commit; the
1.1.0 line (multi-proposal, cross-repay) and the Oct-25 fix-review cover code NOT deployed on Optimism.
=> Far thinner than the 6-firm lending core. Low/Med dup on this surface.

## ACCESS-CONTROL MODEL (read from pluginManifest + runtimeValidationFunction, verified)
- Each user = ERC-4337 modular account (Alchemy MA, ERC-6900). Owner = passkey/ECDSA via WebAuthnOwnerPlugin.
- ExaPlugin exposes 12 execution functions. The card-settlement ones — collectCredit (x2), collectDebit,
  collectCollateral, collectInstallments, proposeRepay, poke, pokeETH — are gated by
  RUNTIME_VALIDATION_KEEPER: `runtimeValidationFunction` requires `hasRole(KEEPER_ROLE, sender)`.
- preUserOpValidationHooks = PRE_HOOK_ALWAYS_DENY on every execution fn => collect* CANNOT be driven by
  a signed userOp (owner passkey). They are reachable ONLY by a direct call from a KEEPER_ROLE holder.
- So the fund-moving authority is KEEPER + an ISSUER signature. The issuer signs EIP-712
  Collection(address account, uint256 amount, uint40 timestamp) — i.e. it binds ONLY {account, amount,
  timestamp}. It does NOT bind the operation type, the market, the maturity, maxRepay, maxAmountIn, or
  the swap route. ExaPlugin holds PROPOSER_ROLE on ProposalManager (ExaAccountFactory.s.sol:33).

---

## CANDIDATE FINDINGS (reachability confirmed in code; severity pending PoC + keeper-trust ruling)

### C1 [HIGH→CRIT candidate] collectCollateral: keeper authority unbounded by issuer authorization
Chain (every edge verified):
  [KEEPER_ROLE holder] holding ANY one valid issuer sig for (victim, amount=$1, ts)
  ->(account.collectCollateral(amount=$1, collateral=victim mkt, maxAmountIn = victim free collateral,
     ts, route, sig); runtimeValidationFunction KEEPER passes; _checkIssuer passes ExaPlugin.sol:127)
  ->(callHash = keccak(collateral,withdraw,maxAmountIn,plugin,victim) & ~1  [bit0=0]; ExaPlugin.sol:131)
  ->(_withdrawFromSender pulls maxAmountIn collateral; preExecutionChecker withdraw branch: receiver=plugin
     has PROPOSER_ROLE, _checkCallHash matches with shouldConsume=false => early RETURN, NO proposal, NO
     delay; ProposalManager.sol:152 + _checkCallHash:205)  [bounded only by account shortfall = free collateral]
  ->(_swap: LiFiDiamond.functionCall(keeper route); only post-check is amountOut >= amount; ExaPlugin.sol:140-144)
  ->> [victim loses ~maxAmountIn collateral; only `amount`($1) USDC reaches collector; the delta is captured
       by the keeper-controlled LiFi route counterparty. Theft of user collateral.]
  reachability: REACHABLE given KEEPER_ROLE (all non-keeper edges confirmed). value: High (per-account free
  collateral; scalable across all Exa accounts). dup: Low. edge-fit: High.
  WHY IT'S A BUG (not just "malicious admin"): the keeper is a single online hot wallet whose JOB is to
  relay issuer-signed charges. A correct design bounds the keeper to what the issuer signed (amount + a
  fair-price swap). Here the keeper freely chooses maxAmountIn, the swap route (arbitrary via LiFi), AND
  which operation to run — so one leaked issuer signature for $1, plus the keeper key, drains every user's
  free collateral. Keeper compromise should be containable to relay/grief, not total loss.
  SCOPE CAVEAT (honest): if Exactly's threat model treats KEEPER_ROLE as fully trusted, triage may rule
  admin-trust / out-of-scope. Frame the report as a privilege-SEPARATION flaw (keeper ⊄ issuer authority),
  not "malicious keeper". Strongest if a keeper compromise is in Exactly's stated threat model.
  PoC (local Foundry, fork Optimism): deploy an Exa account with collateral + a real issuer sig for $1;
  as keeper, call collectCollateral with maxAmountIn=full collateral and a route that swaps through an
  attacker pool returning exactly $1; assert victim collateral gone, attacker balance up.

### C2 [HIGH candidate, same root] one issuer signature authorizes the MOST damaging of 4 operations
  The same Collection(account, amount, ts) signature is accepted by collectCredit, collectDebit,
  collectCollateral, collectInstallments (all call _checkIssuer with refund=false, hash=keccak(amount,ts)).
  The issuer cannot constrain WHICH operation runs. A keeper holding a signature the issuer intended as a
  small debit can instead invoke collectCollateral (C1) or collectCredit at an adversarial maturity.
  antiPattern: signed payload omits an operation/selector discriminator. Fix: bind op-type (and market/
  maturity/maxAmountIn) into the EIP-712 struct. dup: Low. edge-fit: High. Pairs with C1.

### C3 [MED candidate] collectCredit maxRepay defaults to type(uint256).max (no slippage bound)
  collectCredit(maturity,amount,ts,sig) -> collectCredit(...,maxRepay=type(uint256).max,...) ExaPlugin.sol:145.
  Keeper also picks `maturity` (unsigned). Account accepts any fixed-borrow cost. Bounded by market rate
  conditions, but combined with C2 a keeper can borrow the signed amount at an unfavorable maturity with
  zero slippage protection. value: Med. dup: Med.

### C4 [LOW] IssuerChecker.check/checkIssuer is public and consumes the replay slot
  Anyone (not just the plugin) can call checkIssuer(account,amount,ts,sig) with a sniffed valid signature,
  setting collections[account][keccak(amount,ts)]=true (IssuerChecker.sol:53-54) BEFORE the real
  collect* runs => the genuine card settlement then reverts Replay. Griefing/DoS of card payments;
  self-heals (issuer re-signs new ts). Also: replay key omits the operation and the account from the
  hash (account is in the mapping key and the signed struct, so cross-account is safe), and two same-
  amount same-second charges collide. value: Low (DoS). dup: Med.

### Not yet personally verified (delegated to running workflow wmn0hld49) — treat as open candidates
  - WebAuthnOwnerPlugin: ownerless-account / last-owner-removal brick; P256/RIP-7212 verifier trust;
    ECDSA malleability (Quantstamp EXA-2 Acknowledged) and EIP-1271 cross-account/chain replay;
    "signatures valid indefinitely" (EXA-4 Mitigated) — confirm whether mitigation is in deployed v1.0.0.
  - ProposalManager delay-bypass via the callHash bit (deployed collectCollateral uses bit0=0; a later
    commit flips to bit0=1 — understand whether the deployed value weakens any proposal gate beyond C1).
  - receiveFlashLoan cross-repay: c.route keeper-controlled (same LiFi arbitrary-route surface as C1).

---

## DECISION: GO (narrow, generate-first) on the Exa plugin family.
- Primary: build the C1 PoC (keeper + $1 issuer sig -> collateral drain via LiFi route). It is the
  highest-value, lowest-dup, fully-reachable candidate. If the keeper-trust framing holds for Immunefi,
  this is High/Critical. Write it as privilege-separation (keeper ⊄ issuer), with C2 as the amplifier.
- Secondary: let the workflow close WebAuthn (ownerless/replay) — a non-keeper owner-takeover there would
  be unconditionally Critical and would not carry C1's scope caveat. Prioritize that if it lands.
- Keep C3/C4 as supporting/low.

## TIME ALLOCATED (honest): 1 day. Half-day C1 PoC; half-day on WebAuthn owner-takeover from the workflow
  output. Report via Immunefi (KYC + code PoC required). Do NOT touch mainnet/live accounts — fork only.
