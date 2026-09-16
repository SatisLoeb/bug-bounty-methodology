---
name: project-cctp-solana-v2-executed-null
description: Circle CCTP Solana (solana-cctp-contracts) — hand-verified NULL on the fresh V2 surface. Immunefi Critical-eligible. Deployed V2 logic == HEAD; every dev-phase security fix already in it; V2 additions (hooks/fee/denylist/finality) conservative by design. RE-SOURCE.
metadata: 
  node_type: memory
  type: project
  originSessionId: 7156c583-7af7-4e92-807a-9f2dd26bbf35
---

# Circle CCTP Solana V2 — intake NULL (fresh surface hand-verified)

**Program:** Circle Immunefi (hackerone.com/circle-bbp), solana-cctp-contracts in-scope, SC Critical-eligible
(up to 7 figures). Anchor 0.28 / Rust. Program IDs V1 CCTPmbSD…/CCTPiPYP…, V2 CCTPV2Sm…/CCTPV2vP…, live on
Solana mainnet, large USDC TVL. Workspace ~/Desktop/BUGS/circle-2026/repos/solana-cctp-contracts.

## Saturation (the reason it was worth a look): MEDIUM / DELTA-ONLY
CCTP V2's public audits (OtterSec, Halborn, Zellic, ChainSecurity, late-2024/early-2025) are ALL EVM/Solidity.
**No public Solana-V2 audit exists.** Solana V2 launched Oct 2025 — first non-EVM CCTP V2, structurally distinct
Rust/Anchor, 7mo after the EVM audits; EVM audits don't transfer (Solana account-validation/PDA/CPI semantics
differ). V1-Solana = Halborn ~2023, 18mo live = saturated fortress, SKIP. So EV lived ENTIRELY in the V2 delta.

## Verdict: NULL on the fresh V2 surface (hand-verified, not just agent-swept)
14-agent adversarial workflow (11 seams × 3-lens refute) returned 0 candidates. Deep seams were strong
grep-backed nulls; the two FRESHEST seams (fee, denylist) came back THIN, so I hand-read them myself:
- **HOOKS**: null by construction — Solana CCTP V2 does NOT execute hook_data on-chain. hook_data is opaque
  passthrough (appended to burn body bytes[228..], echoed in event, NEVER read on receive; `hook_data()` reader
  0 call sites; message-transmitter-v2 has 0 'hook' occurrences). deposit_for_burn_with_hook → same guarded
  `deposit_for_burn_helper` as deposit_for_burn (denylist check is IN the helper, not the handler → hook sibling
  NOT unguarded).
- **FEE**: null — handle_receive fee split conservative: fee_executed<amount, fee_executed<=max_fee (both
  attested), amount_less_fees=amount-fee_executed; source binds max_fee<amount & max_fee>=min_fee. fee_executed
  is attester(Iris)-set within the user's signed max_fee bound. No unprivileged leak. (#55 "check fee before
  transferring" already in deployed code.)
- **DENYLIST**: null BY DESIGN — mint/receive path has NO denylist check on recipient; burn path checks only
  `owner` (sender). **Same-vendor parity CONFIRMS intentional**: starknet-cctp V2 is IDENTICAL — deposit_for_burn
  + deposit_for_burn_with_hook call assert_not_denylisted_caller_and_origin; handle_receive_finalized/unfinalized
  have NO denylist check. Circle denylists the burn INITIATOR, never the mint recipient, across all non-EVM CCTP.
  Burn-side check is sound (denylist_account PDA seed-bound to owner, Anchor enforces seeds on the UncheckedAccount
  → undodgeable).
- **finality split / nonce / mint-binding / account-validation / attester**: nulls — used_nonce PDA `init` set
  before the finality branch AND before CPI (byte-identical nonce consumption both paths; 2nd init fails); full
  message under keccak gated by verify_attestation_signatures; all money-path accounts PDA-seed-bound;
  remote_token_messenger cross-checked vs attested remote_domain + params.sender==remote_token_messenger.token_messenger;
  singletons one-shot init (0 init_if_needed in programs/v2). reclaim_event_account closes only source MessageSent,
  never used_nonce.
- **token model**: custody-transfer on receive (SPL transfer from ["custody",mint] pool, authority=token_minter
  PDA), burn on deposit. Custody-out bounded by real Iris-attested remote burns → conserved cross-chain; depleted
  custody fails-closed (liveness, not theft). burn_token_custody = token_minter-PDA/admin (OOS).

## Deployed==HEAD (forward-diff residual EMPTY)
Deployed V2 commit = **b37d577** (2025-06-10, "CCTP V2 contracts #28"). All dev-phase security fixes (#50 fix
token_pair seed, #55 fee-before-transfer, #63 add constraints/reclaim-waiting-period/fix-casts, #67 init-constraint
+ denylist-to-PDAs) are ANCESTORS of b37d577 → already in deployed code. Changes AFTER b37d577 to programs/v2/ =
ONLY npm test-dep bumps (glob/sha.js/pbkdf2/e2e), zero contract-logic. So no post-deploy fix names a live bug.
[[feedback-diff-forward-to-head-not-just-scope-changelog]] applied in reverse (deploy→HEAD) = clean.

## RE-SOURCE
Fresh Circle scope untouched: stablecoin-near (NEAR/Rust) — genuinely different codebase, best next Circle pick.
starknet-cctp = same conservative CCTP (used here as parity ref), low marginal EV.
[[feedback-check-prior-audits-and-competitions-at-intake]] [[project-circle-xreserve-f01-drain]]
