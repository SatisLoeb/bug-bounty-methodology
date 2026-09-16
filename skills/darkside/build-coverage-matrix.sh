#!/usr/bin/env bash
# build-coverage-matrix.sh — Door A skeleton generator for the darkside skill.
#
# Emits the {money-path fn × attacked-by-an-adversarial-test? Y/N} matrix skeleton so Door A starts
# from a pre-filled worklist instead of a blank page. This is a HEURISTIC SCAFFOLDER, not a verdict:
# the N column it prints is a STARTING worklist to reason over, and every Y is a NAME-MATCH only
# (an adversarial test mentions the fn), NOT proof the test actually attacks it — you still confirm
# the boundary by hand (Door A discipline: execute their tests, then step one sibling past). It never
# writes into the target; output goes to stdout (redirect it into analysis/DEFENSIVE-COVERAGE-MATRIX.md).
#
# Usage:  ./build-coverage-matrix.sh [TARGET_DIR]      (default: .)
#         ./build-coverage-matrix.sh ~/src/foo > analysis/DEFENSIVE-COVERAGE-MATRIX.md
#
# OPSEC: read-only, no network, no writes to the target tree.

set -euo pipefail

ROOT="${1:-.}"
[ -d "$ROOT" ] || { echo "error: '$ROOT' is not a directory" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

# ---- search wrappers (pure grep — no dependency on `rg`, which is a shell function, not a PATH
#      binary, so a shebang-launched script cannot see it). All patterns are case-insensitive. -----
EXCL=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=out --exclude-dir=cache
      --exclude-dir=target --exclude-dir=build --exclude-dir=coverage --exclude-dir=dist
      --exclude-dir=broadcast --exclude-dir=.github)

# RG PATTERN [PATH]  -> grep -rn (file:line:content). PATH defaults to $ROOT. A leading -e is ignored.
RG() {
  local pat="" path="" a
  for a in "$@"; do case "$a" in -e) ;; *) if [ -z "$pat" ]; then pat="$a"; else path="$a"; fi;; esac; done
  grep -rniE "${EXCL[@]}" -- "$pat" "${path:-$ROOT}" 2>/dev/null || true
}
# RGL PATTERN [PATH] -> grep -rl (file list). PATH defaults to $ROOT. A leading -e is ignored.
RGL() {
  local pat="" path="" a
  for a in "$@"; do case "$a" in -e) ;; *) if [ -z "$pat" ]; then pat="$a"; else path="$a"; fi;; esac; done
  grep -rliE "${EXCL[@]}" -- "$pat" "${path:-$ROOT}" 2>/dev/null || true
}

# ---- ecosystem detection -----------------------------------------------------------------------
ECO="unknown"
if   ls "$ROOT"/foundry.toml >/dev/null 2>&1 || find "$ROOT" -maxdepth 3 -name '*.sol' -print -quit 2>/dev/null | grep -q .; then ECO="solidity"
elif ls "$ROOT"/go.mod         >/dev/null 2>&1; then ECO="go"
elif ls "$ROOT"/Cargo.toml     >/dev/null 2>&1; then ECO="rust"
elif ls "$ROOT"/package.json   >/dev/null 2>&1; then ECO="web"
fi

# ---- money-path function name lexicon (rows of the matrix) --------------------------------------
MONEY='mint|burn|redeem|withdraw|deposit|transfer(From)?|liquidat|settle|auction|socializ|reroute|claim|borrow|repay|swap|flash[Ll]oan|accru|realize|distribut|sharePrice|convertTo(Assets|Shares)|preview(Redeem|Withdraw|Deposit|Mint)|updateTotalAssets|totalAssets|setFee|grantRole|revokeRole|setOwner|transferOwnership|_update|rebase|slash|unstake'

# ---- adversarial-test tells (case-insensitive; the tell word appears ANYWHERE in the test name) --
# rg supports (?i) inline; the grep fallback below sets -i on the whole match instead.
ADV_GO='t\.Run\("[^"]*(attack|exploit|malicious|adversar|overflow|reentr|griefing|halt|dos|drain|steal|panic)|func Test[A-Za-z0-9_]*(Attack|Exploit|Malicious|Security|Invariant|Fuzz|Revert|Fail|Unauthor|Overflow|Reentr|Drain|Steal)'
ADV_SOL='function [A-Za-z0-9_]*(Attack|Exploit|Revert|Cannot|Fail|Steal|Drain|Reentr|Overflow|Unauthor|Invariant|Fuzz|Malicious|Griefing|Insolven|BadDebt)|function (invariant|testFuzz|testFail|test_Revert)'
ADV_RUST='#\[test\]|proptest|fn [a-z0-9_]*(attack|exploit|malicious|revert|panic|overflow|unauth|reentr)'
ADV_WEB='(unauth|idor|bola|bypass|escalat|tenant|cross-account|attacker|malicious|replay|forbidden|401|403)'

case "$ECO" in
  go)       ADV_PAT="$ADV_GO" ;;
  solidity) ADV_PAT="$ADV_SOL" ;;
  rust)     ADV_PAT="$ADV_RUST" ;;
  web)      ADV_PAT="$ADV_WEB" ;;
  *)        ADV_PAT="$ADV_GO|$ADV_SOL|$ADV_WEB" ;;
