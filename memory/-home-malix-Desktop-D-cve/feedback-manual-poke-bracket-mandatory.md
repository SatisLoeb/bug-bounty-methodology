---
name: feedback-manual-poke-bracket-mandatory
description: "The manual improvised cold-poke is a MANDATORY bracket around every intake/hunt — apparatus OFF first, poke by hand, never skipped, never answered-with-more-machinery"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e0ebe540-de2b-4fe6-8682-3b50e56433a0
  modified: 2026-09-08T12:04:45.716Z
---

Le poke manuel-improvisé est un **BRACKET MANDATAIRE** — TOUJOURS, avant ET/OU après le corpus, jamais sauté, jamais limité aux classes du corpus. Il **surpasse** les skills auto-orchestrés.

Discovery window = **soustractif, pas additif** : apparatus OFF d'abord. On suit le truc bizarre, un input de plus, **zéro gate / corpus / schema / workflow autorisé à tourner**. L'apparatus ne tire qu'APRÈS, pour packager + ne-rien-rater — c'est son seul vrai rôle.

Preuve live : le cold-poke a trouvé `admin-api.injective.network` (un backend privilégié entier, live, DB-connecté) en suivant UNE claim JWT (`aud:injective-admin-api`) que le workflow 11-agents avait mappée sans la lire — il avait rendu "fortress-null sur le signing seam" alors qu'un host admin était à une claim de distance. Idem l'ATO `granterAddress` trouvé en pokeant le flux auth 2 jours.

**Why:** le bug vit dans l'indirection en dehors de là où l'apparatus a atteint la compréhension propre ; un skill auto-orchestré mappe la surface sans la LIRE, donc rate la porte qui est à un thread de distance.

**How to apply:** sur toute cible (intake inclus), poke à la main AVANT de lancer corpus-query/skills/workflow. Suivre le truc bizarre, un input de plus, apparatus éteint. **Ne JAMAIS répondre à un miss par plus de machinerie — Délétion ou discipline, jamais un nouveau process.** Si je me surprends à créer un process pour réparer un miss, c'est déjà l'erreur. Voir [[feedback-corpus-not-trusted-100-poke-first]].
