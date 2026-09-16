---
name: starknet-target-state
description: "Starknet (Immunefi $250k) — Phase 0 complète au 2026-08-10 : où vit vraiment l'OS, le régime de menace inversé, et les known issues qui brûlent la veine évidente"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8d3e2c02-85ff-464f-9644-cd0e0ae5b601
  modified: 2026-08-10T18:34:44.559Z
---

Cible ouverte le 2026-08-10. **Primacy of Rules sur tous les tiers** ⇒ l'URL littérale compte.
Pas de coffre (paiement direct équipe StarkNet en USDC). **KYC + screening OFAC obligatoires.**
PoC code obligatoire ; **tests interdits sur mainnet/testnet**, fork local seulement.

**Barème :** Blockchain/DLT Critical = 10 % du dommage (min $15k, max $250k) · **High = FORFAIT
$10 000** · Medium = forfait $2 500. Smart Contract (StarkGate) : Critical seul.
Le High forfaitaire est le meilleur rapport effort/certitude : pas d'abattement économique.

**Où vit le code (le fait le plus coûteux à re-dériver) :**
- L'actif « Starknet OS » n'est **plus** dans `cairo-lang` : retiré entre v0.14.0.1 (2025-07-27) et
  v0.14.1a0 (2025-11-12). Il vit maintenant dans **`starkware-libs/sequencer`**, branche
  **`main-v0.14.3`** (pas `main` !), chemin
  `crates/apollo_starknet_os_program/src/cairo/starkware/starknet/core/os`.
  **49 fichiers .cairo, 10 779 lignes, dont 2 fichiers de test (OOS).**
  Clone local : `~/Desktop/BlackBox/starknet-seq` (sparse-checkout : apollo_starknet_os_program +
  blockifier + starknet_api ; `--filter=blob:none`).
- StarkGate : branche en scope `cairo-1` (Cairo daté 2025-03-03) mais **`src/solidity` est identique
  à `SN-v0.14.2`** ⇒ l'actif Solidity n'est pas périmé, seul l'actif Cairo l'est.
- `cairo-lang` (clone `~/Desktop/BlackBox/starknet-cairo-lang`) garde bien les actifs L1 Solidity et
  `cairo/common/*.cairo`. Attention : repo **squashé par release** (87 commits) ⇒ `git log -S` n'a
  qu'une granularité de version.

**LE MODÈLE DE MENACE INVERSÉ — la chose à ne jamais réapprendre :**
Deux puces ferment l'opérateur : *« Sequencer bugs »* et *« Exploits as a result of a malicious
operator until Starknet is fully decentralized »*. Donc :
- Divergence où **l'OS est plus PERMISSIF** que le blockifier ⇒ atteignable seulement en fabriquant
  un bloc que le séquenceur honnête ne produirait pas ⇒ **opérateur ⇒ HORS SCOPE**.
- Divergence où **l'OS est plus STRICT** ⇒ le séquenceur accepte un bloc **impossible à prouver**
  ⇒ *« Network not being able to confirm new transactions »* ⇒ **High, en scope, $10k**.
Chercher donc les `assert` de l'OS qui peuvent tirer sur une entrée que le blockifier accepte.
(Même leçon que [[zksync-era-paused]] : un différentiel sous enveloppe est latent-inatteignable.)

**Mort en Phase 0 (ne pas y revenir) :** `deprecated_execute_syscalls.cairo:476` compare
`request.selector` (constant dans cette branche) au lieu de `request.function_selector` ⇒ la garde
interdisant `call_contract` → `__execute__` **ne tire jamais**. Réel, présent sur `main-v0.14.3`,
corrigé seulement sur `main` (`abb408d17`, 2026-07-07). **Tué** : le blockifier applique la garde
correctement et `block_direct_execute_call` = **True** pour 0.14.0→0.14.3 (False en 0.13.x) ⇒ seul
l'opérateur peut l'atteindre. Correctif public depuis un mois ⇒ risque de doublon en plus.

