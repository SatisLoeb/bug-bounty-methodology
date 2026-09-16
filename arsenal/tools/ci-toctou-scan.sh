#!/usr/bin/env bash
# ci-toctou-scan.sh -- Campaign 1 orchestrator: GitHub Actions approval-gate TOCTOU.
#
# Triangulates three tools per repo and RANKS the fresh, under-audited
# sub-population (a maintainer authorization gate exists AND the checkout still
# resolves a MUTABLE ref) above the well-known ungated case (dup risk) and the
# pinned-sha mitigated case (skip).
#
#   poutine analyze_repo   -> untrusted_checkout_exec corroboration (GitHub API)
#   zizmor  --offline      -> dangerous-triggers / artipacked corroboration
#   ci-toctou-detect.py    -> the gate+mutable-ref discriminator (the value-add)
#
# Usage:
#   ci-toctou-scan.sh --repo owner/name
#   ci-toctou-scan.sh --list repos.txt        # one owner/name per line ('#' comments ok)
#   ci-toctou-scan.sh --org  orgname          # enumerate public repos of an org (gh)
#   ci-toctou-scan.sh --local /path/to/repo   # already-cloned tree
# Options:
#   --min HIGH|MED|INFO|LOW   min custom severity to report (default MED)
#   --out DIR                 run output dir (default campaigns/ci-toctou/runs/<ts>)
#   --keep                    keep the shallow clones (default: delete)
#   --no-poutine|--no-zizmor  skip a tool
#
# Non-destructive: shallow/sparse clone of .github/workflows only, source review,
# no execution of target code. PoC belongs in YOUR OWN FORK, never the target.
# In-scope repos ONLY -- read the program policy before feeding the list.
#
# State:
#   ~/arsenal/tracking/ci-toctou-flagged.jsonl   append-only merged findings
set -uo pipefail

ARSENAL="$HOME/arsenal"
DETECT="$ARSENAL/tools/ci-toctou-detect.py"
TRACK="$ARSENAL/tracking/ci-toctou-flagged.jsonl"
RUNROOT="$ARSENAL/campaigns/ci-toctou/runs"
TS="$(date +%Y%m%d-%H%M%S)"
MIN="MED"; KEEP=0; USE_POUTINE=1; USE_ZIZMOR=1
MODE=""; ARG=""; OUT=""

RED='\033[1;31m'; YEL='\033[0;33m'; CYN='\033[0;36m'; GRN='\033[0;32m'; NC='\033[0m'
log(){ echo -e "$*" >&2; }
fail(){ log "${RED}[error]${NC} $*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

export PATH="$PATH:$HOME/go/bin:$HOME/.local/bin"
# poutine analyze_repo / gato-x read the token from GH_TOKEN, not gh's keyring.
[ -z "${GH_TOKEN:-}" ] && command -v gh >/dev/null 2>&1 && export GH_TOKEN="$(gh auth token 2>/dev/null || true)"

while [ $# -gt 0 ]; do case "$1" in
  --repo) MODE=repo; ARG="$2"; shift 2;;
  --list) MODE=list; ARG="$2"; shift 2;;
  --org)  MODE=org;  ARG="$2"; shift 2;;
  --local) MODE=local; ARG="$2"; shift 2;;
  --min) MIN="$2"; shift 2;;
  --out) OUT="$2"; shift 2;;
  --keep) KEEP=1; shift;;
  --no-poutine) USE_POUTINE=0; shift;;
  --no-zizmor) USE_ZIZMOR=0; shift;;
  -h|--help) sed -n '2,30p' "$0"; exit 0;;
  *) fail "unknown arg: $1";;
esac; done

[ -n "$MODE" ] || fail "need one of --repo/--list/--org/--local"
have python3 || fail "python3 required"
[ -f "$DETECT" ] || fail "detector missing: $DETECT"
[ "$USE_POUTINE" = 1 ] && ! have poutine && { log "${YEL}[warn]${NC} poutine missing -> skipping"; USE_POUTINE=0; }
[ "$USE_ZIZMOR" = 1 ]  && ! have zizmor  && { log "${YEL}[warn]${NC} zizmor missing -> skipping"; USE_ZIZMOR=0; }

OUT="${OUT:-$RUNROOT/$TS}"
mkdir -p "$OUT/clones" "$(dirname "$TRACK")"
touch "$TRACK"
SUMMARY="$OUT/summary.md"
RUN_JSONL="$OUT/findings.jsonl"
: > "$RUN_JSONL"

# ---- build the target list -----------------------------------------------
REPOS=()
case "$MODE" in
  repo)  REPOS=("$ARG");;
  list)  [ -f "$ARG" ] || fail "list not found: $ARG"
         mapfile -t REPOS < <(sed 's/#.*//' "$ARG" | grep -oE '[A-Za-z0-9._-]+/[A-Za-z0-9._-]+' | sort -u);;
  org)   have gh || fail "gh required for --org"
         mapfile -t REPOS < <(gh repo list "$ARG" --no-archived --limit 500 --json nameWithOwner -q '.[].nameWithOwner' 2>/dev/null);;
  local) REPOS=("LOCAL:$ARG");;
esac
[ "${#REPOS[@]}" -gt 0 ] || fail "no repos to scan"
log "${CYN}[*]${NC} run $TS  targets=${#REPOS[@]}  min=$MIN  out=$OUT"

