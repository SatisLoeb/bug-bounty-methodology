---
name: rocketpool-target-state
description: "Rocket Pool (Immunefi $150k) — frontière de couverture des 3 audits Saturn-1, portes fermées par mesure, leads ouverts (mesuré 2026-08-10)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8d3e2c02-85ff-464f-9644-cd0e0ae5b601
  modified: 2026-08-10T15:22:59.325Z
---

Cible ouverte le 2026-08-10. Saturn 1 (v1.4) est **déployé sur mainnet** et adopté :
4918 validators megapool, 1972 en file (63k ETH demandés), 374 550 ETH total, rETH ≈ 320k.
Repo `rocketpool/` cloné, `npm install` + `npx hardhat compile` OK, suite megapool = 32 tests/36 s.

**Frontière de couverture des audits (le fait le plus coûteux à re-dériver) :**
- Sigma Prime : diff `6f07f2a..269782f`, se termine au **2025-07-11** — ne couvre donc AUCUN
  code megapool de nov/déc 2025 ni janvier 2026, malgré une publication au 5 fév 2026.
- Bailsec : commit de fixes agrégés `59f1a293` (2026-01-16).
- Cantina : ~déc 2025 + fix review. 2 criticals (pubkey réutilisée, corruption LinkedListStorage) + 43 lows.
- ⇒ **Seuls 4 commits contrats sont postérieurs à tout audit** : `75418d28` (RPIP-75),
  `afba69ae` (retire 2 require du chemin de slash), `995dd34a`, `5049193c`.
  `491f703a`/`4e7cbfb5` = hotfix dissolve (28j → 365j en bypassant le guardrail).

**Portes fermées par mesure — ne pas rouvrir sans nouveau déclencheur :**
- Réutilisation de pubkey inter-megapool : bloquée par le check `withdrawalCredentials` de `stake()`.
- Forge de preuve beacon : bornes `_isHistoricalProof` exactes (block_roots ±8192 vérifié à la main).
- Collision de clés de storage additives (`_key + timestamp` dans RocketNetworkRevenues) : grinding 2^226.
- Underflow `userCapital -= userShare` dans `_calculateCapitalDispersal` : **fermé par les paramètres
  mainnet** — courbe de bond LINÉAIRE (baseBondArray=[4,8] ETH, reducedBond=4 ⇒ bondReq(n)=4n),
  donc sur-bondage impossible et `reduceBond` est un no-op en l'état.
- `withdrawCredit` sans plafond de balance : équilibré (le dequeue transfère la même valeur du
  node balance vers le user balance). Liquidité, pas insolvabilité.

**Lead 1 — ABANDONNÉ en Phase 0 le 2026-08-10 (bug réel, impact structurellement plafonné) :**
`afba69ae` passe `_ensureMinimums=false` au slash ⇒ `totalStakedRPL` peut tomber sous `lockedRPL`
⇒ `burnRPL`/`transferRPL` revert ⇒ `claimBondChallenger` brické. Portes PASSÉES : programme actif,
actif listé (Primacy of Rules), pas de frais, **absent des 3 audits** (Bailsec énumère INV 1–9 sur
`slashRPL` sans jamais lier `lockedRPL` au stake ; `afba69ae` n'est PAS un fix d'audit), aucun commit
défensif (`git log -S "_ensureMinimums"` → 1 seul commit ; repo non-shallow vérifié, 2973 commits).
**Tué par l'impact mesuré** : `lockedRPL` ne provient QUE des bonds pDAO à valeurs fixes —
proposal 100 RPL, challenge 10 RPL, RPL = 0.000799 ETH ⇒ **≈$280 / ≈$28**. 10 propositions pDAO
depuis 2021. `finalise()` est post-veto : un burn qui revert ne débloque aucune proposition.
⇒ exposition totale = quelques centaines de $, et l'attaquant doit se faire slasher (>1 ETH) pour
nuire de $28 ⇒ clause « When Is An Impactful Attack Downgraded To Griefing? » ⇒ Low $1k max.
Réouvrir seulement si la pDAO monte `proposal.bond`/`challenge.bond` de plusieurs ordres.

**Lead 3 (divergence commentaire/code du storage layout) — FERMÉ : purement documentaire.**
Tous les sites qui lisent `nodeBond`/`userCapital` somment explicitement la file
(`getNewValidatorBondRequirement`, `dequeue`, `_calculateCapitalDispersal`) ou sont gardés
(`reduceBond` exige `nodeQueuedBond == 0`). `_calculateAndSaveCapitalRatio` exclut la file et
**a raison** (le capital en file ne produit aucun rendement) : c'est le commentaire qui est faux.

