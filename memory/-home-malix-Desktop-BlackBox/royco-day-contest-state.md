---
name: royco-day-contest-state
description: "Royco Day (Cantina $30k, 10-17 Aug 2026) — mesuré-CLOS 0 payable ; 5 audits + 1831 tests dev + 44 findings déjà soumis ; fenêtre payable ultra-étroite."
metadata: 
  node_type: memory
  type: project
  originSessionId: 56a3ddfe-a68d-47af-abe3-99d742bd3c04
  modified: 2026-08-16T10:45:42.780Z
---

Cantina **Royco Day**, $30k (7.5k si aucun High), 10→17 août 2026, solo, KYC, **PoC obligatoire**.
Repo `roycoprotocol/royco-day` @ `fa6d24971a5b1993e4d067fc223c85c8139346c0`, scope = `src/` (12k LOC).
Clone local : `/home/malix/Desktop/BlackBox/royco-day`. **Build : ~2h la première fois** (via_ir + monorepo
Balancer) ; ensuite cache chaud et `forge test` tourne en <1s. Ne PAS relancer `forge build` à froid.

**Cible différente de [[royco-target-state]]** (celle-là = Immunefi, srRoyUSDC + waterfall déployé). Ici c'est
le nouveau codebase Day (EntryPoint async + kernel + accountant + venue Balancer V3 Gyro E-CLP + factory).

## Pourquoi la fenêtre payable est minuscule (le fait décisif)
Seuls DEUX impacts paient : (1) fonds vers une adresse non désignée par le propriétaire, (2) fonds
**définitivement** bloqués. Et l'exclusion **« Incorrect amounts sent to whitelisted parties or their
specified recipients (reversible) »** tue TOUTE la classe comptable/arrondi/yield-split — c'est-à-dire
l'essentiel de la complexité du protocole. Plus : reentrancy EntryPoint (fix 9764c9e) OOS, oracle/NAV
manipulation OOS, admin/centralisation OOS.

## Saturation réelle : CINQ audits, pas deux
La page contest n'en annonce que 2. Dans `audit/` à HEAD : Hexens (7 minor, **corrigés dans le commit de
scope lui-même**, PR #17), Olympix (1M/5L), **Tomer Security (33 findings : 1C/7H/7M)**, **Certora
(1H/11M/14L)**, Cyfrin-Solace (0C/H/M, 8L). Liste dédup complète extraite dans
`scratchpad/KNOWN.md` de la session. + 44 findings déjà soumis. + **1831 fonctions de test dev**
(66k LOC de tests, handler invariant adversarial de 2139 lignes).

## Faits d'atteignabilité établis (utiles si réouverture)
- **Tout l'EntryPoint user-facing est PUBLIC_ROLE** et l'EntryPoint détient ST/JT/LPT_LP_ROLE + SYNC_ROLE
  pour TOUS les marchés (`script/deploy/core/DeployPeriphery.s.sol`). C'est le seul point où de la valeur
  cross-market peut se mutualiser. Le "whitelist bypass" via l'EntryPoint est **explicitement by-design**.
- **Le déploiement de marché est PERMISSIONLESS** (`executeMarketDeployment` → PUBLIC_ROLE). Donc
  `collateralAsset`, `quoteAsset`, `collateralAssetOracle`, `quoteAssetRateProvider`, les blobs d'init YDM
  et les `entryPointTrancheConfigs` sont **input attaquant**, pas config admin → l'exclusion
  "admin misconfiguration" ne protège PAS cette surface. Attaquée à fond, elle a tenu.
- Post-scope l'équipe a ajouté `MIN_REDEMPTION_DELAY_SECONDS = 24h` et déplacé la blacklist en param
  par-marché → ils savaient que la surface deployer-permissionless était mince au commit de scope.

## Ce qui est mesuré-clos (11 agents spécialisés + lecture perso + exécution)
Fan-out 11 surfaces (EntryPoint / kernel flows / accountant / venue / factory / oracles / tranches+blacklist
/ YDM / units+cache / spécialiste lock / spécialiste misroute) → **1 seul candidat, réfuté**. Notes de
négatif complètes (106 KB) : `scratchpad/cleared.md`.
Kills notables à ne pas refaire : FIXED_TERM borné par `fixedTermDurationSeconds` uint24 (≤194j) donc jamais
un lock ; `PREMIUMS_EXCEED_SENIOR_YIELD` prouvé inatteignable avant 2106 (les fenêtres d'accrual pavent
exactement [lastPremiumPayment, now]) ; `_debitAssets` ne peut pas underflow (floor(stNAV·W/P)+floor(jtNAV·W/P) ≤ T) ;
calldata arbitraire vers les YDM partagés keyée par `msg.sender` (l'accountant) donc pas de corruption
cross-market ; conservation du ledger EntryPoint vérifiée sur les 10 sites de transfert ; **zéro `unchecked`
dans `src/`** ; carte d'échappement admin complète (chaque revert de sync a une sortie qui ne rejoue pas
le sync qui échoue — `setCollateralAssetOracle`/`setBPTOracle` écrivent le nouveau pointeur AVANT le sync).

## Ce que j'ai exécuté (et que personne d'autre n'avait fait)
Le handler invariant des devs **clôture le régime dur** : PnL bornée à ±300 bps/op et
`TRANCHE_SUPPLY_CAMPAIGN_BOUND = 1e45`. J'ai sous-classé `DayMarketHandler` avec des ops profondes
(-9900..-301 / +301..+20000 bps) → `test/zdeep/`. Résultat : conservation et liveness tiennent ; la seule
violation levée est un **artefact du budget de poussière du mirror des devs** (chute de 4 wei de prix par
part, ~9e-17 relatif, résidu de virgule fixe du deploy de reinvestment — leur budget dérivé `n/WAD` est
~200× trop serré pour un gros tas idle). Pas un bug protocole.

## Verdict
Forteresse mesurée pour les deux impacts payables. Résidus nommés mais non payables : le tail
`whenVaultLocked` du reinvestment viole l'invariant documenté « tolerates reversions » (toute op in-kind
revert dans une session Vault Balancer déjà unlockée) = DoS de composabilité auto-infligé ;
`_remitClaims` court-circuite si `receiver == address(this)` = gel irrécupérable mais adresse choisie par
l'utilisateur.

**Réouverture seulement sur :** nouveau template enregistré (surface factory neuve), un venue autre que
Balancer V3, ou une révision du barème d'impacts qui rouvrirait la classe "wrong amount".
