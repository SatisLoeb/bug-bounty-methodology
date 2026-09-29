# Chainlink (Immunefi, max $3M) — Phase -1/0 surface dossier, 2026-09-29

Skill: `xsurface-prioritize`, generate-first. Fan-out of 5 agents over CCIP v2 EVM + Move + governance,
all analysis-form (condition→mechanism→guard), NO operational playbooks (live bridge ~$84B). Verdicts
anchored to release tags (program rule: "file must be part of a release; pre-releases excluded").

## Phase 0
- Program: Immunefi, live since 2021-05-11, triaged by Immunefi, PoC + KYC required, USDC on Ethereum.
- 25 assets (10 Smart Contract, 15 Web & App), 34 impacts. Primacy of Impact, LIMITED to Critical+High
  (Overview text) despite the rewards table showing it on all tiers — a Medium/Low on an unlisted asset is refused.
- Rewards: SC Critical $100k floor–$3M (Chainlink discretion above floor), High $75k, Med $10k, Low $5k.
  Web/App Critical $100k (no floor), High $10k, Med $2k, Low $1k. NB: the node/LibOCR/CCIP OCR plugins/relayers
  are classified Web & App → a bug in that off-chain code is judged at the Web ceiling ($100k), not SC.
- No known-issues list and no audit list published by the program (searched Information/Scope/Resources).
  Public dup corpus: Code4rena CCIP contests cover v1.x (2023-2024); NO public competition on v2 code.
- Rule that decides half the scope: "must be part of a release, pre-releases excluded" + "-dev typeAndVersion,
  test/mock/example/dummy/vendored, *.smartcontract.com" all out.
- Network limits from this container: EVM RPC, Etherscan, Code4rena, chain.link/docs.chain.link all egress-blocked
  → on-chain deployed-address/wasm verification and private-audit reading NOT possible here.

