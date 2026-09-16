---
name: enzyme-target-state
description: "Enzyme Blue (Immunefi $200k) — mesuré quasi-forteresse, 0 payable ; Enzyme Onyx est la vraie re-source (11 mois, 73 fichiers, QA-only)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 25a96f78-e91a-4df7-8f39-67f19474d3cd
  modified: 2026-08-22T12:23:00.073Z
---

**DEUX programmes Immunefi distincts, même économie ($200k max, Critical = 10% des fonds affectés, plancher $20k, High $5k–20k, Medium $1k–5k, USDC, pas de KYC, PoC fork OBLIGATOIRE, triage médian 4h, PAS de fee).**

## Enzyme BLUE — mesuré quasi-forteresse (2026-08-18)
Scope local : `/home/malix/Downloads/foundry-v2-enzymefinance-2482cca95dd3523f (1)` (Instascope v2, `chains/<slug>-<id>/src/<Name>_<addr4>/`). 313 assets / 96 noms / 4 chaînes. **Vrai volume = 619 fichiers logiques uniques, 182 = contrats in-scope nommés** (les 4952 .sol sont des copies de deps). TVL ≈ **$85.4M, 90% Ethereum** → seul le core peut dépasser le plancher $20k.

**Deployed-code-not-head VÉRIFIÉ positif :** `FundDeployer.getComptrollerLib()`/`getVaultLib()` == adresses in-scope, `Dispatcher.getCurrentFundDeployer()` == FundDeployer in-scope. Le code audité EST le code qui porte les $77M.

**Corpus Gate 4 COMPLET (aucun trou) — 4 sources, toutes lues en primaire :**
1. 34 audits ChainSecurity → `github.com/enzymefinance/protocol` `/audits` (branche `dev`). **S'arrête 2025-08.**
2. **13 rapports "Extensive QA" ChainSecurity → `github.com/ChainSecurity/quality-assurance-reports/tree/main/Enzyme`** (le lien Immunefi est tronqué ; c'est CE repo). **S'arrête 2025-09-29.** Le programme dit verbatim : « Any prior bugs found in audits or *extensive QA* are ineligible ». Contient aussi `enzyme-onyx/` et `enzyme-myso-v3/`.
3. Page docs Known Issues (`docs.enzyme.finance/enzyme-blue-protocol/topics/known-issues`) = 1 seule entrée, déjà dans l'OOS.
4. 8 entrées OOS Immunefi.

**Veines MESURÉES NULLES (ne pas relancer) :**
- **Post-audit drift = VIDE.** Tous les commits post-2025-08 touchant du code in-scope = AliceV2 (3 fix) + 1 fix gated-queue (`requestRedeem: Zero amount`, 2026-04-10). Le reste supprime des intégrations hors scope (Balancer, ParaSwapV5, TermFinance, UniswapV2).
- **Drift cross-chain = VIDE.** Les 4 versions de source ne diffèrent que par `forge fmt` + style d'import + `override`. Zéro delta logique. Prouvé 2× indépendamment (mon diff mécanique + l'agent core).
- **Asymétrie nonReentrant** (4 chaînes) : 1 seule (`cancelRequestDeposit`), CEI tient.
- **Staleness oracle** : tous les consommateurs de `latestRoundData` checkent `updatedAt`.
- **safeApprove** : tous les sites bare sont gardés par `allowance==0` ou init one-shot.
- **Downcasts uint64 d'accumulateurs** (`cumulativeLoss`, `cumulativeSlippage`) : le check de tolérance PRÉCÈDE le cast.
- **swap-and-pop** : seulement 3 sites dans 619 fichiers (voir défaut Lido ci-dessous).
- 14 diggers Fable-5 par contrat + 8 diggers de COUTURE : voir verdict final.

