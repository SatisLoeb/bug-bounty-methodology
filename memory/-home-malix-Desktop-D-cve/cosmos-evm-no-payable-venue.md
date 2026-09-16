---
name: cosmos-evm-no-payable-venue
description: cosmos/evm module findings have NO open paying venue as of 2026-09; check venue BEFORE validating
metadata: 
  node_type: memory
  type: reference
  originSessionId: e0080da2-e75c-4d95-a6c2-f4c21d8fff97
  modified: 2026-09-16T16:18:49.812Z
---

**UPDATE 2026-09-16: venue RE-OPENED.** The Immunefi Cosmos scope update of 2026-09-16 now lists
**cosmos/evm as IN scope** (Blockchain/DLT, flagged Primacy-of-Impact; only `x/precisebank` is OOS).
Triaged-by-Immunefi + Vault-backed, $50k max, 75 USDC non-refundable fee, 4-node e2e PoC required.
So the blanket "no venue" below is HISTORICAL (was true 2026-09-09). Re-run the tier gate per finding —
the venue being open does not make a finding payable; this program's downgrade rules are brutal.
*(The parked `cosmos-evm-nil-pubkey-crash` was re-triaged 2026-09-16 → tier LOW, code-verified
mempool-confined, chain-halt path architecturally closed → still not worth submitting. See its
`VERDICT-2026-09-16.md`.)*

--- historical (2026-09-09) ---
Findings in the shared **cosmos/evm** module (e.g. the ghost-cache-context batch #01: commit=false CallEVM cache-context non-isolation in x/erc20/keeper) had **no open paying venue** as of 2026-09-09:
- **Immunefi Cosmos program**: cosmos/evm was **OUT of scope** (now IN scope, see update above).
- **HackerOne Cosmos program**: cosmos/evm IS in-scope but the **program is PAUSED** (not accepting/paying).
- Downstream Cosmos-EVM chains (MANTRA/Injective/Kii/Nesa) redirect shared-dependency bugs upstream, so they are not a substitute venue.
- NOTE: the ghost-cache-context batch #01 (x/erc20 keeper) now HAS a venue (Immunefi cosmos/evm), but
  re-triaged 2026-09-16 → **REJECT**: it was killed on VALIDITY (executed refutation 2026-08-14, delta=0
  via commit=false discard), not venue. The one open vector (transfer/commit=true) is closed by the
  BalanceHandler event-replay reconciler (`precompiles/common/balance_handler.go`), and the class is
  twice-patched (ASA-2026-002, GHSA-7g4w #1176/#1253/#1254 → "fixed upstream" OOS). cosmos/evm
  balance-handling = fortress; do NOT re-open the ghost-frame path. See
  `BlackBox/submissions/cosmos/RE-TRIAGE-2026-09-16.md`.

**Why:** validating a finding (dup-check, re-pin, harness) before confirming a payable in-scope venue burns effort on something unsellable. On 2026-09-09 a full v0.7.1..v0.7.2 diff + Gate-2/Gate-4 work was done on the ghost-cache-context finding before discovering it has no open venue.

**How to apply:** for any cosmos/evm (or shared-Cosmos-stack) finding, run the **payable-venue gate FIRST** — is there an OPEN program (Immunefi in-scope, or H1 un-paused) that lists this asset? If not, PARK the finding, don't validate it. Re-check H1 Cosmos status before reinvesting in batch #01. General rule reinforced: establish in-scope + payable + open BEFORE dup/re-pin/harness work. See [[feedback-manual-poke-bracket-mandatory]].
