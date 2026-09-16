---
name: strata-immunefi-resource-only-critical-pays
description: "Strata Immunefi ($250k) = RE-SOURCE; deployed periphery clean, the 2 juicy math assets not deployed ($0), and only Critical pays because High is capped $10k"
metadata: 
  node_type: memory
  type: project
  originSessionId: 842c0079-8868-49b2-b252-41a2746966cf
  modified: 2026-09-09T19:12:41.733Z
---

Cible **Strata** (Immunefi, risk-tranching Senior/Junior CDO, Solidity/Ethereum, $250M TVL, marchés Ethena USDe + Neutrl NUSD). Engagement complet 2026-09-08/09 → **RE-SOURCE**. Détail: `D-cve/strata/TARGET-DOSSIER.md` + `SCOPE.md` + sources déployées dans `D-cve/strata/deployed-src/`.

**Kills structurels (pas EV):**
- **AccountingLib.sol et RoundingGuard.sol NE SONT PAS DÉPLOYÉS** — absents de toute source live (grep sur le bytecode vérifié via Blockscout). Les deux assets math les plus tentants (split Senior/Junior loss ; rounding ≤1 wei) valent donc **$0 funds at risk** sous le calcul Critical "10% des fonds directement affectés" → non payable. NE PAS y dépenser.
- Le blob Immunefi pinne le ref de branche mouvant `tranches` (commit stale 25 mai `2be97f9`) qui **404 sur AccountingLib** → tout finding accounting doit s'ancrer au bytecode déployé, pas au blob.
- Périphérie DÉPLOYÉE (TrancheDepositor, ERC20Cooldown/UnstakeCooldown, AprPairFeed, TwoStepConfigManager, CDOComponent, governance) balayée propre pour attaquant non-privilégié: cooldowns = self-griefing (Gate 1, externes cappés 40<70) + finalize swap-pop correct; TrancheDepositor min-1:1 = self-slippage (user peut passer swapAmountOutMinimum); AprPairFeed = oracle-round-derived non-flash-manipulable (Gate 3 oracle-tiers OOS); TwoStepConfigManager = onlyRole trusted (OOS).
- Le seul défaut solvabilité (DiscreteAccounting NAV-split → InvalidNavSplit gel permanent) est **hors-scope (cœur non listé) + known-issue #3 déclaré + "effectively unreachable"** (Junior ~5% floor + flat NAV ≥1 an). Le fix 6aee201 (4 juin) n'est pas déployé (impls mars/avril) mais l'issue est déclarée.

**Why RE-SOURCE renforcé:** la grille (vérifiée 2026-09-09 sur la page /information/, cf [[immunefi-webfetch-scope-page-mangles-rewards]]) est **Critical $250k/$10k, High MAX $10k, Medium $5k, Low $1k** — High/Med/Low sont tous ≤$10k. Donc **SEUL un Critical paie** vraiment (theft direct / permanent freeze / insolvency). Or il n'existe aucun chemin Critical in-scope: le deployed-periphery est propre et les math juteux sont non-déployés.

**How to apply:** sur Strata, ne construire QUE si l'impact est un Critical on-chain (theft/permanent-freeze/insolvency) ancré au bytecode déployé. Tout ce qui atterrit High-ou-moins = ≤$10k, EV négative après KYC+fee+6-audits-dup. La valeur résiduelle si elle existe est off-chain/web (le TVL tient sur stratégies Ethena/Neutrl/Midas + keepers/updaters) — hors des 11 contrats de ce programme. RE-ARM: si AccountingLib/RoundingGuard sont un jour DÉPLOYÉS sur les impls live, le seam math redevient payable.
