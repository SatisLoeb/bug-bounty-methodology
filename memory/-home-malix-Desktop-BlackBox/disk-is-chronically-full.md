---
name: disk-is-chronically-full
description: The BlackBox machine runs at 97-100% disk; large Rust/Go builds fail unless artifacts are cleaned first and after.
metadata: 
  node_type: memory
  type: project
  originSessionId: 5a66a426-5eb2-479e-86b6-fac2bacca571
  modified: 2026-08-06T09:53:30.159Z
---

The root filesystem is 233 GB with ~210 GB of the user's own data, leaving 2-12 GB free at any
moment. Two builds died on `No space left on device` during the Stacks engagement (a `stackslib`
test binary was never produced as a result), and three cleanup rounds were needed across one
session.

**Why:** bounty work on these targets means compiling large trees — `stacks-core` produces a ~4 GB
`target/`, and a `cosmos/evm` `evmd` integration build regenerates ~4.7 GB of Go build cache. Either
one alone can exhaust the free space.

**How to apply:** check `df -h` before starting any build, not after it fails. Reclaim only your own
artifacts — `rm -rf <repo>/target` and `go clean -cache` are safe and rebuildable. Do NOT run
`go clean -modcache` (~5.4 GB) without asking: it forces a full re-download before anything can run
again. Never touch other sessions' scratchpads under `/tmp/claude-1000/`. Clean up at the end of a
target, not just when blocked. Related: [[bounty-notes-live-in-submissions]].