**TOMBSTONES qui tuent des cibles apparemment fraîches (le gain du front-load) :**
- **BebopBlendAdapter** (scope 17 déc 2025, 0 hit dans les audits) → le QA `..._BebopAdapter.md` nomme déjà read-only reentrancy, leftover tokens, griefing par maker. J'ai confirmé on-chain `TRUSTED_MAKERS_LIST_ID == 0` (garde « trusted makers only » inerte) MAIS le QA nomme la condition (« if list ID is non-zero ») et l'acteur qui choisit l'ordre est le manager trusted. **MORT.**
- **StaderWithdrawalsPosition** → QA Medium/High « valuation des withdrawals non finalisés ⇒ arbitrage de share price », **jamais fixé** (1 seul commit 2024-11-22, deployed == HEAD) ⇒ « unfixed vulnerability mentioned » = **impayable**.
- `AddressListRegistry` list id **0 = sentinelle vide non-ownée réservée** (owner 0x0, updateType None, 1077 listes) — pas une collision.

**LE SEUL VRAI DÉFAUT TROUVÉ (non-payable, à envoyer en courtoisie) :**
`LidoWithdrawalsPositionLib.__claimWithdrawals` compare un **ID de requête Lido à un INDEX de tableau** :
`if (storedRequestId != finalIndex) { requests[j] = requests[finalIndex]; } requests.pop();` — devrait être `if (j != finalIndex)`. Si `storedRequestId == finalIndex` et `j != finalIndex`, le swap est sauté mais le pop a lieu : la requête RÉCLAMÉE reste en storage (GAV gonflé en permanence ⇒ share price gonflé ⇒ les redeemers volent les holders restants) et une requête NON réclamée disparaît.
**ChainSecurity a lu cette fonction exacte** (`CS-SUL13-002 "Deleting From Lists"`, audit 2023-09) et n'a signalé que l'inefficacité gas — le défaut n'est PAS dans le corpus. **Mais Gate 1 échoue** : seul le manager (trusted) peut ajouter/réclamer des requêtes ; un attaquant ne peut pousser les ids Lido que vers le HAUT (loin des petites valeurs nécessaires). `getLastRequestId()` = 132 657 au 2026-08-18. Il faudrait une position détenant une vieille requête à id bas ET exactement `id+1` requêtes en attente. **Erreur de manager, pas une attaque.**
Forme classique : les libs partagées `AddressArrayLib`/`Uint256ArrayLib.removeStorageItem` utilisent `if (i < itemCount - 1)` — CORRECT ; Lido est le seul endroit qui a réimplémenté le helper à la main.

