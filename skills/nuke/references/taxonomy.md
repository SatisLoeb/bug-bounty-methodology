# NUKE — taxonomie & espace négatif

Le champ `silent_classes` de `signals.json` est calculé contre cette taxonomie : si aucun rule-id /
titre d'aucun outil ne matche les aiguilles d'une classe, elle est déclarée **muette** → à chasser à
la main. Pour chaque classe : ce qu'un outil attrape (ou pas), et la question « qu'est-ce que l'auteur
n'a PAS imaginé ? » à poser en lisant le code.

| Classe | Un outil l'attrape ? | La phrase non écrite (à hunter si muette) |
|--------|----------------------|-------------------------------------------|
| reentrancy | oui (slither cross-fn, decurity readonly/erc677/721/777) | read-only reentrancy via un getter de prix ; reentrancy cross-contrat via un callback token non-standard |
| access-control | partiel (tx.origin, unprotected) | authn≠authz : le modifier existe mais un sibling non gardé atteint le même write ; rôle mal scopé |
| arithmetic/precision | faible (underflow basique) | precision loss par ordre des opérations ; rounding qui favorise l'attaquant ; cast qui tronque |
| oracle/price | seulement patterns connus (decurity) | spot price d'un pool manipulable dans le même bloc ; oracle en retard exploitable sous le coût de slippage |
| unchecked-return/call | oui | retour ignoré d'un token non-standard (USDT-like) qui `false` sans revert |
| delegatecall/proxy | oui (slither controlled, decurity) | storage collision proxy↔impl ; slot d'implémentation non initialisé ; upgrade qui décale le layout |
| external-call-order | partiel (CEI) | effet après interaction sur un chemin secondaire que le detector ne trace pas |
| erc20-integration | patterns decurity | fee-on-transfer non géré ; `approve` non remis à zéro ; double-entry point token |
| signature/replay | faible | replay cross-chain (chainid absent du domaine) ; nonce réutilisable ; malléabilité ecrecover |
| randomness | faible | `block.timestamp`/`prevrandao` comme source d'aléa exploitable par un validateur |
| dos/griefing | partiel (unbounded loop) | griefing par un élément qui revert dans une boucle de distribution ; gas-bomb |
| flashloan/economic | rarement | first-depositor share inflation ; donation attack sur le ratio ; asymétrie mint/burn |
| initialization | oui (aderyn) | initializer front-runnable ; ré-initialisation après upgrade |
| front-running/mev | non | absence de deadline/slippage ; extraction sandwich sur un swap interne |

## Règle de lecture

- Une classe **présente** dans la liste des hits = déjà éclairée par un outil → vérifie mais
  n'y passe pas ta valeur d'humain.
- Une classe **muette** ET plausible pour le type de protocole = **priorité de chasse manuelle**.
  Croise avec le type détecté par `/intake` : un lending muet sur `oracle/price` +
  `flashloan/economic` est un signal fort, pas un soulagement.

## Non-EVM — taxonomie CURÉE (pas par soustraction)

Pour Rust/CosmWasm, Solana et Go/Cosmos, la soustraction ne s'applique pas : **aucun scanner ne voit
les classes de vol**, donc presque tout serait « muet ». À la place, `references/negative-space.json`
porte une **worklist de VOL curée par écosystème** (21 CosmWasm · 23 Cosmos-Go · 22 Solana), chaque
classe avec `severity` + `money` (le chemin de vol) + `tell` (grep / où regarder) + `vein` (la veine à
proposer). `aggregate.py --ecosystem <eco>` la rend telle quelle dans la section 🕳️ de `signals.md`,
et `digest.py` route sur le champ `vein`. Les scanners non-EVM ne couvrent que le **substrat mécanique**
(deps CVE, panics/overflow, secrets, non-déterminisme grossier) — un barrage vert y est muet sur le vol,
jamais une absence de bug. Édite `negative-space.json` pour affiner/étendre les classes.

## Bank GPTScan (10 bugs de logique DeFi, aucun scanner ne les voit)

À garder en tête comme prompts sur les classes muettes (issus de la recherche MetaTrust/GPTScan) :
first-deposit share manipulation · price manip via reserve · reward/interest accounting drift ·
slippage manquant · vote/gouvernance à double comptage · unbounded-mint via rounding ·
liquidation seuil mal calculé · withdraw qui n'update pas la dette · fee siphon · asymétrie
deposit/withdraw. Ce sont des cibles de `/extract` et `/invfuzz`, pas des hits d'outil.
