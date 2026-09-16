# Les deux pièges (et le second est du pur « théâtre vs substance »)

## Piège n°1 — les bytes/tableaux de taille symbolique cassent

Halmos exige une **taille constante** pour les dynamiques. Un `svm.createBytes` sans longueur fixe
dans un appel low-level te sort une erreur de décodage.

- ✅ `bytes memory d = svm.createBytes(96, "data");`  (longueur fixe)
- ✅ flag CLI : `--array-lengths data={64,96},sig=65`  ou  `--default-array-lengths 0,65,1024`
- ❌ un `bytes` de longueur libre passé à un `call`/`abi.decode`

Prévois-le sur **tout** ce qui touche `bytes`/`string`/tableaux dynamiques. Le `prove.sh` note la
valeur d'`array-lengths` utilisée à côté du résultat (c'est une borne, donc une hypothèse).

## Piège n°2 — Halmos IGNORE les chemins qui revert → vacuité (le faux vert)

C'est le jumeau exact de la vacuité chez Certora : le badge dit « vérifié », la spec ne contraignait
que le vide.

**Le mécanisme.** Halmos ne considère pas les chemins qui revert. Donc un `check_` **passe** si
l'exécution *revert OU réussit-correctement*. Un chemin qui revert vacuously, ou un `vm.assume` trop
serré qui tue tous les chemins intéressants, te donne un vert qui ne prouve **rien**.

**Ce que Halmos 0.3.x attrape tout seul** : le cas GROSSIER où *tous* les chemins revert. Il sort
alors `[ERROR]` + `WARNING: all paths have been reverted`, pas un `[PASS]`. `prove.sh` le classe
**VACUITÉ** (rouge), jamais « prouvé ». (Vérifié en self-test : `check_vacuous_assume` et
`check_vacuous_revert` → VACUITÉ.)

**Ce qui reste à toi : la vacuité PARTIELLE.** Il subsiste 1 chemin trivial de succès qui atteint
l'assert sans exercer le comportement intéressant (les chemins intéressants ont reverté / été
assumés away). Halmos affiche alors `[PASS]` — mais la preuve est creuse. Deux gardes :

1. **Compte les chemins.** `prove.sh` flague tout `PASS` à `paths <= 1` comme *partiel-suspect*. Un
   `check_` qui devrait brancher mais n'explore qu'un chemin sent la vacuité.
2. **Le canary (décisif), AUTOMATISÉ.** `hprove . --canary check_xxx` fait le geste pour toi :
   il copie le test, remplace `assert(P)` par `assert(false)` **au site de l'assertion** dans `check_xxx`,
   relance Halmos (contrat renommé, nettoyé après), et tranche :
   - **SITE ATTEIGNABLE** (Halmos trouve un contre-exemple → l'`assert(false)` est atteint) → un chemin
     de succès traverse ton assertion → **ton PASS est RÉEL**.
   - **SITE JAMAIS ATTEINT** (Halmos passe encore / all-reverted) → aucun chemin n'atteint l'assertion
     → **faux vert** : desserre les `vm.assume` / la garde conditionnelle, puis re-prouve.

   `prove.sh` te le suggère déjà automatiquement sur tout PASS à ≤1 chemin. Vérifié en self-test :
   une propriété réelle → ATTEIGNABLE ; une assertion dans une branche jamais vraie → JAMAIS ATTEINT.

> Règle : un `check_` qui « passe » avec zéro chemin de succès n'est pas une preuve, c'est du théâtre.
> Comme un invariant-qui-passe n'est pas un finding : construis la substance, observe qu'un chemin
> vit et atteint la propriété.

## Piège n°3 (à connaître) — le mur SMT sur le non-linéaire

`x*y=k`, `sqrt`, intérêt composé → timeout ou indécis. `prove.sh` classe ça **INDÉCIS** (jaune), pas
« prouvé ». Options : `--solver-timeout-assertion <ms>` pour abandonner les chemins trop lents plutôt
que bloquer, borner plus serré, ou rester sur le fuzz pour cette propriété. « Indécis » n'est **pas**
« sûr » — note-le comme tel.
