#!/usr/bin/env bash
# HALMOS scaffold — émet un squelette de test symbolique check_ câblé sur une cible.
# Usage: scaffold.sh <src/Contract.sol> [ContractName]
# Écrit test/<Name>_sym.t.sol (n'écrase pas) et l'imprime.
set -uo pipefail
SRC="${1:-}"; [ -z "$SRC" ] && { echo "usage: scaffold.sh <src/Contract.sol> [ContractName]"; exit 2; }
[ -f "$SRC" ] || { echo "introuvable: $SRC"; exit 2; }
NAME="${2:-$(grep -oE 'contract[[:space:]]+[A-Za-z0-9_]+' "$SRC" | head -1 | awk '{print $2}')}"
[ -z "$NAME" ] && { echo "impossible de déduire le nom du contrat — passe-le en 2e arg"; exit 2; }
REL="$SRC"
OUT="test/${NAME}_sym.t.sol"
mkdir -p test
[ -e "$OUT" ] && { echo "existe déjà: $OUT (rien écrasé)"; exit 0; }

cat > "$OUT" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Test} from "forge-std/Test.sol";
import {${NAME}} from "../${REL}";

// Squelette symbolique pour ${NAME}. Convention: check_ (pas test_).
// halmos --function check_ --contract ${NAME}Sym -vvvv
contract ${NAME}Sym is SymTest, Test {
    ${NAME} target;

    function setUp() public {
        target = new ${NAME}();
    }

    // Remplace tes valeurs concrètes par des symboliques (les args de check_ sont déjà symboliques ;
    // svm.create* sert dans le corps, ex. pour des bytes de longueur FIXE).
    function check_invariant(uint256 amount, address caller) public {
        // address caller = svm.createAddress("caller");
        // bytes memory data = svm.createBytes(96, "data"); // TAILLE FIXE obligatoire (piège n°1)

        vm.assume(amount > 0);          // préfère vm.assume(...) à bound(...) (plus efficace en symbolique)
        vm.assume(caller != address(0));

        // --- exécute la cible depuis l'acteur ---
        // vm.prank(caller);
        // target.doSomething(amount);

        // --- la PROPRIÉTÉ (ce qui doit toujours tenir) ---
        // assert( ... );

        // GARDE VACUITÉ : lance en -vvvv et vérifie qu'un chemin RÉUSSIT et atteint cet assert.
        // Un check_ qui "passe" sans chemin de succès = faux vert (voir references/pitfalls.md).
        revert("TODO: écris la propriété puis retire ce revert");
    }
}
SOL
echo "écrit: $OUT"
cat "$OUT"
