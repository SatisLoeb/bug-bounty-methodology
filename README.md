# Bug Bounty Methodology — private kit

Private, portable kit for the whole hunting method. **No target workspaces, no PoCs, no secrets.**
The point: on any new machine, `git clone` + `./bootstrap.sh` reconstitutes a working environment.

## Layout
- `methodology/` — the playbook (`playbook-bug-bounty-v1.6.md`), the operational **gate-runner** (`finding-acceptance-standard.md`), hunt checklists, report/disclosure templates, standards.
- `workflows/` — reusable **gated fan-out** (`audit-fanout-template.js`): finders → 3-axis playbook gate → PLAYBOOK-AUDIT. Parameterized via `args` (self-bootstrapping: clones the repo + fetches deployed source + census on-chain).
- `drift-watch/` — the daily drift-watch system (scripts, watchlists, triggers, and the env-independent **cloud-routine prompt**). Logs excluded.
- `tools/` — on-chain helpers: `stacks-read.py` (Clarity/Hiro), `evm-anchor.sh` (proxy→impl, Etherscan-v2 verified source, TVL census).
- `skills/` — Claude Code skills (darkside, firmaudit, gravedigger, chill, report-nerve, nexus, nullguard, extract, xseam, nuke, …). `skills/synced/` is account-managed (skip on bootstrap).
- `memory/` — accumulated lessons, **namespaced by workspace path** (`-home-<user>-Desktop-<X>/`). This is the non-obvious portability piece: Claude Code keys memory by absolute path.
- `claude-md/` — workspace CLAUDE.md (Desktop + BUGS) + rules/agents.
- `arsenal/` — executable methodology (audit-lifecycle scripts, profiles, checklists).

Excluded by design (`.gitignore` + `sync.sh` scrub): `*-audit/`/`*-recon/` target workspaces, findings/PoCs, tracking files (OUTCOMES/QUEUE/INCOME/…), cloned repos, key material.

## The two directions
- **`./sync.sh`** — EXPORT: live sources (`~/.claude/skills`, `~/.claude/projects/*/memory`, `~/Desktop/D-cve/playbook`, `~/Desktop/drift-watch`, `~/Desktop/CLAUDE.md`, arsenal) → this kit, scrubbed, then commit + push. Run it after any methodology change. `--dry` to preview.
- **`./bootstrap.sh`** — IMPORT (new machine): kit → a working env. Symlinks skills into `~/.claude/skills`, restores memories into `~/.claude/projects/<hash>/memory`, checks toolchain (git/python3/gh/foundry-cast/`ETHERSCAN_API_KEY`/RPC). `--dry` to preview; `--force-claude-md` to overwrite workspace CLAUDE.md.

## Bootstrap a new machine
```
git clone https://github.com/SatisLoeb/bug-bounty-methodology.git
cd bug-bounty-methodology
./bootstrap.sh --dry     # preview
./bootstrap.sh           # do it
export ETHERSCAN_API_KEY=...   # for EVM anchor/source fetches
```
Memory note: memories restore cleanly when the new machine uses the same user + `~/Desktop/<X>` layout (same path hash). Different paths → rename `memory/<proj>` to the new hash, or use the `import-memory` Claude skill to merge into the current project. The drift-watch **cloud routine** is already environment-independent (runs in Anthropic cloud).
