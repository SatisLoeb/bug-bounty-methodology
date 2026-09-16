---
name: jito-firebam-target-state
description: "Jito/FireBAM Immunefi — firebam mesuré-clos 0 payable, le spec décrit jito-solana pas firebam, côté Rust inexploré."
metadata: 
  node_type: memory
  type: project
  originSessionId: b9d8aaf3-0cf4-4fb9-8c66-a824e509a28b
  modified: 2026-08-12T05:50:45.671Z
---

Jito bug bounty (Immunefi, max $250k, impacts **réseau uniquement** : chain-split/halt/≥30% resource/≥30% node-shutdown/≥500% block-delay ; PAS de catégorie vol-de-fonds SC). Deux assets : `jito-solana` (fork Agave) et `firebam` (fork firedancer pour **BAM** = Block Assembly Marketplace). Évalué 2026-08-12.

**firebam = FORTERESSE, 0 payable trouvé (5 veines tuées par mitigation citée).** Delta en scope = `src/disco/bam/*` + comportement BAM dans pack/execle/resolv/verify/dedup/poh. Le repo embarque son propre audit : `ANTHONY_SLACK_FINDINGS_AUDIT.md` = **47 findings d'Anthony "Asymmetric", #1-41 fixés** ; + OtterSec phase-1 ; + fuzzer différentiel vivant dont `contrib/bam-diff-known-failures.tsv` **nomme** les familles de divergence (M-32 queue-burst, SLOT-TIMING leader-edge, D-01/D-20 non-revert/dup-terminal, M-42 seq_id-split). Voir [[deployed-code-not-head]], [[recevability-gate-before-poc]].

**Tueurs de scope structurels** : (1) le **BAM node est TRUSTED** → tout ce qui exige un node malveillant = discrétionnaire, non-payable ; l'user ne contrôle que les *bytes de transaction*, tout le framing (seq_id/batch_idx/txn_cnt/max_schedule_slot/revert_on_error) est node-assigné. (2) base firedancer/agave = upstream, non payé ici. (3) les tiers node-shutdown sont **inatteignables** : le code BAM ne tourne que sur un leader FireBAM BAM-enabled → impossible d'atteindre ≥10-30% du réseau. Mitigations citées : cost-budget appliqué **2×** (pack admission copie le cost-tracker du bank `fd_replay_tile.c:992` + re-charge au commit `fd_runtime.c:1111`) ; contenu de bloc filtré sur EXECUTE_SUCCESS/is_committable dans le PoH-mixin ET le shred-payload → le leader ne peut qu'**omettre**, jamais émettre-invalide ; aucun gate fee-payer en C (stub upstream) ; execle address-filtré par worker → pas de primitive "drain".

**CORRECTION MÉTHODO CLÉ** (piège WSB [[weak-substitute-binding-class]]) : `bam_spec.md` est un spec **clean-room de jito-solana (Rust), pinné bc49b39**, PAS de firebam (C). "cost=0 admission", "8 workers unbounded receiver", "seul tx[0] fee-payer checké" sont des propriétés du **client de référence** ; firebam implémente l'inverse/l'absence. ⇒ ces veines, si réelles, vivent dans l'**autre asset en scope `jito-solana`, INEXPLORÉ** à cette date. C'est le prochain move à plus haute EV, pas de creuser firebam.

**R1/R2 RÉGLÉS 2026-08-12 = TUÉS sur atteignabilité, SANS build.** C'étaient les 2 résidus : R1 = scan **O(N²)** du suffixe pending non-gardé dans le hot-path de scheduling (`fd_pack_tile.c:2008` scanne tout le pending pour localiser chaque head programmé → drainer N pending = O(N²) ; sibling **gardé** par map-gate `fd_pack_contains_transaction` `:2700-2709`, commentaire dev `:2684-2688`) ; R2 = scan O(N×5) retire-by-sig par txn exécutée, amplifié par sigs dupliquées non-leading (`:886-911` ; BAM exempté du tcache-dedup `fd_txn_m.h:105-112`). **Kill** : `bam_work[]` (la borne du scan) n'est alimenté QUE par le chemin BAM (`pack_tile_append_bam_work` ; le TPU non-vote est droppé à l'ingress quand l'override BAM est actif) → **N est entièrement médiatisé par le node**. Le node honnête ne dispatch QUE du speculatively-committed, cost-limit-gated, slot-pacé (bam_spec §Speculative Execution/Dispatch) et retient le retryable/conflictuel → N reste une petite fenêtre in-flight. Atteindre le régime O(N²) dangereux (N∈milliers-65k) exige que le node sur-livre du valid non-schedulable dans un slot = **node BAM malveillant = hors-scope (tiers trusted, discrétionnaire)**. Bonus : tout PoC devrait forcer artificiellement `bam_pending_work_cnt` haut = condition unit-test non-réaliste, elle-même exclue par le programme. Donc le build greenlighté n'aurait rien produit de payable. **firebam = entièrement clos.**

Clone blobless : `/home/malix/Desktop/BlackBox/firebam` (148M, main@1ae1ff1e). Workflow `wf_c439ed5c-98e`.
