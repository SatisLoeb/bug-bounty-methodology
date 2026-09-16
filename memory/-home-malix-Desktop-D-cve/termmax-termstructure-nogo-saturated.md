---
name: termmax-termstructure-nogo-saturated
description: "TermMax (Term Structure Labs) Immunefi — NO-GO/low-priority intake; small $80k + 19 paid reports saturated, fresh assets all thin (TMX=LayerZero OFT, web $10k)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 842c0079-8868-49b2-b252-41a2746966cf
  modified: 2026-09-09T19:20:52.693Z
---

Cible **TermMax / Term Structure Labs** (Immunefi, prêt/emprunt taux fixe + AMM curves, Solidity/Ethereum multi-chaînes). Intake 2026-09-09 → **NO-GO / basse priorité**. Détail: `D-cve/termstructure/TARGET-DOSSIER.md` + `SCOPE.md`, repo cloné `D-cve/termstructure/termmax-contract-v2`.

**Faits:**
- Petit: **Max $80k**, Critical SC cap $50k (10% funds), High SC $25k. Web Critical $10k. **KYC NON requis**, PoC requis. Grille vérifiée sur /information/ (cf [[immunefi-webfetch-scope-page-mangles-rewards]]).
- **Saturé: 19 rapports payés**, live 2024, cœur repo figé au 27 mai 2026.
- Les 3 assets FRAIS (août 2026) sont tous fins: **TMX token = LayerZero OFT** (adresse 0x3c2f61… = contrat `AICre8Token`, 15 l. custom; `TMX.sol` du repo = OFT aplati 3260 l. dont 99% base LayerZero) → base OFT = **dépendance tierce OOS**, custom quasi-nul; App V2 web = tier $10k hors-edge on-chain.

**Why NO-GO:** petit plafond × saturation HIGH × surface fraîche fine, aucun seam on-chain frais de substance.

**How to apply:** ne pas re-intaker. Si l'opérateur insiste, le seul angle = cœur V2 math (vault ERC4626 bad-debt/dynamic-interest, courbes custom par ordre, 4 rôles vault) via extract/mrrobbot/power, MAIS d'abord la dup-map (audits externes TermMax + topics des 19 reports) sinon EV négative. Ancrer au bytecode déployé (deployments/ = eth+6 chaînes). RE-SOURCE recommandé.

**DUP-MAP FAITE 2026-09-09 → chemin GO conditionnel CLOS.** Git log: 33 commits `fix findings N` (N max=150 = audit compétitif ~150 findings) + 19 reports Immunefi. Classes déjà corrigées = exactement la fresh-slice proposée: `badDebt may overflow` (vault), `gt may be stoled` + collateral post-maturité (gearing), `sllipage can be stolend` (slippage), reentrancy router+vault, partial flash repay, flash rollover, oracle adapters. Négatif-space résiduel mince × plafond $50-80k → **NO-GO FINAL, RE-SOURCE**. Ne plus rouvrir.
