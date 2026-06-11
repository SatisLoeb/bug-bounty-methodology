#!/usr/bin/env bash
# competition-density.sh — estimate hunter saturation on a bounty program.
#
# Best-effort queries across:
#   - Cantina (HTML parse of competition page)
#   - C4 (public report page)
#   - HackenProof (HTML parse)
#   - H1 hacktivity (public metrics)
#
# Emits submission_count, surface_distribution estimate, verdict.
#
# Usage: competition-density.sh <program-url>
set -euo pipefail

# Parse args
URL=""
MANUAL_SUBMISSIONS=""
MANUAL_RESEARCHERS=""
MANUAL_PLATFORM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --submissions) MANUAL_SUBMISSIONS="$2"; shift 2 ;;
    --researchers) MANUAL_RESEARCHERS="$2"; shift 2 ;;
    --platform)    MANUAL_PLATFORM="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: competition-density.sh <program-url>"
      echo "       competition-density.sh --platform cantina --submissions 104 --researchers 28 <url>"
      exit 0
      ;;
    *) URL="$1"; shift ;;
  esac
done

if [ -z "$URL" ] && [ -z "$MANUAL_PLATFORM" ]; then
  echo "Usage: competition-density.sh <program-url>" >&2
  echo "       competition-density.sh --platform <p> --submissions N --researchers M [url]" >&2
  exit 1
fi

# Manual-override mode — apply verdict heuristic directly
if [ -n "$MANUAL_SUBMISSIONS" ] || [ -n "$MANUAL_RESEARCHERS" ]; then
  sub="${MANUAL_SUBMISSIONS:-0}"
  res="${MANUAL_RESEARCHERS:-0}"
  echo "============================================================"
  echo "  COMPETITION DENSITY (manual input)"
  echo "  platform:    ${MANUAL_PLATFORM:-unknown}"
  echo "  submissions: $sub"
  echo "  researchers: $res"
  echo "  url:         ${URL:-(not provided)}"
  echo "============================================================"
  if [ "$sub" -gt 100 ] || [ "$res" -gt 30 ]; then
    verdict="SATURATED — pivot to off-path surfaces (Web2/API/infra/supply-chain) or skip"
  elif [ "$sub" -gt 30 ] || [ "$res" -gt 10 ]; then
    verdict="CAUTION — known surfaces covered, hunt off-path"
  else
    verdict="GO — low saturation"
  fi
  echo ""
  echo "  verdict: $verdict"
  echo "============================================================"
  exit 0
fi

detect_platform() {
  case "$1" in
    *cantina.xyz*)     echo "cantina" ;;
    *code4rena.com*)   echo "c4" ;;
    *hackerone.com*)   echo "h1" ;;
    *hackenproof.com*) echo "hackenproof" ;;
    *sherlock.xyz*)    echo "sherlock" ;;
    *immunefi.com*)    echo "immunefi" ;;
    *intigriti.com*)   echo "intigriti" ;;
    *)                 echo "unknown" ;;
  esac
}

PLATFORM=$(detect_platform "$URL")

echo "============================================================"
echo "  COMPETITION DENSITY — $URL"
echo "  platform: $PLATFORM"
echo "============================================================"

fetch_with_ua() {
  curl -sS --max-time 15 \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
    -H "Accept: text/html,application/json" \
    "$1"
}

