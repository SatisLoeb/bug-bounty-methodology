# Seam-Primitive Sourcing Map — la couche accès de Phase -1 (triple-cross final, 2026-09-17)

**Ce que c'est.** La primitive-mère (« le garde/la lecture vise la variable ADJACENTE à celle que l'attaquant
contrôle ») portée sur N axes, chaque axe rendu en **requête de sourcing exécutable** :
`primitive → signature-de-cible → impact-landing → mur recevabilité → où-chasser-low-dup → différentiel`.
Source = triple croisement (recherche opérateur × recherche assistant × 7-agent mine). Data de référence,
consultée par Phase -1 (playbook §0) + `intake`/`wide`/`xsurface-prioritize`.

> **STATUT : TABLE D'HYPOTHÈSES DE SOURCING, EN OBSERVATION — AUCUNE des 9 branches n'est validée.** Même
> statut que le dup-density-log ou l'audit-count-par-classe : utile, consultable, non-prouvée. Distinction
> CRITIQUE : **cadavre-de-PRIMITIVE ≠ cadavre-de-SOURCING.** Les cadavres cités (RSK/Leather/ENS/Granite/OZ)
> prouvent que la *primitive* (la variable-mal-gardée, §4, 3 cadavres) trouve des bugs. Ils NE prouvent PAS
> que la *signature-de-sourcing* d'une branche route vers une cible PAYABLE — c'est un cran plus amont, sans
> cadavre. La convergence des 3 sources = trois hypothèses d'accord (aucune n'a testé), PAS une validation.
> **Un cadavre-de-sourcing (l'unité de falsifiabilité de cette couche) = une cible que la map a scorée
> haute-EV, sur laquelle tu as dépensé de l'effort GO, morte pour une raison que la map aurait dû prévoir**
> (pas de programme payable rattaché / la primitive ne s'instancie pas en prod, Gate 5 #6 / dup-magnet
> déguisé). Une branche gradue de « hypothèse » à « veine » après UN cadavre-de-sourcing testé jusqu'au bout,
> pas avant. Ne cite jamais une branche comme « le funnel » — ce sont 9 paris classés par mur, pas 9 acquis.

**Garde dup** : 5 sont de la variable-mal-gardée pure → signature-dup connue → ne composent
qu'où le dup est bas (non-EVM, fork-tails, relationnel).

## TIER 1 — mains prouvées, mur BAS, chasse d'abord (convergence des 3 sources)

**P1 — Wrong-selection / weak-key binding** · axe représentation/sélection · *cadavre: RSK #90518*
- signature : un parser/keeper/relayer/light-client off-chain OU un fetch on-chain qui LOCALISE un objet vérifié par une clé faible — `logs[0]`, `topics[0]==SIG` seul, first-match, index non-épinglé, `latestRoundData` quand un round précis est dû. Tell fatal = absence des DEUX : pin emitter (`log.address==KNOWN`) ET (emitter,index) figé.
- impact : mint-infini/theft (bridge), mauvaise-autorisation · **mur BAS** (logique parser/contrat, différentiel natif)
- où (low-dup) : light-clients non-EVM re-parsant un receipt EVM (near-rainbow, SP1/Succinct, Polyhedra, IBC-EVM), AVS/keeper-bots, **Solana sig-verify introspection** (solfork, la foule ne peut lire)
- différentiel : objet genuine seul → dévie si un leurre (2ᵉ emitter, même topic0, montant énorme en logs[0]) le précède.

**P2 — Ledger-key ⊄ preimage signé** · axe ledger-key · *cadavres: Leather V4/dHEDGE (op), Permit2/4337 (agents)*
- signature : un ledger anti-replay/uses/nonce/budget dont la CLÉ ⊋ les champs signés, OU un preimage signé ⊊ les champs CONSOMMÉS. Set-diff : typestring witness Permit2 vs champs lus dans resolve()/execute() ; forgeable = lu-mais-pas-dans-typestring.
- impact : budget frais par variation → double-spend / vol-de-spread · **mur BAS** (différentiel = double-budget)
- où (low-dup) : fork-tails (vendors 4337, modules 1271, forks Permit2/UniswapX) — les canoniques sont durcis.

**P3 — Authn-garde fait confiance au bénéficiaire off-chain** · axe représentation/identité · *cadavres: ENS #92483 (locus A), Upshift (locus B)*
- signature : LOCUS A = champ subgraph/indexer (owner/assignee/to/beneficiary) → `writeContract`/calldata SANS re-dérivation canonique (le sibling EST re-dérivé via `ownerOf`/`resolver`) ; LOCUS B = backend signeur (`signTypedData`/KMS) authn sur session/JWT mais lisant recipient/amount/orderId du `req.body` sans re-lire la valeur autoritaire en DB.
- impact : auth bypass / mis-payment · **mur MOYEN — l'asset off-chain doit être listé EXPLICITEMENT (pré-check recevabilité D'ABORD, sinon $0)**
- où : profil-Upshift (backend co-signeur + API + frontend tous in-scope = dup le plus bas), programmes listant un asset dApp/frontend · différentiel : flippe l'adresse que le subgraph/req.body renvoie.

