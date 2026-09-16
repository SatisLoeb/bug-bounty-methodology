---
name: starkgate-target-state
description: "StarkGate (Immunefi Starknet, Critical seul, 10% des fonds jusqu'à $250k) — quelle version tourne où sur mainnet, et pourquoi les gros pools sont HORS actif (mesuré 2026-08-10)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8d3e2c02-85ff-464f-9644-cd0e0ae5b601
  modified: 2026-08-10T18:22:54.259Z
---

Sous-cible du programme Starknet (voir [[starknet-target-state]] pour le programme : Primacy of Rules,
pas de coffre, KYC+OFAC, PoC code obligatoire, **tests interdits sur mainnet/testnet → fork local**).
**Catégorie Smart Contract : Critical UNIQUEMENT** (vol direct / gel permanent / insolvabilité),
récompense = **10 % des fonds directement affectés**, min $15k, max $250k.

**Actifs listés (URL exactes) :** `starknet-io/starkgate-contracts` branche **`cairo-1`** →
`src/solidity` et `src/cairo`. Clone local : `~/Desktop/BlackBox/starkgate`.
`src/solidity` = **1810 lignes**, dont ~1300 réelles (les `*Tester.sol` + `test_contracts/` sont OOS
explicitement : « All test files and helpers included in the asset directory »).
Fichiers réels : StarknetTokenBridge 613, LegacyBridge 187, StarkgateRegistry 142, StarkgateManager 141,
WithdrawalLimit 88, StarkgateUpgradeAssistExternalInitializer 84, Felt252 83, StarknetTokenStorage 69,
ConfigureSingleBridgeEIC 67, StarknetEthBridge 36, Fees 29, StarkgateConstants 19.
**`src/solidity` est IDENTIQUE entre `cairo-1` et `SN-v0.14.2`** (le diff n'est que la suppression de
`src/cairo/` + `src/openzeppelin/`) ⇒ la branche « périmée » ne l'est PAS pour l'actif Solidity.
`src/cairo` en revanche n'existe que sur `cairo-1` (2025-03-03).

**GATE 7 — MAPPING VERSION↔DÉPLOIEMENT (le fait coûteux à re-dériver).**
Discriminant : `identify()`. Correspondance tag→version mesurée :
v2.0.1 (2024-02-06)=2.0_4 · v2.0.2/v2.1.0=2.0_5 · **v2.1.1 (2025-03-03)=cairo-1=2.0_6** · v3.0.0=2.0_6.
Mainnet au 2026-08-10 :
| contrat | addr | identify | TVL |
|---|---|---|---|
| ETH bridge | 0xae0Ee0A63A2cE6BaeEFFE56e7714FB4EFE48D419 | EthBridge_**2.0_4** | **18 136 ETH** |
| USDC | 0xF6080D9fbEEbcd44D89aFfBFd42F098cbFf92816 | ERC20Bridge_**2.0_5** | 4,90 M |
| USDT | 0xbb3400F107804DFB482565FF1Ec8D8aE66747605 | ERC20Bridge_**2.0_5** | 3,67 M |
| wstETH | 0xBf67F59D2988A46FBFF7ed79A621778a3Cd3985B | ERC20Bridge_**2.0_5** | 2 102 |
| DAI | 0xCA14057f85F2662257fd2637FdEc558626bCe554 | TokenBridge_**2.0_4** | 199 k |
| UNI | 0xf76e6bF9e2df09D0f854F045A3B724074dA1236B | ERC20Bridge_2.0_5 | 3 375 |
| rETH | 0xcf58536D6Fab5E59B654228a5a4ed89b13A876C2 | ERC20Bridge_2.0_5 | 48 |
| **multi-bridge (EKUBO…)** | **0xF5b6Ee2CAEb6769659f6C091D209DfdCaF3F69Eb** | **TokenBridge_2.0_6** ✅ | 9,27 M EKUBO |
| **Registry** | **0x1268cc171c54F2000402DfF20E93E60DF4c96812** | **Registry_2.0_6** ✅ | — |
| WBTC | 0x283751A21eafBFcD52297820D27C1f1963D9b5b4 | TokenBridge_**2.0_6-halt** (variante absente du repo) | 0 |
Starknet Core (messaging) : 0xc662c410C0ECf747543f5bA90660f6ABeBD9C8c4 = `Starknet_2026_11`.
Le Registry est la source de vérité : `getBridge(address token)`. LORDS → `0x…01` = `BLOCKED_TOKEN`.

**⇒ CONSÉQUENCE DE RECEVABILITÉ (à ne jamais oublier ici) :** le code en scope (2.0_6) est déployé
UNIQUEMENT sur le multi-bridge, le Registry et le WBTC-halt. **ETH/USDC/USDT/wstETH/DAI tournent sur
2.0_4/2.0_5, qui NE SONT PAS l'actif listé.** Un bug qui n'existe que dans l'ancien code déployé est
hors scope (Primacy of Rules) ; un bug du code 2.0_6 ne « touche » que le TVL du multi-bridge ⇒ c'est
lui qui fixe les 10 %. Vérifier la valeur $ d'EKUBO avant d'estimer un montant.

