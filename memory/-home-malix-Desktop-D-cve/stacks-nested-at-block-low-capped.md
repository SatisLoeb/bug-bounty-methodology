---
name: stacks-nested-at-block-low-capped
description: "Stacks nested at-block finding (BlackBox 01) is now RE-SOURCE, capped Low by the new DoS matrix; differential test no longer worth running"
metadata: 
  node_type: memory
  type: project
  originSessionId: 842c0079-8868-49b2-b252-41a2746966cf
  modified: 2026-09-09T19:06:29.982Z
---

Le finding **nested at-block** (perte d'isolation du flag non-restauré à profondeur ≥2 ; `BlackBox/submissions/stacks/01-at-block-nested-isolation-break.md`, surface 2 = le cache) passe de « vivant, gaté sur le test différentiel `01356cb413` » à **RE-SOURCE, plafonné Low**.

**Why:** la grille Stacks du 8 septembre 2026 a ajouté une matrice DoS B×R (voir [[stacks-dos-matrix-bxr-grid]]) qui classe ce finding par construction. Son impact réel = un nœud qui replay depuis genesis calcule un state divergent → sync failure d'un nœud isolé = **B1 (local/short-lived)**. Recovery au mieux R3 (patch logiciel non-consensus). Toute la ligne B1 est **Low** quelle que soit la recovery. Le seul chemin plus haut est l'amplificateur B3 (archives régénérées par replay-from-genesis → divergence réseau-wide) — jamais prouvé, et la mort de `at-block` sur Epoch 4.0 rend impossible une divergence de consensus forward. Pas de Critical atteignable.

**How to apply:** ne PAS lancer le test différentiel `01356cb413` ni le crawl #1840 — même s'ils confirmaient la divergence, le tier reste Low. Sur un Low $1k-$2,5k avec fee pay-to-submit + surface (1) toujours dup de #1840, l'EV est négative. Le bug reste réel (belle lecture de code) mais sans tier payable sous la nouvelle grille. C'est le Gate 5 #6 (matérialité via changement de programme) qui mord : re-vérifier le scope AVANT de payer a répondu « ton impact est Low maintenant ». Sur Stacks désormais, viser directement un B3 multi-rôles démontrable ou un theft/freeze on-chain, jamais un DoS mono-nœud. Lié au verdict global [[stacks-fresh-drift-epoch41-dormant]].
