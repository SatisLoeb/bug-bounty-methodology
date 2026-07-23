---
name: reference-landscape-scan-2026-07-21
description: Fresh RE-SOURCE shortlist (2026-07-21) of solo SC bounty targets w/ off-chain/cross-lang/precompile seams; supersedes the 07-20 scan
metadata: 
  node_type: memory
  type: reference
  originSessionId: f5652256-c816-44e4-b6af-cd0249239b55
---

RE-SOURCE sweep 2026-07-21 (33-agent workflow, 100 raw → 73 SC survivors → 24 verified → 4 `pursue`). Triggered because the operator's HTX HackenProof program (web/CEX black-box, ~$153/submission, 50-rep gate) was triaged NO-FIT for a code-audit hunter. **Bottom line: a real fresh solo set exists but NO soft target — every one pays only on the narrow post-audit / cross-language / precompile DELTA, never the audited core.**

Always apply [[feedback-check-prior-audits-and-competitions-at-intake]] before spending depth: my saturation estimates below are workflow-derived and historically optimistic.

## Tier 1 — clean access, low/med saturation, best solo win-probability

- **Hermetica hBTC / USDh** — Immunefi, $100k crit (min $20k, no KYC, USDC-on-ETH), Clarity/Stacks. Repo public: github.com/hermetica-fi/hermetica-contracts (13 in-scope Clarity contracts; keeper granite-liq-bot is TS, archived, OOS). SEAM: daily off-chain NAV push → on-chain Controller ERC-4626-style share mint/redeem math — the NAV-update authority + rounding/mint boundary is the unowned seam (off-chain backend OOS; the on-chain entrypoint that TRUSTS it is in-scope). Saturation LOW-MED (niche Clarity; prior Clarity-Alliance+StrataLabs 2024 audits but contracts materially expanded — hBTC launched Apr 2026 = the fresh delta). VEIN: firmaudit / darkside Door-C on the NAV boundary + extract share-conservation. NO nuke (Clarity has no barrage). = yesterday's #1, HOLDS as best risk-adjusted.
- **Stackup Keystore + Forwarding-Address** — Cantina, $100k crit, Solidity/Foundry, repo github.com/stackup-wallet/keystore. SEAM: only the Merkle root lives on-chain; config tree off-chain, proof selects verification method; shared multi-chain treasury → same root → cross-chain signature/UserOp replay (the Jul-2025 3-day audit ACCEPTED replayability/nonce-absence as design = the residual). Saturation MED (one 3-day audit, 0 crit/high). VEIN: power (proof method-selection + forwarding-address sweep authz) + darkside. Highest raw P(win) — core readable in 1-2 days.
- **Midas Solana** — Cantina, $500k crit, Solidity + Rust/Anchor. Repo github.com/midas-apps/contracts-solana. SEAM: Solana re-implementation of the audited EVM mint/redeem/oracle (fresh Anchor cross-program authority on the SPL-2022 mint-authority holder) + post-2024-audit EVM vault variants (DepositVaultWithUSTB, RedemptionVaultWithSwapper). Saturation MED; both repos pushed within the last week; clean public clone, no access gate. VEIN: invfuzz (EVM↔Solana differential) + power (Solana cross-program authz) + darkside (new vault variants). Freshest of the strong candidates.

## Tier 2 — high ceiling, high variance / access friction

- **Kinetiq** — Cantina ~$1M pool ($5M-crit advertised), Solidity HyperEVM + HyperCore CoreWriter precompiles. Repo github.com/code-423n4/2025-04-kinetiq. SEAM: kHYPE:HYPE booked against what HyperCore actually reports/executes (conservation invariant on the validator-delegation path). CoreWriter shipped 2025-07-05 AFTER all four audits (Spearbit/Pashov/Zenith/C4) = the highest-value code is the least-audited; few auditors know HyperCore precompile semantics. Saturation HIGH. VEIN: darkside Door-A/C (C4-base vs deployed) + extract + upshift (OracleManager/StakeHub keeper). High-variance swing.
- **Paxos** — Cantina $1M crit / $2M annual cap, Solidity+LayerZero + Rust/Solana. Repo github.com/paxosglobal/cross-chain-contracts. SEAM: OFTWrapper delegated-mint proxy — does the LZ-triggered cross-chain mint/burn re-run the freeze-list/sanctions/SupplyControl rate-limit checks a same-chain transfer runs, or is there a differential bypass? The path CLAIMS "same AML standards" (first-maxim gate asserted present, never proven to hold); OFTWrapper had a single audit. Saturation MED. CAVEAT: confirm submission access (invitation-only early). VEIN: power (authz differential) + upshift + extract (USDG rewards conservation).

## Skip / deprioritize for solo

- **Ondo Perps** — Cantina, now $1.5M crit BUT 56 reports already + mandatory KYC + off-chain SGX matching engine not clonable + on-chain repo access-gated. Dup wall. Was yesterday's #2 → DOWNGRADED lean-skip. (Cantina bounty, Cantina-triaged since 2026-06-02.)
- **OKX Labs (DEX Router + PMM)** — $1M but HIGH saturation + must provenance-verify mainnet deployment by an OKX deployer first (unshipped Move/Solana/PMM variants OOS = heavy day-1 gate).
- **Superform v2** — $100k+, 4-audit fortress, v2-core pushed 2026-07-21, only the cross-domain SuperExecutor↔SuperDestinationExecutor / dual-validator seam is fresh.
- **USDai** — now KNOWN OOS, see [[project-usdai-intake]]. Was 07-20 #3.
- Mega / dup-wall: Reserve ([[project-reserve-dtf-filler-seam-null]]), Pendle V2, Morpho, Liquity BOLD, Euler, Uniswap, Polymarket (fresh V2 PMCT/PermissionedRamp sliver only).
- Watch: Concrete Finance $250k (off-chain NAV signer, Upshift analog — confirm the Earn-V2 repo is actually public first), Modular Account V2 (EIP-7702 SemiModularAccount7702 init post-audit), Centrifuge V3.1→3.2 multi-adapter delta, Agglayer VaultBridge.

## Discipline (whichever pick)
Day-1 provenance gate FIRST — deployed == in-scope + confirm submission access (orca P0; [[project-injective-swap-deployed-example-010]]). Carryover 07-20 picks Sport.Fun/Citrea/Metric/Paradex were swept but cut by the 24-candidate verify cap — not re-verified, not killed (Citrea already NULL, see [[project-citrea-clementine-fortress]]).
