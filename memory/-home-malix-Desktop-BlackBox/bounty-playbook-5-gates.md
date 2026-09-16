---
name: bounty-playbook-5-gates
description: "Le playbook maître (3 axes / 5 gates / Phase-0 go-no-go) — cadre d'opération pour toute chasse bounty."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e8f60518-cd46-4277-a906-81b71581d9b9
  modified: 2026-08-15T21:11:58.708Z
---

Playbook maître de l'opérateur, distillé du batch août 2026 → **full doc : `/home/malix/Desktop/BUGS/PLAYBOOK.md`** (le lire à l'intake de toute cible). Vivant : ajouter une ligne par rejet/payé.

**3 axes ORTHOGONAUX (réussir l'un ≠ garantir les autres) :** (1) VALIDITÉ (vrai/déployé/mécanisme prouvé) · (2) RECEVABILITÉ (in-scope/non-dup/non-known/bon tier) · (3) **MATÉRIALITÉ (assez gros à l'échelle réelle pour le tier)**.

**5 GATES à l'intake (pas au write-up)** — chaque rejet passé a concédé le mécanisme et est mort sur une gate :
- **G1 séparation acteur** : acteur≠victime, ≠autorité-config, peut CRÉER+TENIR l'état. Question tueuse : l'attaquant CRÉE la précondition ou juste RIDE un état exogène/privilégié ? Rider → « operational », mort. (Ammalgam, Perena.)
- **G2 guard échappé > guard manquant** : mène avec un guard qui EXISTE poussé hors de sa borne par du permissionless (claim code-level, non-reframable en admin-trust) ; jamais un guard ABSENT (claim design, meurt sur la responsabilité). (StackingDAO ERR_OVER_RESERVE increase-only.)
- **G3 prémisse avant PoC** : stress la prémisse d'abord ; « stale » = stale vs ce que le protocole PROMET, pas ce que je crois. PoC qui ATTEINT l'état vs le CONSTRUIT (warp/patch/config-directe = asserter pas prouver).
- **G4 tombstone prior-audit** : grep audits+docs pour le mécanisme AVANT profondeur ; acknowledged-not-fixed = impayable (« unfixed mentioned »). Fix-bypass valide seulement sur un fix **Resolved** dont on prouve l'incomplétude — jamais cadrer un finding orthogonal en incomplete-fix.
- **G5 MATÉRIALITÉ (NOUVELLE, StackingDAO)** : validité ⊥ matérialité — un finding peut passer G1-G4 et mourir sur la magnitude. Preuve élégante prouve le KIND (ça arrive) pas le DEGREE (c'est gros). Avant soumission : magnitude aux VRAIS params (pas les nombres illustratifs du PoC) · viabilité éco (coût attaque vs extraction) · red-team le siège de l'ingénieur (défense d'échelle = invalidateur #1) · garde kind-vs-degree · auto-limiteur (quantifier dans sa fenêtre). Donne le VRAI tier, pas un veto.

**Phase-0 go/no-go** (tuer les cibles ingagnables jour-1, pas scorer des morts après des semaines) : total-payé-sur-la-vie = fingerprint forteresse ; fee non-remboursable → fermer tout rejet avant de payer ; forme-PoC exigée (4-node vs _test.go) ; densité-de-règles past-threshold = skip ; **saturation ≥60 = RE-SOURCE vers seam payable, jamais immortal-mode prouver-null** (28 SC-core forteresse → 0 payé ; 100% des payouts = seam web/API/off-chain). Réponse structurelle à la saturation = **tier migration**, pas miner plus dur le tier public.

**Why:** trouver le bug est la moitié ; prouver qu'il est à eux/recevable/bon-tier/matériel est l'autre, et c'est celle qui paie. **How to apply:** lancer les 5 gates + Phase-0 à l'intake de chaque cible ; c'est le sur-ensemble qui unifie [[recevability-gate-before-poc]], [[deployed-code-not-head]], [[by-design-gate-not-just-git-dup]], [[measure-before-asserting-in-reports]], [[report-no-self-devaluation]], [[weak-substitute-binding-class]]. Confirmé sur Parallel (2026-08-15) : G5 tue P-01 (over-mint→payees pas attaquant) et la saturation-gate ratifie le RE-SOURCE. Cf. [[parallel-target-state]], [[wsb-sweep-blackbox-outcome]].
