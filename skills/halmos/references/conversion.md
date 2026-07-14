# Convertir un test Foundry en `check_` symbolique

Zéro langage neuf. Tu changes trois choses : le nom (`test_` → `check_`), les inputs (concrets →
symboliques), et tu hérites de `SymTest`. Le reste — helpers, mocks, `vm.prank`, `assert` — est identique.

## Le diff minimal

```solidity
// AVANT (fuzz Foundry)
contract VaultTest is Test {
    function test_deposit_increases(uint256 amount) public {
        amount = bound(amount, 1, 1e30);          // tirage borné
        vault.deposit(amount);
        assertEq(vault.balanceOf(user), amount);
    }
}

// APRÈS (preuve bornée Halmos)
import {SymTest} from "halmos-cheatcodes/SymTest.sol";
contract VaultSym is SymTest, Test {
    function check_deposit_increases(uint256 amount) public {   // check_ + arg symbolique auto
        vm.assume(amount > 0 && amount <= 1e30);                // assume > bound (plus efficace)
        vault.deposit(amount);
        assertEq(vault.balanceOf(user), amount);                // ta propriété, inchangée
    }
}
```

## Sources d'inputs symboliques

- **Args de `check_`** : symboliques automatiquement. `check_f(uint256 a, address b)` explore tout `a`,
  tout `b`.
- **Dans le corps** : `svm.createUint256("x")`, `svm.createAddress("a")`, `svm.createBool("flag")`,
  `svm.createBytes(N, "data")` (N = **longueur fixe** — voir pitfalls.md), `svm.createUint(bits,"y")`.
- **Storage symbolique** : `svm.enableSymbolicStorage(addr)` pour partir d'un état de storage arbitraire
  (utile pour prouver un invariant depuis n'importe quel état, pas juste après `setUp`).

## Contraindre l'espace : `vm.assume`, pas `bound`

Le moteur symbolique préfère une **contrainte** (`vm.assume(x >= a)`) à un **remapping** (`bound(x,a,b)`
fait de l'arithmétique modulaire qui alourdit les formules SMT). Utilise `vm.assume`. Mais attention :
un `vm.assume` trop serré tue les chemins intéressants → vacuité (pitfalls.md).

## Le geste concret (le plus rentable)

Prends TON prochain invariant qui tient « en 10M runs » de fuzz. Copie-le, renomme `test_`→`check_`,
mets `SymTest`, remplace `bound` par `vm.assume`, lance `prove.sh . --function check_… -vvvv`. Tu
obtiens soit « prouvé borné » soit un **contre-exemple concret** que le fuzz n'avait pas su tirer.

## Depuis un PoC NUKE / un candidat signals.md

Un candidat NUKE (signal → PoC) qui « ne casse pas » en fuzz : réexprime sa propriété de sûreté en
`check_`. Si Halmos sort un contre-exemple → ton candidat EST un finding (rejoue les valeurs en forge
concret pour la preuve d'exécution, puis `/report-nerve`). Si Halmos prouve borné → note la borne et
la propriété tient là-dessous (ce n'est pas ∀n, mais c'est bien plus fort que « pas trouvé »).
