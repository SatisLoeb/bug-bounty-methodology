# FINDING — F-<place> · <target>

> Signed verdict card for one candidate that survived the manual loop (SKILL.md §4). Copy to
> `findings/F-<place>.md`. A card is not "ready" until the weight-accounting gate at the bottom passes.
> Severity from reading is a HYPOTHESIS; the severity here is the one the executed PoC produced.

## Verdict

- **Status:** READY_TO_SUBMIT / DOWNGRADE / KILL / SUSPENDED
- **Severity:** <Critical/High/Medium/Low/Info> — `STANDALONE: x / CHAINED: y` if chained
- **Class / door:** <bug class> · found via Door <A/B/C>
- **Payable impact:** `loss=$X` (extraction) OR frozen-$·duration / insolvency-$ / gov-scope-seized /
  halt-duration / users-deanonymized (non-extraction)
- **Reachable by:** untrusted actor / role (which) — GATE #0 result

## 1. The invariant + the breaking mechanism

- **Invariant the code assumes:** …
- **Where it breaks (deployed build, file:line):** …
- **Who reaches the breaking writer/path:** … (untrusted = live; admin-only = OOS unless role boundary exceeded)

## 2. The unbiased PoC (the deciding artifact)

- **Config parity to deployed:** real rates/decimals/oracle/roles/caps via `cast` — list them.
- **No mocks on the tested leg:** …
- **Baseline + honest victim in the SAME PoC:** …
- **Attacker pays full freight** (no `deal()` on the load-bearing precondition): …
- **Genuine-pair-first** (deployed target): whole chain run once on the real contract + real
  counterparty + real production params BEFORE drafting (see `CASE-okx-adapters`). Result: …
- **Pivot read-back** (multi-step): after the pivotal action, `state_after != state_before` asserted by
  the expected magnitude — no silent no-op (see `CASE-perena-bankineco`). Result: …
- **PoC output (pasted, the real numbers):**
  ```
  <loss line / state deltas / -vvvv confirmation the action fired>
  ```

## 3. The disconfirmer (proves the finding is real, not a harness artifact)

- **Disconfirmer aimed at the LOAD-BEARING leg:** add the guard whose absence is the claimed bug → the
  exploit must now revert, the honest baseline must still pass. Result: …
- **Bounding disconfirmer** (anti-inflation): the control that caps the severity honestly (e.g. flat-capital
  = net-zero → requires a pre-existing position → Medium not Critical, see `CASE-f-stale-nav`). Result: …

## 4. KILL-GATE Q1–Q10

1. Design intent? 2. Reachability (untrusted)? 3. Disjoint sets actually overlap? 4. Existing guards?
5. Trigger feasibility? 6. Industry-known / dup vs all prior findings + audits + this contest?
7. Upgradeability path? 8. Auditor cross-ref? 9. Post-audit dating (is the code in the delta)?
10. On-chain deployed state confirms it? — answer each in one line.

## 5. Full-corner closure

- Sibling/parallel paths that generalize: … (see `CASE-morpho-liquidation` — the value is the
  cross-sibling consistency, one report shared-root)
- Every other reachable sibling shown inert: …
- Mock-residual verified off-path (reads AND hooks): …

## 6. Weight-accounting gate (pass BEFORE submit)

- [ ] Every empirical claim in this card was re-run by hand and its output pasted (no agent's word).
- [ ] Every chain arrow has an executed A→B test behind it.
- [ ] The severity equals what the PoC produced, not what reading suggested.
- [ ] Scope: every hop is in-scope OR an OOS hop is carried by a later in-scope untrusted hop.
- [ ] §0.5 self-audit (SKILL.md §0.5 checklist) run against this card.
