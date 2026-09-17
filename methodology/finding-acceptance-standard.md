# Finding Acceptance Standard — the playbook as a gate-runner

> **STAGE 2 of 2. This is the FILTER half. It runs on what `generative-spine.md` (STAGE 1) produced —
> it never runs alone.** Every organ here is a REJECT organ; a method made only of these has the empty set
> as its optimum. Generation comes first (invent the attacks the dev missed); these gates then validate them;
> a NO-GO is admissible only with the kill-list the generative stage produced (recorded in `recall-ledger.md`,
> the recall term). If you find yourself here without having generated first, stop and go to the spine.

Operational decision procedure derived from `playbook-bug-bounty-v1.6.md`. This is the standard
the fan-out applies to ACCEPT / DOWNGRADE / REJECT every candidate finding. It does not replace
the playbook; it turns it into a checklist agents (and I) run at intake, front-loading
RECEVABILITÉ + MATÉRIALITÉ (the playbook's central lesson: validity is never where it breaks).

A finding is PAYABLE only if it passes all THREE axes. Run the gates in the order below —
the cheap killers first — and stop at the first fail (record the killing gate).

## Order of operations (front-load the killers)
-1. **Phase -1 — SURFACE SELECTION (before the target even enters the pipeline; the binding constraint).**
   The corpse-rule is blind to sourcing (a sourcing failure leaves no corpse), so this must be an explicit
   step, not a reflex. **Pay-surface = the SEAM (the boundary no audit owns), any layer incl. deep SC;
   dead = HARDENED CORE-MATH.** NOT "web vs SC". Score seam-density on the 5-boundary taxonomy of the
   record's paid/escalated: signer↔app · session↔callback · deployed-config↔code · periphery↔core ·
   pool↔pool-on-error-path. `score = seam-density × freshness/venue-open × solo-accessible × (1/dup-risk)`.
   **Concrete scorable tell = the guarded-wrong-variable primitive (playbook §4) as a SELECTION signal:**
   at a boundary, a correct guard on variable X with the adjacent attacker-controlled variable Y ungated.
   A target where you can already spot a guarded sibling next to an attacker-controlled field scores high —
   it's the 3/3 mechanism (ENS/Granite/RSK), the best predictor of a paying surface.
   A thin-seam hardened-core-math target = NO-GO day -1 regardless of layer (corpses: StackingDAO/Euler/
   Pareto internal = 0 paid after firm effort; 5 paid/escalated all seam-dense — Decentraland signer,
   Mt Pelerin session, August deployed, Granite periphery↔core, OZ #92486 pool-isolation-error-path).
   **Supply corollary (measured, venue-landscape 2026-09: public fresh comps ≈ 0):** a selection gate
   can't score an empty board — route to the ACCESS layer (tier-migration/reciprocity with paid clients,
   relationship/Upshift-shape, invite-only, pre-mainnet, drift-watch repointed to known seam-dense
   clients' NEW deployments), not the over-farmed board. Don't spend firm effort on saturated core-math
   because "it's what's on the board."
0. **PULL the "Impacts in Scope" list (Phase 0, MANDATORY — the target map).** Copy the program's
   full payable-impact table VERBATIM, every tier (Critical/High/Medium). This is not paperwork: it is
   the list of terminal verbs the hunt must chase. The default failure is the **theft reflex** — hunting
   only "direct theft / extraction" and under-covering the other payable classes (permanent freezing,
   protocol insolvency, MEV→freeze/insolvency, temporary freezing, SC-inoperable/DoS, griefing). Feed the
   FULL list to every finder and every manual poke as the hunt-direction, and keep an **impact-ledger**
   (candidate × impact-class): a class with zero hunters is an un-hunted axis, not a null. *(Pareto near-
   miss 2026-09-16: fanout + manual proved THEFT fair and nearly closed NO-GO, having never run the
   permanent-freeze / insolvency / DoS axis as a first-class target — the richest surface on an epoch/
   liveness-heavy protocol. Granite finding A itself was a FREEZE, not a theft.)*
1. Phase 0 economics + regime (go/no-go for the whole target).
2. Gate 4 (dup / known-issue / OUR OWN prior record) — primary source.
3. Gate 5 (materiality at deployed scale) — the real tier.
4. Entry-vector wall (Rules vs Impact).
5. Gate 1 (actor separation + reachability-premise source).
6. Gate 2 (missing vs escaped guard).
7. Gate 3 (premise before PoC + external premise).
8. VALIDITÉ close: on-chain live verification of every governance-settable premise.

## AXIS 1 — VALIDITÉ (is it TRUE?)
- **V1 Mechanism**: proven line-by-line in DEPLOYED/tagged in-scope code, not HEAD, not a fixture.
- **V2 On-chain mandate (hard gate — the StackingDAO cache lesson, burned 2×)**: every premise about
  state that governance/config/an operator can set — registrations, allowlists, `active` flags,
  escrow/position lists, config vars, balances, supply, roles — MUST be read LIVE on-chain, not
  inferred from code defaults. A code-only "confirmed" is PROVISIONAL until this passes. A finder's
  verdict that conflicts with live state is REJECTED. *(This is exactly what turned 5 agent
  "confirmed HIGH"s on the StackingDAO escrow core into false positives: the core is a registered
  active supported position on-chain → it accrues nothing.)*
- **V3 Deployed-code-not-head + the mirror**: diff on-chain-verified source (Blockscout/Sourcify/
  explorer) against the scope commit file-by-file BEFORE hunting. Two deaths: valid on the judged
  commit but already patched in prod (funds-at-risk = 0); or present in prod but absent from the
  judged commit (out of scope).

## AXIS 2 — RECEVABILITÉ (is it in the RULES?)
- **Phase 0 regime**: Primacy of Impact (impact governs; affected asset may be unlisted, often
  Critical/High only) vs Primacy of Rules (asset must be listed; strict). Sets proof burden AND
  whether an out-of-scope trigger vector kills it.
- **Gate 1 — actor separation (3 prongs, all required)**: (a) actor ≠ victim; (b) actor ≠ the party
  with legitimate authority over the damaged asset's config; (c) actor can CREATE AND HOLD the state
  over the window. Killer question: create/force the precondition, or merely RIDE a state produced by
  a privileged/third party? Shared/pooled resource without authority = real; a resource the actor
  controls = their own affair. **Reachability-premise source**: the proof the attacker can create the
  precondition must live in IN-SCOPE judged code — not a deploy script / fixture / doc / guessed ABI
  (Royco cost a full tier here).
- **Gate 2 — missing vs escaped guard**: missing-guard = a claim about design intent → always
  defendable as "the responsible party is trusted" → weak for payment. Escaped-guard = a guard that
  EXISTS, walked out of its invariant by a permissionless action → a claim about code behavior →
  LEAD WITH IT. *(StackingDAO `ERR_OVER_RESERVE` tests only the increase.)*
- **Gate 3 — premise before PoC**: does the PoC REACH the state or CONSTRUCT it (warp/patch-auth/
  wrong-config = asserting existence, not proving it)? Stress the premise first. **External premise**:
  a mechanism proven line-by-line is NULL if a premise about an EXTERNAL protocol's behavior is
  wrong — close it in PRIMARY SOURCE (event history, verified impl, on-chain read), never a guessed
  ABI/inferred field.
  - **TEST IN DIRTY NUMBERS by default (v1.6 — the silent false-negative).** A PoC built on clean
    values (round prices, divisible amounts) CANNOT structurally reveal the precision / rounding /
    off-by-one classes: rounding only bites when there is a remainder, so a round number HIDES the
    whole class — every test passes, nothing signals. Default to dirty inputs: prices carrying cents,
    non-divisible amounts, prime quantities, decimals != the market's, across every division /
    share-conversion / valuation sink. Round numbers are for the readability of an ALREADY-found bug,
    never for discovery. FOIL (2nd Maxim as tool): *does the dev test in cents or round dollars?* — if
    round, your PoC inherits his blind spot. *(Granite: A/D/B proven on round prices; bug #80206 beat
    #92663 on the precision slice — the fix commit itself: "a whole-dollar price divides evenly and
    hides the defect completely.")*
- **Gate 4 — dup / known-issue (primary source)**: grep public audits for the mechanism AND read the
  named concluded-assessments line-by-line for YOUR EXACT SINK (a summary/keyword-search/agent gives a
  false-negative of confidence). Read the separate `well_known_issues.md` and open fix branches.
  - **DEDUP PER SINK, NEVER PER CLASS (v1.6 — the tombstone false-negative at class scale).** With N
    candidates of one class (rounding, zero-share, oracle-staleness…), the tombstone reads the audit at
    EACH individual sink, N times. "The class is known" is NOT a tombstone — it is a false-negative that
    covers one sink and claims all N. The free mechanical tell: **a patch or audit that guards only ONE
    sink of the class is living proof the class was NOT resolved** — it was resolved in one place; read
    every other sink in primary source, the class is virgin there. FOIL (2nd Maxim as tool): *does the
    dev's patch guard ALL sinks of the class, or one?* — the unguarded siblings are the map. *(Granite:
    "em01/l01/… = known-audit dups" retired the class in-block by association; bug #99 was the same class
    on `borrow`, a sink never read; the fresh patch guarded only `borrow (>new-debt-shares u0)`, leaving
    `repay` / `liquidator-paid-shares` / `LP-deposit` unguarded = the class alive at 3 sinks.)*
  - **PUBLIC-DUP SOURCES TO PULL AT PHASE 0, BEFORE THE FANOUT (both cost a real finding when skipped):**
    1. **A prior Immunefi audit COMPETITION on the exact code** — check `reports.immunefi.com/<project>`
       via the `immunefi-audit-competitions` MCP (`searchDocumentation`/`getPage`). A competition = a
       public corpus of hundreds of disclosed findings; it is near-total saturation on every seam and
       usually a day-1 NO-GO. *(Alchemix v3: 527 disclosed findings — 67 Critical — which my Phase-0 GO
       missed because I only read the firm audits + the AI index, not the competition hub.)*
    2. **The target's OWN in-repo audit corpus** — `README` + an `audit/` folder of PDFs. Feed it as the
       fanout's dedup gate. *(Tenbin: Spearbit/Zellic/Fuzzland/Verilog PDFs sat in `repo/audit/`; the
       convergent insolvency cluster was Spearbit 5.1.2, a dup I only caught post-fanout.)*
    Fetch BOTH, save them as the dedup corpus, and hand them to the finders/verifiers. "Novel mechanism"
    / "launched recently" does NOT mean unfarmed once a competition or multi-audit has run.
  Defensive-doc commit = tombstone (skip); FIX commit = target (bypass-the-fix valid only if a fix
  exists). **AND check OUR OWN empirical record** (playbook §5 + local submission log): a finding we
  already submitted/were rejected on is a self-dup — do not re-spend. *(StackingDAO #88777 is in the
  record, rejected on Gate 5.)*

## AXIS 3 — MATÉRIALITÉ (is it BIG ENOUGH at real scale for the claimed tier?)
- **Phase 0 economics**: max bounty, tiers, **minimum floors**, payment token. **The % funds-at-risk
  cap** turns the headline pot into a function of the in-scope contract's on-chain TVL — read
  funds-at-risk PER IN-SCOPE CONTRACT, on-chain, now (not DefiLlama aggregate). Real max = cap ×
  that contract's TVL, and a slow drain is further bounded by the pause window. Fee (refundable?),
  PoC form required, rule-density go/no-go, lifetime-paid fingerprint, IP-assignment.
- **Gate 5 — six checks before submission**:
  1. Magnitude at deployed scale (real supply/pool/position/window — a SEPARATE calc, not the PoC's
     illustrative 50%).
  2. Economic viability (attack cost vs extraction).
  3. Engineer's-seat red-team (write their best refutation: by-design / bounded / self-limiting /
     immaterial-at-scale — and pre-empt it).
  4. Kind-vs-degree (prove both; an elegant mechanism proof hides a magnitude hole).
  5. Auto-limiter (does the exploit reveal/bound itself? quantify within the limiter window).
  6. Form-exists-in-prod: if the impact needs a FORM (wallet type, config, actor type), census the
     prod on-chain for real instances BEFORE pricing/tiering — zero instances caps the tier.
