---
name: orca-target-state
description: Orca (Whirlpools + xORCA) Immunefi — état mesuré-clos 0 payable au 2026-08-18
metadata: 
  node_type: memory
  type: project
  originSessionId: 5cd55183-fb70-4744-925f-f0ff127c5d13
  modified: 2026-08-18T15:32:59.892Z
---

Orca Immunefi ($500k max, Solana). Repos: orca-so/whirlpools (whirLb…, Anchor, fortress 6 audits/4ans) + orca-so/xorca (StaKE6…, Pinocchio staking, scope 8 jan 2026 FRESH).

**2026-08-18 : mesuré-CLOS 0 payable sur les deux, par lecture primaire exhaustive + 4 agents Fable.**

- **La vraie veine fraîche = un `entrypoint` custom Pinocchio dans whirlpool** qui intercepte 6 discriminateurs de liquidité (Inc/Dec Liq + V2 + IncByTokenAmountsV2 + RepositionLiquidityV2) AVANT Anchor ; les corps Anchor sont `unreachable!()`. **Deployed ≠ audited** : GATE-4 vérifié, 0 mention de pinocchio/reposition/entrypoint dans les 6 PDF d'audit. Chemin monétaire déployé = code jamais audité. → lu ligne-à-ligne : port FIDÈLE, tous les bindings présents (position.whirlpool, vaults, mints V2, token_program==mint.owner, autorité NFT, tick-array binding), math IDENTIQUE (réutilise crate::math partagé, pas re-porté), rounding fidèle (dépôt up/retrait down), dynamic tick array rotate 112 + tick.update overwrite 113B (pas de leak), rent balancé. Agent4 diff = 0 divergence numérique ; 2 deltas non-exploitables (verify_rent_exempt tombé mais runtime enforce ; reward-skip proxy result-equiv).
- **xORCA** : audit Sec3 exclut EXPLICITEMENT « economics/algorithm soundness » → seam. Mesuré : rate round-DOWN 2 sens, monotone non-décroissant ⇒ solvabilité préservée, pas de round-trip profit ; sim perso 400k iters seed live (vault 7.73M/escrow 372k/supply 4.678M) = 0 break, worst +2 atomic (bruit). Inflation/offset-100 MORT à l'échelle live (vault énorme, min-stake ~1 atomic). Validation Pinocchio tight (tout address-pinné). Agent2 confirme.
- **Hors veine** : swap/two_hop/adaptive_fee = chemin Anchor AUDITÉ (l'entrypoint n'intercepte que la liquidité) ; adaptive_fee audité 2025-06. Admin = centralisation OOS.

**Ne pas re-soumettre de bruit** (dropped rent-exempt = Info backstopped runtime). **Réouvrir SI** : l'entrypoint migre les SWAP ops vers Pinocchio (le commentaire du code annonce « swap ops… » à venir) = nouveau chemin monétaire non-audité ; nouvelle instruction dans le module pinocchio ; nouveau type de pool/tick-array ; changement de la math escrow/convert xORCA ; **NOUVEAU pool xORCA ouvert AVANT de seeder la dust incinerator** (branche supply==0 -> mint 1:1 -> drain du stranded, math.rs:15 ; sur le pool live c'est UNREACHABLE car dust incinerator keyless => supply>=1 permanent, donc non-submittable — Gate-1 riden-not-created).

Leçon : sur une forteresse, la veine = le SEAM `déployé-Pinocchio ↔ audité-Anchor` (substitut réécrit silencieusement). Cf [[deployed-code-not-head]], [[weak-substitute-binding-class]], [[bounty-playbook-5-gates]].
