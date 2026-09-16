---
name: charm-alpha-pro-target-state
description: "Charm Alpha Pro Vaults (Immunefi) — état mesuré, seul lane payable = rebalance-TWAP-MEV"
metadata: 
  node_type: memory
  type: project
  originSessionId: 20ed2a6f-0642-4b65-b530-a6f866520993
  modified: 2026-08-20T11:38:26.987Z
---

**STATUT : MESURÉ-CLOS 2026-08-20 (décision opérateur : shelve).** Aucune soumission. Rouvrir seulement si un vault à range SERRÉE (base<=~420) accumule >~$0.5M de TVL réelle (rend le seul lane payable, rebalance-TWAP-MEV, profitablement exploitable ET moins rejetable en by-design).

Charm "Alpha Pro Vaults" — Immunefi, FLAT rewards (Crit $10k / High $3,750 / Med $1,500 / Low $1,000), PoC required, no KYC. Programme n'exclut PAS oracle-manip/flash-loans (verbatim). Mesuré 2026-08-20.

**Scope = 3 fichiers repo main charmfinance/alpha-vaults-v2-contracts @ 0174095** : AlphaProVault.sol, AlphaProVaultFactory.sol, CloneFactory.sol. Clones locaux : `~/Desktop/BlackBox/charm/v2` (in-scope), `v21` (fork v2.1 2025 = oracle des peurs dev, OOS).

**DÉPLOYÉ ≠ HEAD (cf [[deployed-code-not-head]])** : in-scope HEAD 0174095 A le fix MINIMUM_LIQUIDITY=1e3. L2 déployé (arb/op/poly, codehash 0x01c0e0) = commit b632c9e (rebalanceDelegate présent, MINIMUM_LIQUIDITY ABSENT). Mainnet template = pré-b632c9e 2022 (rebalanceDelegate() revert). → le bug d'inflation first-deposit vit sur L2 mais est PATCHÉ dans le code scopé → piège, non soumettable.

**TVL = poussière partout** (mainnet 26 vaults, 24 vides ; les 2 financés [16]base=5000 [25]base=2600 ~$140 ; L2 idem single-wei). MAIS reward FLAT + createVault permissionless → "funds at risk" = tout futur déposant, donc matérialité PAS un NO-GO sec.

**Classes MORTES/réfutées (artefacts exécutés)** : (1) inflation first-deposit = PeckShield 2023-134 PVE-001 publié sur ce repo. (2) permissionless-rebalance access-control = docs by-design + GitHub issue #2 + OOS best-practice. (3) deposit price-manip theft = RÉFUTÉ (round-trip exécuté : v2 deposit ne mint jamais en position, la manip ne fait que surfacturer l'attaquant, profit $0). (4) accounting (rounding-theft 200k trials, underflow-freeze invariant, withdraw fee-asymmetry) = conservation-sound, RÉFUTÉ ; seul résidu = assert(0,0) L258 DoS mais uniquement sur vault VIDE = Medium griefing faible/probable dup. (5) unvalidated pool = Cantina 2025 Medium + OOS self-inflicted.

**SEUL LANE PAYABLE (PoC mainnet-fork ré-exécuté par l'opérateur)** : `rebalance-TWAP-MEV`. checkCanRebalance (AlphaProVault.sol L462-485) lit slot0.tick ET getTwap() (L488) même bloc ; le swap de manip de l'attaquant écrit l'observation Uniswap avec l'ANCIEN tick → getTwap() retourne le TWAP pré-manip (laggé) tandis que slot0.tick est déjà bougé. rebalance() (L396, permissionless quand delegate==0 = TOUS les 26 vaults) re-centre base+limit sur le tick manipulé → l'attaquant reswap et trade contre la liquidité fraîche mal-prixée. Gate borne EXACTEMENT à maxTwapDeviation=100 (D=100 passe, D=101 revert "TP") ; maxTwapDeviation=100 & twapDuration=60 sur 25/26 vaults = config de-facto standard. Profit dépend de la largeur de range : ranges LARGES (les 2 vaults financés) = perte ; ranges SERRÉES (base=240/300/420, configs réelles des vaults live 15/14/13 mais VIDES) = net-positif — base=240 $5M → attaquant +$3.1k, vault −$5.2k, un seul bloc. Break-even ~$0.5-1M sur pool profond. PoC : `~/Desktop/BlackBox/charm/mev-poc/test/Mev.t.sol`.

**Résolution dup (Cantina 2025 lu directement)** : 3.2.6 "ERC777 self-sandwich mint" = ERC777-ONLY (pas ERC20 standard), trigger = hook reentrancy du transfert sur le mint de DEPOSIT (v2.1-spécifique), PAS price-manip du rebalance. 3.2.3 = manager reset les contraintes (privileged/OOS). Cantina n'a PAS rapporté "sandwich du rebalance par manip du tick dans la bande maxTwapDeviation" → mon lane N'EST PAS un dup verbatim. MAIS 3.2.6 + 3.2.3 furent ACKNOWLEDGED by-design, et maxTwapDeviation est la borne documentée intentionnelle → un triager rangera très probablement le résidu within-band dans le même seau "accepted tradeoff".

**Verdict = GO FAIBLE / lean-NO-GO (~25-35% payout, atterrissage probable Low/Info si accepté)** : seul finding réel, in-scope + déployé, non-dup-verbatim, defeat quantifié du claim docs "TWAP prevents MEV". MAIS deux kill-risks dominants : (a) BY-DESIGN — maxTwapDeviation=100 = borne acceptée documentée, résidu within-band = 0.1%/rebalance = lit comme le tradeoff que Charm/Cantina acceptent déjà ; (b) MATÉRIALITÉ — aucun vault financé n'est profitablement exploitable aujourd'hui (financés [16]/[25]=ranges larges=perte attaquant), les configs serrées profitables (vaults 13/14/15) sont VIDES → funds-at-risk purement prospectif. Ne pas concéder le tier en écrivant (cf [[report-no-self-devaluation]]) mais ne pas oversell : si soumis, framing = falsification quantifiée de l'invariant documenté + configs serrées = choix réel du manager (25/26 vaults à mtd=100), ancrer High avec argument Critical-MEV (cf [[audit-comp-severity-anchoring]]), MAIS prévenir l'opérateur que le rejet by-design est le scénario modal. Décision d'engagement = à l'opérateur.
