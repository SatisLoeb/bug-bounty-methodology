---
name: veda-target-state
description: Veda (BoringVault) Immunefi — état de chasse ; 2 Criticals réels trouvés mais tous deux OOS ; 0 submittable in-scope.
metadata:
  type: project
---

Veda bug bounty (immunefi.com/bug-bounty/veda) — mesuré 2026-08-18. Max $1M. Impacts payables UNIQUEMENT : theft / permanent-freeze / insolvency (Crit) ; theft/freeze d'UNCLAIMED YIELD (High). PAS de catégorie DoS/griefing.

Scope = 52 assets = mêmes contrats core sur 3 familles : Ink (BalancedUSDC/BoostedUSDC = AccountantWithYieldStreaming + TellerWithYieldStreaming), Mainnet + Scroll (LiquidETH/BTC/USD = AccountantWithRateProviders + TellerWithMultiAssetSupport ; mainnet teller = TellerWithLayerZeroRateLimiting cross-chain). Source = github Veda-Labs/boring-vault (cloné ~/Desktop/BUGS/veda-src). **Ink déployé == HEAD prouvé par diff bytecode-source (commentaires seulement).**

## 2 Criticals RÉELS trouvés — tous deux OOS (ne pas re-dériver) :
1. **Odos inputReceiver sanitizer gap** (theft) : OdosDecoderAndSanitizer.swap/swapCompact ne pack PAS `tokenInfo.inputReceiver` → strategist merkle-contraint redirige les input tokens du vault. LIVE dans les décodeurs in-scope (fix OdosOwnedDecoderAndSanitizer câblé à ZÉRO décodeur prod). MAIS OOS ×2 : (a) projet-connu = PoC exploit committé `test/integrations/OdosTest.t.sol` (FakeUniV3Pool) ; (b) requiert rôle STRATEGIST trusted (OOS #5, le leaf Odos EST dans le privilège attribué). Non-bankable.
2. **AccountantWithFixedRate double-count** (insolvency, PoC exécuté-PASS) : `_calculateFeesOwed` override (AccountantWithFixedRate.sol:246) mesure le yield depuis la constante `fixedExchangeRate` à CHAQUE update et accumule `yieldEarnedInBase +=` (:266) SANS avancer de highwater mark (le base avance HWM à :617). 2 reports honnêtes au-dessus de fixed entre 2 claims → yield compté 2× → claimYield draine le principal. **MAIS OOS : AccountantWithFixedRate n'est déployé sur AUCUN des 52 (prouvé bytecode : LiquidUSD/BTC/ETH mainnet n'ont pas les sélecteurs claimYield 999927df / setYieldDistributor 3038a60d). FixedRate = uniquement vaults Sonic, hors scope.** → Réouvrir SI un vault FixedRate (Sonic) entre en scope.

## Clusters mesuré-clos (5 agents Fable + relecture perso) :
- Queue+Solver : conservation-safe, self-solve symétrique, CEI neutralise nonReentrant manquant, discount favorise le vault.
- Tellers : lead FoT/rebasing insolvency CLOS (aucun vrai token FoT ; stETH/eETH = 1-2 wei dust).
- Cross-chain LZ/CCIP : peer-auth double-gated (pas d'infinite mint), MessageLib correct, freeze rate-limit inbound = admin-recoverable + config-dépendant.
- Manager+Vault : merkle airtight, manage=call simple, invariant totalSupply-constant.
- Findings d'audit Certora acknowledged (M-02 reward off-chain, L-01 bridged-mint sanctions bypass, L-05 rescue grief) : tous non-payables.
- Prior BoringSolver REDEEM_MINT DoS (rate vs rate+1) : réel mais "unable to operate" PAS un impact Veda + cancel toujours possible (pas un freeze). Non-submittable ici. Draft dans ~/Desktop/BUGS/veda-pocs/submissions/.

## Seul lead in-scope ouvert : manipulabilité des rate providers (Veda garde oracle/flash-loan IN SCOPE). Nécessite énumération on-chain des rateProviderData par asset + analyse par-provider. Prior FAIBLE (assets ether.fi = sources non-AMM : Chainlink, wstETH/weETH natif). Non creusé.

Voir aussi [[deployed-code-not-head]] [[recevability-gate-before-poc]] [[report-no-self-devaluation]] [[by-design-gate-not-just-git-dup]].
