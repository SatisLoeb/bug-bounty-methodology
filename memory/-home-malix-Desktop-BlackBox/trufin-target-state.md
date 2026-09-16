---
name: trufin-target-state
description: "TruFin/TruYields Immunefi — mesuré-clos, Solana 0 payable (freeze + removal-block PoC-tués), Injective F1 = DUP"
metadata: 
  node_type: memory
  type: project
  originSessionId: 208cc87d-b406-4917-a559-2619911748c4
  modified: 2026-08-12T06:27:37.257Z
---

TruFin/TruYields (Immunefi, liquid staking). **Scope rétréci le 2026-08-12** : de 8 assets (Aptos+Injective+Solana, testnet+GitHub, $30k) à **3 assets Solana-seul, $20k max** ; KYC + PoC requis ; Primacy of Impact. Aptos/Injective/Near sortis du scope courant.

**Solana staker** (`TruFin-io/smart-contracts-solana-public`, HEAD ce5d88b 2026-07-07 ; déployé `6EZAJVrNQdnBJU6ULxXSDaEoK6fN7C3iXTCkZKRWDdGM`) = wrapper Anchor mince (~1646 LOC) au-dessus du SPL Stake Pool canonical `SPoo1Ku8`. N'ajoute que : gate whitelist+pause sur dépôt, gestion validateurs. **Matrice d'autz serrée** ; économie du dépôt neutre (le pool re-valide en aval tout compte substituable ; mint TruSOL réel lié à l'autorité du VRAI pool) ; linchpin whitelist (deposit authority = PDA `[b"deposit"]`) confirmé par le state live (supply TruSOL non-nul ⇒ dépôts réussis ⇒ PDA = autorité) + test "direct deposit fails". Devnet tourne un FORK du pool `5d33x6gSAps926kRDBuM4DwXXZq3sJrVU9tsH5ReTXpE` ; testnet/mainnet + repo HEAD = canonical `SPoo1Ku8`. Pool acct partagé `EyKyx9LKz7Qbp6PSbBRoMdt8iNYp8PvFVupQTQRMY9AM`.

**Seule veine vivante** = `deposit_to_specific_validator` permissionless → `IncreaseAdditionalValidatorStake` user-déclenché (transient/ephemeral seeds hardcodés 0). README la pré-concède ("accepted, self-healing").

**PoC exécuté** (solana-test-validator, `.so` prébuild chargé à son id natif via `--bpf-program`, `SPoo1Ku8`+metadata clonés de mainnet, harnais TS autonome réutilisant les helpers du repo) :
- **Thèse de gel pool-wide TUÉE** : l'attaquant occupant le transient seed-0 bloque UNIQUEMENT le `decrease_validator_stake` du manager (0xb) ; n'affecte PAS `UpdateValidatorListBalance`/`UpdateStakePoolBalance`, ni les dépôts, ni les retraits user (mesuré sur 3 époques). L'affirmation README "no other user's deposit or withdrawal path is affected" TIENT.
- **Corollaire blocage-suppression TUÉ** : `remove_validator` (owner) réussit même en contesté et rapatrie le stake de l'attaquant vers la réserve (23+10+5=38 SOL vérifié, validatorStake→0). Pas blocable.
- Net : seul effet reproductible = griefing **Medium** du rebalancing manager, concédé + doublement mitigé (révocation whitelist en 1 tx / suppression validateur en 1 tx). **0 bug payable ≥High.**

**Injective F1** (#87437, DoS unbonding-entry, CosmWasm) : soumis 2026-08-05, revenu **DUP** après auto-triage TruYields (le programme s'auto-triage, Immunefi désabonné). Mort.

**Why:** cible mesurée-close par 3 angles (statique complet + state déployé + PoC exécuté sur les 2 seules thèses ≥High) ; y revenir = brûler des heures sur un fortress serré à plafond $20k.

**How to apply:** NE PAS rouvrir sauf déclencheur : ré-expansion du scope (Injective/Aptos/Near re-listés), déploiement d'une nouvelle génération de gestion validateurs, ou ajout au staker d'une instruction deposit-stake / SOL-withdraw (nouvelle surface non-couverte). [[recevability-gate-before-poc]] [[measure-before-asserting-in-reports]] [[deployed-code-not-head]]