**`src/cairo` (actif L2) — NON DÉPLOYÉ, donc économiquement mort.** Discriminant : le pont L2
`0x0616757a151c21f9be8775098d591c2807316d992bbc3bb1a5c1821630589256` (= `getL2Bridge()` du multi-bridge),
class hash `0x65d7265ac12b330bc42737281a9b73af17bd904d477779a014874d118c4ddbf`, répond
`get_identity()='STARKGATE'` ✓ mais `get_version()=0x2` (l'ENTIER 2). Or le code en scope déclare
`CONTRACT_VERSION: felt252 = '2.0.1'` (=0x322e302e31). Historique : v2.0.1/v2.0.2/v2.1.0 = `2`,
**v2.1.1=cairo-1 = '2.0.1'**, v3.0.0/SN-v0.14.2 n'ont plus `src/cairo` du tout.
⇒ le mainnet L2 tourne du pré-cairo-1 ⇒ un bug dans `src/cairo` affecte 0 fonds ⇒ Critical = 10 %×0.
RPC Starknet qui marchent : `https://rpc.starknet.lava.build`, `https://starknet.drpc.org`,
`https://api.cartridge.gg/x/starknet/mainnet`, alchemy `.../v0_8/demo`. (Blast est mort.)
Sélecteur = `keccak256(nom) & (2**250-1)` (module python `sha3` dispo).

**PÉRIMÈTRE ÉCONOMIQUE RÉEL de l'actif Solidity (ce qui plafonne toute récompense) :**
seul le multi-bridge `0xF5b6Ee2…` (2.0_6) détient des fonds en scope :
**EKUBO 9 265 611 / 10 000 000 = 92,66 % de la supply totale** (token du DEX principal de Starknet)
· ZEND 44,37 M/100 M (zkLend défunt, ~0) · SHIB/PEPE poussière · CRV/LDO/SNX enrôlés à 0.
⇒ un Critical sur `StarknetTokenBridge.sol` 2.0_6 atteint confortablement le plafond $250k.
Les gros pools (ETH 18 136, USDC 4,9 M, USDT 3,67 M, wstETH) sont sur 2.0_4/2.0_5 = **hors actif**.

**Lecture intégrale de `src/solidity` faite (2026-08-10), rien de converti :**
- CEI respecté partout : `consumeMessage`/`cancelL1ToL2Message` (effet) AVANT `transferOutFunds`
  (interaction), dans `withdraw`, `depositReclaim`, `depositWithMessageReclaim`.
- `Felt252.safeToFelt` correct sur chaîne arbitraire : `length ≤ 31` ⇒ décalage ≥ 8 bits ⇒ résultat
  < 2²⁴⁸ < FIELD_PRIME ; chaîne vide ⇒ `SHR 256` = 0. Pas d'injection via `name()`/`symbol()`.
- `WithdrawalLimit` : le motif OFFSET=1 (0 = non initialisé) est correct ; quota journalier
  (`block.timestamp/86400`) donc jamais un gel permanent ; `disableWithdrawalLimit` existe.
- `enrollTokenBridge` est **permissionless par design** (n'importe qui enrôle n'importe quel token) et
  appelle `name()/symbol()/decimals()` sur un contrat ATTAQUANT. Réentrance immédiate bloquée :
  ré-entrer `enrollTokenBridge` → `enlistToken` revert TOKEN_ALREADY_ENROLLED ; ré-entrer `deposit` →
  statut encore `Unknown` → `onlyServicingToken` revert ; `checkDeploymentStatus` → `skipUnlessPending`.
- Le message de déploiement ne peut être annulé par aucune fonction du pont (aucune n'utilise
  `HANDLE_TOKEN_DEPLOYMENT_SELECTOR`) ⇒ `l1ToL2Messages(msgHash)==0` ⟺ vraiment consommé sur L2.
- **`Transfers.sol` (qui déplace réellement les ERC20) n'est dans AUCUN dépôt public** — absent de
  starkgate ET de `cairo-lang/src/starkware/solidity/libraries/` (qui n'a qu'Addresses + NamedStorage).
  Question fee-on-transfer non tranchable depuis les actifs listés.
- Restent non lus : les 2 EIC (`ConfigureSingleBridgeEIC` 67 l, `StarkgateUpgradeAssistExternalInitializer`
  84 l) = code d'upgrade, privilégié ⇒ largement OOS.

**SCÉNARIO « TOKEN MALICIEUX ENRÔLÉ », MULTI-TRANSACTIONS — CREUSÉ ET FERMÉ (2026-08-10).**
Prémisse : `enrollTokenBridge` est permissionless ⇒ l'attaquant enrôle un contrat qu'il contrôle
entièrement (name/symbol/decimals/balanceOf/transfer/transferFrom, et STATEFUL entre tx) dans le
multi-bridge qui détient 93 % de l'EKUBO. Les 9 voies tracées, toutes closes :
1. Réentrance immédiate depuis `name()/symbol()` : `enrollTokenBridge` re-entrant → `enlistToken`
   revert TOKEN_ALREADY_ENROLLED ; `deposit` re-entrant → statut encore `Unknown` ⇒ `onlyServicingToken`
   revert ; `checkDeploymentStatus` → `skipUnlessPending`.
2. Réentrance depuis `transferIn`/`transferOut` : **CEI respecté partout** — `consumeMessageFromL2` /
   `cancelL1ToL2Message` et la consommation de quota sont AVANT `transferOutFunds`.
3. Corruption d'état inter-tokens : impossible, tout est clé par token (`tokenSettings[token]`,
   `intradayQuota[keccak(token,day)]`, `tokenToBridge[token]`, `tokenToWithdrawalBridges[token]`).
