---
name: external-premise-closure-before-finding
description: Un mécanisme prouvé ligne-à-ligne dans le code in-scope ne vaut RIEN si la prémisse sur le protocole EXTERNE qui le déclenche est fausse — ferme-la en source primaire avant PoC/fee.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cf9b6d49-d729-4a75-afce-f7d261143344
  modified: 2026-08-22T12:23:22.826Z
---

Distinguer **« mon tracé du code in-scope est correct »** de **« la prémisse sur le protocole externe que mon tracé suppose est correcte »**. Les deux doivent être fermées ; la seconde est celle qu'on oublie parce que le mécanisme in-scope, une fois prouvé, donne l'illusion de complétude.

**Why:** 3 fois le même piège a fabriqué ou rouvert un lead — RSK (v3 supposé déployé), AliceV2 #1 (« un pending ne met rien dans l'EP »), AliceV2 #2 (« Alice livre le tokenOut par tranche pendant le pending »). Le cas AliceV2 #2 est le plus pur : le double-count était **prouvé ligne-à-ligne dans le code Enzyme** (vrai, il tient), mais il reposait entièrement sur le **modèle de settlement d'Alice** (externe), pris d'un **ABI DEVINÉ par Blockscout** — la source la moins fiable qui soit (le champ "slices" était en réalité `deadline`+`limitAmountToGet`). Réfuté on-chain : Alice = limit-order atomique, 50 settlements 1-par-ordre, fenêtre de largeur zéro. Un mécanisme in-scope prouvé × une prémisse externe fausse = faux positif.

**How to apply:**
1. Quand un finding cross-contrat dépend du COMPORTEMENT d'un protocole externe (settlement atomique-vs-progressif, ordre d'assignation d'id, condition de revert d'un getter, qui reçoit les proceeds et QUAND), **liste cette prémisse explicitement** et ferme-la en **source primaire** AVANT de crier au bug : source vérifiée, ou à défaut sonde on-chain (`cast call`, historique d'events groupé par id, décode manuel des logs).
2. **Un ABI deviné (Blockscout/4byte signature-DB sur un contrat non-vérifié) = source non-fiable** : les noms/types de champs peuvent être faux. Ne bâtis jamais un mécanisme sur des noms de champs devinés — décode la data brute à la main et sanity-check les valeurs (un "slices=1.78e9" est un timestamp, pas un compte).
3. **Ordre des gates :** mécanisme prouvé → **prémisse externe fermée** → recevabilité/payabilité → Known Issues → PoC. Un mécanisme mort rend tout l'aval (payabilité, dup, magnitude) sans objet — on n'instruit pas la recevabilité d'un finding qui n'existe pas.
4. Le kill vaut le finding : fermer une prémisse externe fausse AVANT le fee/PoC évite une soumission mort-née.

Corollaire du même axe : [[measure-before-asserting-in-reports]], [[deployed-code-not-head]], [[recevability-gate-before-poc]], [[by-design-gate-not-just-git-dup]].