- **Written stipulation beats your argument**: if the program downgrades your class in writing,
  place yourself at the tier it allows (surclaim = decote).
- Calibration: not "only submit big" — CHIFFRE the real magnitude and claim the tier it TRULY reaches.

## Entry-vector wall (RECEVABILITÉ)
A real, in-scope mechanism dies if its TRIGGER lives on an out-of-scope asset. Under Primacy of
Rules, every link crossing an unlisted asset is a wall (trigger must be in-scope). Under Primacy of
Impact, only the impact's LANDING must be in-scope. Social-engineering line: standard delivery (a
click on the IN-SCOPE asset) is not excluded SE; manipulation-as-attack (type in console, reveal a
secret, disable a protection) and a click on an OUT-OF-SCOPE asset are. *(tx-sender phishing that
needs the victim to call an attacker contract = out of scope.)*

## Verdict schema (what each finding gets)
```
{
  finding_id, title, contract, function,
  axis_validite:   { mechanism: pass|fail, onchain_verified: pass|fail|not-done, deployed_not_head: pass|fail, notes },
  phase0:          { regime: "impact"|"rules", economics_real_max_usd, fee, tier_ceiling_reason },
  gate1_actor:     pass|fail  (+ create-vs-ride, premise-source),
  gate2_guard:     "escaped"|"missing"|n/a,
  gate3_premise:   pass|fail  (+ external-premise closed-in-primary?),
  gate4_dup:       clear|dup-public|dup-private-risk|self-dup  (+ our-record match),
  gate5_material:  { real_tier, six_checks:{...}, killing_check|null },
  entry_vector:    in-scope|wall,
  VERDICT:         ACCEPT | DOWNGRADE(to tier) | REJECT | LATENT,
  killing_gate:    <name or null>,
  real_tier:       critical|high|medium|low|not-payable,
  one_line:        "<why, in the playbook's voice>"
}
```

## Decision
- ACCEPT only if VALIDITÉ (V1+V2+V3) AND RECEVABILITÉ (Gates 1-4 + entry-vector) AND MATÉRIALITÉ
  (Gate 5 gives a real tier ≥ the program's minimum payable) all hold.
- DOWNGRADE when a gate lowers the tier but the finding survives (Royco: Gate 1 premise-source → −1).
- LATENT when the mechanism is a real code defect but the precondition is a governance/rare state the
  attacker cannot create (report defensively, not as immediately-payable).
- REJECT with the killing gate named. A clean kill closed in primary source BEFORE any fee is worth
  as much as a finding (Enzyme ×4).

*Keep this in sync with the playbook version. When the playbook gains a gate (a finding died of its
absence), add it here. Remove what's absorbed — do not let it ratchet.*
