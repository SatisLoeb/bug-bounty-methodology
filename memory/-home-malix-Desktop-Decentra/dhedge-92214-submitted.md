---
name: dhedge-92214-submitted
description: Immunefi dHEDGE submission #92214 (HyperEVM CoreWriter guard IOC-only slippage) — live, awaiting triage
metadata:
  type: project
---

Soumis le 2026-09-08 sur Immunefi, dHEDGE, **report #92214** par @MalikX31 (Whitehat).

Titre : "CoreWriter guard bounds slippage on IOC only — a pool manager self-deals depositor funds through GTC/ALO".
Target : https://hyperevmscan.io/address/0x615037C2Df6FA97634c5aD2d8144708b9dd3B176 (PoolFactory + linked contracts, HyperEVM chain 999). Impact revendiqué : Direct theft of user funds (Critical-argued). Fee zéro, KYC none.

Cœur : `HyperliquidCoreWriterContractGuard` borne le prix des ordres perp seulement sur IOC ; GTC/ALO passent sans borne → manager (untrusted, confirmé programme) self-deal les fonds du pool. Bypass MESURÉ sur fork ; capture REASONED (non-mesurable dans les règles : mainnet/testnet/tiers interdits, fork ne simule pas HyperCore). Double lame : magnitude indéterminée-par-leurs-règles (le triager ne peut ni exiger la mesure ni mesurer la bande sans violer ses propres règles). Plafonnée à l'attaque initiale (proxy upgradeable).

Dossier local : /home/malix/Desktop/Decentra/dhedge/ (SUBMISSION_DRAFT_finding1.md, GATE_CHECK_finding1.md, PoC_GTCSlippageBypass.t.sol, REPRODUCE.md).
Gist secret PoC : https://gist.github.com/SatisLoeb/478ac80fd7a4c13d034e896b067d42b4 — **NE PAS supprimer avant clôture du report** ; `gh gist delete 478ac80fd7a4c13d034e896b067d42b4` à la clôture.

Discipline post-soumission [[playbook]] : ne pas relancer avant l'échéance SLA ; ask-for-help/médiation = recours en réserve ; soumis ≠ payé. Issue modale attendue = bataille Critical-vs-High (leg de capture non-mesurable dans les règles). Résidu à trancher si le triager pousse : Hyperbolic (manager du pool RSPS $1.58M) est-il incubé dHEDGE (exclu) ou tiers (inclus) ?
