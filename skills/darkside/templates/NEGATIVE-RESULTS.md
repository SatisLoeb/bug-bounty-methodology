# NEGATIVE RESULTS / NO-GO — <target>

> The honest close. Copy to `analysis/_negative-results.md`. A NO-GO is a VERDICT only when it cites
> executed artifacts per door + a passed self-audit — never "by inspection", never on fatigue. A null
> that cannot point to the artifact that produced it is a superficial pass wearing a verdict's clothes.
> See SKILL.md §5 (EXIT) and the `nullguard` skill.

## Gate decision (from §0)

- **Saturation:** audit_count=<n>, auditors=<…>, adversarial dev-tests=<y/n>, fresh-fix=<y/n> → <LOW/HIGH>
- **Emitted:** RE-SOURCE / DELTA-ONLY / FULL-DESCENT — and why.

## Per-door executed close

| door | what was mined | executed artifact (the deciding run) | result |
|------|----------------|--------------------------------------|--------|
| A | coverage matrix N-cells: … | ran their suite + sibling PoC | null: … |
| B | fear-comments / invariants: … | all-writers enumeration (not inspection) | null: … |
| C | canonical-form deviations: … | attacked the unwritten invariant by untrusted actor | null: … |

## Coverage ledger (0.5.6 — mandatory before any costly null)

- Enumerated `find` count: **N** in-scope files. Classify each: `COVERED+artifact` / `COVERED+seam-null`
  / `SKIPPED+allowed-reason`. **UNCOVERED must be 0.**
- "Canonical-dup / helper / trivial / no-seam / small" are depth-priors, NOT skip reasons — each earns a
  delta-pass. (See `CASE-mezo`.)
- Statement: "I enumerated N files; M covered by executed artifact, K skipped for [reasons], 0 uncovered."

## Deployed-layer read pass (0.5.5 — mandatory on audited on-chain targets)

Per fund-moving deployed contract (read-only `eth_getStorageAt`/`eth_call`/verified-source-fetch):
- Upgrade authority (EIP-1967 admin → ProxyAdmin → owner / Safe threshold): …
- Deployed-impl vs repo (verified source diff — NEVER bytecode-grep for revert strings): …
- Live oracle/params vs audit conditions (decoded `latestRoundData()`): …

## §0.5 self-audit before this NO-GO ships (the exit re-run)

- [ ] Every dismissed surface has an EXECUTED artifact, not a reasoned wall (0.5.1).
- [ ] Every `onlyOwner`/gate dismissal survived BECOME-THE-ACTOR / pierce-the-gate (0.5.2 / 0.5.8).
- [ ] Every kill rests on an unbiased PoC I RAN, with a disconfirmer (0.5.3).
- [ ] No un-attacked in-scope surface remains (0.5.4 + the coverage ledger above).
- [ ] Every multi-step PoC pivot was read-back-verified — no silent no-op (0.5.7).
- [ ] No high-impact defect abandoned on "probably unreachable" with un-run recoins (0.5.9).
- [ ] Every load-bearing empirical claim (mine or an agent's) was re-run by hand (0.5.3 c/d/e).

## Decision

- **NO-GO** (redeploy to the queue) / **BANK** finding(s) at honest severity: …
- One line the operator would push on — and its executed answer: …
