---
name: stacks-fresh-drift-epoch41-dormant
description: Stacks main-branch consensus drift lands behind unscheduled epoch 4.1 = dormant on mainnet; re-arm trigger + live surfaces that escape it
metadata: 
  node_type: memory
  type: project
  originSessionId: 842c0079-8868-49b2-b252-41a2746966cf
  modified: 2026-09-09T16:56:20.986Z
---

Sur la cible Immunefi **Stacks** (`stacks-network/stacks-core` @ `main`, programme $250k), le drift frais post-audit d'août (`7084db3f`→HEAD) a un pattern structurel qui rend la plupart des findings consensus DORMANTS.

**Fait:** le comportement consensus neuf est gaté par des prédicats `fixes_*/rejects_*` (ex: `fixes_replace_at_element_arity`, `rejects_versioned_smart_contracts`, stacks-common/src/types/mod.rs:~816-840) qui déclenchent à **epoch 4.1**. Or 4.1 est **non planifié sur mainnet** : `BITCOIN_MAINNET_STACKS_41_BURN_HEIGHT = STACKS_EPOCH_MAX` (stackslib/src/core/mod.rs:147). De plus `StacksEpochId::latest()` = `RELEASE_LATEST_EPOCH = Epoch40` en build release ; seul test/testing voit Epoch41 (stacks-common/src/types/mod.rs:506).

**Why:** tout différentiel consensus / chain-split / version-dispatch introduit par le drift frais est inatteignable tant que 4.1 n'a pas de hauteur mainnet. Historiquement les findings dormants se font dismiss (cf [[cosmos-evm-no-payable-venue]], et le kill août "pox-5 dormant TVL 0").

**How to apply:** avant de creuser un finding consensus sur le drift frais Stacks, GREP le prédicat d'epoch qui le garde et vérifie `BITCOIN_MAINNET_STACKS_41_BURN_HEIGHT`. S'il vaut `STACKS_EPOCH_MAX` → DORMANT, parquer. **RE-ARM TRIGGER:** quand cette constante devient une vraie hauteur (activation 4.1 mainnet), ré-ouvrir replace-at?/#7575 (chain-split 4.0→4.1) et Clarity7/force-latest/#7567.

**Surfaces fraîches qui ÉCHAPPENT à la dormance** (ni epoch-gated ni auth-gated, in-scope, post-août, classe Critical liveness): cluster signer/mineur #7509 (signerdb+477/signer+402), #7510 (miner+260), #7489 (livelock), #7532 (p2p relay). C'est là qu'un payable live peut vivre. Déjà réfutés/parqués: simulate endpoints (auth-gated = mur block_proposal), callreadonly mem-limiter #7440 (bounded MAX_VALUE_SIZE, known-class #7403), replace-at? #7575 (miner is_problematic drop, refuté live + dormant boundary), #7543 (refactor HTTP→DB fidèle). Détail: `D-cve/stacks/FRESH-SURFACE-TRIAGE.md`.
