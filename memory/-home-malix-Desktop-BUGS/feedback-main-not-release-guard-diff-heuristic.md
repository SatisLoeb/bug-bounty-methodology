---
name: feedback-main-not-release-guard-diff-heuristic
description: guard present on main but absent from a shipped release branch = public dated 0-day window; greppable, clone-depth-independent
metadata:
  type: feedback
---

On any multi-repo / release-branch project (Cosmos ecosystem, geth-derived, anything that ships
tagged `release/vX.Y.x` families off a fast-moving `main`), a security guard merged to `main` but
NOT yet backported to a release branch is a **public, dated 0-day window** on every deployment that
tracks a tag from that release family. This is the concrete realization of the "fix-under-pressure =
target" inversion.

**Why:** cosmos/evm GHSA-7g4w-cg88-2cq2 (SubBalance underflow, ~$5.7M across 6 chains) was fixed on
`main` in PR #1176 on 2026-05-15 and only backported (#1253/#1254) on 2026-08-19 — a 96-day window
where the patch was public on `main` and every release was still vulnerable. The `main ↔ release/*`
diff WAS the exploit primer. Evidence-from-source, independent of clone depth.

**How to apply (one gesture per clone, after `git fetch --unshallow` or a `--filter=blob:none` clone):**
```
git log --oneline origin/main --not origin/release/vX.Y.x -- '*.go' \
  | grep -iE 'underflow|overflow|guard|check|panic|validat|sanit|harden|invariant|reject|bound'
```
Then **verify by CONTENT, not by SHA** — backports are cherry-picks with new hashes, so the original
`main` commit ALWAYS shows as "absent" even when its content was backported (this over-reports;
#1176 itself was a false-positive this way). For each candidate, read the file at the release ref
(`git show origin/release/vX.Y.x:path`) and confirm the guard code is genuinely missing.

**Multi-family caveat:** compare `main` against the LATEST family AND the older families a live chain
might still track (ibc-go ships v8.x…v11.x simultaneously; a chain on v8.3.x can lack a guard present
in both v11.2.x and main). A null on the latest family is not a null on the ecosystem.

**Reachability is still the kill-gate:** "guard on main, absent from release" is a PRIMER, not a
finding. It resolves to a live bug only after (a) an actual reachable trigger is proven on the
deployed build and (b) it is mapped to a specific chain shipping the vulnerable tag without the
cherry-pick. First hit logged: cosmos/evm PR #1244 (mempool insert-queue node-crash `recover()`),
content-absent from release/v0.7.x and v0.6.x as of 2026-09-06 — but a blanket recover, so the
reachable panic input is still unproven.

Related: [[cosmos-evm-ghost-cache-distinct-from-ghsa-missed-vesting-surface]] [[feedback-kill-poc-must-sweep-param-space]] [[feedback-a-known-issue-note-is-a-dup-fossil]]

**Sweep 2026-09-06** (evm/ibc-go/cosmos-sdk/wasmd/wasmvm): only strong primer = evm #1244; cosmos-sdk v0.50.x auth guards #26517/#26573 content-absent but weak (baseapp runTx recover, no ASA). Full artifact: BlackBox/cosmos/GUARD-DIFF-SWEEP.md.
