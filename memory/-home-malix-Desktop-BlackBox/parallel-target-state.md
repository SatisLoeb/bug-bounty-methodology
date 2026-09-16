---
name: parallel-target-state
description: Parallel V3 (Immunefi $250k stablecoin) — état de chasse; SC-core mesuré-forteresse.
metadata: 
  node_type: memory
  type: project
  originSessionId: e8f60518-cd46-4277-a906-81b71581d9b9
  modified: 2026-08-15T21:00:26.292Z
---

**Parallel V3** (Immunefi $250k, stablecoin CDP, Angle-Transmuter fork) — mesuré-CLOS côté SC le 2026-08-15, hand-audit complet (firmaudit, crown-jewels-first).

**Verdict : forteresse SC sur le déployé mainnet, 0 payable.** Fork de Angle Transmuter (« Parallelizer » = Transmuter renommé). 4 firmes (Bailsec, Certora, Cyfrin, Zenith) + **double FV** (Certora sur Parallelizer+BridgeToken, Cyfrin FV) jusqu'à v3.2 + passe Bailsec juin-2026 (savings-donation). HEAD = v3.2.1 (2026-07-30).

**Surface hand-auditée (tous les 5 repos, untrusted-reachable) = sound :** Surplus(net-new)+LibSurplus · Savings 570L(2× Angle, storedAssets anti-donation)+EIP3009(x2 byte-identiques)+SavingsEIP3009 · sPRL1/sPRL2/TimeLockPenaltyERC20(invariant Aura=shares+unlocking) · RewardMerkleDistributor · Main/SideChainFeeDistributor · **BridgeableTokenP 680L (custom OFT, Certora-FV'd, credit/debit balance conservé)** · FlashParallelToken · PRL LockBox/PrincipalMigration/TokenP.

**Disconfirmers EXÉCUTÉS on-chain (cast, diamond 0x6efeDDF9…F262a2, AM 0x94Ea…5F7a) :**
- P-01 (Surplus over-mint via managed-`totalAssets`) = **reachability-null** : 4 collat (frxUSD/sfrxUSD/USDe/sUSDe) tous NON-managed + le mint over-va aux payees governance pas à l'attaquant. Latent design-note only.
- AccessManager wiring sain : USDp.mint=role 110 (minter, pas PUBLIC_ROLE), processSurplus/release=30(keeper), setFees=20, setOracle/updatePayees/upgrade=10 ; 4 minters légit confirmés (diamond/savings/bridge/flash).
- « anomalie » 816k issued vs 29.5k USDp local = OFT-bridged (normal, pas un bug).

**Drift post-audit = NULL (diffé 2026-08-15) :** delta source après dernière-audit-merge (2026-07-13) = 1 getter `getSurplusBufferRatio()` + 1 constante keeper-role ; viaIR-off = hardhat.config only (legacy≡viaIR). Tokens/BridgeableTokenP (FV'd) : 0 drift post-FV (dernier changement 2026-02-28 < Cyfrin FV 2026-03-04) ; les labels de fix d'audit = les classes que je chassais (issue_01 globalCreditLimit-bypass, issue_27 isolate-mode) déjà trouvées+fixées. Déployé=HEAD (le getter post-audit répond on-chain). **Résidu non-clos (ne flippe pas) :** enum complète role-110 RPC-capped (4 minters confirmés) ; libs Angle-core lues au seam seulement (FV'd).

**RE-SOURCE (déclencheurs de réouverture) :** (1) **scope Web & App du même programme** (app.parallel.best — la vue Web/App existe ; pattern Polymarket = les seuls payouts de l'opérateur sont web/API/off-chain) ; (2) keeper/relayer off-chain (qui drive processSurplus / fee-bridge release / merkle updateMerkleDrop) ; (3) code déployé NEUF (nouveau module, nouvelle chaîne, upgrade post-v3.2.1). NE PAS ré-auditer le SC-core sans déclencheur. Workspace: ~/Desktop/BUGS/parallel-recon/. Cf. [[deployed-code-not-head]], [[report-no-self-devaluation]], [[wsb-sweep-blackbox-outcome]].
