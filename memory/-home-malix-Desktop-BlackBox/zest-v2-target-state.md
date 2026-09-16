---
name: zest-v2-target-state
description: "Zest Protocol V2 (Immunefi, Stacks/Clarity, $100k) — FERMÉE 2026-08-07 : 8 gates fermés par mesure, 0 finding ; ne rouvrir que sur déclencheur listé."
metadata: 
  node_type: memory
  type: project
  originSessionId: 926ccf4a-cfee-413f-baee-f7ad819193dc
  modified: 2026-08-07T09:31:52.927Z
---

**FERMÉE le 2026-08-07, 0 finding déposé, 0 rapport rédigé.** Motif : 8 gates ouverts, 8 fermés par mesure exécutée ; aucun ne franchit le seuil de recevabilité. Cible auditée 4× (Clarity Alliance ×3, Asymmetric, Greybeard, oct–déc 2025), hygiène de migration réellement haute — mauvais ratio pour du solo malgré les 100 k$ affichés.

**Déclencheurs de réouverture (rien d'autre) :** (1) un `v0-N-market` ou `v0-N-data` déployé avec **plus** qu'un changement d'une ligne — c'est-à-dire un vrai changement de logique post-audit ; (2) une tx DAO `insert`/`update` sur `v0-egroup` (c'est le moment où les invariants « vérifiés off-chain par la DAO » sont réellement exercés) ; (3) StackingDAO déployant `data-stx-v3` (nouvelle fenêtre de redéploiement forcé chez Zest) ; (4) un nouveau vault ⇒ la surface de réhypothécation grandit.

**Seule veine jamais ouverte :** `v0-egroup` l.150-167, monotonicité des LTV par bucket (un update doit être tout-croissant ou tout-décroissant). C'est le seul edge-math d'egroup que le code prétend faire respecter lui-même — le reste est couvert par le carve-out OOS « invariants checked by the DAO off-chain », qui sert de bouclier.

Cible ouverte le 2026-08-07. Deployer `SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7`. Repo public `Zest-Protocol/zest-v2-contracts` (publie v0-4 seulement — la chaîne a v0-5 et v0-6 non publiés). Sources on-chain dans `~/Desktop/BlackBox/zest-onchain/`.

**La nouveauté = `call-ststx-ratio`, rien d'autre.** Le diff v0-4→v0-5→v0-6 (1662 lignes) est une seule ligne : source du ratio stSTX/STX. `block-info-nakamoto-ststx-ratio-v2.get-ststx-ratio-v3` → `data-stx-v1.get-stx-per-ststx` → `data-stx-v2.get-stx-per-ststx` (tous chez StackingDAO `SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG`). Zest court derrière les migrations de StackingDAO avec une adresse codée en dur dans un Clarity immuable ⇒ un redéploiement de market complet à chaque fois.

**Gates fermés PAR MESURE (ne pas relancer) :** décimales (1e6 des deux côtés) · couture multi-market (v0-4/v0-5 dé-autorisés partout, `get-impl`=v0-6) · coût/DoS (382 vs 300 read_count) · double-soustraction de `stx-for-withdrawals` (`get-total-stx` ne nette pas ; c'est `get-stx-available`, non utilisée) · donation à l'escrow (1 M stSTX brûlés pour +2,2 % ; profitable seulement si position > active supply entière) · manipulation par `init-withdraw` (le core vivant `core-stx-v2` verrouille bien contre `stx-reserve-v2` ; `core-v6` est shutdown).

**Faux positif, fermé :** `v0-1-data` revert bien (`get-user-position` → `ArithmeticUnderflow` sur les porteurs stSTX ; cause : ancienne `.stx-reserve` vidée à 0,00 STX = 1406,87−727,87−679) **mais il est superseded**. `v0-2-data` (→data-stx-v1) et `v0-3-data` (→data-stx-v2) sont déployés, même diff d'une ligne, en tandem avec les markets. `v0-3-data.get-user-position` répond OK sur les deux users qui font revert v0-1-data. Seul le REPO est périmé de 3 versions. Pas d'impact, hors scope.

**Cache d'index — fermé aussi :** `get-cached-indexes` est clé sur `stacks-block-time` donc inter-transactions dans un bloc. Seul `socialize-debt` fait baisser lindex, et les devs réécrivent le cache juste après avec le commentaire *"Refresh cache with new indexes post-write-down (lindex decreased)"* (l.891-894 v0-6). Ils savaient. Aucun autre chemin ne baisse lindex intra-bloc.

**Faiblesse structurelle nommée, non close :** aucune bande de validité sur le ratio — `oracle-price-legal` ne teste que `> u0`. `data-stx-v1` renvoie **0** en ce moment : la dégradation silencieuse à zéro n'est pas hypothétique. Un jour un ratio petit-mais-non-nul passera le test et liquidera tout le stSTX à une fraction. Manque un déclencheur non-OOS.

Voir [[deployed-code-not-head]] (le repo publie v0-4, la chaîne tourne v0-6), [[weak-substitute-binding-class]], [[measure-before-asserting-in-reports]], [[recevability-gate-before-poc]].