**Known issues = tombstones (2026, tous récents ⇒ cible activement travaillée par d'autres) :**
- PR 14407 (5 juil.) mishandling of alias contract in state_diff
- STARKNET-14 (15 juil.) un event L1 pas cher gèle tout le messaging L1→L2
- **STARKNET-18 (19 juil.) « Noncanonical Cairo 1 entry point builtin order can make accepted
  Starknet blocks unprovable »** = exactement le régime inversé ci-dessus, instance déjà prise.
  Correctif = `e066f90be` (22 juil.) **côté blockifier** (on remonte l'exécuteur au niveau du
  prouveur), et il **EST** sur `main-v0.14.3`. Le miroir Rust `CAIRO1_SUPPORTED_BUILTINS` est
  actuellement **cohérent** avec l'OS `SelectableBuiltins` (builtins.cairo:17) — vérifié.

**LE BOUNCER FERME TOUTE LA MOITIÉ « TAILLE » DE L'ESPACE DE RECHERCHE.**
`crates/blockifier/src/bouncer.rs` plafonne par bloc : `l1_gas` 2 500 000, `message_segment_length`
3 700, `n_events` 5 000, `n_txs` 600, **`state_diff_size` 4 000**, `sierra_gas`/`proving_gas` 5e9,
`receipt_l2_gas` 5.8e9. Donc tout assert de l'OS borné par une TAILLE est déjà gardé en amont.
Exemple mesuré : l'en-tête de `compression.cairo` code `data_len` sur 20 bits (< 2²⁰ = 1 048 576)
alors que le bouncer coupe à 4 000 ⇒ marge ×262 ⇒ **inatteignable**.
⇒ Filtre de chasse restant : asserts sur la **forme / l'ordre / la canonicité d'un objet unique**
fourni par l'utilisateur (c'était exactement STARKNET-18 : ordre non canonique des builtins).

**Fermé par mesure (ne pas y revenir) :**
- `compression.cairo` en-tête 20 bits ⇒ bouncer (ci-dessus).
- `encrypt.cairo` (223 l, feature « potc/privacy », sept.–déc. 2025) = **code mort sur mainnet** :
  `output.cairo` fait `if (n_keys == 0) return compressed`, et `os_config.cairo` dit lui-même
  « default hash is 0 … as is the case in Starknet environments ». Fait observable : les state
  diffs Starknet sont en clair dans les blobs L1. Zéro fonds affectés ⇒ impact nul.
  Même raisonnement à appliquer aux fichiers `*__virtual.cairo` (mode virtual OS) avant de les lire.
- `syscall_impls.cairo:619/666` `assert request.reserved = 0` (StorageRead/Write) : `reserved` =
  `address_domain`, et le blockifier le rejette **au parsing**
  (`vm_syscall_utils.rs:432-436` / `464-468`, `InvalidAddressDomain`).
- `bls_field.cairo` : tout felt Starknet (< 2²⁵¹) tient dans le corps scalaire BLS12-381 (r ≈ 2²⁵⁴·⁸⁶)
  ⇒ pas de dépassement atteignable par la donnée.

**MIROIRS OS↔blockifier vérifiés ÉQUIVALENTS (2026-08-10, ne pas re-parcourir) :**
- **Alias / stateful compression** (`state/aliases.cairo` ↔ `state/stateful_compression.rs`) : mêmes
  filtres (adresse ≥128, clé ≥128 ∧ contrat >15), même ordre (contrats croissants → clés → adresse),
  4 cas du compteur coïncidents. Les écritures triviales disparaissent des DEUX côtés
  (`strict_subtract_mappings` sur map plate ↔ `if prev==new skip`). L'ordre de tri est identique :
  `Felt: Ord` = `representative().cmp()` (sort de Montgomery → canonique, lambdaworks 0.13
  `stark_252_prime_field.rs:93`), = ordre de `dict_squash`. **Réfuté à 3 niveaux de deps.**
- **Champs tx v3 forcés à 0 par l'OS** (paymaster_data_length, nonce/fee_data_availability_mode,
  account_deployment_data) : les 4 sont gardés INCONDITIONNELLEMENT au gateway
  (`stateless_transaction_validator.rs`, commentaires « to prevent transactions from failing the OS »).
- **Proof facts** (`execution_constraints.cairo:check_proof_facts` 9 asserts ↔
  `account_transaction.rs:validate_proof_facts` + `fields.rs:ProofFactsVariant::try_from`) :
  9/9 couverts (variant VIRTUAL_SNOS, program_hash∈allowed, proof_version==V1 [0.14.3 allowed=V1 seul],
  output_version, block_number≤cur−buffer, block_hash≠0, block_hash stocké, config_hash). Tailles min
  identiques (7 felts). Reachable : `allow_client_side_proving = true` par défaut, MAIS contenu validé.
