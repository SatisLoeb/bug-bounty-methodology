---
name: weak-substitute-binding-class
description: "Classe de chasse nommée — un substitut plus faible est silencieusement lié à la place du composant fort prévu, et l'aval continue d'avoir l'air correct."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0e186640-6bf5-4757-9c53-148601ee9cbf
  modified: 2026-08-06T21:44:20.627Z
---

**Classe : SILENT WEAK-SUBSTITUTE BINDING.** Un substitut plus faible est silencieusement lié
à la place du composant fort prévu ; tout en aval compile, tourne, passe les tests, et produit
une sortie qui *a l'air* correcte.

Trois instances déjà rencontrées, dont deux sont des findings de l'opérateur :
- **Coldcard / libngu (public, 2026)** — `#ifdef MICROPY_HW_ENABLE_RNG` là où il fallait `#if`.
  Coinkite met la macro à 0 *exprès* (wrapper HW maison) ; le build tombe sur le PRNG logiciel
  Yasmarang de MicroPython. 40 bits effectifs sur Mk3, 72 sur Mk4/Mk5/Q au lieu de 128.
  Cinq ans, plusieurs audits. Nota : c'est Rodolfo Novak qui a suggéré que *l'attaquant* aurait
  pu utiliser de l'IA — la presse a inversé la direction. Le défaut est humain.
- **TruFin** — `cw-multi-test` modélise un `x/staking` sans `max_entries` : les 17 tests passent
  sur une contrainte qui n'existe pas dans le simulateur. Le *harness de test* est le substitut faible.
- **Decentraland (finding #2)** — `validateSignature`, déprécié et plus faible, prend le relais
  quand `verify` lève.

**Le sélecteur** = ce qui choisit entre fort et faible. Trois types, par attaquabilité croissante :
1. **Build** — macros, features Cargo, build tags Go, variants Gradle. Choix permanent et invisible.
   Impact max, le plus dur à trouver, exige du code compilé (donc pas Solidity — pas de préprocesseur).
2. **Config** — un flag avec une valeur par défaut. Dépend du déploiement.
3. **Erreur à l'exécution** — fallback / catch / deprecated / legacy / retro-compat. **Le seul où
   l'attaquant peut forcer la sélection**, en faisant échouer le chemin fort. Le moins cher à chercher.

**Signature exacte du bug ifdef-vs-if** (existence testée là où on voulait une valeur) :
`option_env!("X").is_some()` · `env::var("X").is_ok()` (Rust) · `os.Getenv("X") != ""` (Go, et son
miroir `== "true"` qui fait que `X=1` désactive silencieusement) · `process.env.X` en condition (JS —
`"false"` est truthy) · `System.getProperty(x) != null` (Java) · `ifdef` en Makefile.

**Comment appliquer.** Pour chaque composant critique, deux questions : *existe-t-il une version plus
faible qui pourrait prendre sa place ?* et *qu'est-ce qui choisit — et ce choix peut-il être faux ou
forcé ?* Le gate d'admission reste [[recevability-gate-before-poc]] : un cfg/tag/fallback *présent*
n'est pas un finding. Il faut (a) le substitut génuinement plus faible, (b) la preuve qu'il **lie
réellement dans le build expédié** — voir [[deployed-code-not-head]], même exigence de preuve par
l'artefact — et (c) une conséquence payable.

**Pourquoi ça survit aux audits :** l'entropie (ou la contrainte, ou la force d'une signature) est
une **propriété**, pas un motif. Aucune odeur de flux de contrôle, aucune garde manquante, aucune
ligne visiblement fausse. L'audit par correspondance de motifs ne voit pas les propriétés. C'est le
frère non gardé retourné : une garde qui **existe**, qui est **délibérée**, et qui ne tire pas.

## Le discriminant : fail-closed a QUATRE grades, pas deux

La présence d'une branche faible n'est pas le finding — **ce que la branche faible fait** l'est.
Grader avant de dépenser quoi que ce soit sur « est-ce que ça lie dans le build expédié » :

1. **Absence à la compilation** — le symbole n'existe pas sous le sélecteur faible, l'appelant ne
   compile pas. Clôture la plus forte. *Ex. exécuté : wasmvm v3.0.5 a `lib_libwasmvm.go` sous
   `cgo && !nolink_libwasmvm` et **aucun** `lib_no_libwasmvm.go` en face — le type `VM` est absent.*
2. **Panic à la construction** — `ibc-go/.../08-wasm/keeper/keeper_no_vm.go:26` et `:42`, avec le
   commentaire `:16` « This function is intended to panic ».
3. **Retour d'erreur** — fail-closed **seulement si tous les appelants vérifient**. C'est une question
   OUVERTE, pas une clôture : ne jamais écrire « fail-closed » sans nommer les appelants audités.
   *Ex. : `version_no_cgo.go` retourne une erreur ; clos uniquement après avoir constaté que son seul
   appelant ibc-go (`testing/simapp/simd/cmd/root.go:377`) capture `err`.*
4. **Nil / valeur zéro / défaut permissif lu comme un succès** — la forme Coldcard. **Le seul grade
   qui soit un finding.**

Piège d'outillage : un filtre binaire fail-closed/fail-open **supprime silencieusement les grade 3**
avant qu'on ait regardé les appelants. Ne pré-tuer que les grades 1 et 2.

## L'axe prior-art a deux sous-mécanismes de sensibilité opposée

Cet axe n'existe pas pour trier des candidats — il existe pour **t'empêcher de construire** trois
jours sur un doublon. Un faux négatif y coûte les trois jours.

- **0a — phrasé défensif au HEAD** (README, docs, CHANGELOG, commentaire au-dessus du code) :
  « known limitation », « known and accepted », « intended to », « by design », « no stable release ».
  **Indépendant de la profondeur du clone.** C'est ce sous-mécanisme qui a attrapé TruFin (le README,
  commit `9cc8862` n'ayant servi qu'à *dater*). Il tourne partout.
- **0b — `git log -S` / `--grep`** : ne sert qu'à **dater** un hit déjà obtenu, et il est cassé sur
  clone shallow. Voir [[deployed-code-not-head]] : sur ibc-go shallow il n'a pas rendu du vide mais
  du **faux** (`9cc0868 "Reverting context changes"` au lieu du vrai `031c2b831`, PR #5923).
