---
name: halmos
description: >-
  HALMOS — durcir une propriété PRÉCISE en preuve BORNÉE, dans ton format Foundry. Le barreau du
  milieu de l'échelle de garantie (Foundry fuzz → Halmos → Certora) : prend tes tests Foundry, remplace
  les inputs concrets par des symboliques (test_ → check_), et explore TOUS les chemins jusqu'à une
  borne au lieu d'un échantillon. Zéro langage neuf (contrairement au CVL de Certora). Activer quand
  un invariant Foundry sort « pas de contre-exemple en N runs » et que tu veux passer de « pas trouvé »
  à « prouvé borné » ou à un contre-exemple concret ; ou pour durcir un candidat NUKE après le PoC.
  Déclencheurs : "/halmos", "halmos", "prove bounded", "preuve bornée", "symbolic test", "check_",
  "durcis cet invariant", "prouve cette propriété", "symbolic execution Foundry", "vérification bornée".
  Le runner scripts/prove.sh lance halmos en JSON et classe chaque check_ : PROUVÉ / CONTRE-EXEMPLE /
  VACUITÉ / INDÉCIS — et REFUSE d'appeler « prouvé » un vert vacuous (Halmos ignore les chemins qui
  revert ; le garde de vacuité = ta maxime « invariant-qui-passe ≠ finding »). Un CONTRE-EXEMPLE est un
  candidat finding (rejoue-le en forge concret → /report-nerve). Compose l'arsenal : vient APRÈS le
  fuzz (/invfuzz, /fizz) et le PoC de NUKE (verify.md) ; propose /halmos, ne l'auto-lance pas.
---

# HALMOS

Halmos vit dans ton harnais. Tu écris déjà des tests Foundry en Solidity ; Halmos prend ces **mêmes
tests** — même syntaxe, tes helpers, tes mocks — et remplace les inputs concrets par des symboliques.
Une fonction `check_…` à arguments symboliques, et il explore **tous les chemins** au lieu d'un
échantillon. La compétence que tu construis — *penser en propriétés* — se maintient sans quitter
l'environnement où tu es déjà fluide.

## Où ça se place (ne pas confondre les barreaux)

```
Foundry fuzz  → sonde LARGE      → "pas trouvé en N runs"
Halmos check_ → durcit un point  → "prouvé SOUS la borne" | contre-exemple concret   ← ICI
Certora CVL   → invariant système lourd, cross-contract   → seulement si Halmos ne suffit pas
```

Voir `references/ladder.md`. Halmos est le barreau « preuve bornée » de la promotion NUKE :
`nuke → signals → veine → PoC exécuté → **Halmos** → report`.

## Commandes

```bash
# durcir les check_ d'un projet Foundry
prove.sh [repo] [--function check_xxx] [--contract C] [--loop N] [--array-lengths SPEC]

# garde de vacuité PARTIELLE      : prove.sh . --canary check_xxx   (site d'assertion atteignable ?)
# état outil + cheatcodes        : prove.sh env
# preuve que le garde marche      : prove.sh selftest   (proven/counterexample/vacuité×2)
# squelette check_ sur une cible  : prove.sh scaffold src/Vault.sol
# installer (halmos + cheatcodes) : bash ~/.claude/skills/halmos/scripts/setup.sh
```

Lis toujours `<repo>/.halmos/<ts>/proof.md`. Le stdout donne le verdict coloré ; `proof.md` est
l'artefact (verdict + **borne notée** + valeurs de contre-exemple).

## Le geste (celui qui maintient la lame)

Prends ton prochain invariant Foundry qui tient « en 10M runs ». Copie-le, `test_`→`check_`, hérite de
`SymTest`, remplace `bound(x,a,b)` par `vm.assume(x>=a)`, lance `prove.sh . --function check_… -vvvvv`.
Tu sens immédiatement « pas trouvé » vs « n'existe pas, sous ces bornes ». Sur un cas que tu maîtrises,
pas un tutoriel. Conversion détaillée : `references/conversion.md`.

## Lire les verdicts (substance, pas théâtre)

- **PROUVÉ (borné)** — aucun contre-exemple **sous la borne** (`--loop`, `array-lengths`). Note la
  borne à côté ; ce n'est **pas** ∀n. Doute d'un PASS à 1 chemin → vacuité partielle (canary).
- **CONTRE-EXEMPLE** — valeurs concrètes imprimées. C'est un **candidat finding** : rejoue-les en
  `forge test` concret (preuve d'exécution), puis `/report-nerve`. Le fuzz ne l'avait pas tiré.
- **VACUITÉ** — tous les chemins revert : le vert ne prouve **RIEN**. Desserre les `vm.assume` /
  vérifie que la cible ne revert pas toujours, puis relance. `prove.sh` le refuse comme preuve.
- **INDÉCIS** — mur SMT (`x*y=k`, `sqrt`, intérêt composé). Pas « sûr » : `--solver-timeout-assertion`
  ou reste sur le fuzz pour cette propriété.

## Les deux pièges (references/pitfalls.md)

1. **Tableaux/bytes symboliques** : taille FIXE obligatoire (`svm.createBytes(96,…)` ou `--array-lengths`).
2. **Vacuité** (le vrai, jumeau du théâtre-vs-substance) : Halmos **ignore les chemins qui revert**,
   donc un `check_` passe s'il *revert OU réussit*. Halmos attrape tout seul le cas « tous revert »
   (→ VACUITÉ). Pour la vacuité **partielle**, `hprove . --canary check_xxx` automatise le garde :
   il remplace `assert(P)` par `assert(false)` au site et relance → SITE ATTEIGNABLE (PASS réel) vs
   SITE JAMAIS ATTEINT (faux vert). Suggéré auto sur tout PASS à ≤1 chemin.

## Règles

- **U-1** : propose `/halmos` (ou lance `prove.sh` quand l'opérateur le demande) ; n'auto-orchestre
  aucun autre skill. Un CONTRE-EXEMPLE se rejoue en PoC concret avant tout report ; `/report-nerve` et
  `/disclose` restent operator-gated.
- **La borne EST une hypothèse.** Écris-la à côté de chaque « prouvé » (`--loop N`, `array-lengths`).
  « Aucun contre-exemple jusqu'à la borne » ≠ « aucun ∀n ».
- **Solidity/EVM.** Vyper marche aussi (Snekmate). Rust/Move/Cairo : hors périmètre.
- Compose : APRÈS `/invfuzz` et `/fizz` (le fuzz trouve/rassure, Halmos durcit) ; sous la promotion de
  NUKE (`references/verify.md` de NUKE pointe ici).
