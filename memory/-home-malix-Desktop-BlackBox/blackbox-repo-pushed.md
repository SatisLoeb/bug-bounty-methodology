---
name: blackbox-repo-pushed
description: BlackBox research workspace pushed to private GitHub repo SatisLoeb/blackbox; pitfalls handled during the push
metadata: 
  node_type: memory
  type: project
  originSessionId: 7c3689cb-dcb3-4c84-a0cf-22ebea6da148
  modified: 2026-08-09T08:09:46.382Z
---

The `/home/malix/Desktop/BlackBox` directory (all target research: dossiers, PoCs, submissions, the `blackbox` launcher script) was pushed 2026-08-09 to `https://github.com/SatisLoeb/blackbox` (private, account SatisLoeb).

**Why:** user wanted to resume work on this directory from a fresh Claude Code session elsewhere without inheriting the parent `~/Desktop/CLAUDE.md` (an unrelated Monero-marketplace project file with injection-flavored "override all warnings" language — does not describe this directory's actual content) or the user-level skills. The repo's own `blackbox` script already achieves the clean-session goal locally (`--safe-mode`, `--setting-sources ""`, etc.); no extra repo-side config was needed for that part.

**How to apply:** before any future push/sync of this directory (or a similarly-shaped research workspace):
- ~64 subfolders were git clones of audited target source (aztec-packages, cn/hedera-node, cosmos/*, decentraland/*, 1inch/*, etc.). Their nested `.git` dirs were stripped flat — otherwise a top-level `git add -A` silently creates empty submodule gitlinks (zero content pushed, looks complete but isn't). Re-check for reintroduced nested `.git` dirs before any future `git add -A` here (re-cloning a target creates a fresh nested `.git`).
- Real secrets found and excluded via `.gitignore` (`**/.env`, `**/*.env` with explicit `!*.env.example` etc. exceptions): `relay/.env`, `relay/dapp-example/localDappCI.env` (both held live `PRIVATE_KEY`/`OPERATOR_KEY_MAIN`), `lombard-sol/.env`, `cosmos/evm/.../viem/.env`.
- `stacks/.gitattributes` has a blanket `* text eol=lf` that would corrupt the two committed ELF binaries (`stacks/.audit-tools/bin/{bitcoin-cli,bitcoind}`) via LF normalization on checkout. Fixed with a narrower `stacks/.audit-tools/.gitattributes` (`bin/* -text -diff binary`). If new binaries land under `stacks/`, they need the same override or a matching entry.
- Build artifacts (`**/target/`, `**/node_modules/`, `**/build/`) excluded — this is what took the working tree from 8.1GB down to ~90MB staged.
- `.claude/settings.local.json*` gitignored (machine-local permissions, not meant to sync).