# ---- per-repo pipeline ----------------------------------------------------
fetch_workflows(){ # $1=owner/repo  $2=destdir ; sparse clone .github/workflows only
  local slug="$1" dest="$2"
  git clone --no-checkout --depth 1 --filter=blob:none -q \
      "https://github.com/$slug" "$dest" 2>/dev/null || return 1
  ( cd "$dest" && git sparse-checkout set --no-cone .github/workflows >/dev/null 2>&1 \
      && git checkout -q 2>/dev/null ) || return 1
  return 0
}

poutine_untrusted(){ # $1=owner/repo -> count of untrusted_checkout_exec failures
  [ "$USE_POUTINE" = 1 ] || { echo 0; return; }
  local out n   # capture first: these tools exit non-zero on findings (pipefail trap)
  out="$(poutine -q --disable-version-check --format json analyze_repo "$1" 2>/dev/null || true)"
  n="$(printf '%s' "$out" | jq -r '[.findings[]? | select(.rule_id=="untrusted_checkout_exec")] | length' 2>/dev/null)"
  echo "${n:-0}"
}
zizmor_dangerous(){ # $1=workflows-parent-dir -> count of dangerous-triggers/artipacked
  [ "$USE_ZIZMOR" = 1 ] || { echo 0; return; }
  local out n
  out="$(zizmor --no-online-audits --format json "$1/.github/workflows" 2>/dev/null || true)"
  n="$(printf '%s' "$out" | jq -r '[.[]? | select(.ident=="dangerous-triggers" or .ident=="artipacked")] | length' 2>/dev/null)"
  echo "${n:-0}"
}

HIGH_T=0; MED_T=0; INFO_T=0; LOW_T=0; ERR_T=0
{
echo "# CI-TOCTOU scan -- $TS"
echo
echo "Campaign 1 (Jupyter class). HIGH = maintainer gate present AND checkout resolves a mutable ref = the fresh TOCTOU sub-population worth a fork PoC."
echo
echo "| sev | repo | workflow | job | trigger | gate signals | checkout ref | poutine | zizmor |"
echo "|-----|------|----------|-----|---------|--------------|--------------|---------|--------|"
} > "$SUMMARY"

for slug in "${REPOS[@]}"; do
  if [[ "$slug" == LOCAL:* ]]; then
    dir="${slug#LOCAL:}"; slug="$(basename "$dir")"; pcount=0
  else
    dir="$OUT/clones/${slug//\//__}"
    log "${CYN}[*]${NC} $slug"
    if ! fetch_workflows "$slug" "$dir"; then log "  ${YEL}skip${NC} (clone/no-workflows)"; ERR_T=$((ERR_T+1)); continue; fi
    if ! ls "$dir"/.github/workflows/*.y*ml >/dev/null 2>&1; then log "  no workflows"; [ "$KEEP" = 0 ] && rm -rf "$dir"; continue; fi
    pcount="$(poutine_untrusted "$slug")"
  fi
  zcount="$(zizmor_dangerous "$dir")"

  # custom detector, JSONL, tagged with the repo slug
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | jq -c --arg p "$pcount" --arg z "$zcount" \
      '. + {poutine_untrusted_checkout:($p|tonumber), zizmor_dangerous:($z|tonumber), scan_ts:"'"$TS"'"}' \
      >> "$RUN_JSONL"
  done < <(python3 "$DETECT" --json --repo "$slug" "$dir" 2>/dev/null)

  [ "${MODE}" = local ] || { [ "$KEEP" = 0 ] && rm -rf "$dir"; }
done

# ---- rank + render --------------------------------------------------------
# filter by min severity, sort HIGH->LOW, append to tracking + summary table
python3 - "$RUN_JSONL" "$MIN" <<'PY' > "$OUT/_ranked.jsonl"
import sys, json
order={"HIGH":0,"MED":1,"INFO":2,"LOW":3}
minr=order[sys.argv[2]]
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
rows=[r for r in rows if order.get(r.get("severity"),9)<=minr]
rows.sort(key=lambda r:(order.get(r["severity"],9), r.get("repo") or "", r.get("file","")))
for r in rows: print(json.dumps(r))
PY

while IFS= read -r r; do
  [ -z "$r" ] && continue
  echo "$r" >> "$TRACK"
  sev=$(echo "$r"|jq -r .severity); case "$sev" in HIGH)HIGH_T=$((HIGH_T+1));;MED)MED_T=$((MED_T+1));;INFO)INFO_T=$((INFO_T+1));;LOW)LOW_T=$((LOW_T+1));;esac
  echo "$r" | jq -r '"| \(.severity) | \(.repo) | \(.file) | \(.job) | \(.trigger|join(",")) | \(.gate_signals|join("; ")) | `\(.checkout_ref)` | \(.poutine_untrusted_checkout) | \(.zizmor_dangerous) |"' >> "$SUMMARY"
done < "$OUT/_ranked.jsonl"

{ echo; echo "**Totals** (>= $MIN): HIGH=$HIGH_T  MED=$MED_T  INFO=$INFO_T  LOW=$LOW_T  (clone/skip errors: $ERR_T)"; } >> "$SUMMARY"

log ""
log "${GRN}[done]${NC} HIGH=$HIGH_T MED=$MED_T INFO=$INFO_T LOW=$LOW_T  errors=$ERR_T"
log "  summary : $SUMMARY"
log "  findings: $RUN_JSONL"
log "  tracking: $TRACK (appended)"
[ "$HIGH_T" -gt 0 ] && log "${RED}  -> $HIGH_T HIGH candidate(s): verify in a fork, then draft disclosure.${NC}"
exit 0
