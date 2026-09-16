# Playbook kit — the fan-out that gates every finding through v1.6

Answers "do the same fan-out, but use the playbook as the standard to accept/reject findings."
The fan-out still discovers; the **playbook decides**. Validity is never where findings break —
they die on RECEVABILITÉ and MATÉRIALITÉ — so the standard front-loads those.

## Files
- `playbook-bug-bounty-v1.6.md` — the canonical playbook (source of truth; keep in sync with your
  master copy). 3 axes, Phase 0, 5 gates, materiality, disciplines, empirical record.
- `finding-acceptance-standard.md` — the playbook turned into an operational gate-runner: order of
  operations, per-gate decision, the verdict schema, ACCEPT/DOWNGRADE/REJECT/LATENT rule.
- `audit-fanout-template.js` — the reusable Workflow: finders (target-specific, via `args.finders`)
  → per-finding playbook audit (3 adversarial killers: on-chain VALIDITÉ, RECEVABILITÉ gates,
  MATÉRIALITÉ red-team) → PLAYBOOK-AUDIT synthesis, payable-only, real tier.
- `tools/stacks-read.py` — Stacks/Hiro on-chain read helper enforcing the V2 mandate
  (verify every governance-settable premise LIVE). For other chains, swap in the right RPC tool.

## The two lessons this bakes in (both cost us on StackingDAO)
1. **V2 on-chain mandate — "vérifier au lieu de supposer".** Code-only verifiers CONFIRMED five
   HIGH findings on the StackingDAO escrow core; live state refuted them (the core is a registered
   supported position → accrues nothing). The standard makes an on-chain read of every
   governance-settable premise a HARD gate. A verdict that conflicts with live state is rejected.
2. **Gate 4 against OUR OWN record.** Our "best lead" (refresh-position double-count) was already
   StackingDAO #88777, rejected on Gate 5 magnitude. Pass `scope.priorRecord` so the gate flags
   self-dups on day 1 instead of after a re-spent fee.

## Run a new engagement
1. Prep the target folder like `stackingdao/`: pull DEPLOYED sources to `contracts/onchain/`, write
   an `audit/methodology-primer.md` (attacker model + scope + hotspots), and a chain-read tool path.
2. Write target-specific finder specs (surface × lens), as in the StackingDAO run.
3. Launch:
   ```
   Workflow({ scriptPath: "playbook/audit-fanout-template.js", args: {
     target: "<name>",
     onchainDir: "/abs/.../contracts/onchain",
     primerPath: "/abs/.../audit/methodology-primer.md",
     playbookPath: "/abs/D-cve/playbook/playbook-bug-bounty-v1.6.md",
     standardPath: "/abs/D-cve/playbook/finding-acceptance-standard.md",
     chainReadCmd: "python3 /abs/D-cve/playbook/tools/stacks-read.py",   // or your chain's tool
     scope: { regime: "impact"|"rules",
              economics: "max $X, tiers, floors, %-cap, fee, token",
              priorRecord: "our prior submissions on this target incl. rejected ids" },
     finders: [ { label, files:[...], lens, focus }, ... ],
     minPayableTier: "high"
   }})
   ```
4. Output: `accepted / downgraded / latent / rejected` with the killing gate per finding, plus a
   PLAYBOOK-AUDIT synthesis (Phase-0 go/no-go + submittable list at REAL tier + killed list).
5. Trust order on any conflict: **live on-chain reads > your primary-source read > machine verdict.**

## Worked example
`../stackingdao/findings/PLAYBOOK-AUDIT-stackingdao.md` — the standard applied to our StackingDAO
findings. Result: NO-GO (finding 01 = self-dup #88777 already rejected; rest latent / out-of-scope /
on-chain-refuted). This is the kind of day-1 kill the integration is meant to produce.

## Notes / limits
- The template gates critical/high/medium candidates (the floor filters the rest). It caps the gated
  set at 40; raise if needed.
- The playbook is a living doc — "a rule enters only when a real finding died of its absence." When a
  new gate is added there, mirror it in `finding-acceptance-standard.md` and the KILLERS list.
- Keep `playbook-bug-bounty-v1.6.md` synced with your master (currently the v1.6 master
  copy from Downloads).
