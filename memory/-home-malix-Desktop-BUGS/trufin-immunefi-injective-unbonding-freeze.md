---
name: trufin-immunefi-injective-unbonding-freeze
description: "TruFin/TruYields Immunefi — LIVE High/Critical on Injective staker (max_entries=7 monopolisation), PoC pending; Aptos=$3.1M but 2-audit fortress, Solana economically dead"
metadata: 
  node_type: memory
  type: project
  originSessionId: dee528a0-0d9e-4bc1-b625-4ce067702e36
  modified: 2026-08-05T14:28:44.393Z
---

TruFin (TruYields) Immunefi program, engaged 2026-07-30. Workspace `~/Desktop/BUGS/trufin-audit/`.
Rewards Crit $30K / High $15K / Med $5K, **capped at 10% of funds directly affected** — this cap decides
everything: per-chain TVL is Aptos $3.10M · Injective $702K · NEAR $101K · ETH $24K · **Solana $2,499**
(⇒ a Critical on Solana pays ~$250 — economically dead, do not spend depth there).

**F-1 (PoC EXECUTED 4/4, submittable)** — `contracts/injective-staker`: Cosmos `max_entries=7` unbonding entries
per (delegator,validator) is a resource shared by ALL users because the contract is a single delegator, and
`internal_unstake:1221` has NO minimum (`assets > 0` only; `min_deposit` is deposit-only). ~$5 of TruINJ + 7 dust
unstakes in 7 blocks pins a validator for 21 days; 56 txs seal all 8 validators; renewable forever. `add_message`
(no SubMsg/reply anywhere) ⇒ `ErrMaxUnbondingDelegationEntries` aborts every honest user's unstake.
Floor High (temporary freeze), ceiling Critical. Full writeup: `trufin-audit/FINDING-1-*.md`.
Killer support: (a) **cw-multi-test 2.4.0 staking.rs has ZERO `max_entries` modelling** → the dev harness and
Zellic's Nov-2024 audit were structurally blind, 17 unstake tests pass vacuously; (b) **sibling asymmetry** — same
team enforces a 10-APT floor on the Aptos unlock path (`staker.move:1408 EBELOW_MIN_UNLOCK`) and handles NEAR's
4-epoch wait explicitly. Main weakness: attacker must be whitelisted (KYC'd) — but README concedes "revoke a
whitelist status for a malicious user", and revocation does NOT free already-created entries.

**F-2 (real, small $)** — `internal_redelegate:1439` (added Apr 2025, AFTER Zellic Nov 2024) credits
`CONTRACT_REWARDS += src_rewards + dst_rewards` with **no `calculate_treasury_fees` call**, unlike every sibling
site (`internal_stake:1139`, `internal_unstake:1323`, `compound_rewards:645`). Rewards move from the
fee-discounted `total_rewards` term into the fee-free `CONTRACT_REWARDS` term ⇒ treasury fee permanently
forfeited + a front-runnable share-price step. Owner-triggered; 8 redelegation tests assert auth/existence/events
but never the treasury balance or share price.

**PoC (F-1)**: `tests/poc_unbonding_entry_freeze.rs` on **injective-test-tube** (real injectived, zero mocks),
4/4 green: poc_0 harness-validation (8th raw undelegate → "too many unbonding delegation entries") · poc_1
honest baseline (victim unstake Ok) · poc_2 attack (victim → "dispatch: submessages: too many unbonding
delegation entries") · poc_3 disconfirmer (6 entries → Ok, isolating the cap as sole cause). GOTCHA: Rust
≥1.82 emits bulk-memory opcodes the Injective VM rejects → build the wasm with `cargo +1.81.0`; and don't
`pub mod helpers` (helpers needs `--features test`, which would link test-only entry points).

**F-3 — REFUTED, and I was wrong.** I claimed sub-10-APT TruAPT positions are permanently frozen
(`staker.move:1408` vs `:1414` mutually unsatisfiable). The arithmetic is right, the conclusion is not: the
sweep at `:1424-1426` IS the cure. Top up 10 APT, call `unlock(10 APT)`, the branch fires and burns the
ENTIRE balance releasing full `max_withdraw`, dust included; the 10 APT round-trips. Devs' own
`test_unlock_sweeps_anything_below_min_unstake` proves it. I had QUOTED :1424 and read it as an end-of-run
guard without ever asking "what if the holder tops up FIRST" = novel-reading, [[feedback-refuted-by-tracing-the-guard-is-novel-reading]].
Bonus: deleting `:1408` would CREATE a bug — aptos-framework `coins_to_transfer_to_ensure_min_stake`
(delegation_pool.move:1104-1106) silently RAISES a small unlock, breaking the staker's share-price invariant
at `:1461`. So the Aptos floor is load-bearing for a DIFFERENT reason than entry-metering.

**SUBMITTED 2026-08-05 12:49Z — Immunefi report #87437, High, "Temporary freezing of funds",
flat $15,000, asset "Injective staker and whitelist contracts on GitHub".** **ESCALATED 13:05Z, 16 min after submission** — Immunefi confirmed impact in scope, asset in
scope, PoC present, then UNSUBSCRIBED itself: this program does NOT use Immunefi triaging, so
TruYields judges factual correctness, PoC validity and severity directly. Audience is their own
engineers, CONFIRMED: 5 TruYields subscribers (IncredibleBirdie92, ahmedali, pascoli, Matt_TruFin,
**JeremyBokobza**) and Bokobza is the author of the README commit `9cc8862` the report argues
against. So the note's author reads the rebuttal to his own note. SLA for
High: **ack by 2026-08-09T13:05Z (96h), resolve by 2026-08-19T13:05Z (336h)**; "ask for help"
re-subscribes Immunefi and is the lever if the 96h passes silently. OUTCOMES row
`TRUFIN-F1-IMF-87437` (outcome=escalated).
4 screenshots attached; all on-chain figures aligned to block 177292358 so report and evidence
carry identical numbers. **Most likely adverse outcome = Known-Issue close** on the README note
committed 2026-05-21 (`9cc8862`, "known and accepted operational property") inside the in-scope
asset. If they downgrade to Griefing/Medium, the reserve argument is in the rejection matrix:
belong #56881 was tagged ONLY griefing and paid **High** (calls revert), belong #57358 was tagged
griefing + permanent-freezing and paid **Medium** (only gas-expensive). Do NOT volunteer a
downgrade; do NOT post unprompted comments.

**CP5 DONE (2026-07-31) — both agent headlines REFUTED, one better mechanism surfaced.**

(a) div-by-zero brick via `evict_delegator` = **REFUTED**. Chain verified live: feature 56
DELEGATION_POOL_ALLOWLISTING is ACTIVE on mainnet (decoded from `0x1::features::Features`
`0xaeffffffff5fbedfe7f7cfefffa401`, byte 7 = 0xdf bit 0); `enable_delegators_allowlisting` +
`evict_delegator` are both owner-gated, 2 tx; `evict_delegator` → `unlock_internal(full active balance)` and
the leaf `coins_to_redeem_to_ensure_min_stake` (dp.move:1088-1090) "redeem it entirely" when the remainder
would fall under 10 APT, so active really does go to 0. **What kills it:** `total_staked()` sums active
across ALL pools in the table, and TruFin holds TWO pools with TWO DIFFERENT operators
(`0x33f0c333…` op `0x6be6cda7…` 5,485,143 APT; `0xa8f57fe2…` op `0x88e3873f…` exactly 10 APT, DISABLED).
One eviction leaves 10 APT ⇒ `price_num != 0` ⇒ no abort. Needs two independent operators colluding.

(a′) **NOT refuted, the real mechanism, needs execution.** Eviction moves the stake active→pending_inactive→
inactive, and `total_staked()` counts NONE of that (active only). So (i) the TruAPT share price collapses
~99.9998% while the APT is in flight, numerator drops and supply doesn't; (ii) `collect_residual_rewards`
computes `residual = received − (paid + awaiting)` and the evicted principal has NO matching UnlockRequest,
so the whole withdrawn amount classifies as treasury residual and is transferred out. Needs ≥1 unlock
request on the pool for the loop to iterate (`latest_unlock_nonce = 75`, so the table does get used).

(b) treasury misclassification via `ready_to_withdraw` flip-back = **REFUTED**. I traced 3 interleavings;
the `residual_rewards_collected` flag prevents the double-count every time, and I could not construct a
reachable deficit (every path that counts a request in `awaiting` also withdraws its `pending_inactive`
under the same predicate). The clamp-then-reset at `:1103-1128` does erase a deficit, but the deficit
itself is unreachable. **Residual real issue:** `ready_to_withdraw:1338-1341` ORs a permanent condition with
the transient `can_withdraw_pending_inactive` (= `INACTIVE && now>=lockup_secs`, dp.move:714-717), so a
validator rejoining flips it back and a user whose APT is ALREADY in the staker cannot `withdraw` (:1528)
until the OLC advances. Temporary freeze, not attacker-controlled unless the attacker runs the validator.

Scope risk on (a′): the actor is a third-party validator operator, and the program excludes "impacts
involving centralization risks". Recovery exists via `upgrade_contract:783`.

**LESSON (cost me a false positive)**: an agent wrote a cw-multi-test PoC "proving" F-2; its OWN output said
`rewards moved into CONTRACT_REWARDS = 0` / `treasury fee forfeited = 0` while asserting an unexplained
price step — invalid, because cw-multi-test's Redelegate is just `remove_stake`+`add_stake`
(`src/staking.rs:731-762`), no distribution hooks, and it even let a SELF-redelegation succeed
(impossible on-chain: `ErrSelfRedelegation`). Same harness blindness as max_entries. Always read the
agent's numbers, not its assertions. See [[feedback-workflow-agents-coverage-not-verdict]].

META that produced both: the team ships **LLM-written pre-emptive "this is intentional / accepted in audit"
README paragraphs** (commits `80e662f`, `3bd5b0c`, `d60ddba`, `Co-Authored-By: Claude Opus 4.8`) dated exactly when
the repos entered Immunefi scope. Each paragraph is a CONFESSION of a vector already reported (dup risk) — the
money is in the ADJACENT SIBLING the paragraph does not consider. F-1 is literally the shadow of their
`max_entries` note. See [[doctrine-defense-shadow-confession]], [[feedback-audited-target-hunt-invariant-not-class]].

Live mainnet: staker `inj1x997dy6ka7y8u0r56yk2k83llspy33yet9zcnq` (fee 500=5%, min_deposit 1 INJ, 8 enabled
validators, 99.91% of stake on `injvaloper1vm2gf…`, 1/7 entries in use, 116,120 INJ liquid in contract).
Aptos staker `0x6f8ca77dd0a4c65362f475adb1c26ae921b1d75aa6b70e53d0e340efd7d8bc80` — 2 audits (OtterSec+MoveBit
May 2024), residual-rewards accounting traced across 5 interleavings and it balances; well-tested (200+ tests).
