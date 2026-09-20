---
name: aera-transfer-blacklist-hook-arbitrum-immunefi
description: "Aera (Gauntlet) Immunefi $500K — TransferBlacklistHook Arbitrum 0xCe7E…A62C (ajouté au scope 18 Sep 2026). Pré-lecture Phase -1/0 : GO pour la lecture du source déployé sur machine-2 ; source NON lu ici (egress CCR) ; AUCUN finding ; classe réaliste ≤ High freeze, pas le plafond $500K."
metadata:
  node_type: memory
  type: project
  modified: 2026-09-20
---

# Aera — TransferBlacklistHook (Arbitrum) — dossier de pré-lecture

**Cible unique demandée** : `0xCe7Ea99545A6d0744a52Da9017729451Ec92A62C` (Arbitrum One), ligne de scope Immunefi
« Arbitrum – TransferBlacklistHook — 18 September 2026 ».

## 0. Statut honnête — ce que cette session a PU et N'A PAS PU faire

**Pas d'audit du code déployé.** L'environnement Claude Code remote bloque (403 policy) tout ce qui donne accès au
source vérifié et à l'état on-chain : `api.etherscan.io`, `arbiscan.io`, `api.arbiscan.io`, Blockscout, Routescan,
Sourcify (3 hôtes), OKLink, Dedaub, vscode.blockscan, deth.net, **13 RPC Arbitrum publics**, `immunefi.com`,
`cantina.xyz`, `docs.aera.finance`, infsec.io, web.archive.org, r.jina.ai, grep.app, sourcegraph, 4byte, openchain.
Passent : `github.com` (clone + pages), `raw.githubusercontent.com`, `pypi.org`.
Le source du hook n'existe dans **aucun** snapshot public d'Aera (`aera-contracts-public` main `93ce6be` 2026-09-11
+ les 6 refs de PR vérifiées une à une) — il vit dans le repo privé `aera-contracts-v3`
(`src/periphery/hooks/…`, cf. Spearbit 2025). Donc :

- **V1 mécanisme / V3 deployed-not-head : NON FAITS.** Tout ce qui suit est un plan de lecture, pas un verdict.
- **V2 on-chain : NON FAIT.** Aucune lecture live (owner, flag transférabilité, blacklist, câblage vault→hook).
- **Phase 0 Immunefi : page programme NON lue en source primaire** (bloquée). Économie reprise d'une source secondaire
  datée (Yearn risk-score, 31 août 2026, cf. §1) — à re-vérifier sur `/information/` + `/scope/`.
- **AUCUN finding. Aucun tier réclamé.** Le livrable = (a) ce dossier, (b) `tools/aera-hook-anchor.sh` à lancer
  depuis une machine à réseau ouvert, (c) la liste d'hypothèses H1–H8 avec conditions de confirmation/kill précises.

## 1. Cible, programme, économie (Phase 0 — partiel, source secondaire)

