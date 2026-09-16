---
name: feedback-in-scope-asset-list-is-literal
description: anchor recevability on the EXPLICITLY-LISTED in-scope asset, not any file that happens to be in the repo
metadata:
  type: feedback
---

A bug bounty scope's "Assets in Scope" list is LITERAL. A repo can contain first-party workspace packages that are NOT among the listed assets. Anchor the finding's recevability on a file inside an explicitly-listed asset, not on any file that happens to be in the cloned repo.

**Why:** On the ENS Immunefi competition (2026-09), the 5 listed assets were `apps/manager`, `apps/portal`, `packages/smart-account`, `packages/transaction-manager`, `workers`. The migration finding's derivation (`classifyName`, managerAddress) lives in `@ens-apps/migration` (= `packages/migration`), which is NOT one of the 5. The harmful action (the `grantRoles` sink) is native `apps/manager` code (`buildRoleGrantCalls.ts` + `buildAtomicMigrationBatches.ts:613`), and `apps/manager` re-exports and invokes the derivation (`computeMigrationPreflight.ts:201`). A triager could have argued the root cause is out-of-scope; re-anchoring on the in-scope sink + a "Where this sits in scope" pre-emption paragraph closes that.

**How to apply:** After cloning a scope repo, read the exact "Assets in Scope" list. For each finding, cite a file inside a listed asset as the primary anchor; if the root logic lives in an unlisted first-party package, frame the in-scope asset as the one that invokes it and emits the harmful action, and pre-empt the scope objection explicitly. Verify this against the LIVE scope page, not memory (same discipline as [[cosmos-evm-no-payable-venue]] and the row-must-exist lesson).