esac

# ---- gather adversarial test files -------------------------------------------------------------
ADV_FILES="$(
  { RGL -e "$ADV_PAT" "$ROOT" 2>/dev/null || true; } \
  | grep -Ei '(test|spec|security|attack|exploit|invariant|integration|fuzz)' | sort -u || true
)"

# ---- helpers -----------------------------------------------------------------------------------
is_test_path() { echo "$1" | grep -Eiq '(/test/|/tests/|_test\.|\.t\.sol|\.spec\.|/mock|/interchaintest/)'; }

echo "# DEFENSIVE-COVERAGE-MATRIX (Door A skeleton) — $(basename "$ROOT")"
echo
echo "- generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) · ecosystem: **$ECO** · root: \`$ROOT\`"
echo "- **This is a SKELETON, not a verdict.** \`Y\` = an adversarial test file NAME-references the fn"
echo "  (not proof it attacks it). \`N\` = no adversarial test names it = the **bounded worklist**."
echo "- Door A discipline: execute the Y tests to confirm the boundary, then step one **sibling** past"
echo "  the boundary (the untested sibling at the same pattern is the candidate). See \`CASE-injective-voucher\`."
echo

# ---- section 1: the adversarial tests found ----------------------------------------------------
echo "## 1. Adversarial tests located (the map of what the devs feared)"
echo
if [ -z "$ADV_FILES" ]; then
  echo "> **NONE found.** Door A is empty/absent on this target → fall to **Door B** (dev-paranoia-map:"
  echo "> grep fear-comments + invariant runners) and lean on the **thief-inventory admission gate** as the"
  echo "> primary bound. For a web target, the pentest report's tested-endpoint list IS this matrix if one exists."
  echo
else
  echo '```'
  echo "$ADV_FILES" | sed "s#^$ROOT/##"
  echo '```'
  echo
  echo "Adversarial test names (grep tells):"
  echo '```'
  echo "$ADV_FILES" | while IFS= read -r f; do [ -n "$f" ] && RG -e "$ADV_PAT" "$f" 2>/dev/null | sed "s#^$ROOT/##"; done | head -120
  echo '```'
  echo
fi

# ---- section 2: money-path functions (the rows) ------------------------------------------------
echo "## 2. Money-path functions × covered-by-adversarial-test?"
echo
printf '| money-path fn | defined at | adversarial test? | note |\n'
printf '|---|---|---|---|\n'

# collect candidate money-path definition sites from non-test source
DEFS="$(RG -e "($MONEY)" "$ROOT" 2>/dev/null | grep -E '\.(sol|go|rs|ts):' || true)"

# reduce to plausible *definitions* (fn/func/def lines) and dedup by fn name
printf '%s\n' "$DEFS" \
 | grep -Ei '(function |func |fn |def |pub fn )' \
 | while IFS= read -r line; do
     file="${line%%:*}"; rest="${line#*:}"; lineno="${rest%%:*}"; body="${rest#*:}"
     is_test_path "$file" && continue
     # extract a fn name near a money keyword
     name="$(printf '%s' "$body" | grep -oiE "([A-Za-z_]*($MONEY)[A-Za-z_0-9]*)" | head -1)"
     [ -z "$name" ] && continue
     printf '%s\t%s\t%s\n' "$name" "${file#"$ROOT"/}" "$lineno"
   done \
 | sort -u -t$'\t' -k1,1 \
 | while IFS=$'\t' read -r name file lineno; do
     [ -z "$name" ] && continue
     cov="N"
     if [ -n "$ADV_FILES" ]; then
       # Y iff the fn's core name (leading underscores stripped) appears inside any adversarial test
       # file. Substring, case-insensitive — camelCase test names embed the fn without word
       # boundaries (`testBorrowUnauthorized` contains `borrow`), so `-w` would wrongly miss them.
       # NB: a here-string loop (no `... | grep -q`) — grep -q exits early, SIGPIPEs the upstream
       # stage, and under `set -o pipefail` that made the whole `if` test non-zero → false N.
       sname="${name#_}"; sname="${sname#_}"
       while IFS= read -r tf; do
         [ -n "$tf" ] || continue
         if grep -qi -- "$sname" "$tf" 2>/dev/null; then cov="Y"; break; fi
       done <<< "$ADV_FILES"
     fi
     flag=""; [ "$cov" = "N" ] && flag="**← N-cell: worklist**"
     printf '| `%s` | %s:%s | %s | %s |\n' "$name" "$file" "$lineno" "$cov" "$flag"
   done

echo
echo "## 3. Next steps (Door A conveyor)"
echo
echo "1. For each **N-cell**, find its STRUCTURAL SIBLING among the Y rows (same pattern/accounting"
echo "   primitive applied to a different denom/asset/role/path). The tested sibling held; the untested"
echo "   one is the candidate. (\`CASE-injective-voucher\`: 4 halt-tests held, the untested voucher sibling"
echo "   was the only Critical.)"
echo "2. Each surviving candidate → the **THIEF-INVENTORY** (templates/THIEF-INVENTORY.md), admission"
echo "   gate = chains-to-a-payable-impact (fund-movement OR a family-B capability)."
echo "3. Then the manual loop (SKILL.md §4) with an unbiased \`loss=\$X\` PoC before any verdict."
