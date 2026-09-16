---
name: by-design-gate-not-just-git-dup
description: "Recevabilité : gate 'documenté/by-design' SÉPARÉE du dup-check git ; et lire en voleur (tracer le flux), pas par hypothèse"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 208cc87d-b406-4917-a559-2619911748c4
  modified: 2026-08-12T09:18:45.955Z
---

Deux disciplines de recevabilité renforcées sur l'engagement Decentraland (2026-08-12) :

**1. not-patched ≠ not-by-design.** Le dup-check git (`git log -S`) répond « quelqu'un a-t-il reporté/patché ça », PAS « est-ce intentionnel ». Un comportement peut être NON-patché parce qu'il est **documenté / by-design**. Vérifier la **doc officielle + l'intent** (commentaires de code, PRs historiques, subgraphs qui exposent déjà l'état) comme gate DISTINCTE avant de soumettre. L'Estate finding avait un PoC vert mais était by-design (doc « revoke manually » + PR #93 `decentraland/land` + subgraph `LAND-permissions-graph`) → passif, pas actif (situation Lombard).

**Why:** un artefact techniquement correct sur un comportement acknowledged ne paie pas et dévalue le chercheur.
**How to apply:** après le dup git, poser « la doc/les devs décrivent-ils ce comportement comme voulu ? ». Si oui → étagère, ne pas soumettre.

**2. Lire comme un voleur, pas comme un roman.** Une hypothèse d'impact fait lire le code pour la CONFIRMER → on glisse sur le vrai bug qui ne matche pas le template. Sans hypothèse : tracer le **flux de données réel à la couture**, observer ce que le code FAIT, laisser l'anomalie se révéler. Décortiquer TOUTE la surface (les deux chaînes, pas juste une), rien au hasard. « Prouver que c'est une forteresse » ≠ « trouver la vuln ».

**Why:** le mode confirmation-d'hypothèse rate les bugs hors-template ; corrigé plusieurs fois par l'opérateur en une session.
**How to apply:** au lieu de « y a-t-il un vol ? », tracer une valeur (MANA/NFT/approval/signature) à travers les coutures et regarder où une supposition d'un côté ne matche pas l'autre. [[measure-before-asserting-in-reports]]