## Surface selection (Phase -1)
Freshest, highest-value surface = **CCIP v2.0.0 EVM** (release contracts-ccip-v2.0.0 of 2026-06-18; CCIP 2.0 on
mainnet 2026-09-28, ONE DAY before this audit). Entirely new model: permissionless CCVs (verifiers), permissionless
Executors, Pools v2 + ERC20LockBox, Custom Finality (FTF), chain-agnostic MessageV1 format. Low dup on v2 logic.
Scope anchor VERIFIED by git diff: all core files (OffRamp, OnRamp, FeeQuoter, Router, Executor, TokenPool,
ERC20LockBox, SiloedLockRelease, LockRelease, codecs, resolver, SignatureQuorumValidator, TokenAdminRegistry,
RateLimiter, CCVConfigValidation) are IDENTICAL between the v2.0.0 release and HEAD → in scope as-is.
HEAD-only / OUT OF SCOPE (post-release, only in v2.1.0-beta = pre-release): SuccinctZKVerifier.sol (new),
CCTPVerifier +58, LombardVerifier +150, RMN +47, CommitteeVerifier +2/2, fast_mcms/* (Sui), USDC CCTP interfaces.

## Assets, entry points, actors
Terminal assets (Critical impacts): token custody in-motion (releaseOrMint / lockOrBurn), price/data integrity
(FeeQuoter, "misreporting"), RMN curse, governance execution integrity (MCMS/CCIP-Owner), permanent freeze.
Permissionless entry: OffRamp.execute (anyone executes any attested message), OnRamp via Router.ccipSend,
withdrawFeeTokens, timelock_execute_batch. Actors: any sender, any executor (permissionless), CCV signer set,
token pool owner, rate-limit admin, MCMS role holders (proposer/canceller/bypasser/executor), RMN curser (owner).
Admin/operator/governance-key compromise + 51% are OUT per program rules.

## Verdict register (generate-first; each hypothesis written then killed with file:line + differential)
5 agents, ~50 hypotheses. All EVM v2 clusters = clean null with exact guards. Residuals = owner/admin-trust (OOS)
or config foot-guns. Reports in session scratchpad; codec differential in scratchpad/ccip_diff.py (20k cases).

| cluster | representative hypotheses | verdict |
|---|---|---|
| CCV quorum / message forgery (OffRamp, verifiers, resolver) | empty/weak required-CCV set; token-only path skip; sig replay cross-lane/instance; resolver version→weak impl; double-exec; RMN subject mismatch | NULL — required set never empties (address(0) marker→guaranteed-non-empty defaults + unconditional lane-mandated), decode canonical, attestations bound to messageId, curse subject deterministic |
| codecs (MessageV1/ExtraArgs/Finality) | non-canonical decode → dup/collide messageId; CCV/executor hash collision; FTF freeze; finality downgrade; source under-spec | NULL — decode injective+total (length prefixes + final-offset), verified 20k cases; finality no-downgrade; FTF freeze is self-inflicted footgun; ccvAndExecutorHash unread on dest |
| token pools v2 + LockBox | getRequiredCCVs weak for large mint; LockBox cross-silo drain; rate-limit refresh-to-full; decimals inflation; factory registry hijack; hooks freeze | NULL for attacker — CCV set scales UP with amount (same amount that mints), USDC lanes LockBox-isolated, decimals overflow-guarded, registry bound to getCCIPAdmin==caller |
| source / fee / RMN (OnRamp, FeeQuoter, Router, Executor, TokenAdminRegistry) | stale/manip price misreport; fee/revenue skim; source CCV under-spec weakens dest; curse bypass; unbounded gas; pool hijack | NULL — FeeQuoter has no external feed + gated writes, dest recomputes required CCV set (source not trusted), fee floor + FeeExceedsMaxAllowed cap, curse permissioned+fail-closed |
| governance MCMS / CCIP-Owner (EVM + Sui) | sub-quorum/dup-signer setRoot; cross-chain/role replay; timelock delay bypass; blocked-selector bypass; reentrancy; merkle 2nd-preimage | NULL — strictly-increasing signers, metadata leaf binds chainId/role/address, role unforgeable through merkle proof, isOperationReady re-check, CallProxy renounce fix complete, domain-separated leaves |

Cross-contract link verified by me: OffRamp passes the same tokenTransfer.amount / extraData / finality to
getRequiredCCVs and to releaseOrMint, and _ensureCCVQuorumIsReached requires EVERY dest-required CCV present and
invokes each verifier → the token-only "delegate to pool" residual is closed for the shipped pools.

## Residuals (not payable as found; where real risk lives)
- R-1 ERC20LockBox split-ownership: box is only an AuthorizedCallers vault (no rate limit / CCV / per-chain
  accounting). A box owned by a party less trusted than the pool can full-drain. Owner/admin-trust (OOS), but a
  genuine trust EXPANSION vs a self-custodying pool. Watch if a manual (non-factory) SiloedLockRelease box ships.
- R-2 rate-limit-admin ≈ disable rate limits (refill-to-full + no capacity cap). "Rate limit violations" (High)
  reachable IF ops treats that key as lower-privilege. Config/role-trust.
- R-3 inbound finality not validated + FTF bucket falls back to the normal (larger) bucket → enabling FTF without
  a tighter FTF inbound bucket silently gives reorg-able transfers full capacity. Config foot-gun.
- R-4 Lombard release-version V2 lockOrBurn forwards the pre-fee amount to the verifier (post-fee is smaller) →
  at most "theft of protocol revenue" (High) if the verifier does not credit it back; the Lombard verifier itself
  is a HEAD-only delta (OOS). Watch.
- R-5 FTF permanent-freeze footgun + offchainTokenData="" migration freeze for un-upgraded legacy pools:
  documented design; self-inflicted / migration, not attacker-vs-victim.

## Receivability (Move + owner)
| asset | release covers real code? | verdict |
|---|---|---|
| Aptos (MCMS+CCIP) | NONE — only v2.21.0-beta17-internal (pre-release) | OUT — receivability WALL; get written scope confirmation before any Aptos work |
| Sui CCIP (contracts/ccip) | tag sui-v1.0.0 is a 2026-02-10 "import contracts" snapshot; 34 prod modules drifted since (rmn_remote +651, fee_quoter +286, token_admin_registry +239, ...) | UNCERTAIN — code added after the tag faces "not in a release"; only tag-covered logic is safe |
| Sui MCMS (contracts/mcms/mcms) | mcms.move + mcms_registry.move IDENTICAL at tag | IN (fast_mcms/* is HEAD-only OOS) |
| Sui LINK (contracts/link) | link.move identical at tag | IN |
| CCIP Owner (ccip-owner-contracts, EVM) | v0.2.1 formal release, src identical to HEAD | IN |
Caveat: sui-v1.0.0 is a stable-named git TAG with no release-notes object; if the program reads "release" strictly
as a published Release object, even Sui MCMS/LINK could be contested — clarify up front.

## Decision
GO deep was correct. The EVM v2 core is a BREADTH-null at day 1 (genuine hunt: guards + numeric differentials,
not wall-cataloguing) — expected for a $3M target audited privately pre-launch. No permissionless-attacker payable
finding in the fanned-out surface. The live, low-dup, publicly-untested leads that remain are SOLO-trace targets:
- P0 Sui MCMS `contracts/mcms/mcms/sources/mcms_registry.move` (494 L, in scope, identical at release):
  execution-order / callback-consumption (ExecutingCallbackParams hot-potato) — the deepest un-exhausted spot;
  can params be partially consumed, duplicated, or reordered across target modules?
- P1 Sui CCIP drifted modules ONLY where the vulnerable lines exist at the sui-v1.0.0 tag (else receivability wall).
- P1 whether real per-role MCMS signer sets overlap (H3) — needs deployed config (on-chain read, blocked here).
- DROP: Aptos (receivability wall); EVM v2 core (breadth-null, re-open on a new release or a deployed-config read).
Flip conditions: a new non-beta release ships the HEAD deltas (SuccinctZK, CCTP/Lombard/RMN, fast_mcms) into scope;
a deployed-config read shows an empty laneMandatedCCVs + weak default on a value lane; a split-owned LockBox ships.

## Contrast with the fortress-null reflex
The fanout gives BREADTH (no class bug in the core). Per the kit's own lesson, the seam is traced SOLO: the P0 Sui
MCMS registry callback mechanism is where a fresh, unaudited-publicly, in-scope invariant could still break. That
is the next move, not another breadth fanout.
