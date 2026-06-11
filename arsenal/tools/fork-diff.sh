#!/bin/bash
# fork-diff.sh — Security-focused diff between a fork and its parent protocol
# Usage: ./fork-diff.sh <local_fork_dir> <parent_repo_url> [--branch main]
#
# Clones the parent, diffs only source files (.sol/.rs/.go/.cairo),
# filters cosmetic changes, highlights security-relevant modifications.

set -uo pipefail

LOCAL_DIR="${1:?Usage: fork-diff.sh <local_fork_dir> <parent_repo_url> [--branch main]}"
PARENT_URL="${2:?Usage: fork-diff.sh <local_fork_dir> <parent_repo_url> [--branch main]}"
BRANCH="main"

shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

TMPDIR=$(mktemp -d)
PARENT_DIR="$TMPDIR/parent"

echo "========================================"
echo " Fork Diff — Security Focus"
echo " Fork:   $LOCAL_DIR"
echo " Parent: $PARENT_URL ($BRANCH)"
echo "========================================"
echo ""

# Clone parent
echo "[1/5] Cloning parent repo..."
git clone --depth 1 --branch "$BRANCH" "$PARENT_URL" "$PARENT_DIR" 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "Failed to clone parent. Trying without --branch..."
  git clone --depth 1 "$PARENT_URL" "$PARENT_DIR" 2>/dev/null || { echo "Clone failed"; exit 1; }
fi
echo "Done."
echo ""

# Find common source directories
echo "[2/5] Finding common source files..."
EXTENSIONS="sol rs go cairo move ts"
COMMON_FILES=()

for ext in $EXTENSIONS; do
  while IFS= read -r fork_file; do
    # Strip the local dir prefix to get relative path
    rel_path="${fork_file#$LOCAL_DIR/}"
    parent_file="$PARENT_DIR/$rel_path"
    if [[ -f "$parent_file" ]]; then
      COMMON_FILES+=("$rel_path")
    fi
  done < <(find "$LOCAL_DIR" -name "*.$ext" ! -path "*/node_modules/*" ! -path "*/target/*" ! -path "*/lib/*" ! -path "*test*" ! -path "*mock*" 2>/dev/null)
done

echo "Found ${#COMMON_FILES[@]} common source files."
echo ""

# New files in fork (not in parent)
echo "[3/5] Files ADDED in fork (not in parent)..."
NEW_FILES=0
for ext in $EXTENSIONS; do
  while IFS= read -r fork_file; do
    rel_path="${fork_file#$LOCAL_DIR/}"
    parent_file="$PARENT_DIR/$rel_path"
    if [[ ! -f "$parent_file" ]]; then
      echo -e "  ${GREEN}+ $rel_path${NC}"
      NEW_FILES=$((NEW_FILES + 1))
    fi
  done < <(find "$LOCAL_DIR" -name "*.$ext" ! -path "*/node_modules/*" ! -path "*/target/*" ! -path "*/lib/*" ! -path "*test*" ! -path "*mock*" 2>/dev/null)
done
echo "Total new files: $NEW_FILES"
echo ""

# Diff common files — security-focused
echo "[4/5] Security-relevant changes in common files..."
echo ""

SECURITY_KEYWORDS="transfer|approve|mint|burn|withdraw|deposit|sign|verify|auth|admin|owner|role|pause|upgrade|proxy|delegate|execute|call\{|selfdestruct|suicide|delegatecall|staticcall|abi\.encode|keccak256|ecrecover|require\(|revert|assert\(|modifier|onlyOwner|onlyAdmin|nonReentrant|initializ|constructor|receive\(\)|fallback\(\)"

CHANGED_FILES=0
SECURITY_CHANGES=0

for rel_path in "${COMMON_FILES[@]}"; do
  fork_file="$LOCAL_DIR/$rel_path"
  parent_file="$PARENT_DIR/$rel_path"

  # Get the diff, ignoring whitespace and comments
  diff_output=$(diff -u "$parent_file" "$fork_file" 2>/dev/null | grep "^[+-]" | grep -v "^[+-][+-][+-]" | grep -v "^[+-]\s*$" | grep -v "^[+-]\s*//" | grep -v "^[+-]\s*\*")

  if [[ -n "$diff_output" ]]; then
    CHANGED_FILES=$((CHANGED_FILES + 1))

    # Check if any changes are security-relevant
    security_hits=$(echo "$diff_output" | grep -iE "$SECURITY_KEYWORDS" 2>/dev/null)

    if [[ -n "$security_hits" ]]; then
      SECURITY_CHANGES=$((SECURITY_CHANGES + 1))
      hit_count=$(echo "$security_hits" | wc -l)
      echo -e "${RED}[SECURITY] $rel_path${NC} ($hit_count security-relevant changes)"
      echo "$security_hits" | head -10 | sed 's/^/  /'
      [[ $(echo "$security_hits" | wc -l) -gt 10 ]] && echo "  ... and more"
      echo ""
    else
      echo -e "${YELLOW}[CHANGED] $rel_path${NC} (cosmetic/non-security changes)"
    fi
  fi
done

echo ""

# Summary
echo "[5/5] Summary"
echo "========================================"
echo -e " Common files:          ${#COMMON_FILES[@]}"
echo -e " New files in fork:     ${GREEN}$NEW_FILES${NC}"
echo -e " Changed files:         ${YELLOW}$CHANGED_FILES${NC}"
echo -e " Security-relevant:     ${RED}$SECURITY_CHANGES${NC}"
echo "========================================"
echo ""
echo "Priority: Read the ${RED}[SECURITY]${NC} files first, then ${GREEN}new files${NC}."

# Cleanup
rm -rf "$TMPDIR"
