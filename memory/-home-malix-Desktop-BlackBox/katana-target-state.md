---
name: katana-target-state
description: "Katana (Immunefi) — état d'audit ; near-fortress mesuré, 0 clean payable, edge = deployed-anchor drift"
metadata: 
  node_type: memory
  type: project
  originSessionId: 85466c6c-d285-4be1-9ceb-63977f034c57
  modified: 2026-08-21T10:24:06.129Z
---

Katana Network (Immunefi, max $80k, PoC+KYC) — DeFi chain (Polygon CDK / AggLayer). Audité 2026-08-21 par fan-out 11-agents Fable-5 (même méthode que [[ssv-network-target-state]]). VERDICT : **near-fortress mesuré, 0 clean payable** ; le SEUL vrai code non-audité découvert = le drift deployed-vs-HEAD, qui a tout résolu en OOS/dup.

**LE MOVE DÉCISIF (deployed-code-not-HEAD, cf [[deployed-code-not-head]]) :** le déployé n'est PAS le repo HEAD.
- vault-bridge (agglayer/vault-bridge) : déployé = **v0.5.1** (version() on-chain), repo HEAD = v1.1.1. Les 5 audits (Sigma Prime v0.3, ChainSecurity v0.4, Certora v0.5/v1.0/v1.1) → seul v0.5.0 Certora + v0.4.0 ChainSecurity couvrent le déployé. vbTokens = agglayer-only (les contrats layerzero/ de HEAD NE SONT PAS déployés). Seul delta non-audité = MINTER_BURNER_ROLE (ajouté v0.5.0→v0.5.1) → tenu par l'OFT adapter (conservé, secondaryChainBalance==totalNetMinted exact), role DEFAULT_ADMIN-gated = OOS.
- governance (katana-network/katana-governance) : déployé = ve-governance **v1_2_0/v1_4_0** au tip remediation Halborn **audit-4** (dup-dense), PAS le develop@Nov2025 cloné. avKAT = develop + commit "conversion-window" (guard votingActive() sur depositTokenId, DÉPLOYÉ impl 0xd306…a77d).

**Surfaces (toutes mesurées-clean/OOS/dup, artefacts exécutés) :** VaultBridgeToken core (money-path byte-identical audité, 1:1 identity) · NativeConverter×5 (backing==underlying.balanceOf exact) · CustomToken vbTokens (mint=bridge‖converter‖OFT-adapter tous trusted, reinit consommé _initialized=2) · KAT OFT (custom→standard déjà upgradé on-chain, ledger +1004 KAT solvent) · KAT token (mint capacity-gated, formally verified, PAS ERC20Votes) · Jitosol OFT (stock LZ, single Solana peer, 1:1) · vKAT vote-escrow (reset-on-transfer câblé, gaugeVotes≤getVotes tenu) · avKAT ERC4626 262M KAT (principal-conserving, totalAssets non-inflatable, minDeposit=230 KAT tue inflation) · Swapper/Merkl (DUP Cantina High 3.1.1 Fixed PR21, paye msg.sender only) · NFT-repr (pas de setter URI, tokenURI vide) · seam MigrationManager/FEP (agglayer-only pas de replay, FEP=AggchainFEP v3.0.0 shared=OOS).

**Lead le plus tranchant, tué (First Maxim) :** merge() v1_2_0 NE reset PAS le gauge-vote de la source (le call reset-to-voter a été RETIRÉ) → chassé vote-then-deposit double-count (Critical gov + double reward). Tué : le TRANSFER du veNFT vers le vault (précède merge) déclenche moveDelegateVotes→updateVotingPower→_reset (AddressGaugeVoter L316 reset quand power baisse), et transfer user↔user est whitelist-disabled. gaugeVotes≤getVotes vérifié on-chain.

**Résidus non-payables :** createLockFor permissionless (audit-4 §7.5 dup, grief-with-cost) · single-DVN KAT OFT (Hexens KATA1-2 Med, centralization-OOS) · drainYieldVault DoS (Certora L-05 Low, documented) · MINTER_BURNER_ROLE uncapped mais trusted (OOS).

**Adresses clés (Katana 747474) :** NativeConverter 0x639f…C77DE · vbUSDC 0x203A…FD36 (impl 0x58bb…f2f1) · avKAT 0x7231…FbfCeB (impl 0xd306…a77d, 262M KAT) · vKAT escrow 0x4d6f…c13Ead (447M KAT) · vKAT lockNFT 0x106F…296d · gauge voter 0x5e75…9352 · clock 0x1704…95ab (14d epoch/7d vote) · strategy 0x6023…0463 · Swapper 0x92D2…4768 · Merkl 0x3Ef3…D9Ae · unified LxLy bridge 0x2a3D…2EDe. ETH RPC cloudflare-eth.com ; Katana RPC rpc.katana.network. Source local : ~/Desktop/BlackBox/katana/{vault-bridge,vault-bridge-v051,katana-governance,lz-kat-upgradeable,kat-token}, FINDINGS/*.md, CONTEXT.md.

**Réouvrir si :** vault-bridge upgrade v0.5.1→v1.x déployé sur Katana (nouveau code) · vbToken câblé à un underlying fee-on-transfer/rebasing · gov redéployé avec LINEAR≠0/MAX_EPOCHS>0 ou lockNFT enableTransfers (débloque double-vote) · nouvelle strategy qui persiste un Merkl operator at-rest · avKAT re-init/nouvelle master. ROI faible ($80k, sur-audité).
