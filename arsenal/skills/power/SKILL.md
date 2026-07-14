---
name: power
description: >-
  Détecte la veine AUTHZ. Activer AVANT audit profond d'une cible avec surface authentifiée (smart contract à rôles, API, wallet). Structure = SONDAGE : un test exécuté décide. Trouve la frontière pouvoir↔autorisation nue en MESURANT la distance par exécution depuis un acteur non-privilégié, jamais en inférant l'authz de la présence d'un modificateur.
---

# power — sondage de la veine authz

Veine = AUTHZ (l'attaquant ACQUIERT un pouvoir sur la valeur d'autrui).
Structure = sondage. Un test décide. Pas une checklist.

## Phase 1 — Énumérer les POUVOIRS (pas les fonctions) + GATE DE POUVOIR

Grep les pouvoirs, pas les fonctions :
- verbes de mutation (transfer, mint, burn, withdraw, set, delete, upgrade, grant)
- modificateurs de rôle (onlyOwner, onlyRole, require(msg.sender ==))
- events de mutation
- grants on-chain (authz, approve, delegate)

GATE DE POUVOIR (dur, mécanique). Score chaque op :
- 5 = agit sur la valeur/l'identité d'autrui
- 4 = agit sur un état partagé / une protection
- ≤3 = agit sur soi, lecture, ou sans valeur

JETTE tout ≤3 AVANT de tester. Ne teste que ≥4.

Contrôle de brutalité du filtre : si plus de ~15 lignes entrent en Phase 2,
le filtre n'est pas assez brutal — resserre. 200 mutations → ~10 power≥4 → 10 tests.

[trou NoOnes : un grep correct-par-accident n'est pas correct-par-construction.
Le gate doit être mécanique, pas dépendre de quels verbes tu as pensé à grep.]

## Phase 2 — Mesurer la distance pouvoir↔authz PAR EXÉCUTION

Pour chaque op power≥4 : EXÉCUTE l'appel depuis un acteur non-privilégié
(clé fraîche, aucun rôle, aucun grant). Le RÉSULTAT de l'appel EST la mesure.

INTERDIT : inférer l'authz de la présence d'un modificateur. Un onlyOwner peut
être contourné ; un appel sans modificateur peut être gardé ailleurs. Seul
l'appel exécuté tranche.

VERROU NON-RÉSOLU : une op trop coûteuse à appeler reste NON-RÉSOLU.
Troisième état, PAS écarté. Ne jamais écrire "gardé/forteresse" sur une op
power≥4 sans un appel rejeté EXÉCUTÉ.

SONDE CONTRE-VALEUR-D'AUTRUI : teste contre de la valeur que l'appelant ne
possède PAS. Permissionless-sur-soi ≠ veine. Permissionless-sur-autrui = veine.

## Phase 3 — Différentiel voisin

Compare l'op à son op VOISINE (même famille, scope adjacent).
Asymétrie d'autorisation entre voisines = veine (le BFF Helix, le v2/v2-local
Polymarket, le main/subaccount Deribit).
Différentiel sur une op de LECTURE = view, pas capacité = Informative.

## Phase 4 — Gate impact-réalisé

Une frontière pouvoir-nue SANS population exposée = morte.
(piège Polymarket-dormant : capacité réelle, zéro utilisateur, impact nul.)
Vérifie qu'il existe une valeur/population réelle derrière la frontière.

## Sortie
- s'arrête Phase 1 : pas de power≥4 → NO-GO (phemex, NoOnes)
- s'arrête Phase 2 : authz nue mesurée → capacité (bff-api)
- passe les 4 → capacité avec impact réalisé → creuse en profondeur

## DETTE DE VALIDATION (honnête)
L'ordre sur ~10 ops n'a jamais été exercé en réel (Scribe n'avait que 4 ops).
Le gate de pouvoir et la sonde par-exécution sont validés ; l'enumération à
grande échelle ne l'est pas.
