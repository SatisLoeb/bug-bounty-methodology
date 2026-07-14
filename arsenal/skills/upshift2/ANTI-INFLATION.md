---
name: anti-inflation
description: The honesty gate that makes findings survive triage -- promoted to first-class in upshift2. Three corrections every finding must pass before any external send: SCOPE (is it actually in-scope and reachable in prod?), MAGNITUDE (is the impact number sourced and honest, not a naive over-match?), MECHANISM (is the chain real, or did you force two unrelated primitives into one story?). Derived from the three corrections the upshift-package documents catching before any external communication. Run at Phase 4b, before kill-gate, before drafting, ALWAYS before send -- never after.
---

# Anti-inflation -- the honesty gate (the pass that makes findings survive triage)

## Why this is first-class in upshift2

In upshift, anti-inflation was implicit -- folded into "epistemic precision" and the theoretical-bug-kill rule. But when you read what the upshift-package actually *did*, the most impressive work was not finding F1. It was **catching itself inflating, three separate times, before any external send**:

1. **Scope/mechanism error:** a draft delta misread the EIP-1967 ProxyAdmin slot (`0xb53127684a…`) as the implementation slot (`0x360894a13b…`) and claimed two contracts had been "upgraded" -- they had not. Caught on second pass by re-reading the correct slot.
2. **Magnitude error:** a draft chain claimed "$50M–$308M coordinated cross-chain drain". Corrected by on-chain hand-verify: `operator (0xE0b7DEab) ≠ ProxyAdmin owner (0x828F86BC)` -- two distinct keys, two separate single-points-of-failure, **not one $308M chain**. Honest proven number: $5.96M on coreUSDC.
3. **Magnitude trap:** an unauth endpoint showed a `$1.96B` vault with `actual_tvl = $0.96`. The inflation read: "vaults undercollateralized, $74M missing." The disciplined read: `actual_tvl` is a derived/mislabeled internal field; a $1.96B vault truly holding $0.96 would be the most visible collapse in DeFi history -- it isn't. Severity dropped from "solvency Critical" to "info-disclosure Medium pending backend-formula confirmation."

These three corrections are why the engagement has credibility with the Co-CEO. **Inflation is the single fastest way to lose a triager permanently.** An acknowledged Medium beats a dismissed-and-distrusted "Critical". This file makes the three corrections a *gate*, run on every finding before any external send.

This composes with -- does not replace -- the D9 Adversarial-Rebuttal gate. D9 is "argue from the triager's seat"; anti-inflation is "did I overstate the facts." Run anti-inflation first (clean the facts), then D9 (defend the cleaned facts).

## The three corrections

### Correction 1 -- SCOPE: is it actually in-scope and reachable in production?

The finding is real in the repo. Is it real *in the deployed system the program covers*?

Checklist:
- **Production reachability.** Trace from a real external entry point to the vulnerable code in the *deployed* build/binary/image/model -- not just the repo. Code present ≠ code reachable (CLAUDE.md Rule 5). Different build targets wire different topologies.
- **Scope membership.** Is the affected component literally in the program's scope? "When in doubt, out of scope" for platform bounties. For direct disclosure, scope = what is deployed and affects users.
- **Deployment liveness.** Is the contract/service/endpoint deployed in *production*, not a testnet/staging/abandoned instance? Non-prod deployment = instant kill (the on-chain-state-verification gate).
- **Trusted-actor honesty.** If the trigger is a trusted actor, say so plainly. Do NOT dress a trusted-operator action as an anonymous exploit. (But: distinguish a *real* trust-reduction argument -- "the trusted key is a bare single EOA with this much exposed infra, so the trust assumption is weak" -- from a forced one. The upshift-package's L3 chain is the model of an honest trust-reduction argument: it explicitly labels itself PARTIAL -- opsec amplification, not a mechanism bypass.)

Output line per finding: `SCOPE: reachable in prod via <entry>; in-scope because <reason>; trigger = <anon | trusted-actor X>.`

### Correction 2 -- MAGNITUDE: is the impact number sourced and honest?

The number in the headline must be defensible to the dollar (or the unit). Every weak leg caps the ceiling: `severity = min(evidence_strength, chain_completeness, impact_quantified)`.

Checklist:
- **Sourced inputs.** Every number traces to a live read (a balance, a TVL endpoint, a row count, a measured rate) with a timestamp/block. Not a guess, not a round number.
- **No naive over-match.** The upshift `gcp(0)==0` grep over-matched non-vault addresses; the honest move was per-impl enumeration *before* stating a portfolio figure. Generalize: before stating "N affected", confirm each of the N actually exhibits the bug -- don't extrapolate from a pattern grep.
- **Derived-field trap.** Before treating a displayed value as ground truth, ask: is this a *raw* observed value or a *derived/computed/labeled* field? The `$0.96 actual_tvl` was a derived field. Cross-check one instance against the underlying source (on-chain `totalAssets()`, the DB, the raw log) before building a claim on it.
- **Don't sum independent SPOFs.** Two distinct single-points-of-failure are two findings, not one combined number. Only sum into one figure when a single actor can traverse the whole chain (Pass 4's question 3).
- **Banned words.** "could drain / significant / substantial / massive / catastrophic / many users". Replace each with a sourced number or delete it.