**P4 — Désynchro temporelle entre 2 state-machines** · axe temporel · *cadavres: RSK/Granite/OZ (op), Stacks/EigenLayer/CosmWasm (agents)*
- signature : deux machines couplées, A avance sur un trigger E que B lit comme inchangé. Paires : epoch/cycle, finalize/settle, snapshot/claim, deposit/valuation, pause/activation, oracle-push↔consumer-read.
- impact : **fork/non-déterminisme (Critical, mur HAUT** — programme doit payer le non-déterminisme + PoC souvent multi-nœud**)** OU insolvency/double-spend (**mur BAS**, contract-logic). → chasse d'abord les variantes insolvency/double-spend.
- où (instances live des agents) : Stacks signer-set cycle-edge (A1, epoch-3.x LIVE, variante fork), EigenLayer stale-slashing-factor (A4, wrappers LRT/AVS, PAS le core), CosmWasm reply/IBC-ack (A7).

**P5 — Chemin error/refund/timeout : isolation + conservation + result-variant** · axe branche-non-testée+temporel · *cadavres: OZ #92486 (op), A7/A9 (agents)*
- signature : la branche de PERTE (catch/_refund/_cancel/_settleFailed/`reply_always`/ibc_ack) qui crédite sans le débit-miroir, paie d'un pool partagé, rejoue sans clé d'idempotence (channel,sequence), OU commit un succès sans brancher sur la variante de résultat (`SubMsgResult::Ok` vs `Err`).
- impact : double-spend / inflation · **mur BAS-MOYEN** · différentiel : livraison OK (isolé) vs échouée (cross-pool) ; finis en `V_in==V_out` exécuté sur le chemin non-testé.
- où (low-dup) : CosmWasm/IBC (`reply_always`, ack — Neutron/Osmosis/Mars/Astroport/Sei/Injective), settlement batch EVM (CoW/UniswapX/0x), refund paymaster 4337.

## TIER 2 — fraîches / gated

**P6 — Identité multi-représentation** · axe identité · *fresh*
- signature : même autorité sous deux adresses/formes traitées comme distinctes (double-budget) ou deux autorités comme la même (confusion) — 7702, 1271, smart-accounts, proxies, alias cross-chain ; **Move address/signer decoupling** (A5 : `borrow_global_mut<R>(target)` au lieu de `signer::address_of(s)` = authn≠authz pur) ; ERC-2771 `_msgSender` spoof.
- impact : auth bypass / double-budget · **mur MOYEN — Gate-5 #6 : recense la prod, la forme doit EXISTER (piège V4)** · où : 7702 (récent), Move (densité-warden minuscule : Thala/Aries/Econia, Cetus/Scallop/Navi/Suilend).

**P7 — Encodage non-canonique → collision de digest / decode-boundary** · axe représentation cross-lang · *cadavre: A6 (Wormhole)*
- signature : une byte-string signée DÉCODÉE asymétriquement — point de commit (keccak/`_hashTypedDataV4`/verifyVAA/merkle-leaf, note la byte-range couverte) vs point de consommation (`abi.decode`/offset-arith/borsh) où couvert ≠ consommé ; skew sérialiseur Go↔Rust. NE grep PAS `abi.encodePacked` (Slither-owned, dup-magnet).
- impact : deux messages même digest signé / ré-interprétation de payload · **mur MOYEN** · où : bridges multi-langage (Wormhole guardian Go + Solidity + receivers Rust/Solana).

