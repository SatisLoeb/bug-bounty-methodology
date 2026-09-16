---
name: farmed-program-dup-baserate
description: Sur un programme Immunefi mûr/haut-plafond, mesurable-clean + novel-looking ne prédit PAS un dup-risk bas ; les bons findings convergent et sont déjà soumis en privé. Suivre le fee-EV par programme.
metadata:
  type: feedback
---

**Preuve (Babylon, 2026-08-21) :** 3 findings soumis, 3 DUPS, 0 payout, ~$100+ de fees.
- C-2 (covenant-signer HMAC replay) -> dup #62507 (Medium, privé)
- V-1 (atomic slasher ordering) -> dup (Medium, escaladé Apr 26, privé, ~4 mois avant nous)
- indexer sanitizeEvent DoS -> dup #74576 (public)
Deux des trois dups étaient des soumissions PRIVÉES Immunefi — invisibles à toute vérif source-primaire
(git log -S, scan PR/issues, lecture d'audits publiée). Ma Gate-4 renforcée était correcte et propre sur le
canal public ; le finding était déjà pris quand même.

**La leçon dure (extension de [[audited-control-is-trodden-vein]]) :** j'ai projeté une confiance HAUTE sur V-1
(« le plus propre de la semaine, meilleur que les deux dup'd sur chaque axe mesurable ») et c'était un dup. Sur un
programme mûr/haut-plafond/ouvert-longtemps, **« mesurable-clean + a l'air novel » ne prédit PAS un dup-risk bas** :
les bons chercheurs CONVERGENT sur les mêmes bugs subtils-mais-réels (crypto-adjacents, extraction, seams
d'enforcement off-chain). Le trodden-vein n'est pas que « contrôle audité » — c'est TOUTE cible de chasse à haut
intérêt. La vérif était juste ; c'est la RECOMMANDATION (« GO, vaut le pari ») qui était trop optimiste vu la
base-rate accumulée.

**Sévérité, 3e confirmation :** #62507=Medium, V-1-prior=Medium (reporter a tenté High/Critical, landed Medium).
La classe « avoiding-slashing / griefing / liveness sur enforcement off-chain » paie MEDIUM sur ces programmes,
peu importe le mapping verbatim sur l'impact listé. Ancrer la sévérité sur les payouts OBSERVÉS de la classe (ces
dups eux-mêmes), pas sur ma lecture de la liste d'impacts.

**How to apply :**
1. Suivre le **fee-EV par programme** dans le state-memory. Après 2 dups invisibles sur un même programme, traiter
   le canal comme SATURÉ-EN-PRIVÉ : le fee-EV est structurellement négatif pour du « clean mais pas primitive-novel »,
   RE-SOURCE hors du programme entier — ne pas continuer à nourrir chaque finding suivant.
2. Réserver le pay-to-submit à un finding avec une **primitive vraiment neuve** (pas juste correcte+propre) OU sur un
   programme FRAIS (relaunch, nouvelle chaîne, code récent) où la base-rate de dup privé est basse.
3. Quand je recommande un GO-fee, pondérer explicitement la base-rate de dup du programme, pas seulement les axes
   mesurables. Dire « mesurable-clean mais base-rate dup élevée sur ce programme farmé » plutôt que « le plus propre,
   vaut le pari ». Cousin de [[recevability-gate-before-poc]], [[measure-before-asserting-in-reports]].
