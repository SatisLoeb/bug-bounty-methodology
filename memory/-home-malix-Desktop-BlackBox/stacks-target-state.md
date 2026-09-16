---
name: stacks-target-state
description: "Stacks / stacks-core (Immunefi, $250k, Blockchain/DLT) — distinct de sBTC. Re-ouvert 2026-08-11 : mesuré-clos, 4 threads + 3 résidus signer-set morts par lecture ; seuls submittables = Low drafts 02/03."
metadata: 
  node_type: memory
  type: project
  originSessionId: c3f26598-57e6-44d7-a480-6af4533000f1
  modified: 2026-08-11T20:10:36.744Z
---

Programme **Stacks** (stacks-network/stacks-core) sur Immunefi, max **$250k**, catégorie Blockchain/DLT.
**Distinct du programme sBTC** (contrats Clarity, autre programme) — voir [[sbtc-target-state]].
Clone : `/home/malix/Desktop/BlackBox/stacks`, node v4.0.1, Epoch 4.0 live. Scope = `stacks-common/`,
`stacks-node/src/`, `stackslib/` (inclut `boot/*.clar` dont pox-5.clar), `stacks-signer/`, `clarity/`.
Modèle d'attaquant DUR : RPC + P2P seulement, PAS de coopération miner Bitcoin, PAS de clés/adresses
privilégiées/gouvernance. PoC requis. Récap complet : `stacks/AUDIT-SESSION-RECAP.md` ; notes de
soumission : `submissions/stacks/` (BRIEF.md + 00-negative-space.md + drafts 01/02/03).

## ⚠️ Pièges d'environnement mesurés
- Le clone `stacks/` **n'est plus un repo git** — aplati dans le parent BlackBox au push (voir
  [[blackbox-repo-pushed]]). `git log` = 1 commit squashé. **Archéologie git impossible** :
  `d03b11494d` et tout hash cité dans le récap sont `Not a valid object name`. Ne pas prétendre
  vérifier un commit historique ici — re-cloner upstream pour ça.
- Disque chronique 4.4G libre / 99% ([[disk-is-chronically-full]]). Les builds `cargo` MEURENT
  (`No space left`) — c'est le blocage réel de la session initiale, pas l'analyse. **Toute la
  ré-ouverture 2026-08-11 fut grep-only, zéro build.** `stacks/target` = 6.6G récupérables.

## Re-ouverture 2026-08-11 — 4 threads + 3 résidus, TOUS morts par lecture exécutée
- **Thread A · divergence signer-set cycle-stability** (chain split, Critical) → MORT. Le sélecteur
  `active_pox_contract_for_cycle` (`signer_set.rs:976`→`burnchains/mod.rs:440`) est déjà cycle-keyed,
  pas tip-keyed. Mainnet `(960230-666050)%2100=180` = pleine reward phase du cycle 140, aucune
  prepare phase ne chevauche 960230. Boot-assert `core/mod.rs:1417`. **Et test de régression upstream
  dédié `burnchains/tests/cycle_dispatch.rs`.** Triple-désarmé + déjà corrigé.
- **Thread B · pause-admin/rewards-paused** (halt, Critical) → MORT. `rewards-paused` a UN seul
  lecteur (`pox-5.clar:2404`, dans `claim-rewards`, zéro appelant Rust non-test) = interrupteur de
  payout, pas levier de halt. Dups #7328/#7416/#7360.
- **Thread C · Vein 3 burnchain-op drop** → MORT, **en-dessous de Medium** (le récap le sur-notait
  Medium). Burn ops n'entrent QUE depuis Bitcoin (codec P2P test-only, aucun `net/api`) → non
  atteignable RPC/P2P ; `output[0]` = adresse dust du sender lui-même, erreur avalée
  (`blocks.rs:4176`) zéro état → seul coût = fee BTC du sender. Auto-infligé, déterministe.
- **Thread D · Vein 5 liveness off-consensus (aggregate pubkey)** → MORT. Écrivain unique derrière 2
  gates authz → multisig fédération sBTC (privilégié, OOS) ; contrats sBTC dans `.audit-tools/` =
  déploiement externe **hors scope**. **Corrige le récap** : la pubkey stockée est un point on-curve
  réel, `from_slice` réussit quelle que soit la parité — l'histoire « 1/2 des inputs off-curve » était
  fausse.
