---
name: project-midas-solana-executed-null
description: "Midas Solana (Cantina, $400k, midas-apps/contracts-solana @2932436) = the RE-SOURCE's one clean GATE-PASSED target, hunted to executed-NULL: 5 crown-jewel seams hand-pierced, one real-but-OOS differential (reject-no-refund). Don't re-audit from scratch."
metadata:
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

**Midas Solana** — Cantina bounty, Rust/Anchor 0.30.1 programs, scope `programs/**/*.rs` (`midas-apps/contracts-solana`),
**$400k hard cap**. Repo `~/Desktop/BUGS/midas-solana-2026/contracts-solana` @ HEAD `2932436b13c055cf51c74da07a12a580f64ad56e`.
6970 LOC, 4 programs: midas-vault (mint/redeem), token-authority (mint+set_authority), data-feed (oracle incl MANUAL feeds),
access-control (roles). **This was the FIRST and ONLY clean GATE-PASSED GO of the whole 2026-07-20/21 RE-SOURCE** — genuinely
fresh (init Nov 2024, 18 commits since Apr 2026), NO in-repo audits/ folder, and a real EVM→Solana differential the 302 Solidity
findings do NOT cover. README confirms an intentional PARTIAL port (Sanctions/Swapper/BUIDL redeemers omitted from Solana).

**VERDICT (2026-07-21): executed NULL for a solo payable finding.** 13-agent Ultracode hunt (1.29M tokens, find→adversarial-verify
over 5 crown-jewel seams) + operator hand-verify of the one live thread. All payable seams hand-pierced to NULL on the REAL code:
- **Arithmetic/differential (the classic EVM→Solana risk) = NULL, hand-derived with concrete decimals.** mint_instant
  calc_and_validate_deposit (utils.rs:548-613): m_token = (payment_base9·rate/1e9 − fee)·1e9/m_rate, every checked_div=FLOOR,
  truncate() floors, fee floors → ALL rounding favors the PROTOCOL, faithful to Solidity DepositVault. redeem_instant
  (redeem_instant.rs:186-282) payout=FLOOR, protocol-favorable; round-trip mint→redeem is loss-making for the user. convert()
  (utils.rs:213) exact for dec>9, floor for dec<9. u128→u64 casts = try_into().unwrap() = revert-on-overflow = DoS only, needs
  an astronomically large SELF-FUNDED deposit = unreachable. No over-mint / over-redeem.
- **Unauthorized-mint (crown jewel) = NULL behind 4 gates:** mint_to signed by the real token_authority PDA (fake can't sign the
  real mMint); minter-role PDA bakes authority.key() into seeds; M_MINTER only grantable by grant_role needing ADMIN on the REAL
  ac_role (new_ac_role only makes you ADMIN of a FRESH unrelated ac_role); Anchor enforces owner=access_control at both the vault
  layer AND inside the token-authority CPI. token-authority::mint has no address-constraint on `mint` but mint_to's PDA-signer
  is the real mMint authority so a substituted mint reverts.
- **Oracle/data-feed = GATED.** All price-writes FEED_ADMIN-gated (update_feed/new_manual_feed/update_manual_feed require an
  initialized authority_ac_role PDA). Read path pinned: address=vault_common.m_mint_feed (immutable after new_vault_common) +
  address=payment_mint_state.data_feed (admin-set) + underlying re-checked by require_keys_eq! (utils.rs:31). Bounds (min/max
  price), per-mode staleness (MANUAL=1y/PYTH=300s/SWITCHBOARD=216000 slots), decimals all present. Non-admin can't inject/sub a
  feed. Permissionless new_feed exists but its FeedState is never on any vault-pinned path = informational, not payable.
- **Access-control role-escalation = NULL.** grant_role/revoke_role need the caller's ADMIN PDA already existing under the REAL
  ac_role; new_ac_role only ADMINs a fresh caller-supplied ac_role (keypair must sign, can't collide/re-init the real one).
- **Account-confusion/PDA = NULL.** request PDAs bound by distinct prefixes (mint_vault_request vs redeemer_vault_request) +
  vault key + single monotonic counter (each id used once). No cross-type collision, no replay.

**The ONE real defect = reject-no-refund differential (OOS, DO NOT SUBMIT as-is).** create_redeem_request escrows the user's
mTokens into the redeemer_vault PDA ATA (utils.rs:855-860, unprivileged signer); approve burns them; **reject_redeem_request
(reject_redeem_request.rs:63-70) is emit!()+close(rent-only) with NO mToken accounts in its Accounts struct → structurally can't
refund.** Same gap in reject_mint_request. The EVM RedemptionVault.rejectRequest DOES refund → the Anchor port dropped it. Dev
tests assert nothing about balances (redeem-vault.testers.ts:885-896 mToken read commented out) = never implemented/verified.
**Why OOS / not payable (hand-verified):** (1) the loss-causing step (reject) is strictly VAULT_ADMIN-gated (authority_ac_role
PDA seeded with VAULT_ADMIN) → NOT an unprivileged trigger; (2) the escrowed mTokens are ADMIN-RECOVERABLE via withdraw_tokens
(VAULT_ADMIN, arbitrary receiver, moves mint_vault_ata) → NOT a permanent/cryptographic freeze. Every realization maps to
malicious-admin (OOS) or honest-admin-forgets-to-manually-refund (admin-error/centralization, OOS). The scope's "wrong
implementation of an admin function → severity per matrix" carve-out is pinned by its own "i.e." to authz-bypass (a NON-admin
reaching a privileged op), which this is not. Same verdict class as [[project-symbiotic-rwa-layer-oos]] / [[project-usdai-intake]]
C1 / Rheo-NULL: real, fix-worthy, but fails the [[feedback-trigger-reachability-is-payability-gate]]. OPTIONAL: out-of-bounty
hardening disclosure (port should auto-refund on reject like the EVM), operator's call, no reward claim.

**NUKE static barrage (2026-07-21, ran AFTER the agent hunt — confirms it independently):** 6 scanners
(cargo-deny/clippy/geiger/solana-lints/opengrep-Decurity; cargo-audit dead on an advisory-db RUSTSEC-2026-0009 parse
error + no `default` toolchain), 739 signals → 133 clusters, 0 corroborated, 22 silent classes. The 22 silent classes =
the curated Solana theft worklist = exactly the 5 seams the 13-agent hunt already hand-pierced. Only real code leads =
3 clippy arithmetic_side_effects, all hand-read + cleared: utils.rs:172 (`allowance -= amount` guarded by require_gte!
above), utils.rs:212 (branch-guarded abs-diff, no underflow), utils.rs:223 (`price_diff_percent as u64` = the one SILENT
non-revert downcast — latent truncation, but only weaponizable by a >18x price move and require_variation_tolerance runs
on the FEED_ADMIN price-write path = OOS hardening, not payable). The one HIGH = Cargo.toml cargo-deny duplicate/gather-
failure = dep-graph dup, zero sec impact. Workdir contracts-solana/.nuke/20260721-124910/. Net: nuke adds independent
mechanical confirmation + one new hand-verified OOS locus (utils.rs:223), no new payable finding.

**Bottom line:** the gate WORKED (this was NOT a fortress/phantom/OOS-at-intake — it was legitimately fresh differential code),
the hunt was rigorous, and the fresh Anchor code is genuinely well-built on every payable class. Don't re-audit from scratch.
If re-sourcing here later: the only un-swept corners are the pause/* seam (admin-gated, low EV) and any POST-2932436 commit
drift (`nuke diff`). See [[feedback-check-prior-audits-and-competitions-at-intake]], [[feedback-hunt-dont-narrate-ev]].
