---
name: stacks-dos-matrix-bxr-grid
description: "Stacks Immunefi grid changed 2026-09-08 — new DoS blast-radius×recovery matrix, High capped $15k, multi-role PoC required for B3 network-shutdown"
metadata: 
  node_type: memory
  type: project
  originSessionId: 842c0079-8868-49b2-b252-41a2746966cf
  modified: 2026-09-09T19:06:42.040Z
---

La grille du programme **Stacks** (Immunefi, $250k) a changé le **8 septembre 2026** (Last Updated). Fait de programme durable, utile pour toute future cible Stacks.

**Changements:**
- **Nouvelle matrice DoS B×R** (blast radius × recovery), qui n'existait pas avant août. Le tier d'un DoS se lit dessus:
  - **B1** (local / short-lived, un nœud échoue sans empêcher les autres de confirmer) = **Low quelle que soit la recovery**. Toute la ligne B1 est Low.
  - **B2** (échec de confirmation partiel) et **B3** (network shutdown) montent selon R (R1 automation par défaut … R4 changement de consensus / pas de recovery). Ex: B3×R3=Medium, B3×R4=High.
- **Grille refondue et plus basse:** Critical $15k-$250k, **High plafonné à $15k** (avant $25k), Medium $2,5k-$5k, Low $1k-$2,5k.
- **Exigence PoC multi-rôles pour B3:** « a network shutdown (B3) must be demonstrated across the independent production roles… the PoC must reproduce the halt with miner and signer roles running separately. »

**Why:** ça plafonne structurellement tout impact mono-nœud à B1=Low (cf [[stacks-nested-at-block-low-capped]]), et rend un B3 (le seul chemin vers High/Critical côté DoS) impossible à démontrer si l'impact est par nature mono-nœud.

**How to apply:** avant de dépenser (le programme est pay-to-submit, PoC+KYC requis), mapper l'impact réel sur la matrice AVANT de construire. Un DoS mono-nœud = Low, EV négative. Pour viser High/Critical côté liveness, il faut un B3 démontré avec mineur ET signer tournant séparément — sinon viser un theft/freeze on-chain. Complète le dossier `D-cve/stacks/SCOPE-DOSSIER.md`. Lié au verdict drift [[stacks-fresh-drift-epoch41-dormant]].
