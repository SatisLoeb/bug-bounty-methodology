---
name: corpus-projection-systematic-phase
description: "Le corpus-pattern-projection est une PHASE systématique du hunting (après le poke manuel), pas optionnelle : même null il révèle ce qu'on a raté — la carte du négatif."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cf9b6d49-d729-4a75-afce-f7d261143344
  modified: 2026-08-22T13:00:29.266Z
---

Après le poke manuel (apparatus OFF, on suit le truc bizarre), tirer une **passe corpus systématique** : prendre chaque **classe de pattern qu'on maîtrise** (rapporté-vs-mesuré / substitution silencieuse, authz power-vs-authorization, swap-and-pop index-vs-id, state-gate edge-math, weak-substitute lié en silence, staleness lazy-write/unguarded-read) et la **re-projeter sur TOUTES les surfaces** de la cible, croisée avec le corpus (audits + QA + known-issues + OOS + impacts-in-scope).

**Why:** c'est le rôle « not-miss » de l'apparatus (il tire APRÈS le poke, pour packager + ne rien rater). Sa valeur n'est PAS que de trouver un bug — **même quand il est null, il révèle ce qu'on a raté** : les classes qu'on n'avait pas projetées partout, et surtout **POURQUOI chaque surface est fermée** (par design / par règle OOS écrite / par asset-selection-gouvernance). Cette carte du « pourquoi fermé » convertit « j'ai regardé, rien trouvé » en « voici la raison structurelle de fermeture de chaque classe, et le seul endroit où elle ne l'est pas ». C'est un livrable en soi : il oriente la re-source et empêche de re-labourer la même veine sur la prochaine cible du même type. Ex. Enzyme 2026-08-22 : la passe corpus a mappé rapporté-vs-mesuré sur toute la couche valuation (adapters=mesuré/guard-IM, EP=mesuré-ou-oracle-manager-OOS, price-feeds=pass-through/asset-selection) → 0 finding MAIS a prouvé structurellement pourquoi la forteresse tient, et isolé l'unique ouverture théorique (oracle-manip in-scope mais réduite à l'asset-selection).

**How to apply:**
1. Ne pas sauter cette phase parce que le poke n'a rien donné — c'est justement là qu'elle vaut le plus (elle borne l'exhaustivité).
2. Pour chaque classe-pattern, faire une **matrice surface × classe** ; la case vide (« pas projetée ici ») est la worklist ; pour chaque case fermée, **écrire le mécanisme de fermeture** (design/OOS/asset-selection) — pas juste « rien ».
3. Croiser chaque case contre le corpus : déjà audité (dup), OOS écrit (mort), ou trou réel.
4. Le produit final = la carte du négatif → alimente la mémoire d'état de la cible et la décision re-source.

Voir [[bounty-playbook-5-gates]], [[external-premise-closure-before-finding]], [[measure-before-asserting-in-reports]], [[nullguard]] (capitulation MESURÉE vs non-mesurée : cette phase fournit la mesure).