- **Resource bounds ordre/forme** : type RPC = `AllResourceBounds` (3 champs nommés) → variante `L1Gas`
  (pré-0.13.3) inatteignable. Forme garantie par typage.
- **Constantes de gaz** (`constants.cairo` « Autogenerated ») : `constants_test.rs:test_os_constants`
  régénère TOUT le fichier depuis `VersionedConstants::latest` et compare via `expect_file!` ⇒
  aucune dérive silencieuse possible. `assert "Predicted gas costs inconsistent"` (syscall_impls:436)
  donc structurellement synchronisé.

**⇒ LEAD VIVANT (le seul, en cours 2026-08-10) — échec d'un contrat Cairo 0 dans une tx revertible :**
`deprecated_execute_entry_point.cairo` ne renvoie `is_reverted=1` QUE si l'entry point est introuvable
(ligne 131). Sinon `call abs contract_entry_point` (ligne 171) : si le bytecode Cairo 0 échoue en VM,
**l'OS lui-même échoue** (Cairo 0 n'a pas de revert gracieux). Et `deprecated call_contract` →
`assert is_reverted = 0` (deprecated_execute_syscalls / deprecated_execute_entry_point:109) : un callee
qui revert fige aussi. CÔTÉ BLOCKIFIER : `run_revertible` branche `Err(execution_error)` →
`new_reverted()` « Revert, even if the error is sequencer-related » ⇒ la tx est INCLUSE en REVERTED,
frais prélevés, PAS rejetée (`account_transaction.rs:820`). Échec Cairo 0 = `Err` VM non rattrapable
(passe par `execute()?` ligne 447 de syscall_base, pas par le `call_failed`→Revert gracieux ligne 452).
Nouvelle classe Cairo 0 non déclarable (`RpcDeclareTransaction` = V3 seul ; `executable_transaction.rs`
confirme) ⇒ l'ensemble des classes Cairo 0 est FIGÉ à l'avant-migration. Pas de garde builtins à la
déclaration (la déclaration est fermée), seulement à l'exécution.

**Le mode d'échec asymétrique EST identifié — divergence des listes de builtins Cairo 0 :**
- Blockifier `CAIRO0_BUILTINS_NAMES` (deprecated_entry_point_execution.rs:32) = **6** :
  range_check, pedersen, ecdsa, bitwise, ec_op, poseidon. Hors-liste ⇒ `UnsupportedCairo0Builtin`
  ⇒ tombe dans le `_ =>` de `execution_utils.rs:97` (SEULS `EntryPointNotFound`/`NoEntryPointOfType`
  →ENTRYPOINT_NOT_FOUND et `InsufficientEntryPointGas`→OUT_OF_GAS sont convertis en revert gracieux)
  ⇒ `Err` remonte ⇒ tx REVERTED **incluse** (run_revertible:820).
- OS : `SelectableBuiltins`/`BuiltinEncodings` (builtins.cairo:17,42) = **10** (les 6 + segment_arena,
  range_check96, add_mod, mul_mod). `inner_select_builtins` (lib `starkware/cairo/builtin_selection/`,
  HORS scope core/os, récupérable dans clone `starknet-cairo-lang`) mappe par sous-séquence ordonnée
  puis `select_builtins` fait `assert n_selected_builtins = selected_encodings_end - selected_encodings`.
  ⇒ l'OS SAIT encoder ces 4 builtins que le blockifier refuse.
- Ordre canonique Cairo (all_builtins.py) : output,pedersen,range_check,ecdsa,bitwise,ec_op,**keccak**,
  poseidon,range_check96,add_mod,mul_mod. keccak est NON-selectable OS (non_selectable) ET hors des 6.

