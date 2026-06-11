# Severity Commit — {FINDING_ID}

**MANDATORY: populate BEFORE opening draft file.** Artifact-required per tier. Default = tier immédiatement inférieur si no pointer physique.

Enforces CLAUDE.md rule #39. Protects against framing inflation during writing (HRB-001, Phemex R2, RF F18 lessons).

---

## Finding metadata

```
Finding ID:       
Protocol:         
Class:            [ ] auth-bypass       [ ] fund-theft          [ ] access-control
                  [ ] info-disclosure   [ ] signature-forge     [ ] DoS
                  [ ] business-logic    [ ] IDOR                [ ] other: _______
Date drafted at:  [ISO timestamp — populated by on-finding.sh]
```

---

## Equation

```
severity = min(evidence_strength, chain_completeness, impact_quantified)
```

Each input must be committed with its artifact pointer. Auto-declaration without artifact = default to tier immédiatement inférieur.

---

## Input 1 — Evidence strength

Commit ONE tier. Check the box AND fill the artifact fields.

- [ ] **L1 — theoretical, code read only.** No artifact required.

- [ ] **L2 — static analysis, grep pattern, architectural trace.**
  - `artifact:` `[file:line refs, must resolve to actual code]`
  - `artifact_proves:` `[ONE SENTENCE — what the static trace proves about the claim]`

- [ ] **L3 — dynamic test, executable reproduction.**
  - `artifact:` `[Foundry test path / curl command / anchor test path / script that runs]`
  - `artifact_proves:` `[ONE SENTENCE — what the dynamic test shows]`

- [ ] **L4 — mainnet-proven, production state delta.**
  - `artifact:` `[tx hash + block number + cast call output OR fork test pinned to block]`
  - `artifact_proves:` `[ONE SENTENCE — what the on-chain state confirms]`

**Default if no tier committed with resolving artifact:** L1.

---

## Input 2 — Chain completeness

Commit ONE tier.

- [ ] **unverified** — no end-to-end chain test attempted.

- [ ] **partial** — some links proven, gaps remain.
  - `gaps:` `[list the unproven links, one per line]`

- [ ] **full_ethical** — complete chain proven via ethical variant (CHAIN-PROOF-GATE Stage 2).
  - `artifact:` `[HTTP response block with status code and body / forge test asserting state delta]`
  - `artifact_proves:` `[ONE SENTENCE — which server-side acceptance or on-chain state this proves]`

**Default if no tier committed with resolving artifact:** unverified.

---

## Input 3 — Impact quantification

Commit ONE tier.

- [ ] **narrative** — prose only, no computed number.

- [ ] **computed_W1** — formula with cited inputs.
  - `artifact:` `[dated calculation block with formula + each input source (cast call / API readback / docs URL)]`
  - `artifact_proves:` `[ONE SENTENCE — what dollar amount or measured degradation this yields]`

- [ ] **W5_anchored** — ≥1 paid precedent with $ figure from H1 / C4 / Cantina / Sherlock / OUTCOMES.jsonl.
  - `artifact:` `[pointer to paid precedent — report ID, URL, or OUTCOMES.jsonl line]`
  - `artifact_proves:` `[ONE SENTENCE — which class of precedent backs the claim]`

- [ ] **both_W1_W5** — W1 computed AND W5 anchored (strongest).
  - `artifact_W1:` `[...]`
  - `artifact_W5:` `[...]`

**Default if no tier committed with resolving artifact:** narrative.

---

## Severity mapping

| evidence | chain | impact | max severity eligible |
|---|---|---|---|
| L4 | full_ethical | computed_W1 / W5 / both | Critical |
| L3 | full_ethical | computed_W1 / W5 / both | High |
| L2 | partial+ | computed_W1 | Medium |
| L1 | any | any | Low / Informational |
| any | unverified | any | Informational |
| any | any | narrative | Low MAX |

Apply min() across inputs. The output is the severity CEILING — you can commit lower, never higher.

---

## Severity commit

```
Committed severity: [ ] Critical [ ] High [ ] Medium [ ] Low [ ] Informational
Inputs: evidence=[L1-L4], chain=[unverified/partial/full_ethical], impact=[narrative/W1/W5/both]
```

---

## Self-check (all boxes required)

- [ ] Every artifact pointer I committed actually resolves (file exists, curl runs, hash on-chain, test path valid). Not hypothetical.
- [ ] Every `artifact_proves` field written in ONE sentence tied to THE claim I'm making (not a generic class-level proof).
- [ ] No input upgraded without artifact present. No "I think L3 because I read the code carefully" — that's L2 maximum.
- [ ] Committed severity matches the min() equation output.
- [ ] If I feel the finding "deserves" higher severity than the equation permits, I don't edit the inputs — I either produce the missing artifact or accept the lower tier.
- [ ] Post-submission severity concession discipline: before replying to any triager comment that touches severity, see `report-nerve § Triager response discipline`. This template handles the submission-time floor; the post-submission window (do not volunteer downgrade) is encoded there.

---

## Signature

```
Artifact-validator run at: [timestamp — populated by artifact-validator.sh]
Validator verdict:         [ ] PASS [ ] FAIL
Draft authorized to open:  [ ] YES [ ] NO
```

**Draft file cannot be opened until validator PASS.** Enforcement: on-finding.sh writes a marker; preflight-mechanical.sh reads the marker to block submit if SEVERITY-COMMIT not signed.