- **Résidus signer-set (Vein 6 étendue) — les 3 tranchés** : (a) empty-set (récap) ; (b) zero-key
  `unwrap_or([0;33])` `signer_set.rs:421` = code mort — l'assert `is-eq (secp256k1-recover? …)
  signer-key` à `pox-5.clar:2766-2778` force 33 octets exacts sur l'unique writer `:964` ; (c)
  linked-list Abort inatteignable — `get-signer-set-next-item-for-cycle` `pox-5.clar:3410-3421` est
  une fonction TOTALE (`optional principal`, jamais Err), les 3 Abort arms de `fallible_next` ne
  peuvent structurellement pas tirer. 2 writers privés symétriques seulement, invariant
  `(dans liste) ⟺ (delegated ≥ MIN)` maintenu.

## Finding 01 (at-block + cache) — re-vérifié INFORMATIONAL 2026-08-11 (dup/scope/sévérité/reachability)
Réconcilié contre la page Immunefi live + le dup #1840. Résultat : **ne pas soumettre, ne pas dépenser
les 75 USDC.**
- **Scope OK** (contredit le réflexe OOS-ref) : les assets Blockchain/DLT épinglent `main` non-releasé ;
  `clarity/` est dedans. Row Critical « different nodes … yielding different results » existe.
- **Surface (1) [rollback wrapper pending reads] = issue #1840**, CLOSE, fixée par **PR #2027 "Fix:
  Clarity (at-block) behavior"** (merged 2020-11-10, kantai, `c321cbfe2512`). OOS (issue+PR trackés).
  La forme nested re-bypasse le fix #2027 mais impact identique à #1840 → « novel path » faible.
- **Surface (2) [cache de contrats, `clarity_db.rs:953` `get_contract`] = NON-#1840** (cache 2026,
  `01356cb413` ; #1840 = 2020, rollback wrapper only — vérifié : #1840/PR#2027 ne mentionnent ni cache
  ni get_contract ni nesting). Le différentiel across `01356cb413` DIVERGE (pre-cache Err → post Ok,
  #5/#6). MAIS sans gâchette.
- **Reachability = INFORMATIONAL** (2 passes indép. + reopen-challenge, contre current main) :
  surface (2) exige `is_retargeted()` faux-négatif → SEUL chemin = at-block nesting depth≥2
  (`contexts.rs:1527` unique `set_block_hash(_,false)`, `:1532` reset `true` en dur) ; le cache est
  **par-tx** (`ClarityTransactionConnection`, `clarity.rs:279`, drop au commit, test
  `contract_cache_is_scoped_to_transaction:3690`) → aucun escape cross-tx/reorg/replay ; at-block mort
  au runtime Epoch 4.0 (`database.rs:562` → AtBlockUnavailable) ; aucun nouveau contrat at-block
  déployable (rejet à l'analyse `v2_1/natives/mod.rs:139`). **`grep '(at-block ' *.clar` = 0 hit**
  in-tree. Le seul déclencheur = rejouer un bloc pré-3.4 dont une tx invoque un contrat pré-3.4 à
  at-block nested (depth≥2) — ensemble **gelé** et **mesuré vide** par le sweep 149 536 déploiements.
- **Sévérité plafond même SI atteignable** : les archives Hiro sont des **snapshots byte-copy** (pas
  du replay-regen) → un état divergent NE se propage PAS network-wide ; seul un nœud sync-from-genesis
  rejoue l'histoire → au pire **Low/Medium (DoS/transient d'un nœud)**, jamais la row Critical
  chain-split. L'« amplificateur archive » de l'analyse Phase-0 est FAUX.

## Corrections au README de soumission (mesurées, downgrades)
- **Finding 01 (at-block) = Informational, PAS un Medium payable** : atteignabilité vide ET close
  depuis Epoch 3.4 (sweep 149 536 déploiements → 0 gâchette). Ne pas soumettre comme Medium.
- **Vein 3 = en-dessous de Medium** (auto-infligé, fee-scale, non atteignable RPC/P2P).
- **Seuls submittables réels = drafts Low `02`** (shadow-bit bypass sur buffering P2P) **et `03`**
  (mispricing coût `get-bitcoin-tx-output?`). Immunefi paie Low (remote DoS d'un nœud). Non renforcés
  ce pass — besoin d'un harnais 2-nœuds pour 02, micro-bench pour 03.

## Verdict d'allocation : CLOSE pour ce pass (définitif)
La primitive de halt signer-set pox-5 est mesurée-imprenable par un acteur RPC/P2P. Le **dernier fil**
— angle **coût/DoS d'itération** (gonfler la liste de nodes phantom Skip pour épuiser l'eval de
`inner_setup_block`) — est **MORT** (probe 2026-08-11, 0 survivant). L'eval EST non-métré
(`as_free_transaction`→`LimitedCostTracker::new_free()`, `clarity.rs:2290`), MAIS **le primitif
phantom n'existe pas** : les 4 chemins de seating (`pox-5.clar:761/892/1013/1130`) sont tous gardés par
`(unwrap! (get-signer-info signer) ERR_SIGNER_NOT_FOUND)` AVANT l'insert → tout node de la liste a une
entrée `signers` → jamais le Skip branch (`signer_set.rs:410`) ; et `signers` n'a aucun `map-delete`
(revoke la laisse intacte `:2820`). Backstops : `SIGNER_SET_MIN_USTX = 50k STX`/node distinct (`:82`,
site unique `:1717`) et cap dur `SIGNERS_MAX_LIST_SIZE=4000` (`signer_set.rs:631`). Pour dépasser le
budget de validation 120s (`stacks-signer/src/config.rs:41`) à 3 `map-get?` O(1)/node il faudrait des
milliards de STX (> supply ~1.8B). Chacun des trois tue seul.

**Seul résidu théorique restant** (hors modèle d'attaquant, noté pour mémoire) : >4000 signers légitimes
distincts font tomber `signer_set.rs:631` en `Err` **déterministe network-wide** (halt symétrique, PAS
un split) — mur capital ~200M STX (>10% supply), non contrôlable par attaquant. À ne ressortir que sur
une thèse liveness « coalition capital-lourde ».

**Trigger UNIQUE de réouverture** (post-4.0.1, surveillance par diff grep-cheap) : tout commit sur
`pox-5.clar` (ou `pox-6.clar`) qui (a) ajoute un writer des maps `signers` / `signer-set-ll-for-cycle`
/ `signer-delegated-per-cycle` (surtout un `map-delete signers`, un writer public de next-pointer, ou
un decrement qui ne re-stitch pas), OU (b) relâche l'assert `secp256k1-recover? == signer-key`
(`pox-5.clar:2766-2778`). Sinon ne pas rouvrir. Voir [[measure-before-asserting-in-reports]] et
[[report-no-self-devaluation]] pour le cadrage de 02/03.
