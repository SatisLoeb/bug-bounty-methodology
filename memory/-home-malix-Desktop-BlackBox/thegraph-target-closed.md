---
name: thegraph-target-closed
description: The Graph (Immunefi) — trigger REO du 18-08-2026 mesuré DORMANT, cible re-fermée ; ne rouvrir que sur activation issuance.
metadata:
  type: project
---

Engagement The Graph (Immunefi) : clos 2026-08-06, **rouvert et re-mesuré 2026-08-18** sur déclencheur, re-fermé sans finding payable.
Dossier initial : `~/Desktop/BlackBox/thegraph-dossier.md`. Repo re-cloné : `~/Desktop/BlackBox/graph` (contracts monorepo, packages/issuance).

## Déclencheur 2026-08-18 (RÉEL mais DORMANT)
Le programme a ajouté **ce jour** un actif frais : **REO = RewardsEligibilityOracleA** `0x02753bae61c08abd4351bce7f48524935c2cc78e` (Arbitrum, proxy transparent, impl `0x66cebbec…`, proxyAdmin gouvernance). C'est le package `issuance` (le code le plus frais, jusque-là hors scope). Seul REO est entré ; le reste du scope = batch 13-mars-2026. Impacts INCHANGÉS : 4 cases, vol >$1M ou impersonation, pas de DoS/griefing/freezing, Critical exclut slashing. Max bounty $50k.

## Pourquoi non-payable (mesuré on-chain + 3 sous-agents Fable)
- `getEligibilityValidation()==false` → `isEligible()` renvoie **true pour tous** = garde no-op live. Oracle actif (50 indexers, update ~10h) → fail-open timeout inerte aussi.
- **Deployed-not-HEAD** : le RewardsManager Arbitrum live `0x971B9d3d0Ae3ECa029CAB5eA1fB0F72c85e6a525` **n'a PAS l'intégration REO** — `rewardsEligibilityOracle()/getProviderEligibilityOracle()/issuanceAllocator()` REVERT ; seul `issuancePerBlock()` (120.73) existe. Le `_deniedRewards`/`setProviderEligibilityOracle` du repo = HEAD derrière GIP-0088, pas déployé. REO câblé à RIEN de live.
- `GRT.isMinter(IssuanceAllocator)==false` → système issuance PAS encore minter (l'ancien RM reste le seul minter). RAM reçoit 0 issuance, RecurringCollector **pausé**. Balances REO/IA/ReclaimedRewards/RM = **0 GRT** (le "$2.4M" du tableau n'est PAS à REO, oracle sans fonds).
- REO logique (Agent A) : SAINE. Seul writer permissionless = `removeExpiredIndexer`, **ne fait que rétrograder** ; toute promotion est OPERATOR/ORACLE/temps-gated ; rôles non self-grantables, DEFAULT_ADMIN à personne.
- Even si activé + `revertOnIneligible=false` (non déployé, live=true→revert=report pas confiscation) : mint borné à la propre allocation de l'attaquant, **pas de redistribution** (deny A n'augmente pas B), pas de retrait d'escrow → self-benefit/QoS-bypass = classe griefing exclue, jamais vol-du-protocole >$1M.

## Dup gate (Agent C, audits Trust Security)
Audit dédié EligibilityOracle (2025-12-13) portait sur 116-LOC ; source déployée = 369-LOC. Les 3 mécanismes ajoutés (`oracleUpdateTimeout` fail-open, `eligibilityValidationEnabled` default-false, `removeExpiredIndexer` permissionless) ne sont dans AUCUN des 6 audits — mais tous by-design (natspec) et non-payables. Dups durs : large-period (TRST-L-1), config/claim race (TRST-L-2), rewards-non-redistribués (TRST-SR-4), double-mint (TRST-CL-3, Fixed).

## Ce qui rouvrirait (activation, pas juste scope)
IssuanceAllocator devient minter GRT · nouveau RewardsManager déployé AVEC l'intégration REO + governor `setProviderEligibilityOracle(REO)` · operator `setEligibilityValidation(true)` · RecurringCollector dé-pausé avec escrow >$1M. Lead ouvert non-poursuivi (hors scope + pausé + audité) : audit dédié authz/accounting de RecurringCollector. Voir [[recevability-gate-before-poc]], [[deployed-code-not-head]], [[bounty-playbook-5-gates]].
