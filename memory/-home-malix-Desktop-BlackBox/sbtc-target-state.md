---
name: sbtc-target-state
description: "sBTC (Immunefi, 250k) — surface Clarity de 1105 lignes cartographiée ; le meilleur candidat est mort sur MAX_SIGNERS=16 ; ne pas rejouer."
metadata: 
  node_type: memory
  type: project
  originSessionId: 0e186640-6bf5-4757-9c53-148601ee9cbf
  modified: 2026-08-18T11:09:06.836Z
---

Programme **sBTC** sur Immunefi, max 250 000 $, en ligne depuis le 2026-07-02. Scope Smart Contract =
`contracts/contracts`, **5 contrats, 1 105 lignes de Clarity**, **gelés depuis le 2024-12-12**.
Clone local complet : `/home/malix/Desktop/BUGS/sbtc-audit` (non-shallow, 48 tags).
Distinct du programme **Stacks** (stacks-core, Blockchain/DLT) dont le brief est
`BlackBox/submissions/stacks/BRIEF.md`.

## Le paysage (établi 2026-08-07, ne pas refaire)

- **48 findings publiés** sur les deux attackathons — et **quasiment aucun ne touche la Clarity** :
  signers, WSTS/DKG, libp2p, Emily (Lambda), parsers Rust. L'attention est allée où sont les crashs.
- **Aucun audit sBTC publié.** `stacks.org/audits` redirige vers `stacks.foundation/audits`, qui ne
  contient que du Stacks 2.0 de 2020 (NCC, Certik, ToB). La clause d'exclusion « concluded
  assessments » ne couvre donc pas ces contrats.
- **Un seul PR a jamais touché `contracts/contracts`** : #1662 (fermé, non mergé). Sa discussion
  donne l'invariant porteur, énoncé par `djordon` : le registry **ne vérifie pas le rejeu**, tout est
  délégué à `sbtc-deposit`/`sbtc-withdrawal` ; le registry et le token sont immuables sans hardfork,
  `sbtc-deposit` et `sbtc-withdrawal` sont remplaçables. Justification : « une majorité malveillante
  y arriverait de toute façon ». Toute proposition de filet on-chain sera fermée pareil.

## Ce qui est cartographié et propre

- **Authz** : les 5 contrats passent tous par `is-protocol-caller` (`sbtc-registry.clar:361-369`) qui
  exige les **deux sens** (`contracts[flag]==c` ET `roles[c]==flag`). Les entrées périmées ne sont
  jamais purgées par `update-protocol-contract:335-337`, mais le croisement rattrape chaque cas de
  transition. `get-active-protocol:144` est le seul lecteur à sens unique et **aucun des 5 contrats
  ne l'appelle**. Pas de frère non gardé.
- **Rejeu** : 6 des 7 `map-insert` du registry jettent leur booléen ; le 7ᵉ (`:305`, `rotate-keys`)
  le vérifie avec `ERR_AGG_PUBKEY_REPLAY`. Différentiel frappant, mais = doublon du PR #1662 fermé.
- **Compteur de retrait** : `last-withdrawal-request-id` n'est écrit qu'en `:355` par `+ u1`.
  Monotone, jamais remis à zéro ⇒ `map-insert withdrawal-requests` ne peut pas échouer en silence.
- Défauts mineurs relevés : `sweep-txid` absent de l'assert `sbtc-withdrawal.clar:264-266` alors que
  `:267` le consomme en `unwrap-panic` (signer-gated, Low) ; mutation d'état avant authz en
  `sbtc-registry.clar:169`/`:171` ; `protocol-lock` avant le check dust en `sbtc-withdrawal.clar:135-136`.

## Le candidat principal — MORT, ne pas rejouer

**Divergence de dérivation du principal signataire à n ≥ 17.** Clarity encode m et n en un octet brut
(`sbtc-bootstrap-signers.clar:85,87`) ; Rust `Builder::push_int` n'utilise l'opcode court que pour
`(1..=16)` puis bascule sur un push préfixé (`stacks-common/.../script.rs:551-563`). Prouvé et
**exécuté** : à n=16 le contrat réel, mon modèle Clarity et le modèle Rust donnent le même principal ;
à n=17 le contrat donne `SNZFPM75F98…` et le wallet signer `SN18CVSQEF4D…`.
PoC auto-validant conservé : `BlackBox/submissions/sbtc/poc-signer-principal-divergence.py`.

