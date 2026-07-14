// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Template canonique d'un test symbolique Halmos — ton harnais Foundry, inputs symboliques.
// Copie, renomme, câble ta cible. Lance: halmos --function check_ -vvvv
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Test} from "forge-std/Test.sol";
// import {Target} from "../src/Target.sol";

contract TemplateSym is SymTest, Test {
    // Target target;
    function setUp() public {
        // target = new Target();
    }

    // Les arguments d'un check_ sont AUTOMATIQUEMENT symboliques (tout uint256, pas un tirage).
    // svm.create* sert dans le corps, notamment pour les bytes/tableaux de TAILLE FIXE.
    function check_property(uint256 amount, address caller) public {
        // bytes memory data = svm.createBytes(96, "data"); // ← taille CONSTANTE obligatoire (piège n°1)

        vm.assume(amount > 0);              // préfère vm.assume(x >= a) à bound(x, a, b) en symbolique
        vm.assume(caller != address(0));

        // --- exécute la cible depuis l'acteur ---
        // vm.prank(caller);
        // uint256 before = target.value();
        // target.mutate(amount);

        // --- la PROPRIÉTÉ ---
        // assert(target.value() == before + amount);

        // GARDE VACUITÉ (piège n°2) : un check_ passe si un chemin REVERT *ou* réussit-correctement.
        // Donc lance en -vvvv et confirme qu'un chemin RÉUSSIT et atteint cet assert. Si aucun chemin
        // de succès ne l'atteint (assume trop serré, cible qui revert toujours), le vert ne prouve RIEN.
        // Canary: remplace temporairement assert(P) par assert(false) ; si Halmos passe encore = vacuous.
    }
}
