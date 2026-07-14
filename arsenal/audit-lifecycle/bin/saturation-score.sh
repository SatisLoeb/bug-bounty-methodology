#!/usr/bin/env bash
# saturation-score.sh — (ex fortress-score.sh) Compute a SATURATION SCORE for a
# target at Phase 0, BEFORE committing depth. A HIGH score means the SC-CORE is
# already picked clean by top auditors + an adversarial team — so it is NOT a
# reason to prove-null on that core; it is a signal to RE-SOURCE to a PAYABLE
# SURFACE (web/API, off-chain/operator infra, fresh <2-audit module) where the
# theft that survived the audits actually lives.
#
# Track record behind the reframe (2026-07-08): 28 SC-core "fortress" targets →
# 71% self-nulled, ZERO paid; the only cash ($10K) and 100% of acks came from a
# theft BUILT on a web/API/off-chain seam. Same protocol (Polymarket): on-chain
# core = null, web relayer = $10K. Surface decides the payout, not effort.
#
# Origin: the Mezo engagement (2026-06-08) burned ~15 surfaces of deep work for 0
# findings on a textbook fortress. The EV-gate ran downstream (filter findings)
# instead of upstream (filter targets). This script forces the upstream check —
# and now names the RE-SOURCE target instead of just saying "NO-GO".
#
# Usage:
#   saturation-score.sh --workspace <path>          # auto-scan cloned repos + audits dir
#   saturation-score.sh --repo <path> [--audits <dir>]
#   saturation-score.sh --manual                    # interactive prompt of the inputs
#
# Exit codes:
#   0 — saturation LOW/MED  → GO on this target (ore likely remains)
#   1 — saturation HIGH     → RE-SOURCE to a payable surface (do NOT prove-null on the core)
#   2 — could not determine → operator fills the card manually
#
# Saturation dimensions (0-100, higher = core more picked-clean = lower P(payable finding IN THE CORE)):
#   audit_count        : 0 audits=0 / 1=10 / 2=20 / 3=30 / 4=40 / 5+=50   (cap 50)
#   auditor_tier       : top-tier firm present (+15)
#   adversarial_devtests: tests/comments anticipating attacks (+15)
#   audit_freshness    : most-recent audit < 6 months old (+10)  (fresh core = thin residual)
#   team_pedigree      : known elite team (+10, operator-supplied)
# PLUS a PAYABLE-SURFACE scan (does NOT change the core score — it names where to RE-SOURCE):
#   web/API surface · off-chain/operator infra · fresh/unaudited module
#
# Gate: HIGH = score >= 60. MED = 35-59. LOW = < 35.

set -uo pipefail

BOLD=$(tput bold 2>/dev/null || echo ""); RED=$(tput setaf 1 2>/dev/null || echo "")
GRN=$(tput setaf 2 2>/dev/null || echo ""); YEL=$(tput setaf 3 2>/dev/null || echo "")
CYN=$(tput setaf 6 2>/dev/null || echo ""); RST=$(tput sgr0 2>/dev/null || echo "")

WORKSPACE=""; REPO=""; AUDITS_DIR=""; MANUAL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) WORKSPACE="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --audits) AUDITS_DIR="$2"; shift 2;;
    --manual) MANUAL=1; shift;;
    *) shift;;
  esac
done

TOP_AUDITORS='Thesis|Trail.?of.?Bits|Spearbit|OtterSec|Zellic|ChainSecurity|Cantina|Quantstamp|Halborn|OpenZeppelin|Sherlock|Code4rena|Certora'
ADVERSARIAL_RE='[Dd]o[Ss]|[Aa]ttack|[Ee]xploit|[Mm]alicious|[Oo]verflow|[Rr]eentran|[Ff]orge|[Ss]pam|[Gg]rief'

score=0; notes=()