**LEAD RÉFUTÉ le 2026-08-10 — raison réutilisable : le flag `is_reverted` découple inclusion et preuve.**
Chaîne testée : Cairo 1 `__execute__` → syscall `call_contract` → contrat Cairo 0 utilisant un builtin
hors des 6 (keccak/add_mod/…). Blockifier : `UnsupportedCairo0Builtin` remonte comme `Err` NON-Revert
(via `call.execute()?` syscall_base:447, pas le `call_failed`→Revert:452), et `try_extract_revert`
(vm_syscall_utils:843) ne rend « revert » QUE `Self::Revert{}` ⇒ branche `_ => Original` = FATAL, non
rattrapable par l'appelant Cairo 1 ⇒ tx échoue ⇒ `run_revertible:820` `Err` ⇒ **REVERTED, incluse**.
MAIS côté OS (`transaction_impls.cairo:338`) : `%{ IsReverted %}` devine le flag, `check_is_reverted`
est **un corps VIDE** (`execution_constraints.cairo:20`, `return()`), et `if (is_reverted==FALSE)` ⇒
**l'OS SAUTE l'exécution des tx reverted** ⇒ il ne rejoue jamais le `call_contract` fautif ⇒ pas
d'assert `select_builtins` cassé ⇒ **pas d'irrouvabilité**. Le flag reverted découple l'inclusion de la
preuve : toute tx que le blockifier reverte, l'OS la saute.
**Généralisation (à réappliquer partout) :** un échec d'exécution NON rattrapable ne fige jamais la
chaîne, car le blockifier le reverte et l'OS saute les tx reverted sans les rejouer. Pour un finding
« bloc irrouvable » en scope, il faut un chemin qui échoue à l'OS **hors** de la partie
`if (is_reverted==FALSE)** — c.-à-d. dans validate (`run_validate`, non-reverting), dans charge_fee,
dans les syscalls d'un `__validate__`, dans le calcul du hash de tx, dans la construction de l'état/DA,
ou sur une tx que le blockifier marque ACCEPTED. Ne PAS repartir sur un échec de la phase execute.
(`check_is_reverted` non-vide seulement en mode virtual OS ⇒ `assert is_reverted=FALSE`, hors scope
mainnet.) Le flag `is_reverted` lui-même non contraint = soundness côté prouveur/opérateur = OOS.
Fork local requis pour tout PoC (test testnet/mainnet interdit).

**Phase VALIDATE vérifiée équivalente (2026-08-10) :** l'OS `run_validate`
(`execute_transaction_utils.cairo:149`) est non-reverting (`assert is_reverted=0`) et, pour un compte
Cairo 1 (`is_deprecated==0`), exige `retdata == [VALIDATED='VALID']`. Le blockifier `validate_tx`
(`account_transaction.rs:1046`) exige EXACTEMENT pareil : `PanicInValidate` si failed,
`InvalidValidateReturnData` si retdata != `VALIDATE_RETDATA`. Ces `Err` sont dans `validate_tx`
AVANT `run_or_revert` ⇒ tx REJETÉE du bloc, pas revert-incluse ⇒ l'OS ne la voit jamais. Couvert.
Note : ni l'OS ni le blockifier ne vérifient le retdata d'un `__validate__` **Cairo 0** (symétrique).

**FILTRE DE PROGRESSION (le plus tranchant de la cible) :** la phase EXECUTE est stérile (revert →
l'OS saute, cf. réfutation du flag). Ne chercher l'irrouvabilité QUE dans les phases non-reverting où
l'OS `assert` sur un résultat que le blockifier laisse passer : (1) hash de tx, (2) charge_fee,
(3) construction état/DA/commitment, (4) sortie du bloc. Les asserts de forme sur des champs de tx
sont tous miroités au gateway (validate_stateless) ⇒ improductifs.

**commitment.cairo + bls_field.cairo — VÉRIFIÉS ROBUSTES (2026-08-10), pur OS (blockifier ne compte
que les steps `compute_os_kzg_commitment_info.n_steps=113`, ne rejoue pas) :**
- `horner_eval` : invariant inductif limbes ∈ [0, 4·BASE)=[0,2⁸⁸) STABLE pour tout n (même 4096 coef) —
  `reduced_mul` ré-réduit à [0,3·BASE) puis +c0∈[0,BASE). Son assumption limbes <2¹⁰⁴ tient avec 16 bits
  de marge. Aucun débordement sur state diff légitime.
- Tout felt Starknet <P_stark<r (BLS_PRIME=r, scalaire BLS12-381 ≈2²⁵⁴·⁸⁶) ⇒ pas de réduction requise
  sur les coefficients. `felt_to_bigint3` : PRIME_HIGH=(P-1)/2¹⁷²=2⁷⁹+17·2²⁰ (division EXACTE car
  P-1=2¹⁷²·2²⁰·(2⁵⁹+17)), cas value==-1 traité à part, ne peut échouer pour un felt valide.
- Taille : `use_kzg_da` = flag du block header (block.rs:705, =true mainnet), pas piloté par tx.
  da_size = state diff COMPRESSÉ ⇒ borné par bouncer state_diff_size=4000 < BLOB_LENGTH=4096 ⇒
  n_blobs=1 toujours ⇒ jamais > limite blobs L1 (6). `assert_le(1,n_blobs)` + asserts data_size↔n_blobs
  satisfiables pour tout da_size≥0. Pas d'échec OS structurel.
- `bigint3_to_uint256` peut accepter un eval non-canonique (canonical+r, limbes encore [0,3·BASE)) MAIS
  (a) prouveur honnête produit toujours res canonique via hint divmod, (b) précompile EIP-4844 rejette
  y≥r ⇒ auto-sabotage OOS.

**PIVOT NOTÉ (asset L1 Solidity, en scope, Critical theft/freeze) :** le contrat StarkNet Core L1 reçoit
l'output OS (z, n_blobs, kzg_commitments, evals) et vérifie le KZG. **À vérifier sur l'asset L1** :
exige-t-il y<r (BLS_MODULUS) avant/dans le point-evaluation ? contourne-t-il le précompile ? La
soundness du DA repose sur cette vérif L1. C'est un angle séparé (Solidity, pas Cairo).

**LES 4 CANDIDATS NON-REVERTING — TOUS FERMÉS (2026-08-10, miroirs vérifiés côté Rust) :**
- **C1 tx_hash** (`transaction_hash.cairo` ↔ `starknet_api/transaction_hash.rs:get_invoke_transaction_v3_hash`) :
  miroir de contact critique (l'OS rejoue `__validate__` non-reverting qui vérifie la sig sur le hash
  que l'OS recalcule ⇒ hash divergent = irrouvable). Ordre des champs IDENTIQUE, y compris le champ NEUF
  `proof_facts` haché « si non-vide » des DEUX côtés. `pack_resource_bounds` OS
  `(resource·2⁶⁴+max_amount)·2¹²⁸+max_price` ≡ Rust `get_concat_resource` `[0|name56|amount64|price128]`
  (vérifié bit à bit : 'L1_GAS'=0x4c315f474153 aux bits 192-239). `data_availability_modes`=nonce·2³²+fee
  identique. fee_fields poseidon([tip,l1,l2,l1data]) identique.
- **C2 version/max_fee** (`execute_transaction_utils.cairo:41`) : l'OS accepte v∈{0,1,2,3} mais le RPC
  n'émet que V3 (Invoke/Declare/DeployAccount) ⇒ legacy inatteignable ; v0 = L1Handler only.
- **C3 charge_fee** (`transaction_impls.cairo:111`) : transfer STRK compte→séquenceur en non-reverting
  (`assert is_reverted=0`), montant `low_actual_fee` deviné mais `assert_nn_le(amount, max_fee)`.
  Invariant : le blockifier garantit la fee payable (`PostExecutionReport.recommended_fee`, sinon tx
  rejetée du bloc), et l'OS rejoue le même état (execute annulé côté blockifier = execute sauté côté OS).
  charge_fee tourne AUSSI pour les tx reverted (hors du `if is_reverted==FALSE`). Cohérent.
- **C4 class hash pre-image** (`contract_class.cairo:finalize_class_hash` ↔
  `starknet_api/state.rs:calculate_class_hash`) : miroir Declare, atteignable (Declare V3 actif).
  **Piste de divergence de normalisation creusée puis RÉFUTÉE** : l'OS fait `normalize_address(hash)`
  = `hash % (2²⁵¹−256)`, et le Rust fait EXACTEMENT pareil `class_hash.mod_floor(&L2_ADDRESS_UPPER_BOUND)`
  avec `L2_ADDRESS_UPPER_BOUND = CONTRACT_ADDRESS_DOMAIN_SIZE − MAX_STORAGE_ITEM_SIZE = 2²⁵¹−256`.
  Même ordre de composants (version, external, l1_handler, constructor, abi, sierra), même poseidon.
  Le class_hash n'est PAS fourni par l'user (`rpc_transaction.rs:371` le calcule). Pas de fenêtre de grind.

**L1 CORE CONTRACTS — EXPLORÉ, 0 finding (2026-08-10).** Sources :
`~/Desktop/BlackBox/starknet-cairo-lang/src/starkware/starknet/solidity/` (1158 l : Starknet 474,
StarknetMessaging 219, Output 189, StarknetState 82). Core mainnet
`0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4` = `StarkWare_Starknet_2026_11`,
`messageCancellationDelay = 432100 s = 5,00 j` exactement, stateBlockNumber ≈ 13 081 315.
- **Régime d'attaque** : `updateState`/`updateStateKzgDA` sont `onlyOperator` ⇒ tout défaut de
  SOUNDNESS y est OOS. Le seul sens en scope est le GEL : un utilisateur qui rend la mise à jour
  d'état impossible pour un opérateur honnête. (Même inversion que côté OS.)
- **PIVOT KZG RÉSOLU — négatif mais propre.** `verifyKzgProofs` ne vérifie PAS `y < BLS_MODULUS` en
  Solidity (juste `yLow/yHigh <= uint128.max` puis `y = yHigh<<128 | yLow`), **mais n'en a pas besoin** :
  le précompile EIP-4844 (0x0A) fait `verify_kzg_proof → bytes_to_bls_field(y)` qui
  `assert field_element < BLS_MODULUS` ⇒ y non canonique ⇒ staticcall échoue ⇒ `require(ok)` revert.
  De plus le code vérifie la SORTIE du précompile contre `keccak(FIELD_ELEMENTS_PER_BLOB‖BLS_PRIME)`,
  ce qui attrape aussi un précompile absent (staticcall vide « réussi ») et un futur changement.
  Commitment borné à `uint192` ×2 (48 octets), proof à `PROOF_BYTES_LENGTH`, blobhash version 0x01.
- **`nBlobs` non borné par l'OS** (commentaire de `commitment.cairo` : « the number of blobs per L1
  transaction is limited, and should be checked outside of this program ») ⇒ si nBlobs > max blobs/tx,
  `blobhash(i)=0` ⇒ `require(INVALID_BLOB_INDEX)` ⇒ opérateur bloqué. **Non déclenchable par un user** :
  borné en amont par le bouncer `state_diff_size` (4000 < BLOB_LENGTH 4096 ⇒ n_blobs=1).
- **`Output.processMessages` solide** : bornes contre `programOutputSlice.length` PUIS
  `require(offset == messageSegmentEnd)` final ⇒ un message ne peut pas déborder du segment ;
  hash d'enregistrement `keccak(slice[offset:endOffset])` ≡ hash de consommation
  `keccak(from, to, payload.length, payload)` — tout est en `uint256` donc aligné 32 octets,
  `abi.encodePacked` sans ambiguïté ⇒ pas d'usurpation de `fromAddress` depuis un contrat L2.
- `validateProgramOutput` : assembleur, valide TOUS les mots < FIELD_PRIME. `updateStateKzgDA` est
  encadré par `checkPrevBlockNumber`/`checkNewBlockNumber` (anti-réentrance explicite).
- **Vecteur de gel identifié puis écarté** : `processMessages` (L1→L2) exige `messages[hash] > 0` pour
  chaque message que l'OS déclare consommé ; annuler sur L1 un message déjà consommé sur L2 rendrait
  la mise à jour inapplicable. Exige que l'état accuse >5 j de retard ⇒ hypothèse de liveness
  opérateur, pas user. **Et c'est le known issue STARKNET-14** ⇒ OOS.

**BILAN AXE OS↔blockifier : ÉPUISÉ, 0 finding.** ~10 surfaces + 4 candidats non-reverting fermés par
mesure. Motif confirmé : StarkWare miroite tout rigoureusement, avec tests de conformité
(`test_os_constants` régénère les constantes ; class hash via crate compilateur partagée). Densité de
bugs Cairo très faible. **PROCHAIN AXE À FORT IMPACT = l'asset L1 Solidity** (StarknetCore /
GpsStatementVerifier, Critical $250k) — non exploré. Pivot noté : vérif KZG (exige-t-il y<r ?), et la
surface d'update d'état L1 qui consomme l'output OS. Repo à localiser (probablement dans le scope L1
listé « StarkNet L1 Core Contracts », branche à identifier).

Voir [[recevability-gate-before-poc]], [[weak-substitute-binding-class]], [[deployed-code-not-head]].
