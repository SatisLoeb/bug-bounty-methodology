---
name: invfuzz
description: >-
  Détecte la veine INVARIANT-DIFFÉRENTIEL. Activer AVANT audit profond d'une cible qui ré-implémente une math de référence (header-chain Bitcoin, primitive crypto, codec, parser de conformance, retarget de difficulté). Structure = HARNESS DIFFÉRENTIEL EXÉCUTÉ : le hand-reading ne tranche pas une divergence de math. Seul le différentiel exécuté contre la lib de référence, PUIS le trace de reachability amont, tranche.
---

# invfuzz — veine invariant-différentiel (harness exécuté)

Veine = INVARIANT-DIFFÉRENTIEL (une math ré-implémentée diverge de l'implémentation
de référence sur un input ATTEIGNABLE → split de preuve / faux-consensus).
Structure = harness différentiel. Le hand-reading donne une divergence au niveau
fonction ; il ne donne PAS le verdict. Seul l'exécuté + le gate de reachability le donne.
[Formalisé 2026-06-22 depuis l'usage exécuté réel citrea-fresh/invfuzz-headerchain/INVARIANTS.md.
Version canonique (skill nouveau, n'a jamais existé ailleurs) ; affiner à l'usage.]

## Phase 1 — ÉNONCER L'INVARIANT

Quel invariant DOIT tenir, pour tout input qui peut entrer ?
- déterminisme : même input → même output, aucun panic sur input atteignable.
- correction-consensus : l'output égale la référence pour tout input valide.
Une divergence sur un input atteignable = split. (header-chain : LC-proof split = Critical.)

## Phase 2 — HARNESS DIFFÉRENTIEL (copier verbatim, comparer à la référence)

- copie la fonction cible VERBATIM depuis le code déployé (pas une paraphrase).
- compare-la à la lib de RÉFÉRENCE (rust-bitcoin, la conformance impl, le standard).
- balaye les inputs-BORD, pas le happy-path : tailles 0..max, mantisses-bord
  (sign-bit, all-ones, max), valeurs historiques réelles, underflow/overflow.
- BUILD = release (= l'arithmétique wrapping du guest déployé ; debug-panic ≠ déployé).

490 cas + 8 nbits historiques + sonde underflow = l'instrument. Monter le harness
SANS balayer les bords = ne pas l'exercer.

## Phase 3 — CLASSER CHAQUE DIVERGENCE PAR EXÉCUTION (jamais par raisonnement)

Pour chaque divergence trouvée, deux axes, tranchés par l'exécution :
- reachable vs unreachable (décidé Phase 4).
- safe-direction vs exploitable : la cible est-elle PLUS conservatrice que la
  référence ? (Citrea rejette → 0 là où rust-bitcoin est lenient = la cible matche
  Bitcoin Core = direction sûre.) Plus-conservateur = pas une veine.

## Phase 4 — GATE DE REACHABILITY (le fait décisif)

Trace le gate AMONT qui décide si l'input divergent peut ENTRER une exécution vérifiée.
(header-chain : verify_header_chain_common Check-4 `bits() != expected_bits → reject`.
expected_bits = max_bits OU l'output du retarget, tous deux bien-formés → un attaquant
NE PEUT PAS soumettre une nbits sign-bit/size-56 : rejetée AVANT que la valeur diverge.)
Une divergence sur un input que le gate amont rejette = MORTE.
Ne jamais écrire un NULL-COÛTEUX (un échec-à-voler chèrement documenté, jamais un badge) sans avoir tracé CE gate par exécution/lecture du code — chaque divergence est une tentative d'ATTEINTE (vol de valeur | gel/freeze | faux-consensus/split de chaîne | censure/rejet-de-valide) qui doit mourir avec son artefact exécuté. **Une divergence qui REJETTE un input VALIDE (over-rejection) n'est pas inerte : les fonds valides sont bloqués ou la chaîne forke = liveness/gel/censure, payant même sans vol** (`~/.claude/skills/IMPACT-LEDGER-PLAYBOOK.md`).

## Phase 5 — DISCONFIRMER

Écris le test qui essaie de rendre ce PAS un bug. (underflow timestamp : release-WRAPS
→ clampé à expected×4 → borné + déterministe → pas de split.) Un harness qui ne
confirme que ton hypothèse est à moitié fait.

## Sortie
- divergences toutes gated/safe-direction → NULL-COÛTEUX (rare, cher, jamais « gagné » ;
  le null que le hand-reading ne pouvait PAS donner : les divergences sont réelles au
  niveau fonction ; seul l'exécuté + le gate amont les règle comme inatteignables). Légal
  SEULEMENT avec le registre : chaque divergence listée avec le gate exécuté qui l'a tuée,
  puis RE-SOURCE vers une couture payable — jamais un badge.
- une divergence sur un input ATTEIGNABLE, exploitable-direction → Critical (split).

## DETTE DE VALIDATION (honnête)
Validé sur Citrea header-chain (NULL-COÛTEUX : 7 divergences, toutes gated par
expected_bits). Le bras "divergence atteignable = Critical" n'a jamais été touché
en réel — l'instrument a tué par la Phase 4 (reachability), pas par une divergence vivante.
