---
name: project-stbl-fortress-executed-null
description: "STBL (HackenProof, all-Critical, EVM verified source) — RWA principal/leveraged-token tranching on Ondo USDY/OUSG. Executed NULL: core value math is a clean light-fortress (Cyfrin 0-High + 5-finder workflow + manual poke all clean). Front-run is OOS which kills the only live bug (M-3). RE-SOURCE, don't re-audit."
metadata:
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

**STBL Smart Contracts** — HackenProof, all-Critical scope, EVM (ETH + BSC), **verified source** (Etherscan). RWA
yield stablecoin, founder Reeve Collins (Tether co-founder), $50M USST line w/ Ondo (credible payer). Deposit Ondo
**USDY** (rebasing yield USD) / **OUSG** (T-bills) → mint **USST** (principal stablecoin) + **YLD** (yield NFT). Two
tiers **PT1** (Principal Token) + **LT1** (Leveraged Token), each Issuer/Vault/YieldDistributor/Oracle. `~/Desktop/BUGS/stbl-2026`.

**Gate (the reason it's a fortress):** ONE Cyfrin audit (v2.0, Sep 10 2025, commit `568c9211`, 10 days) but scope ≈ FULL
deployed set → NOT the Perena un-audited-drift edge. **18 findings: 0 Crit / 0 High / 4 Med / 7 Low.** All resolved
except acknowledged M-3/I-4/I-6. `audits/cyfrin-stbl.pdf`.

**SCOPE KILLER:** OUT = "vulnerabilities exploitable through front-run attacks ONLY." → the one LIVE unfixed real bug,
**M-3 (front-running yield distribution → theft of accrued rewards, ACKNOWLEDGED)**, is OOS. Any MEV/reorder angle is dead.

**EXECUTED NULL (2026-07-22)** — 5-finder adversarial workflow (`stbl-conversion-seam-hunt`, ran twice: 1st died on
transient API ConnectionRefused, 2nd = 5 done/0 err, all `findings:[]`) + independent manual poke of LT1_Vault:
- **Vaults PT1/LT1** (PT1==LT1 byte-identical logic): deposit/withdraw/yield conservation ✓ (constant-price round-trip
  net-zero, user recovers `G(1−df−inf−wf) < G`, never more than deposited). Every fetchForwardPrice(asset→USD)/
  fetchInversePrice(USD→asset) call-site DIRECTION-CORRECT. Haircut = returnable over-collateral BUFFER (subtracted at
  deposit into stableValueNet, added back at withdraw — inert for theft). Rounding floors protocol-favorable. Leverage
  lives in the external oracle, applied SYMMETRICALLY → cancels every round-trip, can't amplify. Reentrancy unreachable
  (USDY/OUSG are hookless plain ERC20). distributeYield = YIELD_DISTRIBUTION_ROLE-gated.
- **Issuers/split**: no M-1 sibling (M-1 haircut fwd/inv IS fixed, generateMetaData L417/419 uses inverse; and it's
  metadata-only, never read in a value path). PT/LT split conserves.
- **Core/Register/USST/YLD**: M-2 bridgeBurn fix present (pull-then-burn requires allowance), M-4 negative-rebase
  solvency guard present, **I-6 = `withdraw(uint,address)` is an EMPTY NO-OP** (no attacker-profit).
- **Only 2 defects found, BOTH non-payable**: (1) `STBL_Register.fetchAssetElement` flag mapping OFF-BY-ONE (omits
  doc's isSetup=5 → flag≥5 returns wrong field) — but **ZERO on-chain call-sites** (getter for off-chain only; value
  paths use fetchAssetData struct-getter) → view-only, First-Maxim-pierced. (2) STBL_Decoder imported into Core, never
  invoked (dead code).
- The `// look at this in depth` dev comment (LT1_Vault:239 cumilativeHairCutValue -=) DEFLATES: variable is
  **write-only** (never read in a value expr) → worst case underflow = revert = DoS, not theft.

**VERDICT: cheap-gate win, executed NULL, ZERO PoC burned. RE-SOURCE.** Core value math clean, rounding
protocol-favorable, only real theft (yield front-run) is OOS. Un-swept residual (low-EV): cross-chain bridge
(Token/USST on ETH+BSC, bridgeBurn/mint BRIDGE_ROLE-gated + off-chain orchestration = likely OOS/off-repo); OUSG set
(== USDY byte-identical). Don't re-audit. Pairs [[project-arcadia-fortress-executed-null]] [[project-valantis-stex-fortress]]
[[feedback-tool-complete-stop-polishing]]. LESSON confirmed [[feedback-check-prior-audits-and-competitions-at-intake]]:
1-audit + scope==deployed + 0-High + front-run-OOS = fortress; the drift-edge that made Perena payable is ABSENT here.