## Enzyme ONYX — la vraie RE-SOURCE
`immunefi.com/bug-bounty/enzyme-onyx/` — **live depuis 2025-09-04** (vs 5 ans pour Blue), 44 assets, **73 fichiers .sol**, repo `github.com/enzymefinance/protocol-onyx` (dev actif jusqu'au 2026-07-30). Tokenisation de véhicules de gestion : `Shares`, `ValuationHandler` (share price CACHÉ + staleness), `FeeHandler`, `ERC7540LikeDepositQueue`/`RedeemQueue`, `SyncDepositHandler`, `SharesMintHandler`/`SharesBurnHandler` (juillet 2026), intégration **Chainlink CRE + ACE** (couture on-chain↔off-chain workflow, nonce/expiry).
Revue : seulement **3 audits** (2025-09 onyx-initial, OnyxCCIPWallet, OnyxChainlinkACEIntegration ajouté 2026-07-30) + 3 QA. Le QA note lui-même *System Risk: High* sur « incorrect share calculation » et « incorrect fund movement » de `SyncDepositHandler`.
**ATTENTION recevabilité (dense, à front-loader) :** OOS = « everything noted in this document set », « everything noted in audit reports », « user error », et **explicitement « share price staleness/fairness/etc during deposit or redemption — admin has full control over the price »** ⇒ la veine xseam évidente est morte par règle écrite. Aussi : « Deposits Can Be Stolen By Inflating The Share Price » = **Risk Accepted** dans l'audit 2025-09 ⇒ mort. Les assets sont des **URLs GitHub, pas des adresses** ⇒ Gate 5 : « 10% des fonds affectés » peut retomber sur le plancher $20k.
Veine restante la plus crédible : **post-audit drift sur 73 fichiers** (`#131` SharesDeployer du 2026-07-29 est postérieur au fix d'audit `#130` du 2026-07-23).


### ONYX — mesures exécutées 2026-08-18 (hand-audit opérateur + 12 diggers Fable-5)
Repo `scratchpad/onyx` (73 fichiers, **7 722 LOC src**, 14 579 LOC de tests = ratio 1,9:1). Corpus Gate 4 local :
`scratchpad/onyx-audits-txt/` (3 audits) + `scratchpad/qa-reports/enzyme-onyx/` (3 QA) + `scratchpad/ONYX-DOSSIER.md`.

**MATRICE DE COUVERTURE DÉFENSIVE (Door A, mécanique) :** 453 tests / 95 fonctions externes state-changing.
Seules 7 n'ont AUCUN test d'échec, dont **4 sans aucun test du tout** : `WalletsManager.batchSendTokensViaCCIP`,
`DepositorWallet.sendCCIPMessage`, `SharesBurnHandler.setPreBurnHook`, `SharesMintHandler.setPreMintHook`.
**Tout le sous-système CCIP n'a aucun fichier de test** (pas de WalletsManager.t.sol ni DepositorWallet.t.sol) —
mais il est admin-gated, donc l'absence de test ne donne pas d'acteur non-trusted.

**Thèses construites puis TUÉES par lecture (ne pas refaire) :**
- `SharesDeployer.deploy()` non-gardée + `__preMint` s'auto-enregistre deposit-handler et mint un `total`
  fourni par l'appelant → **MORT** : `deploy()` crée TOUJOURS un `Shares` neuf via factory, aucun point
  d'entrée n'accepte un Shares existant. (Note : handoff `Ownable2Step`, le deployer reste owner jusqu'à
  `acceptOwnership()` — inerte, aucun moyen d'agir sur un vault existant.)
- **Squat d'adresse CCIP** (l'audit ACCEPTE « DeterministicBeaconFactory.deployProxy is permissionless », et
  les wallets dérivent de `(sourceChainSelector, sender)`) → **MORT** : `deployProxy` met `msg.sender` DANS le
  sel CREATE2 (`keccak256(abi.encode(msg.sender, _salt))`), un appelant direct atterrit ailleurs. C'est
  précisément ce qui rend l'acceptation de l'audit légitime.
- `Shares.authTransfer` sans modifier vs `authTransferFrom(onlyRedeemHandler)` → require inline, asymétrie
  correctement orientée (`authTransfer` ne bouge que les shares du handler lui-même).
- `hurdleRate` int16 casté en `uint16(...)` → `setHurdleRate` exige `>= 0` ; l'int16 est du future-proofing documenté.
- Extracteurs ACE : les 7 sont cohérents ; `SyncDepositHandlerPostDeposit` n'a pas de param destinataire parce
  que `deposit()` mint à `msg.sender` uniquement — il n'y a pas de destinataire à perdre.
- `DepositorWallet.executeCalls` = calls arbitraires pilotés par un message cross-chain → confiné : `isInstance`
  est ÉCRIT mais JAMAIS LU dans src/, donc un wallet n'a aucun privilège protocole.
- `CreWorkflowConsumer.onReport` : forwarder + workflowId + workflowName + workflowOwner + expiry + nonce strict.

**Balayages mécaniques sur les 73 fichiers :** 0 `unchecked`, 0 low-level call, 1 seul `try/catch`
(`WalletsManager`, self-gated), 1 seul swap-and-pop (`LinearCreditDebtTracker`) qui compare **index vs index**
— la forme CORRECTE du bug Lido de Blue. Downcasts : tous bornés (minRequestDuration est `uint24`).

**Résidus notés, NON soumettables :** `getSharePrice()` retombe silencieusement sur `1e18` quand
`lastShareValue == 0`, et `executeRedeemRequests` jette le timestamp (aucun check de staleness au redeem) —
**mort par la règle écrite** « share price staleness/fairness during deposit or redemption is OOS ».
`__updateShareValue` revert définitivement si `totalFeesOwed > totalPositionsValue` (seul chemin de refresh du
prix) — vraie forme de freeze mais aucun levier non-trusted. `batchSendTokensViaCCIP` rembourse
`address(this).balance` entier au lieu du `msg.value` non dépensé — admin-gated.

## BLUE — passe MANUELLE main/source-primaire (2026-08-22, apparatus-off poke)
Scope local `foundry-v2-...enzymefinance-...(2)` (Instascope v2, 313 assets, dates Immunefi = "last updated" PAS déploiement). 4 assets pokés à la main, TOUS mesurés-propres :

1. **GatedRedemptionQueueSharesWrapper (Lib bb84 + Factory 73b9)** — propre bout-en-bout. Le Factory `0x73b9…290d` est **vraiment redéployé récent** (creation_block 25 809 052, ~mi-août 2026, via **Blockscout** `eth.blockscout.com/api/v2/addresses/<addr>` — etherscan bloque WebFetch en 403) MAIS c'est un **beacon** (`IBeacon`) dont `implementation` = bb84 = **le Lib audité en scope** (zéro mismatch), `setImplementation` gated `Dispatcher.getOwner()`, init OOS (`require(vaultProxy==0)` + front-run OOS). `deploy` permissionless → instances-fantômes inertes (owner = vault owner live). Invariant `balance ≥ sharesPending` tenu sur toutes les entrées permissionless.
2. **BebopBlendAdapter** — pass-through mince, parser/action symétriques (même `order`), champs non-contraints (`packed_commands`,`flags`,`maker_amount`) maker-signés → manip nuit au maker pas au vault.
3. **ThreeOneThirdAdapter** — net-accounting parser (somme deltas par asset). `takeOrder` **sans `onlyIntegrationManager`** (divergence vs BebopBlend) mais push que la balance de l'adapter → drain accidentel = OOS. **CLASSE ADAPTER ENTIÈRE ÉLIMINÉE** par le guard IM : `IntegrationManager.sol:387/437/440` mesure le **delta de balance RÉEL du vault** par-asset (`balanceOf(vault) après - avant >= minIncoming`), le parser rapporté n'est qu'un **seuil**, l'enforcement est mesuré. Spend borné physiquement par `__withdrawAssetTo(maxSpend)` (pas d'approval en Transfer). Le parser peut mentir sans effet.
4. **AliceV2PositionLib (a286)** — EP-valuation MESURÉE (settled = `balanceOf(EP)`) / principal-figé-mais-correct (pending = `outgoingAmount`, tokenIn réellement plein dans Alice). **FAUX DOUBLE-COUNT tué en source primaire** : j'avais prouvé un double-count ligne-à-ligne (pending compte principal plein + `balanceOf` capte le tokenOut déjà arrivé si un ordre settled B partage l'asset) — MAIS il reposait sur « Alice livre le tokenOut par tranche pendant le pending », prémisse tirée d'un **ABI Blockscout DEVINÉ** (le champ "slices=1784729339" était en fait le `deadline`, "duration" le `limitAmountToGet` — décodé main sur l'OrderPlaced ; Alice `0x6F13230851B7e00e3e79277DccE6953140D8302D` non-vérifiée). Réfuté on-chain : **50 events settlement (`0x85cfa59b`, orderId indexé), 50 orderIds distincts, ZÉRO doublon, montant plein en 1 tx** → Alice = limit-order ATOMIQUE (pas TWAP, pas de fill partiel). Fenêtre pending-avec-tokenOut = largeur ZÉRO → le XOR par-ordre tient → **pas de double-count**. `getOrderHash` throw = "invalid id OR settled" (sonde `cast` sur ids 0..72). `getDebtAssets` vide.

**Verdict passe manuelle : Blue = forteresse confirmée à la main, 4/4 assets frais propres. Enzyme (Blue) épuisé solo côté SC.**

Voir [[bounty-playbook-5-gates]], [[recevability-gate-before-poc]], [[deployed-code-not-head]], [[by-design-gate-not-just-git-dup]], [[measure-before-asserting-in-reports]], [[external-premise-closure-before-finding]].
