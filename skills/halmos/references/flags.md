# Flags Halmos utiles (vérifiés sur 0.3.x)

| Flag | Rôle | Note |
|------|------|------|
| `--function RE` | ne lancer que les `check_` matchant la regex | cible une propriété |
| `--contract C` | ne lancer que ce contrat de test | |
| `--loop N` | **borne de déroulage de boucle** (défaut 2) | **c'est LÀ que vit ton hypothèse « bounded »** — note-la |
| `--invariant-depth N` | profondeur pour les tests d'invariant stateful | |
| `--array-lengths NAME={a,b},X=n` | longueurs des dynamiques symboliques | piège n°1 |
| `--default-array-lengths a,b,c` | longueurs par défaut (défaut `0,65,1024`) | |
| `--solver-timeout-assertion MS` | abandonne un chemin d'assertion trop lent | contre le mur non-linéaire |
| `--solver-timeout-branching MS` | timeout sur le branchement | |
| `--early-exit` | stoppe au premier contre-exemple | rapide en mode « y a-t-il un bug ? » |
| `--json-output F` | résultats machine (exitcode/num_models/models/num_paths) | ce que `prove.sh` parse |
| `--statistics` / `-st` | stats de perf | |
| `-v`..`-vvvvv` | verbosité (chemins, modèles, steps) | **-vvvv pour le canary de vacuité** |
| `--storage-layout {solidity,generic}` | modèle de storage | `generic` si storage symbolique exotique |
| `--panic-error-codes C1,C2` | quels Panic comptent comme échec | par défaut `0x01` (assert) |

## Codes de sortie (par test, dans le JSON)

| exitcode | num_models | sens (comme classé par `prove.sh`) |
|----------|-----------|-------------------------------------|
| `0` | 0 | **PROUVÉ** (borné) |
| `1` | ≥1 | **CONTRE-EXEMPLE** (les valeurs sont dans `models` / le log) |
| `4` | 0 | **VACUITÉ** — all paths reverted (ne prouve rien) |
| autre ≠0 | 0 | **INDÉCIS** — mur SMT / timeout |

## Réflexes

- `vm.assume(x >= a)` **>** `bound(x, a, b)` (contrainte native, pas d'arithmétique modulaire).
- Toujours noter `--loop`/`--array-lengths` **à côté** du verdict « prouvé » : c'est l'hypothèse.
- `--early-exit` pour un premier passage « existe-t-il un contre-exemple ? », puis retire-le pour la
  preuve complète bornée.
- Docker si tu veux éviter la gymnastique de solveurs : `ghcr.io/a16z/halmos:latest` (lit ton
  `foundry.toml` tel quel).