**Tué par `signer/src/config/mod.rs:48` `pub const MAX_SIGNERS: usize = 16;`**, appliqué en `:467`,
sur le chemin obligatoire `Settings::new` → `:625 validate()` → `:633`, unique site de prod
`signer/src/main.rs:101` avec propagation par `?`. Le binaire **refuse de démarrer** au-delà de 16.
Atteignabilité nulle par attaquant comme par accident. Set mainnet = 11 clés / seuil 8.

**Mon erreur de méthode, à ne pas répéter :** j'avais conclu « aucun plafond à 16 » depuis un grep
`"MAX_KEYS\|MAX_SIGNERS\|..."` suivi d'un **`head -20`** qui a coupé avant `config/mod.rs:48`.
Conclusion négative tirée d'une sortie tronquée — même forme que le faux négatif du clone shallow
dans [[deployed-code-not-head]]. **Ne jamais conclure une absence depuis un grep tronqué** : compter
les hits (`| wc -l`) avant de `head`. Voir [[weak-substitute-binding-class]] pour l'axe prior-art.

## Sweep Blockchain/DLT (Rust) — 2026-08-11, 8 seams, 0 finding PAYABLE

Deuxième sous-programme sur la MÊME page Immunefi (scope Blockchain/DLT = `wsts`+`emily`+`signer`+`sbtc`,
~125k LOC ; **`wsts` ajouté au scope le 13 juil.**). Clone `/home/malix/Desktop/BUGS/sbtc-audit`,
main HEAD `9bea9fd2` (2026-08-04, à jour). Workflow 8 agents + vérif adverse + 3 seams re-lus à la main.
**Fortress confirmée** — l'architecture tue la classe « transaction forgée » : chaque signer RECONSTRUIT
le sweep depuis SA PROPRE DB, lie en SIGHASH_ALL, et ne signe QUE des sighash qu'il a lui-même dérivés
(`will_sign_bitcoin_tx_sighash`, transaction_signer.rs:1209). Un coordinateur malveillant ne peut donc
NI rediriger un output NI injecter des bytes bruts ; la valeur ne fuit que par une **requête** malveillante
(deposit/withdrawal) que les signers honnêtes incluent — et `deposits.rs::validate_tx` re-sérialise et
compare octet-à-octet (amount = UTXO réel, pas un champ de script). Gates mesurés qui TIENNENT :

- **idpack overflow** (`sbtc/src/idpack/codec/decoder.rs:188` `offset+position+1`, non-checké ; le commentaire
  ligne 170 CLAME « won't overflow » — faux ; `overflow-checks=true` en release ⇒ **panic prod**, reproduit
  `-C overflow-checks=on`). MORT sur atteignabilité : seul site de decode = `utxo.rs:1609`, gated par
  `is_signer_created` (1er input dépense un UTXO signer) + observer bloc uniquement + OP_RETURN toujours
  ré-encodé honnêtement. Injectable seulement par la majorité signataire (qui vole direct). Même forme que
  MAX_SIGNERS : tell bruyant, porte tient. **Ré-ouvrir SI** un endpoint Emily/API ou un observer relâché
  passe des bytes externes à `Segments::decode`.
- **leb128** : accepte les encodages non-canoniques (`[80,00]`→0) = malléabilité, mais aucun sink ne dépend
  de la canonicité on-chain. Sans impact.
- **emily** : les filtres warp n'ont AUCUNE authz ; l'authz est à l'AWS API Gateway (3 gateways, `apiKeyRequired`
  dérivé des specs OpenAPI générées). Tous les endpoints MUTANTS (PUT deposit, chainstate, new_block…) sont sur
  le gateway PRIVÉ avec `ApiGatewayKey`. `new_block` filtre `contract_identifier==deployer.sbtc-registry &&
  topic=="print"`. Pas de chemin externe.
