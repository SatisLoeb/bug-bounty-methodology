---
name: feedback-anchor-access-control-attribute
description: "On Anchor programs, authz can live in"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a811a6bc-6075-48c3-a7de-7c7a1c1f6aa1
---

Before claiming "missing signer/owner check → theft" on an Anchor (Solana) program, inspect the **lib.rs instruction entrypoint's attributes**, not just the handler body and the `#[derive(Accounts)]` struct. Anchor's `#[access_control(fn(&ctx))]` runs an arbitrary check function BEFORE the handler — so a handler body can look completely bare of authz while being fully gated.

**Why:** On Meteora DBC I read the 4 handler bodies (claim_partner/creator_trading_fee, partner/creator_withdraw_surplus), saw a bare `Signer` with no `== config.fee_claimer` / `== pool.creator` and an arbitrary destination, and nearly wrote a Critical "any signer drains fees." The checks were there the whole time as `#[access_control(is_partner_fee_claimer(...))]` / `#[access_control(is_pool_creator(...))]` on the lib.rs entrypoints, calling `require!` in access_control.rs. `withdraw_migration_fee` did it IN-body (so my grep found that one but not the 4 attribute-gated ones — the asymmetry was an artifact of WHERE the check lives, not WHETHER).

**How to apply:** (1) grep `access_control` in lib.rs and read the attribute line ABOVE each `pub fn` (a `grep -nB2 "pub fn"` — my grep started AT `pub fn` and missed it). (2) The repo's own negative tests are the tell: `expectThrowsAsync(fn, "Unauthorized")` asserting an unauthorized caller reverts = the check exists; if your hypothesis contradicts a green test, YOU are wrong until proven otherwise. (3) This is the First-Maxim inverse trap: over-claiming a bypass you didn't EXECUTE. Checking the test harness before building the PoC saved the wasted build. [[feedback-manual-poke-mandatory-bracket]] [[feedback-consult-operator-bugs-corpus-first]]
