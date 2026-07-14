#!/usr/bin/env bash
# sync-skills.sh — keep the 3 skill locations aligned.
#
#   SOURCE OF TRUTH : ~/Desktop/methodology-backup/skills   (git; never auto-written)
#   WORKING COPY    : ~/arsenal/skills
#   LOADABLE BY CC  : ~/.claude/skills                       (what Claude Code scans)
#
# Flow (default):  backup ──► arsenal ──► ~/.claude/skills
# Every skill is YAML-validated BEFORE it is installed into the loadable dir,
# so a broken frontmatter is reported and skipped, never silently shipped.
#
# Usage:
#   sync-skills.sh                      # backup -> arsenal + ~/.claude/skills (additive)
#   sync-skills.sh --from=arsenal       # arsenal -> ~/.claude/skills (e.g. after live-editing in arsenal)
#   sync-skills.sh --from=load          # ~/.claude/skills -> arsenal (rare)
#   sync-skills.sh --mirror             # also DELETE skills in targets that no longer exist in source
#   sync-skills.sh --dry-run            # show what would change, write nothing
#
set -euo pipefail

BACKUP="$HOME/Desktop/methodology-backup/skills"
ARSENAL="$HOME/arsenal/skills"
LOAD="$HOME/.claude/skills"
EXCLUDES=(--exclude='*.bak-frontmatter' --exclude='*.bak' --exclude='*.tar.gz' --exclude='.git')

SRC_NAME="backup"; MIRROR=0; DRY=0
for a in "$@"; do
  case "$a" in
    --from=*) SRC_NAME="${a#--from=}";;
    --mirror) MIRROR=1;;
    --dry-run|-n) DRY=1;;
    -h|--help) sed -n '2,28p' "$0"; exit 0;;
    *) echo "unknown arg: $a (try --help)"; exit 1;;
  esac
done

case "$SRC_NAME" in
  backup)  SRC="$BACKUP";;
  arsenal) SRC="$ARSENAL";;
  load)    SRC="$LOAD";;
  *) echo "bad --from='$SRC_NAME' (backup|arsenal|load)"; exit 1;;
esac
[ -d "$SRC" ] || { echo "FATAL: source missing: $SRC"; exit 1; }

# Targets = {arsenal, load} minus the source. The git backup is NEVER an auto target.
TARGETS=()
for t in "$ARSENAL" "$LOAD"; do [ "$t" = "$SRC" ] || TARGETS+=("$t"); done

command -v rsync >/dev/null 2>&1 || { echo "FATAL: rsync required"; exit 1; }
RSYNC=(rsync -a "${EXCLUDES[@]}"); [ "$MIRROR" = 1 ] && RSYNC+=(--delete)
[ "$DRY" = 1 ] && RSYNC+=(-n --itemize-changes)

# --- validate a single skill dir: SKILL.md present + valid YAML frontmatter with name+description ---
validate_skill() {  # $1 = skill dir ; echoes "<name>" on success, returns 1 on failure
  local d="$1" sk="$1/SKILL.md"
  [ -f "$sk" ] || { echo "no SKILL.md"; return 1; }
  python3 - "$sk" <<'PY'
import sys,yaml
p=sys.argv[1]; t=open(p,encoding="utf-8",errors="ignore").read()
if not t.startswith("---"): print("no frontmatter"); sys.exit(1)
end=t.find("\n---",3)
if end<0: print("unterminated frontmatter"); sys.exit(1)
try: m=yaml.safe_load(t[3:end])
except Exception as e: print("bad yaml: "+str(e).split(chr(10))[0][:50]); sys.exit(1)
if not isinstance(m,dict) or not m.get("name") or not m.get("description"):
    print("missing name/description"); sys.exit(1)
print(m["name"]); sys.exit(0)
PY
}

echo "── sync-skills ── source=$SRC_NAME  mirror=$MIRROR  dry-run=$DRY"
echo "   SRC: $SRC"

# Externally-managed skills (live in ~/.agents or on machine-2): never mirror-deleted.
KEEP_EXTRA=("find-skills")

# 1. validate every skill in source
declare -a VALID=() NAMES=() INVALID=()
for d in "$SRC"/*/; do
  [ -d "$d" ] || continue          # skips broken symlinks (not real dirs)
  if name="$(validate_skill "$d" 2>/dev/null)"; then
    VALID+=("$(basename "$d")"); NAMES+=("$name")
  else
    INVALID+=("$(basename "$d"): $(validate_skill "$d" 2>&1 | tail -1)")
  fi
done
echo "   valid: ${#VALID[@]}   invalid: ${#INVALID[@]}"
if [ "${#INVALID[@]}" -gt 0 ]; then
  printf '   ⚠ SKIPPED (broken frontmatter, NOT installed): %s\n' "${INVALID[@]}"
fi

# 2. sync to each target
for T in "${TARGETS[@]}"; do
  mkdir -p "$T"
  if [ "$T" = "$LOAD" ]; then
    # loadable dir: install ONLY validated skills (per-skill), so broken ones never ship
    echo "   → $T  (validated skills only)"
    for s in "${VALID[@]}"; do
      "${RSYNC[@]}" "$SRC/$s/" "$T/$s/" >/dev/null
    done
    # ALSO carry top-level shared .md docs (COVERAGE-LEDGER-PLAYBOOK / SURFACE-INVENTORY-PLAYBOOK /
    # DARKSIDE-AUDIT-LOG etc.) referenced by skills at ~/.claude/skills/<FILE>.md. These are NOT skill
    # dirs, so the per-skill loop above misses them — that was the DS-3 sync gap (2026-06-23) which left
    # darkside's MANDATORY coverage-ledger/surface-inventory refs pointing at non-existent files.
    [ "$DRY" = 1 ] || find "$SRC" -maxdepth 1 -name '*.md' -exec cp {} "$T"/ \;
    # in mirror mode, remove loadable skills that are not in VALID
    if [ "$MIRROR" = 1 ]; then
      for d in "$T"/*/; do
        b="$(basename "$d")"
        if ! printf '%s\n' "${VALID[@]}" "${KEEP_EXTRA[@]}" | grep -qx "$b"; then
          echo "     (mirror) removing $b (not in source/valid)"
          [ "$DRY" = 1 ] || rm -rf "$d"
        fi
      done
    fi
  else
    # arsenal working copy: full mirror of source (keeps everything, excludes backups)
    echo "   → $T  (full)"
    "${RSYNC[@]}" "$SRC"/ "$T"/
  fi
done

echo "── done.  Invocable as: $(printf '/%s ' "${NAMES[@]}")"
[ "$DRY" = 1 ] && echo "   (dry-run — nothing written)"
echo "   NOTE: a NEWLY-created ~/.claude/skills needs a Claude Code restart; edits to an existing one hot-load."
