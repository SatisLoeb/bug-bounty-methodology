---
name: project-injective-swap-deployed-example-010
description: "Injective \"Helix Swap Contract\" code_id 67 (inj1psk3468…) deploys atomic-order-example 0.1.0, NOT repo HEAD 1.1.2 — code_hash 540A79C5… is provenance truth, cw2 string only a hint."
metadata: 
  node_type: memory
  type: project
  originSessionId: a192f5d3-b494-41f9-aa1a-7780911eebcb
---

Deployed reality of the Injective swap contract (the fresh surface from [[project-injective-peggy-exhausted]]), verified against live mainnet `injective-1`:

- **Component:** swap contract, `code_id 67`, canonical instance `inj1psk3468yr9teahgz73amwvpfjehnhczvkrhhqx` ("Helix Swap Contract").
- **Deployed code_hash:** `540A79C5144AAC87D90DB41B54DE00170F7E8673FED4577262C98BDF0F562AF2` (user re-computed sha256 of the downloaded on-chain wasm → matches on-chain data_hash; download integrity confirmed).
- **Instantiated cw2 version:** `atomic-order-example 0.1.0` — an *example/tutorial* contract (the injective-cosmwasm SpotMarketOrder atomic-swap sample), NOT repo HEAD.
- **Three numbers, three namespaces — do not amalgamate ([[feedback-separate-and-attribute-not-amalgamate]]):** `1.0.1` = CometBFT (chain consensus, unrelated). `1.1.2` = repo HEAD, NOT deployed. `0.1.0` = the actual instantiated contract — the only one governing Cantina recevability.

**Why:** Cantina findings must reproduce against the DEPLOYED bytecode (code_hash 540A…/code_id 67), not repo HEAD 1.1.2. A bug present only in HEAD but not in the deployed example-0.1.0 build carries no live TVL impact on the canonical instance; auditing HEAD and reporting against it gets rejected as "not the deployed code." See [[feedback-commit-anchored-scope-pays-deployment-impact]].

**How to apply:**
1. The **code_hash 540A… is the provenance truth; the cw2 "0.1.0" string is only a hint** — `set_contract_version()` is dev-controlled metadata, routinely stale, and can say "example 0.1.0" over heavily-modified bytecode. To PROVE deployed==public example 0.1.0 (the Peggy-style byte-identical conclusion), reproduce-build atomic-order-example@0.1.0 with the pinned cosmwasm/rust-optimizer and compare sha256 to 540A…. Match ⇒ surface is that small example (SpotMarketOrder create → reply/refund accounting → min-output rounding). No match ⇒ custom build, stale cw2, audit the wasm itself.
2. Verify `inj1psk3468…` actually carries live order flow / is the instance Helix's frontend routes to (verify-don't-assume) before crediting "canonical + value-bearing".
3. Audit the example-0.1.0 surface, not HEAD 1.1.2. Likely /extract vein (swap value math): reply-handler refund path and min_output rounding.
