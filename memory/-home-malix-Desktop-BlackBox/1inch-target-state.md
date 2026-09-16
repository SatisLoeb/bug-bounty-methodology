---
name: 1inch-target-state
description: "1inch Smart Contracts (Immunefi, $500k) — forme structurellement défavorable mesurée : le code sous-audité n'est pas déployé, le code déployé est sur-audité. 0 finding."
metadata: 
  node_type: memory
  type: project
  originSessionId: 926ccf4a-cfee-413f-baee-f7ad819193dc
  modified: 2026-08-08T09:45:29.424Z
---

Passe du 2026-08-08. 8 dépôts GitHub, Primacy of **Rules**. Sources dans `~/Desktop/BlackBox/1inch/` (clones blobless `--filter=blob:none` — ne PAS faire `git checkout` complet, ça timeout ; utiliser `git show <tag>:<path>`).

**Deux règles qui cadrent tout :** « The program applies only to the latest tag/releases » (ni master ni HEAD — les tags) ET Critical exige « live on a mainnet deployment », sinon downgrade en High 10–30k « at full discretion ». Aussi : **« Submitting AI-generated reports » est en Prohibited Activities**, fenêtre de divulgation de **24 h après découverte**, KYC obligatoire.

**Latest tags mesurés :** cross-chain-swap 1.1.0 (2026-01-26, le plus récent) · solana-crosschain 1.1.0 (2025-08-08) · delegating 2.0.0 + farming 4.0.0 (2025-07-03) · token-plugins 2.0.0 (2025-07-02) · fusion-protocol 3.1.1 (2025-05-29) · LOP 4.3.2 (2025-05-28) · solana-fusion 1.0.0-release (2025-04-25).

**LE FAIT STRUCTURANT :** le triangle sous-audité (token-plugins 1 audit Pashov / farming audits **V3** alors qu'il est en 4.0.0 / delegating **ZÉRO** — le mot « delegat » est absent de tout le dépôt 1inch-audits) **n'est pas déployé**. Le bump majeur de juillet 2025 est le renommage `Plugin → Hook`, or le mainnet tourne encore la génération **`pods`** (gen 1) : dst1INCH `0xAccfAc2339e16DC80c50d2fa81b5c2B049B4f947` et le hook de délégation `0x806d9073136c8A4A3fD21E0e708a9e17C87129e8` exposent `podsCount/addPod/removeAllPods/hasPod/pods` en bytecode. Deux renommages de retard (`pods`→`plugins`→`hooks`). Donc Critical impossible sur ces 3 assets. Inversement cross-chain-swap a **17 audits** (v1 ×6, v2 ×6, fees v1.1 ×5 dont Certora + Sherlock) et Solana **18**.

**Gates fermés par mesure (ne pas relancer) :**
- Correctif de réentrance caché dans le renommage : `_removeAllHooks` 1.3.0→2.0.0 passe de `remove()` dans la boucle à `erase()` en amont (d'où le `ReentrancyHookMock` neuf). Bug dans 1.3.0 = pas le latest tag = hors scope. **Frère non corrigé cherché et absent** : `_addHook`/`_removeHook`/`_removeAllHooks` ne sont pas `nonReentrant` (contrairement à `_update`) mais tous committent l'état AVANT l'appel externe, et `balanceOf` est `nonReentrantView` ; le solde caché correspond exactement à ce que le hook retiré comptabilisait. Pattern robuste.
- Dérive post-audit cross-chain-swap (prerelease 2025-08-05 → tag 2026-01-26) : les 40 lignes de `ImmutablesLib.sol` sont du **natspec pur**, `onlyTaker→onlyCaller` est un renommage neutre, et le seul vrai changement est un durcissement AJOUTÉ (`InvalidFeeAmounts`). Pas de régression.
- Faux trou `onlyValidImmutables` : absent des signatures de `withdraw`/`cancel` dans le contexte du diff, mais appliqué sur les internes `_withdrawTo`/`_withdraw`/`_cancel` ⇒ hérité par tous les points d'entrée. Vérifié par lecture intégrale au tag.
- LOP 4.0.3→4.3.2 (+749 l) : les extensions de frais (`AmountGetterWithFee`, `FeeTaker`) sont couvertes par « Fees for LO and Fusion V1 » (6 cabinets).

**Meilleur candidat, mort sur la recevabilité :** `SafeOrderBuilder` (85 l, neuf en 4.3.x, **déployé mainnet** `0x370De82413251A9d204DCEAB50dB2d7ec3Bd1769` + 11 chaînes, **aucun dossier d'audit**). Lib delegatecall pour Gnosis Safe qui écrit `signedMessages[msgHash]=1`. Défauts réels : `uint256(latestAnswer)` sans contrôle de signe, pas de check `answeredInRound`, `originalAnswer` fourni par l'appelant. Mais l'appel **direct** est mort — preuve exécutée : `cast call domainSeparator()` **revert** (le contrat ne l'implémente pas, il ne fait qu'émettre le sélecteur vers `address(this)`). Seul chemin vivant = delegatecall depuis le Safe = acteur privilégié = OOS. Et les angles oracle tombent sous « Incorrect data supplied by third party oracles ».

**Si réouverture un jour :** (1) 1inch déploie enfin la génération `hooks` ⇒ le triangle sous-audité devient Critical-éligible, c'est LE déclencheur à surveiller ; (2) un nouveau tag LOP > 4.3.2 ; (3) `OrderRegistrator`/`ETHOrders` (déployés, dans le diff 4.0.3→4.3.2, non lus en détail) ; (4) fusion-protocol 3.1.1 non ouvert.

Voir [[deployed-code-not-head]] (ici la variante est inversée : le tag en scope n'est PAS déployé), [[recevability-gate-before-poc]], [[measure-before-asserting-in-reports]], [[zest-v2-target-state]], [[sky-target-state]].