# --- locate audits + repo from workspace if given ---
if [ -n "$WORKSPACE" ]; then
  [ -z "$REPO" ] && REPO=$(find "$WORKSPACE" -maxdepth 3 -type d -name '.git' 2>/dev/null | head -1 | xargs -r dirname)
  [ -z "$AUDITS_DIR" ] && AUDITS_DIR=$(find "$WORKSPACE" -maxdepth 4 -type d \( -iname 'audits' -o -iname 'audit' \) 2>/dev/null | head -1)
fi

if [ "$MANUAL" = "1" ] || { [ -z "$REPO" ] && [ -z "$AUDITS_DIR" ]; }; then
  echo "${BOLD}SATURATION SCORE — manual card${RST}"
  echo "Answer from Phase 0 recon (DeFiLlama, audit pages, github, bounty payout history):"
  echo "  audit_count        = ? (# of distinct audit firms)"
  echo "  top_tier_auditor   = ? (any of: $TOP_AUDITORS)"
  echo "  adversarial_devtests = ? (tests/comments anticipating attacks: y/n)"
  echo "  audit_freshness    = ? (most recent audit < 6 months: y/n)"
  echo "  team_pedigree      = ? (elite team e.g. tBTC/Thesis, ToB, top-infra: y/n)"
  echo "  bounty_payout_history = ? (do they pay at the class you can reach? y/n/unknown)"
  echo "  PAYABLE SURFACE?   = ? (web/API app-backend · off-chain keeper/relayer/signer · fresh <2-audit module)"
  echo ""
  echo "Scoring: audit_count*10 (cap 50) + top_tier(15) + adversarial(15) + fresh(10) + pedigree(10)"
  echo "Gate: >=60 HIGH (RE-SOURCE to a payable surface) · 35-59 MED · <35 LOW (GO)"
  echo ""
  echo "${YEL}exit 2 — operator must fill this card before committing depth${RST}"
  exit 2
fi

# --- audit_count + auditor_tier + freshness (from audits dir filenames) ---
audit_count=0; top_tier=0; fresh=0
if [ -n "$AUDITS_DIR" ] && [ -d "$AUDITS_DIR" ]; then
  mapfile -t auditfiles < <(find "$AUDITS_DIR" -type f \( -iname '*.pdf' -o -iname '*.md' \) 2>/dev/null)
  firms=$(printf '%s\n' "${auditfiles[@]}" | grep -oiE "$TOP_AUDITORS" | tr '[:upper:]' '[:lower:]' | sort -u)
  audit_count=$(printf '%s\n' "$firms" | grep -c . || echo 0)
  [ "$audit_count" -gt 0 ] && top_tier=1
  if printf '%s\n' "${auditfiles[@]}" | grep -qE '202[5-9]-(0[1-9]|1[0-2])'; then
    fresh=1
  fi
  notes+=("audit firms detected: $(echo $firms | tr '\n' ',')")
else
  notes+=("NO audits dir found — audit_count=0 (could be pre-first-audit = GOOD target, or just not cloned)")
fi

# --- adversarial dev-tests (in repo) ---
adversarial=0
if [ -n "$REPO" ] && [ -d "$REPO" ]; then
  hits=$(grep -rolE "func.*Test.*($ADVERSARIAL_RE)" "$REPO" --include='*_test.go' --include='*.t.sol' --include='*.test.ts' 2>/dev/null | head -5 | wc -l)
  devnotes=$(grep -rlE 'by design|DEV NOTE|NOTHING PREVENTS|attacker (can|could|would)|anticipat' "$REPO" --include='*.go' --include='*.sol' 2>/dev/null | head -5 | wc -l)
  if [ "$hits" -gt 0 ] || [ "$devnotes" -gt 0 ]; then
    adversarial=1
    notes+=("adversarial dev-tests/notes: $hits attack-named tests, $devnotes attack-anticipating comments → team thinks adversarially")
  fi
fi