**TOMBSTONE — principal distribué comme rendement = Cantina 3.4.3, « Acknowledged », NON corrigé.**
`getPendingRewards()` traite les 32 ETH d'un validator sorti comme du rendement tant que
`notifyExit` n'est pas appelé. Mesuré : split node 5 % / voter 9 % / pDAO 0 % / rETH 86 %, ratio
0,125 ⇒ rETH reçoit 24,08 au lieu de 28 (−3,92 ETH utilisateurs), node +1,40. Risque résiduel
déporté sur le client oDAO (hors scope). **Toute variante retombe dessus** : prouver une seconde
withdrawal plus petite (après top-up d'un validator sorti) échappe bien à la parade oDAO, mais
l'opérateur ne récupère que ~17 % de ce qu'il convertit en rendement et encaisse la dette ⇒
toujours perdant. Ne pas re-creuser cette veine.

**SSZ / système de preuves — FERMÉ (branche « bypass du fix » épuisée).**
Fix Cantina 3.2.4 = `303453a4` (2025-09-12) : `require(_gindex < 2**_length)` dans `from`,
`require(_index < 2**_log2Length)` dans `intoList`/`intoVector`, callers en uint40/uint16,
et `validators` passé de `intoVector` à `intoList`. Vérifié complet : bits hauts bloqués,
list/vector conformes à Electra (validators 41, historical_summaries 25, block_roots 13,
withdrawals 5), gindices BeaconState corrects à profondeur 6 (37 champs), pas de malléabilité
de témoins (`length(path) == witnesses.length` + boucle consommant exactement pathLength).
Seul défaut latent trouvé, **non exploitable** : `concat` fait `require(lenA + lenB <= 248)` en
arithmétique **uint8 sous `unchecked`** ⇒ wrap possible à >255, mais le chemin le plus long
atteignable est de **65 bits** (verifyWithdrawal historique), 191 de marge. Informatif, non soumettable.

**RocketNetworkVoting — FERMÉ sur les deux angles (2026-08-10).**
(a) *Bond en file → pouvoir de vote* (variante distincte de Bailsec, dont le bug `fundsReturned`
enfermé dans `if (userShare > 0)` de `dissolveValidator` est corrigé — appel désormais inconditionnel,
vérifié). Chaîne réelle : `requestFunds` pousse `megapool.eth.provided.node.amount` dès l'enfilement,
`dequeue` rend 100 % en crédit sans verrou, et `getVotingPower` lit cette clé. Mesuré :
`node.voting.power.stake.maximum` = 1.5e18, RPL = 0.000799 ETH ⇒ 4 ETH déclampent 7 509 RPL.
**Tué : aucune réduction de coût** — même déclampage par ETH que du staking honnête ; pas de
multiplicateur (crédit plafonné par `getNodeUsableCredit` ≤ solde du pool ; `_insert` écrase
intra-bloc) ; l'amplification √N est du Sybil (hors scope) et marche aussi sans ce mécanisme.
Reste seulement un avantage de durée d'immobilisation ⇒ puce « basic economic and governance
attacks », et le tier High exige « with cost impact ».
(b) *Underflow `totalETHStaked - borrowedETH`* (RocketNetworkVoting.sol:67). Statique : plus aucun
site d'incrément de `eth.matched.node.amount` (création de minipool legacy supprimée), 2 décréments
seulement (`_finalise:390`, `destroyMinipool:487`) chacun apparié à un décrément de
`minipools.active.count` ; `reduceBondAmount` revert désormais (`RocketMinipoolBondReducer:34`).
**Mesuré : `getVotingPower` appelé sur les 4151 nœuds enregistrés → 0 revert.** Marge structurelle
≥ 8 ETH par minipool actif (bond minimum 8). Enjeu si ça cassait : `RocketDAOProtocolVerifier:497`
appelle `getVotingPower` dans la boucle de vérification des feuilles ⇒ une feuille qui revert bloque
le fraud-proof. Ne rouvrir que si un site d'incrément d'`eth.matched` réapparaît.

**Leads restants (non explorés) :**
1. L'underflow de dispersion redevient atteignable si la pDAO baisse `baseBondArray[0]` ou
   `reduced.bond` (la suite de tests fabrique déjà « With overbonded megapool » via reduced.bond 4→2).
   Déclencheur à surveiller : tout RPIP modifiant la courbe de bond.
3. Le commentaire de `RocketMegapoolStorageLayout` affirme que `nodeBond`/`userCapital` incluent la
   valeur en file — le code dit le contraire. Divergence modèle-mental/code non encore exploitée.

Voir [[recevability-gate-before-poc]], [[deployed-code-not-head]], [[measure-before-asserting-in-reports]].