case "$PLATFORM" in
  cantina)
    # Cantina is fully client-rendered + API requires auth.
    # Investigated 2026-04-21: api.cantina.xyz returns {"type":"not_found"} for all public paths.
    # Sitemap gives competition UUIDs but no metadata without auth session.
    echo ""
    echo "  Cantina is a React SPA with auth-gated API. Automatic scrape not supported."
    echo ""
    echo "  Manual workflow:"
    echo "    1. Open the competition page in browser (authenticated session)"
    echo "    2. Read submission count and researcher count from the dashboard"
    echo "    3. Re-run this script with manual flags:"
    echo "       competition-density.sh --platform cantina --submissions N --researchers M $URL"
    echo ""
    echo "  Historical density baselines observed (update as data accumulates):"
    echo "    Polymarket SC (2026-04): ~104 submissions on \$5M program"
    echo "    Polymarket Web (2026-04): ~28 researchers on \$250K program"
    echo "    Morpho (2026-04): ~60 submissions on \$200K program"
    ;;

  c4)
    slug=$(echo "$URL" | grep -oE 'contests/[a-z0-9-]+' | cut -d/ -f2)
    if [ -z "$slug" ]; then
      slug=$(echo "$URL" | grep -oE 'reports/[a-z0-9-]+' | cut -d/ -f2)
    fi
    if [ -z "$slug" ]; then
      echo "ERROR: could not extract C4 contest slug"
      exit 1
    fi
    echo ""
    echo "  C4 contest slug: $slug"
    html=$(fetch_with_ua "https://code4rena.com/reports/$slug" 2>/dev/null || echo "")
    if [ -n "$html" ]; then
      h_count=$(echo "$html" | grep -oiE 'H-0[0-9]+' | sort -u | wc -l)
      m_count=$(echo "$html" | grep -oiE 'M-0[0-9]+' | sort -u | wc -l)
      echo "  High findings in report: $h_count"
      echo "  Medium findings in report: $m_count"
    else
      echo "  (report not yet public — contest may be in flight)"
    fi
    echo ""
    echo "  verdict: manual — C4 needs per-contest saturation judgment"
    ;;

  h1)
    handle=$(basename "$URL" | sed 's/\?.*$//')
    echo ""
    echo "  H1 handle: $handle"
    html=$(fetch_with_ua "https://hackerone.com/$handle" 2>/dev/null || echo "")
    if [ -n "$html" ]; then
      resolved=$(echo "$html" | grep -oE '"resolved_report_count":[0-9]+' | head -1 | grep -oE '[0-9]+$')
      [ -z "$resolved" ] && resolved="?"
      bounties=$(echo "$html" | grep -oE '"total_bounties_paid":"?\$?[0-9,]+' | head -1 | grep -oE '[0-9,]+' | tr -d ',')
      [ -z "$bounties" ] && bounties="?"
      echo "  resolved reports (all-time): $resolved"
      echo "  total bounties paid: \$$bounties"

      if [ "$resolved" != "?" ] && [ "$resolved" -gt 500 ]; then
        echo ""
        echo "  verdict: SATURATED on surface-level — hunt logic/auth/business-flow only"
      elif [ "$resolved" != "?" ] && [ "$resolved" -gt 100 ]; then
        echo ""
        echo "  verdict: CAUTION — mid-maturity program"
      elif [ "$resolved" != "?" ]; then
        echo ""
        echo "  verdict: GO — low-maturity program"
      fi
    else
      echo "  could not fetch — may require auth"
    fi
    ;;

  hackenproof)
    html=$(fetch_with_ua "$URL" 2>/dev/null || echo "")
    echo ""
    if [ -n "$html" ]; then
      echo "  (HackenProof HTML parse — submission count often private)"
      hof=$(echo "$html" | grep -oE 'hall-of-fame[^>]*>[^<]*[0-9]+' | grep -oE '[0-9]+' | head -1)
      [ -n "$hof" ] && echo "  hall of fame size: $hof"
    fi
    echo "  verdict: manual check — HackenProof obscures density"
    ;;

  sherlock|immunefi|intigriti|unknown)
    echo ""
    echo "  Platform $PLATFORM: no automated probe yet."
    echo "  Manual checks:"
    echo "    - Sherlock: contest page shows watson count"
    echo "    - Immunefi: program page shows resolved count"
    echo "    - Intigriti: hall of fame + response metrics"
    ;;
esac

echo ""
echo "============================================================"
echo "  Heuristics:"
echo "    GO:        <30 submissions / <10 researchers / <14d since last submit"
echo "    CAUTION:   30-100 submissions OR 10-30 researchers"
echo "    SATURATED: >100 submissions OR >30 researchers OR known-issues list"
echo "============================================================"
