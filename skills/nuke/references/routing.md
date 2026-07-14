# NUKE — routage (PROPOSE, ne lance jamais — U-1)

Après lecture de `signals.md`, propose à l'opérateur la ou les veines suivantes. NUKE ne spawn
aucun de ces skills : il les nomme, l'opérateur confirme et lance. Table de décision :

| Ce que le barrage + l'espace négatif montrent | Veine à PROPOSER | Pourquoi |
|-----------------------------------------------|------------------|----------|
| Cible avec math de valeur (vault ERC-4626, AMM, lending, primitive crypto), classes `arithmetic`/`oracle`/`flashloan` muettes | **`/extract`** | détecte la veine MATH-EXTRACTIBLE, chaîne de gates par vitesse-de-mort, fork seulement si le gate qui tue survit |
| Cible qui ré-implémente une math de référence (header-chain, codec, retarget, parser de conformance) | **`/invfuzz`** | harness différentiel EXÉCUTÉ contre la lib de référence ; le hand-reading ne tranche pas une divergence |
| Surface authentifiée / rôles / modifiers denses ; classe `access-control` bruyante ou suspecte | **`/power`** | mesure la distance pouvoir↔autorisation par exécution depuis un acteur non-privilégié, jamais inférée d'un modifier |
| Cible déjà auditée par une firme, high-value, chasse des coins sombres | **`/darkside`** | mine ce que les devs ont TESTÉ → liste ce qu'ils ont oublié ; mentalité voleur qui emmagasine des primitives |
| Cible multi-surface (exchange, wallet+extension+web) — décider OÙ dépenser la profondeur | **`/wide`** | Stage 0 allocation par capacité×plafond×accessibilité-solo×(1/dup) |
| Cible avec orchestration off-chain (keepers, executor/operator, backend qui signe) | **`/upshift`** ou **`/upshift2`** | le bug vit dans le seam entre on-chain et off-chain |
| Nouvelle cible, direction pas claire | **`/intake`** | le vrai front door : classe, corpus-load, propose la veine rankée (ne lance rien) |
| Nouvel engagement profond, immortel, qualité firme | **`/firmaudit`** | Phase 0→S→T→A→R, 4-pass fan-out ; lit les veines en RÉFÉRENCE |

## Routage non-EVM (Rust/CosmWasm · Solana · Go/Cosmos)

Sur une cible non-EVM, `signals.md` et `nuke-digest.md` portent **déjà la veine curée par classe**
(`references/negative-space.json`). Suis-la ; rappels :

| Classe muette dominante | Veine | Écosystème typique |
|-------------------------|-------|--------------------|
| authz `authn≠authz`, Receive-spoof, invoke_signed seeds, remaining_accounts, mint-substitution, gov-authority bypass | **`/power`** | tous |
| share-inflation, rounding, oracle/TWAP, overflow-checks gap, mint-sans-burn, decimals confusion, Token-2022 | **`/extract`** | tous |
| reply-reentrancy, state-machine escrow, sudo/ICQ/ICA, non-déterminisme, panic Begin/EndBlock, migrate/upgrade, stale-après-CPI, zero-copy | **`/darkside`** | tous |
| **bridge valset/sig-scope/nonce-replay (Peggy/Gravity), IBC lifecycle, keeper/orchestrateur off-chain** | **`/upshift`/`/upshift2`** | Go/Cosmos surtout — le seam |

**Move/Cairo** : pas de barrage → route **Prover/formel** : `aptos move prove` (z3/boogie, local) /
asymptotic sui-prover pour l'invariant comptable ; Cairo → Aegis (Lean4) / Horus (SMT) pour UN
invariant durci + snforge (property tests) + audit manuel bridge/AA/upgrade. Semgrep = triage-flag
mince (règles à écrire), jamais une claim de couverture.

**Couche outillage non-EVM** (rappel installation via `scripts/setup.sh`) : Rust = cargo-audit/deny/
clippy(→SARIF)/geiger (+ solana-lints Dylint sur Solana) ; Go = golangci-lint/govulncheck/gitleaks/
nilaway/opengrep(ToB)/codeql. sec3-xray/radar (Docker) et codeql (build DB) = opt-in
(`NUKE_SEC3=1`, `NUKE_CODEQL=1`). SARIF = colonne de normalisation commune.

## Couche agent LLM (Pashov — optionnelle, coûteuse en tokens)

À proposer quand l'opérateur veut un fan-out automatique en plus de la chasse manuelle :

- **`/x-ray`** — recon/threat-model pré-audit, génère `x-ray.md` (invariants, entry points, git risk).
  Bon juste après NUKE pour cartographier avant de plonger.
- **`/solidity-auditor`** — 12 agents-attaquants en parallèle + 4 portes de validation. Token-heavy
  sur Opus ; propose de rétrograder les sous-agents en Sonnet/Haiku.
- **`/fizz`** — génère un harness Echidna/Medusa. À proposer sur une cible à invariants (croise
  `/invfuzz`). `medusa` est installé sous `vendor/bin/`.
- **`/halmos`** — barreau « preuve bornée » : après le fuzz, durcis un invariant précis en test
  symbolique `check_` (`hprove . --function check_… -vvvvv`). Un CONTRE-EXEMPLE = candidat finding ;
  un PASS = prouvé sous la borne (note-la) ; il refuse la vacuité. Ordre : fuzz → Halmos → Certora.

## Clôture (toujours operator-gated)

`report-nerve` (structure) → `chill` (style anti-classifieur si triage humain) →
`immunefi-submit` / `disclose` / `screenshot`. `/disclose` n'est **jamais** auto-lancé — action
sortante, difficile à annuler.