| Champ | Valeur | Source / statut |
|---|---|---|
| Contrat | TransferBlacklistHook `0xCe7E…A62C`, Arbitrum | Scope Immunefi (ligne fournie par l'opérateur) |
| Date d'ajout au scope | 18 Sep 2026 (2 jours avant ce dossier) → **fraîcheur maximale** | idem |
| Programme | Aera (Gauntlet), Immunefi, max **$500K** | Yearn risk-score 2026-08-31 + snippet WebSearch |
| Tiers | Critical SC = **10 % des fonds directement affectés, min $20K, max $500K** ; High **$10K** ; Medium **$2K** ; USDC | Yearn 2026-08-31 — **à re-vérifier** |
| Régime | **Primacy of Rules** ; KYC + PoC obligatoires | Yearn 2026-08-31 — **à re-vérifier** |
| Assets | 5 assets sur Ethereum/Arbitrum/Base/Polygon/Optimism au 31/08 ; le hook Arbitrum s'y ajoute le 18/09 | idem |
| Fonds « directement affectés » via ce hook | les vaults câblés dessus. Candidat connu : gtUSDa Arbitrum vault `0x000000001DC8bd45d7E7829fb1c969cbe4D0D1eC`, NAV **$5.03M** / 4 651 243 units (31/08/2026), cap $100M | Yearn (on-chain daté) ; **câblage vault→0xCe7E NON vérifié** |

Conséquences immédiates :
- **Primacy of Rules** ⇒ l'impact doit figurer VERBATIM dans « Impacts in Scope ». Un « blacklist/sanctions bypass »
  n'est en général PAS un impact listé ⇒ un bypass de screening, même prouvé, est probablement non payable sauf s'il se
  reformule en impact listé (freeze / DoS / insolvency). Tirer la liste complète AVANT de dépenser (règle Phase 0).
- **Plafond réel** : un hook `view` ne déplace pas de fonds. Les classes atteignables = freeze/DoS. Sur ~$5M,
  10 % = $503K ⇒ le $500K n'est en jeu QUE si un **permanent freeze** listé Critical est déclenchable par un acteur
  non privilégié. Sinon : temporary freeze = High $10K, griefing = Medium $2K. **Ne pas se raconter le plafond.**
- Vault balance / known-issues / exclusions chirurgicales : non lus (bloqués). Gate 0 du skill `immunefi-submit`
  à exécuter sur machine-2.

## 2. Établi en source primaire (snapshot public `aera-contracts-public` HEAD `93ce6be`, 2026-09-11)

### 2.1 L'interface que le déployé DOIT implémenter — `v3/src/core/interfaces/IBeforeTransferHook.sol` (pragma 0.8.34)
- `setIsVaultUnitsTransferable(address vault, bool)` — erreur `Aera__NotVaultOwner()` ⇒ gardé par le **owner du vault**
  (Timelock 1 jour sur mainnet), pas par le owner du hook.
- `beforeTransfer(address from, address to, address transferAgent) external view` — **view ⇒ STATICCALL** depuis le
  vault : le hook ne peut écrire aucun état pendant un transfert (classe reentrancy morte par construction).
- Erreur `Aera__VaultUnitsNotTransferable(address vault)`, event `VaultUnitTransferableSet(vault, bool)`.
- Aucune erreur/event blacklist dans cette interface ⇒ l'interface spécifique (`ITransferBlacklistHook` ?) est privée.

### 2.2 Le contexte d'appel — `v3/src/core/MultiDepositorVault.sol`
- `_update()` L114-131 : le hook est appelé sur **CHAQUE** `_update` — mint (`from == 0`), burn (`to == 0`) et
  transfert — avec `transferAgent = provisioner` (L118), AVANT le check `areUserUnitsLocked(from)` (L122-127).
- Hook optionnel : `if (address(hook) != address(0))` (L116) — issu de Spearbit 5.5.30 / PR 338.
- `setBeforeTransferHook(hook)` L100 `requiresAuth` ⇒ **chemin de récupération** de tout freeze induit par le hook =
  le owner du vault le remplace/le met à 0 (mainnet : Timelock 1 jour ; Arbitrum : à lire).
- `enter/exit` `onlyProvisioner` (égalité d'adresse directe).

### 2.3 Matrice des mouvements d'units côté Provisioner — ce que le hook VOIT (`v3/src/core/ProvisionerV2.sol`)

| Chemin | `from` | `to` | Remarque |
|---|---|---|---|
| `requestRedeem` L832 `safeTransferFrom(user → provisioner)` | user | provisioner | escrow ; **seul moment où le détenteur est screené côté `from`** |
| solve redeem vault L1228 / L1284 `exit(provisioner, …)` | provisioner (burn) | 0 | le détenteur d'origine n'est **jamais re-screené** |
| tokens de sortie L1231 / L1286 `token.safeTransfer(request.receiver)` | — | — | USDC part vers `request.receiver` **arbitraire** (validé seulement ≠ 0, L1525) — hook non impliqué |
| solve deposit vault L1104 / L1161 `enter(…, request.receiver)` | 0 (mint) | receiver | receiver screené SEULEMENT si le chemin mint teste `to` |
| refund redeem : `_transferWithFallback` L1390-1395 | provisioner | receiver → fallback `request.user` | `trySafeTransfer` : revert du hook sur receiver ⇒ fallback user ; **user aussi bloqué ⇒ refund revert ⇒ units coincés en escrow** (design sanctions) |
| `cancelRequest` redeem, fee burn L372-373 `exit(provisioner, token, 0, fee, provisioner)` | provisioner | 0 | |
| `solveRequestsDirect` deposit L1325 `safeTransferFrom(solver → receiver)` | solver | receiver | aucun des deux n'est l'agent ⇒ **revert si non-transférable** (le solve direct des deposits est impossible sur un vault non-transférable — conséquence de design) |
| `solveRequestsDirect` redeem L1333 `safeTransfer(provisioner → solver)` | provisioner | solver | chemin agent |
| `refundDeposit` L253-255 `exit(receiver, …)` puis fallback `exit(receiver, …, sender)` | receiver (burn) | 0 | privilégié (`requiresAuth`) |
| sync redeem `_syncRedeem` L1045 `exit(msg.sender, …)` | user (burn) | 0 | |
| `refundRequest` L305 | (idem refund) | | deadline passée OU autorisé |

`_validateRequest` L1523-1535 ne connaît pas le hook : un `receiver` blacklisté/sanctionné peut être posé dans une
request (revert seulement au solve ⇒ le solver privilégié filtre off-chain ; refund après deadline via fallback).

### 2.4 Corpus d'audit — ce qui a été vu du hook, et quand
- **Spearbit, 5 juin 2025** (repo `aera-contracts-v3`, commit `a8300f08`, 67 issues) : les hooks existaient comme
  `TransferWhitelistHooks` / `TransferBlacklistHooks` **retournant un bool**, avec l'early-return
  `if (from == address(0) || to == address(0)) return true;`. Finding 5.4.1 (gas) : Aera « Fixed in PR 201 »,
  Spearbit : *« The check is relevant now as it overrides the `_update` function »* ⇒ **l'exemption zéro-adresse est
  REQUISE** dans le design actuel (mint/burn passent par le hook). Autres touches : 5.5.16 naming (acknowledged),
  5.5.30 hook optionnel (PR 338). **Aucun finding de sécurité sur la logique du hook.** Adjacent utile : 5.2.12
  (Medium — fragilité du lock d'units / refund timeouts), 5.5.28 (refund privilégié sans consentement).
- **Cantina competition, 18-25 juin 2025** (commit `4c24979c`, $15K, 397 soumissions, 1H/3M/2L publiés) :
  **zéro mention** des transfer hooks.
- **Cantina managed review, 15 avril 2026** (commit `fda89451`) : scope = Provisioner / PriceAndFeeCalculator /
  Types / MorphoV2 adapter — **hooks HORS scope**.
- ⇒ L'interface a été **réécrite après la revue Spearbit** (bool → revert custom errors, ajout de `transferAgent`),
  et le déployé du 18/09/2026 est à une **nouvelle adresse**. Aucun rapport public ne couvre cette version.
  Au sens du playbook : FIX/rewrite-commit = cible, dup-risk public faible sur cette version.

### 2.5 Census tiers daté (Yearn `risk-score`, rapport gtUSDa, vérifié on-chain par eux au 31/08/2026 — mainnet)
- Hook mainnet `0x1703a1B0fee4D507CA8a743f04E168BCd4862d24` : `isVaultUnitTransferable(gtUSDa) == false` ; 327 events
  `Transfer` depuis le déploiement, tous mint/burn/Provisioner ; **« additionally blocks addresses flagged by a
  Chainalysis-interface sanctions oracle `0x40C57923924B5c5c5455c48D93317139ADDaC8fb` »** ⇒ le hook fait un appel
  externe à un contrat qu'Aera ne possède pas, dans un `view` obligatoire sur chaque mint/burn/transfert.
- `setIsVaultUnitsTransferable` = owner du vault = TimelockController 1 jour (Safe Gauntlet 3/9 proposer+executor).
- Gouvernance Aera (Safe 3/7 → Timelock FeeCalc 1 jour) possède PriceAndFeeCalculator, RolesAuthority(FeeCalc),
  Whitelist. **Le owner du HOOK n'est pas documenté** — à lire.
- Arbitrum : vault gtUSDa `0x000000001DC8…D1eC` ($5.03M). L'adresse du hook Arbitrum **avant** le 18/09 est inconnue
  ⇒ `0xCe7E…` est soit une nouvelle version câblée sur gtUSDa, soit le hook d'un NOUVEAU vault. Lire
  `beforeTransferHook()` sur `0x0000…D1eC` en premier.

## 3. Phase -1 — score de surface (formule du playbook)

- **Seam-density : 3 frontières** — périphérie↔core (le hook s'exécute DANS `_update` du core, sur chaque mint/burn/
  transfert) ; deployed-config↔code (flag par vault + entrées de blacklist + adresse d'oracle) ; **dépendance externe**
  (Chainalysis) dans un chemin de liveness obligatoire.
- **Tell « guarded-wrong-variable »** (le meilleur prédicteur du playbook §4) : l'exemption `transferAgent` est une
  garde sur UNE variable (transférabilité) ; sa sœur (screen sanctions/blacklist) est-elle exemptée par la MÊME
  branche ? C'est H2, et c'est exactement le motif ENS/Granite/RSK.
- **Fraîcheur** : ajouté au scope il y a 2 jours, nouvelle adresse, version non couverte publiquement.
- **Solo-accessible** : oui (petit contrat, 1-2 h de lecture une fois le source en main).
- **Dup-risk** : faible sur cette version ; MAIS Gate 4 exige la liste known-issues Immunefi (non lue).
- **Économie** : plafond réaliste ≤ High ($10K) sauf permanent-freeze non-privilégié listé Critical.

**Verdict Phase -1 : GO pour la lecture du source déployé sur machine-2, budget 2 h, puis NO-GO ferme si H1–H5
sont tuées.** Ne pas lancer de fan-out avant d'avoir le source ET la liste d'impacts (règle « apparatus is packaging »).

## 4. Plan de lecture du source déployé — hypothèses ordonnées par EV, avec confirmation/kill

**H2 — Bypass du screen par le chemin escrow (guarded-wrong-variable).**
Confirmé si, dans `beforeTransfer`, la branche `from == transferAgent || to == transferAgent` (ou `from == 0 ||
to == 0`) **retourne avant** le test blacklist/sanctions. Alors : un détenteur sanctionné `requestRedeem` (`from` =
lui, `to` = provisioner ⇒ exempté), un solver règle (`exit(provisioner…)`, burn exempté), l'USDC part vers
`request.receiver` arbitraire (§2.3) — la contrainte n'est consultée à aucune étape. Symétrique côté entrée si le
mint (`from == 0`) est exempté : `requestDeposit(receiver = sanctionné)` ⇒ mint vers un sanctionné.
Kill : le test blacklist/sanctions s'applique inconditionnellement à `from` ET `to` (hors adresse zéro), et seule la
garde de transférabilité utilise `transferAgent`.
Variante résiduelle même si tué : désignation APRÈS escrow ⇒ la request en attente se règle vers un receiver
arbitraire (fenêtre ≤ deadline ≤ `MAX_SECONDS_TO_DEADLINE`) ; `refundRequest` privilégié possible. Design gap, valeur
bornée.
**Tiering (si confirmé)** : cadre compliance-exposure de [[feedback-compliance-control-bypass-severity-frame]] —
plancher fund-loss = Low/Medium, plafond argumenté par la posture réglementaire ; **Gauntlet n'est pas un émetteur
licencié type Circle ⇒ plafond faible** ; sous Primacy of Rules, probablement **non listé ⇒ LATENT/défensif** sauf
si « Impacts in Scope » contient un item de type bypass de restriction de transfert. Décider APRÈS lecture de la liste.

**H1 — Dépendance de liveness sur l'oracle de sanctions (tiers, non possédé).**
Confirmé si `beforeTransfer` appelle `isSanctioned(from/to)` sans `try/catch` : tout revert/brick/pause de
`0x40C5…C8fb` (upgradeable par Chainalysis) ⇒ **chaque mint/burn/transfert du vault revert** ⇒ deposits/redeems gelés
(gtUSDa Arbitrum ~$5M) jusqu'à ce que le owner du vault change le hook (`setBeforeTransferHook`, timelock 1 jour).
Acteur = tiers privilégié ⇒ Gate 1 échoue pour paiement ; exclusion Immunefi standard « third-party oracle » probable.
⇒ **LATENT / note défensive**, pas une soumission. Vérifier aussi que `0x40C5…` **a du code sur Arbitrum** (un
appel high-level vers une adresse vide revert ⇒ vault mort dès le 1er mint — un vault vivant tue cette sous-branche).

**H5 — Régression de l'exemption zéro-adresse (burn avec `from` non-agent).**
Les chemins `_syncRedeem` L1045 (`from` = user, `to` = 0), `refundDeposit` L253 (`from` = receiver, `to` = 0) et le
fee-burn L373 passent par le hook. Si la nouvelle version teste la transférabilité sur `to == 0` sans exemption ⇒ sync
redeem / refundDeposit DoS sur tout vault non-transférable. Kill : early-return `from == 0 || to == 0` présent (ce
que Spearbit a validé sur PR 201). Impact max Medium ; probablement couvert par tests. 15 min.

**H3 — Auth de `setIsVaultUnitsTransferable`.** Owner-only (`Auth(vault).owner()`) vs `requiresVaultAuth(vault)`
(owner OU `authority.canCall`) : si autorité, lire la RolesAuthority Arbitrum (`setPublicCapability`, rôles). Le
paramètre `vault` est fourni par l'appelant : un attaquant passe son propre contrat (dont `owner()` = lui) ⇒
n'affecte que SA clé ; bug seulement si un flag global existe. Kill : mapping `vault ⇒ bool` pur.

**H4 — Surface admin blacklist.** Qui ajoute/retire (owner du hook `requiresAuth` ? autorité ?), liste globale ou par
vault, `Auth2Step.pendingOwner` non nul ?, qui est owner (EOA ? Safe ? Timelock ?). Centralisation = census, pas
finding. Signal de monitoring si owner = EOA.

**H8 — Delta code vs version revue.** Diff de l'ordre des tests dans `beforeTransfer` et de l'early-return contre la
description Spearbit 5.4.1 ; tout changement de forme « fix » = cible prioritaire.

**Classes mortes sans lire (recall ledger)** : reentrancy (STATICCALL), mint non adossé (`onlyProvisioner`, pas le
hook), arithmétique (aucune), upgradeabilité (Auth2Step attendu, pas de proxy — le script vérifie les slots 1967),
H7 (provisioner/vault lui-même blacklisté ou sanctionné = acteur privilégié/tiers ⇒ non payable ; signal de monitoring).

## 5. Protocole machine-2 (réseau ouvert) — dans l'ordre, ~2 h

1. `export ETHERSCAN_API_KEY=… ARB_RPC_URL=…` puis
   `tools/aera-hook-anchor.sh 0xCe7Ea99545A6d0744a52Da9017729451Ec92A62C ./anchor/aera-hook`
   → source vérifié sur disque + greps de seam (ordre des tests de `beforeTransfer`, `transferAgent`, `address(0)`,
   `isSanctioned`, `try`, auth) + lectures live (owner/pendingOwner/authority, câblage `beforeTransferHook()` du vault
   gtUSDa Arbitrum, `isVaultUnitTransferable`, code de l'oracle sur Arbitrum, census des events du hook).
2. Immunefi `/information/` + `/scope/` : **copier VERBATIM « Impacts in Scope »**, known issues, exclusions, vault
   balance, KYC, PoC — Gate 0 du skill `immunefi-submit`. Confirmer que l'asset est bien « TransferBlacklistHook »
   à cette adresse et pas un autre contrat.
3. Lire `beforeTransfer` ligne à ligne contre H2 → H1 → H5 → H3/H4 → H8. Noter la condition qui tue chaque H.
4. Si H2 confirmée : ne PAS rédiger avant d'avoir la liste d'impacts ; chercher la reformulation en impact listé ;
   sinon classer LATENT et passer.
5. Si tout est tué : NO-GO écrit ici (une ligne par H), pas de fan-out.

## 6. Verdict au 2026-09-20

**NOT READY — aucun finding, source non lu.** Surface fraîche et seam-dense (GO lecture), mais la classe payable
réaliste d'un hook `view` est freeze/DoS (High $10K) ; le $500K n'est atteignable que via un permanent-freeze
non-privilégié listé Critical, ce qui n'a aucune preuve à ce stade. Le vrai risque de ce dossier est le
**surclaim** : un bypass de screening prouvé sera vendeur techniquement et probablement non payable sous Primacy of
Rules. Décider sur la liste d'impacts, pas sur l'élégance du mécanisme.

Voir [[feedback-verify-before-working-no-theater]], [[feedback-compliance-control-bypass-severity-frame]],
[[protocol-fortress-null-hunt]], [[feedback-target-diet-is-the-binding-constraint]].
