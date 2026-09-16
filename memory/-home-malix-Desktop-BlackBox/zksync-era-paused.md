---
name: zksync-era-paused
description: ZKsync Era (Immunefi) engagé puis mis EN PAUSE le 2026-08-06 — cible non fermée, reprendre sur log_sorter.
metadata:
  type: project
---

Engagement ZKsync Era (Immunefi, max $300k) **en pause**, cible **non fermée**.
Dossier : `~/Desktop/BlackBox/zksync-dossier.md`.

**L'acquis principal, qui ne se redécouvre pas** : sur cette cible, les circuits de **précompile**
(sha256, keccak256, ecrecover, secp256r1) sont protégés par leur enveloppe Yul — un contrat système
normalise l'ABI, donc tout différentiel y est latent-mais-inatteignable. Les circuits **VM et files**
(log_sorter/L1Messages, storage_application, main_vm, ram_permutation, demux_log_queue) prennent leurs
entrées de la trace d'exécution arbitraire d'un utilisateur : aucune enveloppe, pas de gate
d'atteignabilité. Chercher là, pas dans les précompiles.

Reprise recommandée : `log_sorter` (941 LOC, 1 seul test, alimente ce que le pont L1 croit vrai).

**Ne pas refaire** : le candidat sha256 `num_rounds=0` (tué — `PrecompileCall` est kernel-mode only et
`SHA256.yul` garantit `numRounds ≥ 1`) ; et surtout ne pas retenter de builder `era-zkevm_test_harness`
sans plan — il ne compile sous AUCUNE toolchain essayée (détail des 4 échecs dans le dossier). Le harnais
n'est nécessaire qu'au PoC, pas pour instruire un candidat.

Voir [[recevability-gate-before-poc]] et [[thegraph-target-closed]].