Output line per finding: `MAGNITUDE: loss = $X (sourced: <live read @ block/time>); N affected (each confirmed, not extrapolated); fields used are raw/<derived+cross-checked>.`

The `$3.47` substitution test (from WEIGHT-CARD): if you replaced the dollar figure with `$3.47`, would the finding still read as coherent? If yes, the number is decorative and you haven't quantified impact.

### Correction 3 -- MECHANISM: is the chain real, or forced?

The most seductive inflation is a chain that *sounds* devastating but has a broken link.

Checklist:
- **Every link verified at the cited commit/block, on BOTH sides of any boundary.** Cross-language / cross-layer line refs are load-bearing -- verify every file:line resolves at the cited version on both sides before submit (the cross-language-line-refs lesson). The upshift-package caught a "anon → master pwd → updateTotalAssets" chain as BROKEN because `updateTotalAssets` was never an API call -- it's `OperatorOnly()`, signed off-chain. The mechanism didn't connect.
- **Observed state delta, not counterfactual.** `value_after < value_before` from real state = proof. `cost_a − cost_b > 0` from arithmetic = argument = dismissed. Fork/replay-based, real addresses, zero mocks.
- **Honest victim.** A dedup/fail-open/replay finding needs an honest party who *loses* -- not just that the mechanism replays. (The Hyperbridge F-002 lesson: flawless replay proof, closed informative because the only proven trigger was a sender-side mistake; no victim grievance.) Name who loses what.
- **No platform-semantics assumption.** Don't apply one platform's threat model to a platform that already prevents the bug (Solana account-lock kills TOCTOU; Soroban archival kills expiry-replay; NEAR receipt atomicity kills double-distribution; the Solana ±bps bound kills the EVM 1-shot NAV crash). Verify the runtime/platform model FIRST.
- **Label the chain honestly.** Per the upshift-package's severity table: each chain gets `standalone | chained(honest) | trigger | anon?`. A chain that requires a trusted-key compromise is labelled so; a chain whose value is "recon amplification" is labelled PARTIAL.

Output line per finding/chain: `MECHANISM: each link verified @ <commit/block> both sides; PoC = observed delta <after vs before>; victim = <who loses what>; platform model checked = <model>; chain label = <standalone|chained|partial>, trigger = <X>, anon = <Y/N>.`

## The gate (run on every surviving finding, Phase 4b)

For each finding write `findings/<id>/ANTI-INFLATION.md`:

```markdown
# Anti-inflation gate -- <finding id>

SCOPE:     <line>            → PASS / DOWNGRADE / KILL
MAGNITUDE: <line>            → PASS / DOWNGRADE / KILL
MECHANISM: <line>            → PASS / DOWNGRADE / KILL

Verdict: PASS (ship at committed severity)
       | DOWNGRADE (ship at lower tier -- restate the honest ceiling)
       | KILL (does not survive triage -- document in KILLED-<id>/REASON.md)

If DOWNGRADE: the honest severity is <tier> because <which leg capped it>.
```

A finding ships only on PASS or DOWNGRADE-with-restated-ceiling. The committed severity in SEVERITY-COMMIT must equal the anti-inflation verdict's tier, not the hunt-time guess.

## Self-correction is a feature, not a failure

The upshift-package documents its three corrections in an explicit "audit trail of corrections" table, framed *for transparency*. This is the right posture. Catching your own inflation before send is the work -- it is not an embarrassment to hide. A report that says "I initially read this as $74M missing; on cross-check it is a mislabeled internal field, the real finding is the unauth exposure, severity Medium" is *more* credible than one that overstates, because it demonstrates the discipline the triager needs to trust.

The anti-pattern: discovering the inflation *after* sending. That is the cost this gate exists to prevent. Run it before every external communication -- Stage 1 email, Stage 4 fortress, every salvo, every re-verification ping. Never after.

## Relationship to the other gates

```
hunt (Pass 1-4) → VERIFY LIVE (Phase 4) → ANTI-INFLATION (Phase 4b, this file)
  → KILL-GATE Q1-Q10 → SEVERITY-COMMIT → D7/D8/D9 → PREFLIGHT 22/24 → send
```

Anti-inflation runs *before* the kill-gate because a finding that fails scope/magnitude/mechanism honesty shouldn't consume kill-gate effort -- and because the kill-gate's own questions (reachability, disjoint sets, on-chain state) assume the facts are already clean. Clean the facts first.
