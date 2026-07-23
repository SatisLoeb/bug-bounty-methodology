---
name: feedback-diff-forward-to-head-not-just-scope-changelog
description: "At intake, dup-check by diffing the scope commit FORWARD to HEAD/latest-tag, not just reading its own changelog — a bug fixed in a later release is a hard known-issue."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

When a bounty scopes a **specific tag/commit**, the dup-check is NOT complete until you diff that
commit **FORWARD to HEAD** and enumerate every newer tag/release. Reading the scope commit's OWN
changelog / known-issues (its PAST) only tells you what the devs knew *then*. The kill usually lives
in its **FUTURE**: a fix commit in a later release whose message often *verbatim describes your bug
class* = a public acknowledgment = hard known-issue/dup, even if the scoped tag is literally still
the in-scope code.

**Why:** Aurora Launchpad (2026-07-23). I surfaced a PROVEN Critical (withdraw rollback absolute-restore
→ cross-account desync → insolvency), 6 facts verified at source, unit-test PASSES against scope tag
0.5.1. Looked ready_to_submit. Operator pushed angle #5: "check HEAD before submitting." `git fetch`
revealed **8 newer tags** and fix `#98` — *"do not use global values between promises in withdrawal
logic"* — landed **2025-12-02 in 0.6.0**, 8 months before intake, clean through 0.8.0. The fix was
literally my recommended fix. At intake I'd only diffed 0.5.1's own changelog (found #56, preempted it),
never 0.5.1→HEAD. The finding was real-but-fixed = dead.

**How to apply — add to every intake, BEFORE deep audit (pairs [[feedback-check-prior-audits-and-competitions-at-intake]] and [[feedback-today-impact-before-poc]]):**
1. `git fetch --tags origin` on the scope repo. List all tags newer than the scope tag (`git for-each-ref --sort=-creatordate`).
2. `git log --oneline <scope-tag>..<latest-tag> -- <the-file-your-finding-lives-in>` — read every commit touching your surface. A `fix:` whose title matches your class = your finding is acknowledged/fixed.
3. For a candidate finding, `git show <latest-tag>:<file>` the specific function and confirm it still has the defect. If HEAD is fixed, `git tag --contains <fix-commit> | sort -V | head -1` = the exact release that killed it.
4. **The one survivor when HEAD is fixed:** a LIVE on-chain deployment still running the vulnerable version with real TVL (commit-anchored scope pays deployment-impact [[feedback-commit-anchored-scope-pays-deployment-impact]]). Check the deployed version/address before conceding OR before submitting — that's the only payable path when source is fixed.

The scope tag being 9 months stale vs a fast-moving repo (0.5.1 while latest is 0.8.0) is itself the
tell: verify what's actually deployed/scoped, don't audit a frozen tag in a vacuum.