4. **Confusion de type de message (déploiement ↔ dépôt)** — la piste la plus sérieuse : l'attaquant
   contrôle le payload de déploiement `[token, name, symbol, decimals]` via son contrat. TUÉE par
   `l1ToL2MsgHash = keccak(abi.encodePacked(from, to, nonce, selector, payload.length, payload))` —
   **sélecteur ET longueur inclus**, tous champs en 32 octets fixes ⇒ pas d'ambiguïté de packing.
5. `balanceOf` malicieux dans `acceptDeposit`/`calculateIntradayAllowance` : renvoyer ~max fait
   revert (overflow 0.8) ⇒ auto-DoS seulement ; et `withdrawalLimitApplied` est `onlySecurityAgent`.
6. `Felt252` sur name/symbol arbitraires : toujours un felt valide (cf. plus haut).
7. Cycle enroll → 5 j → expire → `delete tokenSettings` + `selfRemove` → ré-enroll : répétable mais
   sans résidu (`containsAddress` empêche les doublons dans withdrawalBridges) ; les dépôts faits en
   `Pending` restent récupérables (message L1→L2 non consommé ⇒ cancel+reclaim marche).
8. Horodatage de cancellation jamais nettoyé (`l1ToL2MessageCancellations[msgHash]` reste après
   `cancelL1ToL2Message`) ⇒ **inatteignable** : le nonce est un compteur global monotone
   (`sendMessageToL2` : `nonce = l1ToL2MessageNonce(); setUint(nonce+1)`), le hash ne réapparaît jamais.
9. Front-run de l'enrôlement d'un token légitime avec `MIN_FEE` (10¹² wei) : bloque 5 jours et les
   dépôts en Pending sont récupérables ⇒ griefing/gel temporaire ⇒ **pas Critical**, et cette
   catégorie est Critical-only ⇒ non soumettable.
⇒ Isolation d'état par token + liaison du hash (sender+selector+length+nonce) rendent les attaques
inter-tokens et inter-types structurellement impossibles. **Ne pas relancer cette veine.**

**Constantes utiles :** UINT256_PART_SIZE=2¹²⁸ · MAX_PENDING_DURATION=5 days · BLOCKED_TOKEN=0x1 ·
ETH=address(0x455448) ('ETH' en felt) · MIN_FEE=10¹² (mainnet) · MAX_FEE=10¹⁶ ·
TRANSFER_FROM_STARKNET=0.

**Observations de lecture (non encore converties) :**
- `LegacyBridge.deposit(uint256,uint256)` (ABI legacy 2 args) **n'a PAS `onlyServicingToken`**, contrairement
  à `StarknetTokenBridge.deposit(address,uint256,uint256)`. Dépôt possible sur token Deactivated.
- `StarknetEthBridge` ignore le paramètre `token` dans `acceptDeposit` ET `transferOutFunds`.
- `LegacyBridge.consumeMessage` : try/catch qui accepte l'ancien format à 4 champs
  `[0, recipient, low, high]` (SANS token), rattrapé par `require(bridgedToken()==token)` APRÈS
  consommation (OK car revert global). `catch Error(string)` ne rattrape ni Panic ni custom error.
- `checkDeploymentStatus` est **public**, et sur expiration fait `delete tokenSettings()[token]` +
  `registry.selfRemove(token)` — remet le token en Unknown alors que des dépôts « Pending » ont pu
  être acceptés (récupérables via cancel/reclaim car le message L1→L2 reste non consommé).
- `acceptDeposit` (ERC20) crédite `amount` sur L2 mais transfère via `Transfers.transferIn` — vérifier
  le comportement fee-on-transfer (lib `starkware/solidity/libraries/Transfers.sol`, HORS `src/solidity`).

Voir [[recevability-gate-before-poc]], [[deployed-code-not-head]], [[measure-before-asserting-in-reports]].
