---
name: rootstock-flyover-target-state
description: "Rootstock/Flyover Immunefi ($200k) — état d'engagement, seul submittable = captcha fail-open Medium"
metadata: 
  node_type: memory
  type: project
  originSessionId: e7eba51c-0494-463f-a04a-ad24e83256ef
  modified: 2026-08-13T02:03:54.374Z
---

RootstockLabs Immunefi (max $200k, live depuis 10 fév 2026, KYC+PoC). Engagé 2026-08-12.

**Scope.** SC-core (audité, graveyard): LBC proxy + split du 3 juil 2026 = PegIn/PegOut/CollateralManagement/
FlyoverDiscovery/PauseRegistry (impls derrière ERC1967) + libs Quotes/BtcUtils/SignatureValidator. Repo =
`rsksmart/liquidity-bridge-contract` (src/*.sol in-scope; src/legacy/{LiquidityBridgeContract,Quotes}.sol OOS).
Web/App (surface track-record, off-chain): `liquidity-provider-server` (Go 81k LOC), 2wp-api, flyover-sdk,
bridges-core-sdk — clonés dans BUGS/rootstock-flyover.

**rskj/powpeg AUDIT in-scope-active 2026-08-20 — 0 clean payable, DLT tier MESURÉ-ÉPUISÉ.** Workflow focalisé (RSKIP540 fees + release-tx released + powpeg fédérateur) -> 2 survivants, hand-verifiés, aucun clean : **#1 (Low, NON-payable, dup-risk)** BridgeSupport.processPegoutsInBatch : `totalPegoutValue` calculé une fois sur la liste complète (1507-1510) JAMAIS recalculé après le split max-tx-size (subList(0,size/2) 1521-1526) -> la tx bâtie paie firstHalf mais le total périmé va à logReleaseBtcRequested (event corrompu) ET adjustBalancesIfChangeOutputWasDust (1552) -> BURN ~secondHalf du RESERVE RBTC du Bridge vers 0xFFFF. MAIS invariant peg 1:1 PRÉSERVÉ (users payés plus tard, circulating==locked) -> pas de vol/insolvency/split ; pas de row Immunefi pour 'burn d'un slice de la réserve d'émission' ; Second-Maxim (dev n'a pas imaginé l'état post-split). Non-soumettable. **#2 (Medium griefing, OOS-menacé)** powpeg BtcToRskClient.onTransaction (390) : put(wtxid,[]) + write(FULL fileData) à chaque tx vers l'adresse fédération surveillée (même mempool/dust, coinsReceivedOrSent) ; entrées non-confirmées JAMAIS purgées (tx==null->continue 551) -> map immortelle, O(n) write/tx O(n²) cumulé, RAM/disk non bornés, sur TOUS les fédérateurs. Réel/vérifié MAIS : (a) freeze matériel NON démontré + économiquement borné (dust+fee+ancestor-limit 25 ; ~100k entrées≈0.3BTC = dégradation modeste pas freeze) -> clause OOS 'DoS economically impractical' ; (b) risque lecture OOS 'pure P2P DoS' (trigger = txs réseau BTC). Recevabilité (P2P-DoS reading) = GATE À RÉSOUDRE AVANT tout PoC. EV faible. **Bilan Rootstock COMPLET : F1 killed + SC/Web null + powHSM forteresse + Union OOS-un-wired + rskj/powpeg 0 clean = cible mesurée-épuisée, RE-SOURCE.** Seuls résidus : #2 filable Medium (si gate P2P résolu, EV bas) ; Union Bridge = re-auditer si un futur release câble l'adresse mainnet. Cf. [[report-no-self-devaluation]], [[recevability-gate-before-poc]].

**rskj / powpeg-node scoping 2026-08-20 (full-push opérateur) — surface in-scope-active MINCE.** Clones locaux : rootstock-rskj @ tag VETIVER-9.0.4 (273MB->350MB, released code) + rootstock-powpeg @ VETIVER-9.0.3.0 (3MB). Activation mainnet : HFs actifs jusqu'à vetiver900=8804200 ; `isActive == 0<=h && h<=block` donc height -1 = JAMAIS actif. **Veine fraîche la plus juteuse = UNION BRIDGE (co.rsk.peg.union) mais OOS TRIPLE sur mainnet** : (1) RSKIP502=reed810=-1 (inactif ; testnet reed810=7139600 actif) ; (2) UnionBridgeMainNetConstants unionBridgeAddress=ZERO_ADDRESS ; (3) changeUnionBridgeContractAddressAuthorizer=ZERO_ADDRESS + setter testnet-only (SET_..._FOR_TESTNET). Donc requestUnionRbtc/releaseUnionRbtc (near-permissionless, authz = caller==unionBridgeAddress, compta compteur weisTransferredToUnionBridge + lockingCap + circuit-breaker) sont INATTEIGNABLES sur mainnet ET non-câblés — activation mainnet exige un RELEASE FUTUR qui pose une vraie adresse+authorizer. = 'under development, not enabled by default' OOS. Pas coiled-spring prêt : watch-item pour un futur release qui câble l'union (re-auditer À CE MOMENT). **Seul changement peg IN-SCOPE+ACTIF+FRAIS = RSKIP540 (vetiver900) = pegout fee estimation (getEstimatedFeesForNextPegOutEvent / getEstimatedFeesForPegOutAmount / min-pegout-as-extra) = plafond bas.** Reste peg = ancien/saturé (audité à mort). powpeg = fédérateur mince, money-path HSM-gated (HSM = forteresse prouvée -> feed-bad-data non payable). Master a des commits pegout-tx frais (segwit vsize, RSKIP378, batching, dust) mais NON dans le tag vetiver => OOS (deployed-not-head). Workflow focalisé lancé sur RSKIP540 + release-tx released + powpeg non-HSM-gated. Cf. [[thegraph-target-closed]] (dormant->reopen-on-activation), [[deployed-code-not-head]].

**TIER DLT OUVERT 2026-08-20 — rsk-powhsm 5.6.2 firmware = MESURÉ-NULL FORTERESSE, 0 payable.** Fan-out adversarial 6-seams (bc_advance/bc_diff/bc_mm/srlp/auth_tx/auth_trie) + hand-verify opérateur sur la primitive de vol. ~50 nulls cités. Invariant central VÉRIFIÉ À LA MAIN : la difficulté cumulée est liée au VRAI PoW BTC — `check_difficulty` (bc_diff.c:77) target=2^256/difficulty, mm_hdr_hash<=target ; `cap_block_difficulty` borne la contrib/bloc ; `bc_adv_accum_diff` (bc_advance.c:290) accumule avec `if(carry) FAIL(TOTAL_DIFF_OVERFLOW)` (pas de wrap) et n'avance best_block QUE si total>=MIN_REQUIRED_DIFFICULTY, ancré au best_block de confiance par préimage keccak. Le merged-mining lie 1 PoW BTC réel <-> 1 header RSK honnête (coinbase épinglé par merkle_root, collision 20-byte keccak = 2^80). Inclusion receipt liée à ancestor_receipt_root par chaîne keccak. => vol / chain-split / seed-wipe / replay-PoW / forge-inclusion TOUS morts. 2 oddités réelles NON-payables : (1) DIFF_ZERO dead-code (bc_diff.c:82-105) accepte un bloc difficulty=0 mais il contribue 0 -> n'avance rien ; (2) OOB 1-byte depth-5 dans auth_receipt update_indexes (index[4]++ dans aux[0] même struct) = contenu, fuzz-dup. Seul audit in-scope du Ledger app = NCC 2022 (v3.0.1) ; Quarkslab 2025 = SGX (OOS) -> drift post-audit réel mais surface saine. NON-TOUCHÉ = powpeg-node + rskj (Java, externally-connected, saturés, gros lift) + middleware Python (local-only par deployment-assumption = tier bas). Track-record dit RE-SOURCE avant immortal-mode sur core Java saturé.

**⚠️ CORRECTION 2026-08-20 (playbook 5-gates sur F1) — F1 TUÉ, non-submittable.** Passage de F1 par les 5 gates : Gate-3 KILL. Le trigger exige reCAPTCHA **v3** (branche score-based = seul chemin vers le `!validCaptcha` sans-return ; sous v2, `Score==nil` -> validCaptcha=Success, et tout échec v2 porte des error-codes captés par la branche PRÉCÉDENTE qui, elle, `return`). Or `docs/Environment.md:46` (présent dans la release courante v2.5.2-rc, commit 2026-02) dit littéralement : *"Threshold ... when using recaptcha v3 (right now we're using v2)"* + le code lui-même commente `// if is v3 we also use the score`. => sous la config DOCUMENTÉE (v2) le fail-open n'est PAS atteignable par un attaquant. Match direct clause OOS "cannot be realistically triggered ... under default configurations". Le rapport affirmait v3 (depuis l'existence de CAPTCHA_THRESHOLD) et n'a JAMAIS confronté la ligne v2 = piège Gate-3 (stale vs ce que je CROIS, pas ce que le protocole DOCUMENTE). Bug réel-en-code mais résidu v3-conditionnel = hardening/best-practice OOS. NE PAS SOUMETTRE. Bilan cible : SC+Web+off-chain = 0 payable, F1 inclus. Seul chemin de valeur restant = **tier Blockchain/DLT** (rsk-powhsm 5.6.2 / powpeg-node / rskj), OUVERT 2026-08-20. Cf. [[recevability-gate-before-poc]], [[measure-before-asserting-in-reports]], [[by-design-gate-not-just-git-dup]].

**SUBMITTABLE (le seul).** F1 = **captcha fail-open** dans LPS `middlewares/captcha.go:51-55`: `if !validCaptcha {
unexpectedCaptchaError(w,..) }` sans `return` → tombe dans `next.ServeHTTP` → le handler protégé (acceptQuote)
s'exécute quand même. reCAPTCHA v3 score-bas (success:true, score<threshold, error-codes vides) → validCaptcha
=false → bypass. Captcha enabled par défaut + le code est bâti autour de v3 (`CAPTCHA_THRESHOLD`=concept v3-only).
**Phase 0 faite proprement 2026-08-12**: clone SHALLOW (git log -S faux-négatif) → dé-shallowisé → `captcha.go`
intact depuis 2024, **bug présent dans release v2.5.1 ET master** (released-code OK), 0 fix, 0 dup (PRs
#691/#697/#705 = feature trusted-account pas fix, 0 GHSA).
**SÉVÉRITÉ — corrigée 2026-08-13 (2 tours de sous-cotation rattrapés).** Primaire = **High "Taking down the
application/website"** sur l'onglet **Web&App** (celui de l'asset), **sans PoI** = $2,500 flat. Fallback écrit =
**Medium Griefing** (onglet SC, via PoI) si le triageur lit "taking down" comme downtime strict. J'avais d'abord
filé Medium-Griefing-primary via PoI = **doublement pire** (tier inférieur ET cross-tab contestable) alors qu'une
row High est posée sur mon propre onglet. LEÇON: ne jamais ouvrir sous le plafond ; le High-takedown est sur
l'onglet de l'asset sans PoI, le griefing-SC est un fallback pas une ouverture. **SC High ($10k) INATTEIGNABLE**:
F1 ne gèle/vole aucun fonds on-chain (réservation off-chain pure, fonds LP mobiles) → "Temporary freezing of
funds" = overclaim mort. Rewards/onglet: Web Crit $10k/High $2.5k/Med $1.5k ; SC Crit $100k/High $10k/Med $2.5k ;
DLT Crit $200k.
**PoC = VRAI CODE (drain-demo fait), pas repro.** 2 `_test.go` qui pilotent le vrai `NewCaptchaMiddleware` (bypass,
PASS) + la vraie compta `AvailablePeginLiquidity`/`HasPeginLiquidity` (drain `1000→0` → `NoLiquidityError`, PASS).
Le drain-demo est ce qui MÉRITE le High (prouve le déni de service réel), pas le wording. Livrables organisés dans
`Desktop/BlackBox/rootstock/` (report.md + poc/*.go + README). Tier ⇄ profondeur PoC couplés. Cf.
[[recevability-gate-before-poc]], [[report-no-self-devaluation]].

**Faux-Critical tué par mesure (garder — c'est la discipline qui a marché).** F2 pegout timing double-spend:
refundUserPegOut slashe le LP + refund user inconditionnellement après expiry sans savoir si le LP a payé le BTC;
LPS sert sans check de marge d'expiry (validateDepositedPegoutQuote) et send_pegout teste l'expiry contre le
bloc de DÉPÔT pas le temps courant → LP envoie BTC puis user reclaim RBTC dans la fenêtre de confirmations.
Mécanisme RÉEL mais **reachability-null sous défaut**: `PegoutMaxValue=0.1 rBTC` plafonne au tier 40-RSK/2-BTC
conf → marge ExpireBlocks(500)−DepositConf(40)=460 blocs >> 2 blocs BTC → LP safe. Exige operator de monter
MaxValue à ~4 rBTC sans monter ExpireBlocks = OOS operator-misconfig. Cf. [[by-design-gate-not-just-git-dup]],
[[measure-before-asserting-in-reports]].

**Nulls avec artefact.** deposit-event forge (LbcAddress LP-set), over-commit (accounting+mutex), captcha
empty-sig (validate:required), slash wrong-party (punisher=reward par design), fee-math (borné LP-config),
SignatureValidator (OZ ECDSA no-malleability no-1271), Quotes hashing (abi.encode no-collision).

**V-PI-seam MESURÉ-NULL sur les gates logiques (trace rskj fait 2026-08-12).** Mirror off-chain du LP FIDÈLE :
(1) montant = somme des outputs à l'adresse de dérivation des deux côtés (LP AmountToAddress vs bridge
getAmountSentToAddresses) ; (2) min-par-UTXO = LP `GetMinimumLockTxValue()` → précompile Bridge.java:781 retourne
EXACTEMENT `getMinimumPeginTxValue(activations)`, la valeur que `validateFlyoverPeginValue` enforce → zéro
divergence de seuil ; (3) cap-refund `shouldTransferToContract` rembourse le LP (REFUNDED_LP) côté BTC quand il a
servi, early-return correct + parité legacy (LiquidityBridgeContractV2:533) ; (4) confirmations = recoverable.
Résidu NON-COÛTÉ = divergence byte-level parser BTC (Go/node-RPC LP vs bitcoinj bridge) — Lieu-C profond, faible
proba. Pas de Critical sur ce seam.

**Surface Web&App = MESURÉ-NULL (workflow adversarial 7-surfaces + cross-checks CP5, 2026-08-13).** 2wp-api
(data-API : broadcast=relais, 0 RCE/SSRF/clés, NoSQL bloqué par LoopBack type-validation, fédération on-chain,
features GET-only donc pas de write-path) ; 2wp-app (natif : BRIDGE_CONTRACT_ADDRESS littéral hardcodé
constants.ts:286 ; flyover : destination non-substituable ; wallet/xpub/chain-id : gates tiennent ; 1 résidu XSS
= markdown-it 14.3.0 validateLink-bypass javascript-entity dans TermsContent innerHTML MAIS terms non
attacker-writable → null) ; flyover-sdk 1.9.1 (acceptQuote valide addr on-chain + sig ; depositPegout ancré au
pegoutContract deep-frozen) ; bridges-core-sdk (isValidSignature LIVE-TESTÉ contre ethers@5.7.2 = sound ;
isSecureUrl https-only) ; 2wp-api processors (throw-sites untrusted sous try/catch, status-only). **Toute la
surface off-chain+web+SC épuisée, F1 = le seul payable.** Reste NON-TOUCHÉ = le tier **Blockchain/DLT** (rskj
Java node / powpeg-node / rsk-powhsm firmware) = engagement séparé bien plus lourd ($200k Crit, vecteur
untrusted-on-chain-data→middleware→HSM). Cf. [[deployed-code-not-head]], [[report-no-self-devaluation]],
[[measure-before-asserting-in-reports]].
