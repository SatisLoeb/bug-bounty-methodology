# NUKE — protocole de promotion (signal → finding)

Un signal ne devient un finding qu'en franchissant une flèche EXÉCUTÉE. Ce fichier donne le
protocole et un template de PoC Foundry. Aucun hand-reading ne promeut.

## Les quatre portes (adaptées de la doctrine de l'opérateur)

1. **Chemin de code exécuté vérifié** — le detector a pointé une ligne ; toi tu prouves qu'un acteur
   non-privilégié l'ATTEINT. `cast call` / trace depuis l'attaquant, pas une lecture « ça a l'air
   atteignable ».
2. **Complétude de la chaîne d'exploit** — pas juste « le gate s'ouvre » : la valeur SORT. Ouvrir un
   gate ≠ finding (cf. mémoire TWAP/Ammalgam : ouvrir une liquidation à -116 600 pour <10k n'est pas
   un vol — la part LP a monté).
3. **Réplique du check du protocole** — value la sortie *à la manière du protocole* (bon prix, toutes
   les jambes) et réplique le guard accept/revert réel. Un `>2x` de magnitude brute est presque
   toujours ta bug de valorisation.
4. **Séparation d'intention** — un comportement voulu par le déployeur (admin/oracle/DAO) n'est pas
   un vol. Sépare et attribue la perte sur TOUS les chemins externes avant de créditer ton vecteur.

Un candidat qui passe les 4 avec artefact = finding. Sinon : mort-prouvé (le gate tient, tu l'as
exécuté) ou à re-sourcer. Écris le verdict dans `TRIAGE.md`.

## Template PoC Foundry (fork ou local)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Test.sol";

contract Nuke_PoC is Test {
    // Cible + acteurs
    address attacker = makeAddr("attacker");
    address victim   = makeAddr("victim");

    function setUp() public {
        // fork si mainnet-state nécessaire :
        // vm.createSelectFork(vm.envString("RPC_URL"), BLOCK);
        // sinon : deploy local du/des contrat(s) en scope
    }

    function test_theft() public {
        // 1. état AVANT (chiffré)
        uint256 beforeAtk = attacker.balance; // ou balanceOf(attacker)

        // 2. la chaîne, depuis l'acteur non-privilégié
        vm.startPrank(attacker);
        //   ... exécute le chemin que le signal a pointé ...
        vm.stopPrank();

        // 3. delta observé = la preuve
        uint256 afterAtk = attacker.balance;
        emit log_named_uint("attacker gain", afterAtk - beforeAtk);

        // 4. assertion de vol (pas juste "gate ouvert")
        assertGt(afterAtk, beforeAtk, "no value extracted");
    }
}
```

```bash
forge test --match-contract Nuke_PoC -vvvv     # -vvvv = trace complète pour la preuve
# fuzzing d'invariant si la veine l'exige (medusa installé sous vendor/bin/) :
#   ~/.claude/skills/nuke/vendor/bin/medusa fuzz --target . --deployment-order ...
# ou proposer /fizz pour générer le harness.
```

## Barreau supérieur : de « ne casse pas » à « prouvé borné » (Halmos)

Un candidat qui **ne casse pas** en fuzz n'est pas mort — le fuzz échantillonne. Escalade d'un cran :
réexprime sa propriété de sûreté en test symbolique `check_` et lance Halmos (**propose `/halmos`**).

```bash
# après le PoC/fuzz, durcir la propriété en preuve bornée (dans le même projet Foundry) :
hprove . --function check_<prop> -vvvvv     # ou bash ~/.claude/skills/halmos/scripts/prove.sh
```

- **CONTRE-EXEMPLE Halmos** = candidat finding que le fuzz n'a pas su tirer → rejoue les valeurs
  concrètes en `forge test`, c'est ta preuve d'exécution.
- **PROUVÉ (borné)** = aucun contre-exemple sous `--loop`/`array-lengths` → note la borne comme
  hypothèse ; la propriété tient là-dessous (pas ∀n).
- **VACUITÉ** = faux vert (Halmos ignore les chemins qui revert) — `/halmos` le refuse comme preuve ;
  c'est le jumeau de « invariant-qui-passe ≠ finding ». Desserre les `vm.assume`, relance.

Ordre de garantie : fuzz (`/invfuzz`, `/fizz`) sonde large → **`/halmos`** durcit le point précis →
Certora seulement si la propriété dépasse ce que Halmos exprime.

## Ce qui compte comme delta valide

- Un transfert net de valeur victime→attaquant (assertGt sur un solde/part réel).
- Une part/share qui bouge dans le mauvais sens pour la victime.
- Un état atteint qui viole un invariant nommé (V_in vs V_out).

Ce qui NE compte PAS : un revert évité, un gate franchi sans sortie de valeur, un output d'une
fonction interne pris pour de la sur-saisie sans réplication du guard.