## TIER 3 — impact max, mur MAX (seulement si le programme paie)

**P8 — Finalité optimiste / cross-domaine** · axe finalité
- signature : un côté traite l'état comme final avant l'autre (L2→L1, OE baseapp, cross-chain msg, oracle push/pull).
- impact : non-déterminisme/insolvency (max) · **mur HAUT — souvent by-design-accepted + PoC multi-nœud** → n'attaque QUE si le programme paie explicitement la finalité/non-déterminisme et accepte ton format.

## AJOUTS du croisement (ce que les 7 agents ont RATÉ)

**P9 — Branche privilégiée la moins-testée (migrate/recover/emergency) qui re-grant du pouvoir durable** · axe branche-non-testée · *cadavre: la MOITIÉ migration de ENS #92483*
- Les agents ont plié ENS dans P3 (beneficiary-trust) et lâché ceci : une branche écrite-une-fois (v1→v2/upgrade/recovery/emergency) qui re-grant un rôle ou reset un guard que le steady-state protège. mur BAS-MOYEN · où : tout protocole avec un chemin migration/recovery/emergency.

**C0 — COMPOSEUR « devenir l'acteur » (méta, pas standalone)** · darkside 0.5.2
- Le premier hop Gate-1 qui transforme P6/P9/tout owner-gated de « privilégié » en **Critical non-privilégié** : init-hijack, clone-front-run (salt ne bind pas l'owner), `_msgSender` spoof, role-admin gap, storage-collision. **À lancer sur CHAQUE sink privilégié avant d'écrire OOS.** Aucune source ne l'avait listé (c'est un composeur) = le plus haut levier manquant.

## KILL-LIST — NE chasse PAS (validée par le filtre agents + tes garde-fous)
- **NAV / non-realizable-value 4626** — ton cul-de-sac mesuré 2× (Pareto/infiniFi NO-GO), victime inversée, ton Maslow qui sonne.
- **DoS mono-nœud** (Low par construction, matrice Stacks) · **griefing sans profit** (downgrade Medium) · **impact hors-scope**.
- **Classiques déguisés** (la vraie concurrence les grep en premier) : reentrancy nue, overflow, access-control manquant, oracle-stale simple, first-depositor inflation, Solana `remaining_accounts`, cw20 receiver spoof, payable-multicall `msg.value`, 2D-nonce, accrual-index ordering, cross-layer rehypothecation, L2 priority-auction (PoC infalsifiable).

## Ordre de priorité (ta ligne + le mur)
1. **P4 (variantes insolvency/double-spend)** & **P2** — mains prouvées, mur le plus bas.  2. **P1** (+ bonus Solana) & **P5** — prouvées, low-dup non-EVM.  3. **P9 + C0** — les ajouts du croisement.  4. **P6** (recense la prod d'abord).  5. **P3** (recevabilité D'ABORD).  6. **P8** seulement si le programme la paie.
**Le "pari" divergent A1 Stacks cycle-edge — DÉMOTÉ : une hypothèse à 3 murs déjà payés, pas un pari.** Séduisant (accès en main, divergent) mais **l'accès ne surmonte AUCUN des 3 murs que ton dossier stacks-nested porte déjà** : (1) **matrice DoS Stacks** — un cycle-edge mono-nœud tombe en Low ; il faut un vrai B3 multi-rôles (miner+signer séparés), pas un desync mono-nœud ([[stacks-dos-matrix-bxr-grid]]) ; (2) **format PoC 4-nœuds** exigé, ton harness simnet ne passe pas ; (3) **epoch-4.1-dormant = Gate 5 #6** : la forme n'existe pas en prod → realized impact ZÉRO jusqu'à l'epoch ([[stacks-fresh-drift-epoch41-dormant]]). RE-LIS stacks-nested AVANT d'en faire un GO — tu as payé ces 3 murs une fois là-bas. La "fork=Critical variant" doit prouver B3-multi-rôle + tourner en 4-nœuds + une forme live, sinon c'est un Low mono-nœud sur une forme absente.

*Maintenir : une primitive graduе au playbook §4 quand elle produit un cadavre. Une entrée sort si un finding meurt de sa mauvaise signature-de-cible (couche accès falsifiable, comme les gates).*