# --- PAYABLE-SURFACE scan (names the RE-SOURCE target; does NOT change core score) ---
payable=()
if [ -n "$WORKSPACE$REPO" ]; then
  SCANROOT="${WORKSPACE:-$REPO}"
  # web/API app-backend
  if find "$SCANROOT" -maxdepth 4 \( -iname 'package.json' -o -iname 'openapi*.y*ml' -o -iname 'openapi*.json' -o -iname 'next.config.*' -o -type d -iname 'api' -o -type d -iname 'frontend' -o -type d -iname 'app' \) 2>/dev/null | grep -q .; then
    payable+=("web/API app-backend (package.json / openapi / api|frontend|app dir) → /gravedigger + web-corpus: IDOR/auth-bypass/SSRF/BFLA")
  fi
  # off-chain / operator infra
  if grep -rlqiE 'keeper|relayer|executor|operator.?(wallet|key|signer)|bff|off.?chain|cron|bot' "$SCANROOT" --include='*.ts' --include='*.js' --include='*.go' --include='*.py' 2>/dev/null | grep -q .; then
    payable+=("off-chain/operator infra (keeper/relayer/executor/signer/BFF) → /upshift: the backend that signs on-chain")
  fi
fi

# --- compute core saturation ---
ac_pts=$(( audit_count * 10 )); [ "$ac_pts" -gt 50 ] && ac_pts=50
score=$(( ac_pts + top_tier*15 + adversarial*15 + fresh*10 ))
notes+=("team_pedigree + bounty_payout_history NOT auto-scored — operator adds +10 each if applicable")

echo "${BOLD}=== SATURATION SCORE: $score / 100  (core hardness; higher = more picked-clean) ===${RST}"
echo "  audit_count=$audit_count (${ac_pts}pts) · top_tier_auditor=$top_tier (×15) · adversarial_devtests=$adversarial (×15) · audit_fresh=$fresh (×10)"
for n in "${notes[@]}"; do echo "  - $n"; done
if [ ${#payable[@]} -gt 0 ]; then
  echo "${CYN}  PAYABLE SURFACE(S) DETECTED (RE-SOURCE HERE):${RST}"
  for p in "${payable[@]}"; do echo "${CYN}    → $p${RST}"; done
else
  echo "${CYN}  No payable surface auto-detected in the clone — check for a web app / API / off-chain infra tier off-repo before committing to the SC core.${RST}"
fi
echo ""

if [ "$score" -ge 60 ]; then
  echo "${RED}${BOLD}VERDICT: HIGH SATURATION ($score) → RE-SOURCE to a payable surface.${RST}"
  echo "  The SC-core is picked clean (top auditors + adversarial team). The theft that survived the audits does NOT"
  echo "  live deeper in this core — it lives on the UNSATURATED surface. Do NOT enter immortal-mode to prove-null."
  if [ ${#payable[@]} -gt 0 ]; then
    echo "  → Route depth to the PAYABLE SURFACE listed above (web/API/off-chain), NOT the SC core."
  else
    echo "  → Source a fresh/off-chain/web target (h1disclosed-style). Track record: 28 SC-cores → 71% null, \$0;"
    echo "    every payout came from a payable seam. If proceeding on the core anyway: fresh post-audit delta ONLY,"
    echo "    hard timebox, generate ≥3 theft-hypotheses first, 6 dead attempts → RE-SOURCE."
  fi
  exit 1
elif [ "$score" -ge 35 ]; then
  echo "${YEL}${BOLD}VERDICT: MEDIUM SATURATION ($score) → GO, but hunt the fresh/off-chain/web seam first.${RST}"
  echo "  Favor the fresh/post-audit delta + off-chain seam + payable surface + uncovered classes. Re-baseline EV after Phase A."
  exit 0
else
  echo "${GRN}${BOLD}VERDICT: LOW SATURATION ($score) → GO.${RST}"
  echo "  Ore likely remains. Thin-audited / fresh-launch / off-chain-seam / web-API = where findings live."
  exit 0
fi