- **fee** : cap per-request `max_fee` borne le drain ; `div_ceil` favorise le peg ; fee_rate borné [0.001,1000].
- **dkg/rotate** : `RotateKeysV1::validate` + latch Failed refermé par `block_observer check_pending_dkg_shares`.

**Seul bug réel = non-payable (WSTS DKG coordinator panic).** `fire.rs` (FireCoordinator = le coordinateur DKG
prod, transaction_coordinator.rs:1748). Un signer malveillant envoie un `DkgEnd(Failure(BadPublicShares({N})))`
signé, N ∉ participants (ex. N=num_signers) ; `authenticate_message` authentifie l'émetteur mais PAS le payload,
donc le set malveillant atteint `&self.dkg_public_shares[bad_signer_id]` (fire.rs:420 ; siblings :447/:459/
:465/:466/:469/:471, + `dkg_end_gathered` :548/:557) ⇒ index BTreeMap/Vec hors borne ⇒ **panic ⇒ crash du process
coordinateur** (join! non-spawn, unwind, pas de catch_unwind). Répétable contre chaque coordinateur tournant ⇒
bloque toute rotation DKG. MAIS : (a) exige un signer malveillant (porte `authenticate_message` confine l'acteur),
(b) availability pure — le signing FROST sous la clé existante CONTINUE, pas de gel de fonds. Stipulation programme :
« availability DoS via malicious signer → downgrade 1+ niveau » ⇒ sous le plancher payable. Novel (pas dans les
PR/issues ni attackathons). Path signing (`gather_nonces`/`gather_sig_shares`) VÉRIFIÉ safe (invariant sign_wait ⇒
`signature_shares[i]` toujours présent) — pas d'escalade vers un panic du chemin de signature normal.

**Verdict allocation :** cible tenue sur les deux sous-programmes. Ne PAS re-sweeper. Le WSTS panic vaut une
divulgation upstream courtoise (GHSA wsts/sbtc) plutôt qu'une soumission bounty. Déclencheurs de réouverture :
nouveau code sur `contracts/contracts` OU un decode idpack sur input externe OU un changement de la fédération.

**Re-check 2026-08-16 (WSTS panic toujours VIVANT, code inchangé) :** `stacks-network/sbtc` `main` HEAD =
TOUJOURS `9bea9fd2` (2026-08-04, tip figé, dernier commit inchangé depuis le PoC). `wsts/src/state_machine/
coordinator/fire.rs` byte-identique : index brut `[bad_signer_id]` en `:420` + siblings `:447/:459/:465`,
zéro garde `.get()`. Reachability intacte : `transaction_coordinator.rs:1748` FireCoordinator::new,
`:1924` gate `authenticate_message` = sender-only (payload `bad_shares` jamais validé), `:1850`
`process_message` synchrone. 0 PR open, 0 advisory GHSA, pas de fix upstream (le repo `stacks-network/wsts`
standalone n'existe plus — wsts est vendored dans le monorepo ; `xoloki/wsts` figé 2026-05-01 & divergent =
hors-scope). Verdict économique inchangé : availability DoS via malicious signer → sous plancher payable.

**Scope Immunefi vérifié live 2026-08-16 (page MàJ 14 août) :** asset `The WSTS library` = `sbtc/tree/main/wsts`
(ajouté 13 juil.) IN SCOPE, pointe sur `main` = commit vulnérable. Table reward BTC/DLT : Critical 25-250k /
High 5-25k / Medium 1-5k / **Low flat 1k, AUCUN palier sous Low**. 3 stipulations, la #3 = « Non-Critical
availability DoS dépendant d'un malicious signer → downgrade 1 OR MORE levels ». Le panic DKG ne monte PAS à
High (« sustained total shutdown ») car le signing sous clé existante continue (report-prouvé) → au mieux Low →
stip#3 le pousse SOUS Low = 0. **SEULE porte payable** : les stips ne touchent que le « Non-Critical » — chaîner
le blocage DKG permanent en un Critical freeze/loss échapperait au downgrade (non prouvé à ce jour, angle ouvert).

**Escalade DKG-freeze creusée 2026-08-16 (2 subagents Fable 5 + vérif perso) — Critical MORT, mais plancher RELEVÉ :**
(1) Critical (permanent freeze) INATTEIGNABLE, prouvé sur 4 sous-chemins : rotate-keys = swap atomique post-DKG
(`sbtc-registry.clar:295-323`, pas de revoke séparé) ; peg wallet = P2TR key-path pur SANS timelock (`keys.rs:459`
`new_p2tr(...,None)`) → dépensable par clé courante à jamais ; latch Failed = `verified` ne peut JAMAIS →`failed`
(`write.rs:938-940`, transitions only WHERE unverified) ; fenêtre vérif = DB-local, 0 effet on-chain. Clé Verified
inaltérable ⇒ fonds jamais indépensables. Seul « permanent » = choix opé externe (détruire clé ancien set) = OOS.
(2) MAIS blast radius PIRE que cru : `main.rs:153-168` = un seul `tokio::join!` (coordinator+signer FROST+block-obs
+libp2p), ZÉRO `tokio::spawn`/`catch_unwind`, panic=unwind → **process ENTIER meurt**, pas juste le tenure DKG ;
auto-entretenu (`should_run_dkg` reste true post-crash, chaque coordinateur élu re-meurt). ⇒ impact BRUT = **High**
« sustained total sBTC shutdown », PAS Low. (3) Ingress malicious-signer CRYPTO-INVIOLABLE vérifié (gatekeeper
`is_allowed_peer` + peer-id↔pubkey `event_loop.rs:438` + `verify_digest:443` + `authenticate_message:1924`) ⇒
stip#3 s'applique forcément. **Sévérité finale : High brut −1/−(1+) via stip#3 = Medium($1-5k)/Low($1k) = PAYABLE**,
pas « nil » comme dit plus haut. Rapport : mener sur High brut (whole-process death + boucle), joindre l'invest.
Critical comme due-diligence, ne PAS auto-citer stip#3. PoC panic déjà prêt dans `wsts-dkg-panic/`.

**Rapport finalisé 2026-08-16 (report-nerve+chill, grep-clean) :** `wsts-dkg-panic/REPORT-submission.md` (92 l,
killshot ferme, whole-process-death lead, negative-space no-permanent-loss) + `chain-of-custody-comment.txt` (à
poster ~2min après submit). 2 pré-empts recevabilité ajoutés sur retour opérateur : **(A)** anti-exclusion
trusted-party ancré sur la GARANTIE THRESHOLD BRISÉE (FROST t-of-n conçu pour tolérer signers malveillants
jusqu'au seuil → 1 seul qui crash tout = bris de résilience, PAS abus de trust ; style Hedera-04). **(B)** claim
de tier explicite mappé sur la row listée High « signers unable to confirm new tx / sustained total shutdown » +
cadrage set-stuck (le crash bloque la complétion du set-change → set coincé, retrait attaquant impossible in-band).
**Vérifié :** onboarding signer = **fédération bootstrap CURÉE** (`config/mod.rs:394 bootstrap_signing_set`,
membership via rotate-keys governance-gated), PAS PoX-permissionless → renfort permissionless DROPPÉ (pas affirmé).
Form Immunefi : sélectionner impact High. Soumission = action OPÉRATEUR (compte KYC), pas moi.

**Whole-process-death EXÉCUTÉ 2026-08-16 (plus inféré) :** l'unique jambe inférée du dossier est désormais un
artefact. `wsts/examples/whole_process_death.rs` (dev-dep tokio ajouté) pilote un VRAI FireCoordinator via l'API
publique (`test::{setup,feedback_messages}` = `pub mod test`, PAS cfg(test)) jusqu'au panic réel `fire.rs:420`,
dans une structure `tokio::join!`/`run_checked` copiée de `main.rs:153-168`, avec 3 heartbeats témoins pour les
autres composants. Run direct → **exit 101, panic sur `thread 'main'`, 0 tick heartbeat post-panic, lignes
post-join! jamais imprimées** = mort du process entier prouvée. Artefacts dans `wsts-dkg-panic/` :
`poc-whole-process-death.patch` + `poc-whole-process-death-output.txt`. Rapport MAJ (94 l, grep-clean). PoC
principal (`poc-add-test.patch`) re-confirmé sur main courant (panic fire.rs:420:80). Clone `sbtc-audit` re-cloné
puis `cargo clean` (disque). Finding passé les 5 gates (Phase 0 + G1-G5) : submission-ready, seul résidu = onset-
dependency G1 (adressé) + downgrade stip#3 attendu vers Medium/Low.
Voir [[stacks-target-state]] (sous-programme distinct, stacks-core).

## 🛑 CORRECTION 2026-08-18 — le finding N'EST PAS NOVEL, c'est un DUP (re-vérif 4 agents Fable 5 + primary sources)

**La claim porteuse « Novel (pas dans les attackathons) » du rapport est FAUSSE. Ne PAS soumettre — sera fermé duplicate.**
Le dup-check des sessions précédentes a MANQUÉ deux rapports concluded-assessment, tous deux listés dans l'exclusion
known-issues du programme live (`reports.immunefi.com/stacks-i-attackathon` + `stacks-ii-attackathon`) :
- **#38030 [BC-Insight] « Coordinator can be crashed by signers on DKG »** (stacks-i). Son item #1 nomme
  EXACTEMENT notre sink : *« Here we index `dkg_public_shares[bad_signer_id]` … if a signer manages to have
  `bad_signer_id` not in `dkg_public_shares`, it is possible … for completeness »* — old `fire.rs#L580` = current
  **L420**, même variable, même mécanisme. Dev `djordon` a confirmé sur Discord : « marked as Insight anyways ».
- **#40731 [BC-Medium] « A malicious signer can force a panic in the coordinator by sending `DkgFailure::BadPrivateShares`
  with an invalid signer ID »** (stacks-ii). MÊME sink `self.dkg_public_shares[bad_signer_id]`, MÊME technique id
  hors-borne (`non_existent_signer_id = 9999` ↔ notre `num_signers`), MÊME panic string *« no entry found for key »*,
  MÊME impact *« effectively stopping the network from processing transactions »*. Diffère uniquement par le bras
  `BadPrivateShares` vs notre `BadPublicShares` — même `match dkg_failure`, arm voisin.
Notre seule nouveauté réelle = le trigger « facile » (`DkgEnd(BadPublicShares({num_signers}))`) pour le cas que #38030
disait « not easy » + l'argument whole-process-death. Sous la clause « Novel attack methods that lead to an already
documented impact are allowed » → considéré MAIS plafonné au tier de l'impact documenté = **Insight (#38030) / Medium
(#40731)**, puis stip#3 (availability DoS malicious-signer → −1+) rabote encore. Réaliste = **$0 (duplicate/known-issue)**,
au mieux Low $1k.

**Technique = 100% CONFIRMÉE (re-vérif indép.) :** panic fire.rs:420 réel (gate sender-only `:381`, index BTreeMap
non-gardé) ; reachability prod OK (authenticate_message `:1924` sender-only, decode `zst_to_hashset`=`into_keys().collect()`
zéro borne, process_message inline `:1850`) ; whole-process-death OK (`main.rs:153-168` join! sans spawn/catch_unwind,
`run_transaction_coordinator:417` await inline). Le bug est vrai — c'est la RECEVABILITÉ (dup) qui tue, pas la technique.
**Impact tier corrigé : « sustained total sBTC shutdown » = HIGH (pas Critical) dans la table live.** Leçon =
[[recevability-gate-before-poc]] + [[weak-substitute-binding-class]] : le dup-check doit couvrir les bras VOISINS du
même match/sink, pas seulement la string exacte du vecteur.

## Verdict d'allocation

Surface petite, entièrement lisible, prior art vide côté audits — mais elle tient. La seule veine non
épuisée serait une **défaillance démontrée d'une garde déléguée** dans `sbtc-deposit`/`sbtc-withdrawal`
(le registry n'ayant aucun filet) ; je n'en ai pas trouvé. Ne rouvrir que sur déclencheur : un nouveau
commit sur `contracts/contracts` (gelés depuis 20 mois) ou un changement de la fédération de signers.
