---
name: ens-audit-comp-migration-role-assignee-critical
description: ENS Audit Competition #92483 CONFIRMED CRITICAL (dup of #89314) — migration grants ROLE_SET_RESOLVER to an unvalidated subgraph assignee; a precise honest-floor report self-upgraded Insight->Critical
metadata:
  type: project
---

**CONFIRMED CRITICAL, reward pending (2026-09-14).** ENS Audit Competition (Immunefi, 18 Aug–14 Sep 2026,
apps/manager, audit-comp-ens @ 1c9b47f). Report **#92483** (submitted 10 Sep as High). This is **Track A** of the ENS
comp and it PAID where the web class did not — contrast [[ens-trackb-dcl-class-fortress-null]] (the Decentraland
case/normalization class was an executed fortress-null on the ENS web surface).

**The bug.** v1→v2 migration appends `grantRoles(resource, ROLE_SET_RESOLVER, managerAddress)` where `managerAddress`
= the v1 subgraph controller (`domain.owner.id`), never re-validated on-chain and never shown before signing. The
sibling `tokenHolder` IS re-validated (`ownerOf`/`getData`); the flow **authenticates the token and never authorizes
the assignee**. Source: `packages/migration classifyNames.ts:162-167` (re-exported + invoked in-scope at
`apps/manager .../classifyNames.ts` / `computeMigrationPreflight.ts:201`). Sink: `apps/manager
.../buildRoleGrantCalls.ts:23`, injected unconditionally at `buildAtomicMigrationBatches.ts:613`. Class =
unvalidated-assignee authorization (BFLA-adjacent). Workspace: `~/Desktop/BUGS/ens-finding-01-migration-role-assignee/`
+ `ens-app-verdict/STATE.md`. PoC (gist SatisLoeb/1d45c4a6...): two tiers — real `classifyName`+`buildRoleGrantCall`
emit the third-party grant (measured calldata) + Sepolia fork lands it on the deployed v2 ETHRegistry (status 1,
0->ROLE_SET_RESOLVER; control ROLE_RENEW grant reverts `EACCannotGrantRoles` => EAC enforcing, not a fork artifact).

**The severity trajectory is the lesson.** Submitted High → set **Insight** + Confirmed as dup of #89314 (10 Sep) →
**regraded Critical** with a project **apology** (14 Sep). The two Insight bases were BOTH wrong and the project
retracted them itself: (a) "grant is revocable" is not a basis the impact rows permit; (b) "visible in the Explorer
roles view" is inaccurate — Manager has no roles surface, its dashboard role query is scoped to the connected
account, so the grant renders on the **seller's** dashboard and never the buyer's. Their own
`MIGRATION_CASE_STUDY.md` confirms the migration batch **extinguishes** the v1 controller's authority (reclaim on
BaseRegistrar, v1 resolver cleared, fresh v2 registration) ⇒ the grant is authority-**CREATION**, not carry-over.

**Why this generalizes (the transferable win):** a precise, honest-floor report can **self-upgrade past its own
committed severity**. Operator committed **High** and pre-empted the Medium downgrade with **Path B = authority-
creation not carry-over**; the triager used that exact reasoning to jump **Insight→Critical**, ABOVE the operator's
own honest floor. No appeal comment was posted — the report's Path B framing was the correction. This is the inverse
of overselling: the honest floor ([[feedback-reachability-is-kill-gate-not-severity-modifier]], "commit the floor,
argue the ceiling, downgrade is the triager's job") built the credibility that let the impact carry the ceiling — and
here the triager UPGRADED. Reinforces [[doctrine-surgical-reports-fight-to-the-end]] and
[[feedback-audit-acknowledgment-is-a-liability-not-an-asset]] inverted: the report's own body, not a fight, flipped it.

**Payout caveat (open):** confirmed as a **dup in the #89314 family** (primary 18 Aug; sibling dups #89336, #91602;
Medium-race variant #89249) — so the reward is a **dup-share of the Critical pool**, not the full primary, DESPITE the
report page also showing a **"Chief Finding"** badge (those two imply different weights). Comp primary pool ~$49k;
vault ~$69,990 on 14 Sep. **Confirm the exact figure with the project before Paid.** OUTCOMES id `ENS-AC-92483`.
Wallet on file: 0xAc954A2B28456a0Be831ef1a883CDb37fcADEC35.
