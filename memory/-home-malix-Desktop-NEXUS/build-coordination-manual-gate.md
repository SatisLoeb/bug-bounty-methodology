---
name: build-coordination-manual-gate
description: "Gate every build/deploy on an explicit per-instance go-ahead — the user runs concurrent work on other terminals against the same NEXUS tree and stages changes before building; don't reuse a prior 'build' approval."
metadata:
  node_type: memory
  type: feedback
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-04T02:08:24.979Z
---

The user frequently has concurrent terminals / sessions editing the same NEXUS working tree, and
stages changes there before a build. On 2026-09-04, right after saying "lance le build" they
interrupted: "attend j'ai des modifs a faire sur un autre terminal avant de build je te dirrais quand
lancer."

**Why:** a build (`wasm-pack`, `npm run build`) or deploy captures the current disk state of a shared
tree — running it before the user has staged their other-terminal edits would ship a half-baked tree
or race their work. The `git diff --stat` here already showed many files changed by other
work/sessions (aura/*, static/app/*, index.tsx…), confirming the tree is shared/live.

**How to apply:** before ANY `wasm-pack` / `npm run build` / full `cargo build` / deploy, wait for an
explicit, current go-ahead — even if they approved a build moments earlier and then paused. Do all the
source edits + native/unit tests + typecheck (cheap, non-tree-clobbering) freely; hold the actual
build/deploy for the signal. Relatedly, keep off shared cargo when a peer session is building. See
[[sas-wordlist-impl-2026-09-04]], [[build-oom-server-crate]].
