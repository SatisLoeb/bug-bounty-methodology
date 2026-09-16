---
name: project-sbtc-upshift-seam-null
description: "sBTC (Stacks, Immunefi $250k, KYC) — off-chain-orchestration seam (signer<->emily<->block_observer) + reorg-accounting = MEASURED NULL, 10 traced kills. RE-SOURCE. Don't re-drill this seam. WSTS-internal + Clarity-core undrilled but saturated/downgraded."
metadata:
  node_type: memory
  type: project
---

**sBTC = separate Immunefi program** (carved out of Stacks-L1 on 2 Jul 2026; $250k, **KYC required** — operator's KYC is done). Repo `~/Desktop/BUGS/sbtc-audit` @ HEAD #2097. 5 in-scope assets: contracts (Clarity), Emily (Rust/AWS-Lambda API), signer (Rust), deposit-lib (`sbtc/src/deposits.rs`), WSTS (Rust MPC, added 13 Jul). Full dossier+ledger in `sbtc-audit/TARGET-DOSSIER.md`.

**Engaged via intake→wide→upshift 2026-08-27.** /wide allocated depth to the off-chain seam (bet: attackathons hit Clarity+consensus, under-invested the AWS backend + emily↔signer trust boundary = upshift profile). **Bet FALSE.**

**MEASURED NULL — 10 traced kills.** Emily is a NON-authoritative coordination cache; every money-affecting value is re-derived from the signer's OWN observation of canonical Bitcoin+Stacks:
- deposit amount/recipient: `block_observer.rs:106` `get_tx_info` on own node; `deposits.rs:185` amount=real UTXO value + taproot-committed recipient.
- deposit mint underflow: gated `validation.rs:883` `max_fee.min(amount)`.
- withdrawal peg-drain: output = flat `amount` (`utxo.rs:619`), fee from SEPARATE `max_fee` bucket (Clarity locks `amount+max_fee`, `<= fee max_fee` l.173 + guarded refund l.181). The signer-side asymmetry (withdrawal validate l.1036 lacks `.min(amount)`) is correct-by-design.
- recipient: Clarity `validate-recipient` version 0-6 + hashbytes 20/32.
- mint trigger: swept status = canonical-chain SQL CTE (`read.rs:2239`); mint re-fetches real sweep tx (`tc:1366`, `BitcoinTxMissing` else).
- **reorg-accounting**: dedup = recursive CTE over canonical chain (reorg case explicitly tested `_response_tx_reorged`); `withdrawn_total` from `compute_withdrawn_total(canonical, window)`; rolling cap = rate-limit `saturating_add`. Every residual reorg race needs a **Bitcoin reorg ≥3-6 blocks** (buffers: `DEPOSIT_LOCKTIME_BLOCK_BUFFER=3`, `WITHDRAWAL_MIN_CONFIRMATIONS=6` Bitcoin blocks) = **miner cooperation = explicitly OOS**. Windows measured in Bitcoin blocks ⇒ Stacks-only micro-fork can't reach them.

**Residual (don't bother):** Emily unauth writes (`create_deposit`/`update_deposits_*`, no api-key) → signer re-validates on-chain ⇒ no fund path; caps at Medium "API crash/incorrect-processing", bled by <1%-user downgrade + rate-limit=3rd-party-AWS-OOS + `is_from_trusted_source` flag = **negative EV** on a Critical-focus program.
**Undrilled but deprioritized:** WSTS/DKG internals (malicious-signer non-Critical downgrade caps EV); Clarity core-accounting (saturated by 2 attackathons: `reports.immunefi.com/stacks-{i,ii}-attackathon` + `stacks.org/audits`).

**VERDICT: RE-SOURCE. Don't re-open without a NEW in-scope asset dated post-2026-08, a worthwhile Medium tier, or a relaxed malicious-signer downgrade (→ WSTS drill).** OUTCOMES row `sbtc-upshift-seam-2026-08-27`. [[feedback-findings-die-on-the-actor-not-the-mechanism]] [[reference-stacks-bugbounty-landscape-2026-07]]
