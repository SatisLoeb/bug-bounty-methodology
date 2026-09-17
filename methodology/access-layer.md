# Access Layer — la couche accès de Phase -1 (la contrainte liante, 2026-09-17)

**Ce que c'est.** La réponse à la contrainte mesurée : supply de comps fraîches sur les boards publics ≈ 0
([[venue-landscape]]). Le levier n'est plus la *sélection* parmi ce qui est listé — c'est l'**ACCÈS** à la
surface hors-board. Phase -1 (§0) route ici quand le board est vide.

> **STATUT — distinct de la sourcing-map : les CANAUX ont des cadavres, la sourcing-map n'en a pas.**
> Chaque canal ci-dessous a déjà produit un finding payé/escaladé → le canal est PROUVÉ-payant. Ce qui
> n'est pas prouvé, c'est chaque *poursuite spécifique* (tel client rouvrira-t-il ? telle invite paiera-t-elle ?)
> = les bets. Donc : **cadavre-de-canal ≠ garantie-live-maintenant.** Un canal peut être prouvé-payant ET
> sec aujourd'hui (comp-fraîche). L'unité de falsifiabilité = **cadavre-d'accès** : une move d'accès tentée
> qui n'a donné aucune surface payable (client recontacté sans scope ouvert, invite rejointe sans finding) —
> ça n'invalide pas le canal, ça retire ce nœud. La contrainte n'est PAS la validation (les canaux paient),
> c'est le TRAVAIL de les poursuivre. C'est pour ça que access > selection.

## Le gate commun (avant toute move d'accès) — la porte du bas du funnel
Toute cible d'accès doit passer, AVANT l'effort : **venue payant OUVERT × impact-landing in-scope pour la
primitive visée.** C'est l'hypothèse la plus partagée des 9 branches sourcing, déjà partiellement falsifiée
sur les boards publics. L'access-layer existe précisément pour pré-confirmer ce gate hors-board — ne pose un
GO que sur une cible où venue+impact sont acquis, sinon le cadavre-de-sourcing t'apprend « pas de venue »
(déjà connu) au lieu d'enseigner la primitive.

## Les canaux (classés par : prouvé × live-maintenant × coût)

**A1 — Deployed-layer access** · *cadavre: August/Mezo (39 findings, plusieurs Critical)* · **PROUVÉ + TOUJOURS LIVE**
- La surface on-chain déployée que le board ne liste pas : autorité Safe (mono-clé/threshold), impl-drift (deployed ≠ repo), condition d'audit violée, oracle/params live vs audité. **Le SEUL canal qui contourne entièrement le supply≈0** : pas de board, pas d'invite — juste lire on-chain (`tools/evm-anchor.sh`, read-only).
- gate : le programme paie le deployed-layer/config (beaucoup le font sous Primacy of Impact). next : deployed-pass sur les contrats live des clients déjà mappés. **Priorité #1 — disponible sans rien attendre.**

**A2 — Tier-migration / réciprocité** · *cadavre: Decentraland #87537 ($18k, client exemplaire, housekeeping gratuit post-payment)* · **PROUVÉ + WARM**
- Un client qui a PAYÉ rouvre du scope ; le housekeeping gratuit post-payment = l'actif relationnel. next : recontacter chaque client payé/confirmé du record avec une value-add (nouvelle surface, passe housekeeping). gate : scope ouvert/réouvrable. cadavre-d'accès : client recontacté sans rien d'ouvert (le canal tient, ce nœud sort).

**A3 — Relation-sourced engagement** · *cadavre: Upshift (48 findings, ack 24h, patch 30h)* · **PROUVÉ + À CULTIVER**
- Un engagement qui vient d'une relation, pas d'un board (privé/direct). next : convertir les équipes escaladées-in-flight (Granite #92663, OZ #92486) en relations APRÈS résolution — c'est la move-réciprocité de Decentraland appliquée aux wins en cours. gate : la relation ouvre une surface in-scope avec un arrangement payant.

**A4 — Comp fraîche haut-plafond** · *cadavre: ENS #92483 (Chief/payé, via ré-engagement à froid §3)* · **PROUVÉ mais SEC aujourd'hui**
- Le mode ENS : ré-engagement à froid sur une comp fraîche. **Actuellement le canal le plus faible** — [[venue-landscape]] : fresh comps ≈ 0. Ne l'attends pas. next : le census navigateur (venue-landscape) est le moniteur — **re-run-le, ne suppose jamais un board live** (le 1er pass avait halluciné ~20 comps). gate : une comp fraîche haut-plafond réellement live.

**A5 — Invite-only / pré-mainnet** · *AUCUN cadavre = HYPOTHÈSE (marqué comme tel)* · **NON-PROUVÉ + À AMORCER**
- S'inscrire aux programmes invite-only (Aerodrome noté invite-only) ; surveiller les déploiements pré-mainnet des clients seam-denses. next : (1) s'inscrire aux invites connues ; (2) **drift-watch REPOINTÉ** — au lieu de re-scanner l'étang public sur-pêché, surveiller les *nouveaux déploiements/annonces des clients seam-denses connus* (le signal pré-mainnet). C'est le seul canal sans cadavre → le premier finding via A5 est son cadavre-d'accès fondateur.

## Composition avec la sourcing-map + Phase -1
**L'accès fournit le VENUE (cible à venue+impact pré-confirmés) ; la sourcing-map fournit la PRIMITIVE à y chasser.** Séquence Phase -1 : **accès-first** (A1/A2/A3 — proven+live — donnent une cible avec le gate venue neutralisé), PUIS `seam-primitive-sourcing-map.md` (choisis la primitive qui matche la forme de cette cible). Un GO sur une cible d'accès = un cadavre-de-sourcing dont le gate venue est déjà passé → il enseigne la primitive/le dup, pas « pas de programme ». C'est le premier cadavre-de-sourcing à haute valeur.

## Priorité opérationnelle (proven + live d'abord, ne pas Maslow la méta)
1. **A1 deployed-pass** (toujours dispo, contourne supply≈0) · 2. **A2 recontacter les clients payés** (warm) · 3. **A3 convertir Granite/OZ en relations** (post-SLA) · 4. **A5 amorcer** (s'inscrire invites + repointer drift-watch) · 5. **A4** (attendre le census, ne pas s'y fier).
**Rappel revenu-d'abord** : l'accès sert à obtenir un venue payable, pas à valider un framework. Si un canal donne un finding payable, prends-le ; la validation tombe gratuite en chemin.

*Maintenir : un canal reste prouvé tant qu'il a ≥1 cadavre payé. Un cadavre-d'accès retire un NŒUD (client/invite), jamais le canal. A5 gradue de hypothèse → prouvé à son premier finding. Falsifiable comme les gates.*
