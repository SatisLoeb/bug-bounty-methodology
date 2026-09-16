#!/usr/bin/env bash
# Reconstitute a working bug-bounty methodology environment from this kit on a fresh machine.
# The inverse of sync.sh: sync.sh EXPORTS live -> kit; bootstrap.sh IMPORTS kit -> a new env.
#
# Usage:
#   ./bootstrap.sh              # do it
#   ./bootstrap.sh --dry        # print what it would do, change nothing
#   ./bootstrap.sh --force-claude-md   # also overwrite workspace CLAUDE.md from the kit
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
DRY=""; FORCE_MD=""
for a in "$@"; do
  [ "$a" = "--dry" ] && DRY=1
  [ "$a" = "--force-claude-md" ] && FORCE_MD=1
done
run(){ if [ -n "$DRY" ]; then echo "DRY: $*"; else eval "$@"; fi; }
say(){ printf '\n=== %s ===\n' "$*"; }

CLAUDE_SKILLS="$HOME/.claude/skills"
PROJECTS="$HOME/.claude/projects"
STAMP="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || echo backup)"

say "1. Skills -> $CLAUDE_SKILLS (symlink; skip account-synced + backups)"
run "mkdir -p '$CLAUDE_SKILLS'"
for d in "$KIT"/skills/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  case "$name" in
    synced|.darkside-*backup*) echo "  skip $name (account-managed / backup)"; continue;;
  esac
  tgt="$CLAUDE_SKILLS/$name"
  if [ -e "$tgt" ] && [ ! -L "$tgt" ]; then run "mv '$tgt' '$tgt.pre-bootstrap.$STAMP'"; fi
  run "ln -sfn '$d' '$tgt'"
  echo "  linked $name"
done

say "2. Memories -> $PROJECTS/<proj>/memory  (keyed by absolute workspace path)"
for md in "$KIT"/memory/*/; do
  [ -d "$md" ] || continue
  proj="$(basename "$md")"
  tgt="$PROJECTS/$proj/memory"
  run "mkdir -p '$tgt'"
  run "cp -rn '$md'. '$tgt'/"   # -n = never clobber a newer local memory
  echo "  restored $proj ($(ls "$md"*.md 2>/dev/null | wc -l | tr -d ' ') files)"
done
echo "  NOTE: memory dirs are keyed by the workspace's absolute path hash (e.g. -home-malix-Desktop-D-cve)."
echo "        Same user + same ~/Desktop layout  -> restored as-is above."
echo "        Different user/paths -> rename kit/memory/<proj> to the new hash, OR open Claude in the"
echo "        workspace and use the 'import-memory' skill to merge kit memories into the current project."

say "3. Workspace CLAUDE.md"
if [ -n "$FORCE_MD" ]; then
  [ -f "$KIT/claude-md/CLAUDE-Desktop.md" ] && run "cp '$KIT/claude-md/CLAUDE-Desktop.md' '$HOME/Desktop/CLAUDE.md'" && echo "  wrote ~/Desktop/CLAUDE.md"
  [ -f "$KIT/claude-md/CLAUDE-BUGS.md" ] && [ -d "$HOME/Desktop/BUGS" ] && run "cp '$KIT/claude-md/CLAUDE-BUGS.md' '$HOME/Desktop/BUGS/CLAUDE.md'" && echo "  wrote ~/Desktop/BUGS/CLAUDE.md"
else
  echo "  skipped (pass --force-claude-md to overwrite workspace CLAUDE.md from the kit)"
fi

say "4. Toolchain check (the method needs these live)"
command -v git      >/dev/null && echo "  git OK"      || echo "  MISSING git"
command -v python3  >/dev/null && echo "  python3 OK"  || echo "  MISSING python3 (tools/stacks-read.py, evm-anchor)"
command -v gh       >/dev/null && echo "  gh OK"       || echo "  MISSING gh (needed for repo visibility checks + sync push)"
if command -v cast >/dev/null; then echo "  foundry/cast OK"; else
  echo "  MISSING foundry/cast  -> curl -L https://foundry.paradigm.xyz | bash && foundryup"
fi
[ -n "${ETHERSCAN_API_KEY:-}" ] && echo "  ETHERSCAN_API_KEY set" || echo "  ETHERSCAN_API_KEY NOT set  -> export it (EVM verified-source + anchor fetches)"
echo "  ETH RPC: export a working endpoint (e.g. https://ethereum.publicnode.com) for cast reads"

say "Done"
cat <<EOF
  Playbook (methodology):  $KIT/methodology/playbook-bug-bounty-v1.6.md
  Gate-runner:             $KIT/methodology/finding-acceptance-standard.md
  Reusable gated fanout:   $KIT/workflows/audit-fanout-template.js
  On-chain tools:          $KIT/tools/
  Drift-watch system:      $KIT/drift-watch/   (daily cloud routine is env-independent already)
  To re-export live->kit:  ./sync.sh
EOF
