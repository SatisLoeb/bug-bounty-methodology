#!/bin/bash
# dep-audit.sh — Dependency Zero-Day Audit Tool
# Maps all dependencies, versions, CVEs, fork diffs
# Outputs DEPENDENCY-AUDIT.md
#
# Usage: ./dep-audit.sh <project-dir> --lang sol|rs|go
#
# Phase 0.7 of MrRobbot methodology
# Battle-tested on Reserve Protocol ($10M bounty)
# Result: correctly identified all deps as battle-tested (OZ, Aave, Chainlink) → SKIP in <30min

set -euo pipefail

PROJECT_DIR="${1:-.}"
LANG="sol"
OUTPUT="DEPENDENCY-AUDIT.md"

while [[ $# -gt 0 ]]; do
    case $1 in
        --lang) LANG="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done

echo "# Dependency Zero-Day Audit" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "> Generated: $(date -u '+%Y-%m-%d %H:%M UTC')" >> "$OUTPUT"
echo "> Project: $PROJECT_DIR" >> "$OUTPUT"
echo "> Language: $LANG" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# ============================================================
# SOLIDITY
# ============================================================
if [[ "$LANG" == "sol" ]]; then

    echo "## 1. Package Dependencies" >> "$OUTPUT"
    echo "" >> "$OUTPUT"

    # Extract from package.json
    if [[ -f "$PROJECT_DIR/package.json" ]]; then
        echo "### package.json" >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
        python3 -c "
import json, sys
with open('$PROJECT_DIR/package.json') as f:
    d = json.load(f)
deps = {**d.get('dependencies', {}), **d.get('devDependencies', {})}
for k, v in sorted(deps.items()):
    # Flag security-relevant deps
    flag = ''
    if any(x in k.lower() for x in ['openzeppelin', 'chainlink', 'aave', 'uniswap', 'compound', 'curve', 'solmate', 'solady']):
        flag = ' [WELL-AUDITED]'
    elif 'mock' not in k.lower() and 'test' not in k.lower():
        flag = ' [CHECK]'
    print(f'{k}: {v}{flag}')
" 2>/dev/null || echo "  (parse error)"
        echo '```' >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    fi

    # Extract from remappings.txt
    if [[ -f "$PROJECT_DIR/remappings.txt" ]]; then
        echo "### remappings.txt" >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
        cat "$PROJECT_DIR/remappings.txt"  >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    fi

    # Check foundry.toml for libs
    if [[ -f "$PROJECT_DIR/foundry.toml" ]]; then
        echo "### foundry.toml libs" >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
        grep -E "libs|remappings|dependencies" "$PROJECT_DIR/foundry.toml" 2>/dev/null >> "$OUTPUT" || echo "  (no lib config found)"
        echo '```' >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    fi

    echo "## 2. Vendor Files (Forked/Copied Code)" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "| File | LOC | Modification Signals |" >> "$OUTPUT"
    echo "|------|-----|---------------------|" >> "$OUTPUT"

    # Find vendor directories
    find "$PROJECT_DIR/contracts" -path "*/vendor/*" -name "*.sol" 2>/dev/null | while read f; do
        loc=$(wc -l < "$f")
        # Check for modification comments
        mods=$(grep -ci "modified\|changed\|custom\|added by\|our change\|reserve\|fork" "$f" 2>/dev/null || echo "0")
        if [[ "$mods" -gt 0 ]]; then
            echo "| $(basename "$f") | $loc | **$mods modification signals** |" >> "$OUTPUT"
        else
            echo "| $(basename "$f") | $loc | clean copy |" >> "$OUTPUT"
        fi
    done

    echo "" >> "$OUTPUT"

    echo "## 3. Pragma Versions (Old Compiler = Risk)" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    grep -rh "pragma solidity" "$PROJECT_DIR/contracts" --include="*.sol" 2>/dev/null | sort | uniq -c | sort -rn >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    echo "" >> "$OUTPUT"

    echo "## 4. CVE Check" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    if command -v npm &>/dev/null && [[ -f "$PROJECT_DIR/package.json" ]]; then
        echo '```' >> "$OUTPUT"
        cd "$PROJECT_DIR" && npm audit --json 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    vulns = d.get('vulnerabilities', {})
    if not vulns:
        print('No known CVEs found.')
    else:
        for name, info in vulns.items():
            sev = info.get('severity', 'unknown')
            print(f'{name}: {sev} — {info.get(\"title\", \"\")}')
except:
    print('npm audit not available or parse error')
" >> "$OUTPUT" 2>/dev/null || echo "npm audit failed" >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
    else
        echo "npm not available — manual CVE check required" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"

    echo "## 5. Decision" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "- [ ] All deps battle-tested → SKIP dep deep-dive" >> "$OUTPUT"
    echo "- [ ] Obscure/forked dep found → DEEP DIVE (list which)" >> "$OUTPUT"
    echo "- [ ] Outdated version with CVE → INVESTIGATE" >> "$OUTPUT"
    echo "- [ ] Custom math/crypto lib → FUZZ in Phase 2" >> "$OUTPUT"

# ============================================================
# RUST
# ============================================================
elif [[ "$LANG" == "rs" ]]; then

    echo "## 1. Cargo Dependencies" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
        echo '```' >> "$OUTPUT"
        grep -A 100 "\[dependencies\]" "$PROJECT_DIR/Cargo.toml" | grep -E "^[a-zA-Z]" | head -50 >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"

    echo "## 2. Cargo Audit" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    if command -v cargo-audit &>/dev/null; then
        echo '```' >> "$OUTPUT"
        cd "$PROJECT_DIR" && cargo audit 2>&1 | head -50 >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
    else
        echo "cargo-audit not installed — run: cargo install cargo-audit" >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"

    echo "## 3. Decision" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "- [ ] All deps well-known → SKIP" >> "$OUTPUT"
    echo "- [ ] Custom crypto crate found → DEEP DIVE + FUZZ" >> "$OUTPUT"

# ============================================================
# GO
# ============================================================
elif [[ "$LANG" == "go" ]]; then

    echo "## 1. Go Dependencies" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    if [[ -f "$PROJECT_DIR/go.mod" ]]; then
        echo '```' >> "$OUTPUT"
        grep -E "^\t" "$PROJECT_DIR/go.mod" | head -50 >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
    fi
    echo "" >> "$OUTPUT"

    echo "## 2. govulncheck" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    if command -v govulncheck &>/dev/null; then
        echo '```' >> "$OUTPUT"
        cd "$PROJECT_DIR" && govulncheck ./... 2>&1 | head -50 >> "$OUTPUT"
        echo '```' >> "$OUTPUT"
    else
        echo "govulncheck not installed — run: go install golang.org/x/vuln/cmd/govulncheck@latest" >> "$OUTPUT"
    fi

    echo "" >> "$OUTPUT"
    echo "## 3. Decision" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "- [ ] All deps well-known → SKIP" >> "$OUTPUT"
    echo "- [ ] Custom p2p/consensus lib → DEEP DIVE + FUZZ" >> "$OUTPUT"

fi

echo ""
echo "=== Dependency audit complete ==="
echo "Output: $OUTPUT"
echo "Next: review $OUTPUT and decide SKIP or DEEP DIVE"
