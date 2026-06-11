#!/usr/bin/env bash
# fortress-score.sh — Compute a FORTRESS SCORE for a target at Phase 0, BEFORE
# committing audit depth. A high score predicts $0 (the surface is already swept
# by top auditors + an adversarial-thinking team) and should gate to NO-GO or
# fresh-delta-only with an explicit "expected null" operator opt-in.
#
# Origin: the Mezo engagement (2026-06-08) spent ~15 surfaces of deep-beast work
# for 0 submittable findings. Mezo was a textbook fortress (5x audited by
# Quantstamp/Halborn/Cantina/OtterSec/Thesis, tBTC/Thesis team, DEV-NOTES
# anticipating attacks incl. their own DoS_ZeroIsUnlimited test). EVERY signal
# was present at Phase 0. The EV-gate ran downstream (filter findings) instead of
# upstream (filter targets). This script forces the upstream check.
# See feedback_fortress_target_selection_ev_gate.md.
#
# Usage:
#   fortress-score.sh --workspace <path>           # auto-scan cloned repos + audits dir
#   fortress-score.sh --repo <path> [--audits <dir>]
#   fortress-score.sh --manual                     # interactive prompt of the inputs
#
# Exit codes:
#   0 — fortress score LOW/MED  → GO (normal EV expectation)
#   1 — fortress score HIGH     → NO-GO or fresh-delta-only + explicit "expected null" opt-in
#   2 — could not determine     → operator fills the card manually
#
# Score dimensions (0-100, higher = more fortress = lower P(payable finding)):
#   audit_count        : 0 audits=0 / 1=10 / 2=20 / 3=30 / 4=40 / 5+=50   (cap 50)
#   auditor_tier       : top-tier firm present (+15)  [Thesis,TrailOfBits,Spearbit,
#                        OtterSec,Zellic,ChainSecurity,Cantina-managed,Quantstamp,Halborn]
#   adversarial_devtests: tests named *DoS*/*attack*/*exploit*/*malicious*/*overflow*
#                        OR DEV-NOTE comments anticipating attacks (+15)
#   audit_freshness    : most-recent audit < 6 months old (+10)  (fresh = thin residual)
#   team_pedigree      : known elite team (tBTC/Thesis, a16z/Paradigm-backed core infra) (+10)
#
# Gate: HIGH = score >= 60. MED = 35-59. LOW = < 35.

set -uo pipefail

BOLD=$(tput bold 2>/dev/null || echo ""); RED=$(tput setaf 1 2>/dev/null || echo "")
GRN=$(tput setaf 2 2>/dev/null || echo ""); YEL=$(tput setaf 3 2>/dev/null || echo "")
RST=$(tput sgr0 2>/dev/null || echo "")

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
  echo "${BOLD}FORTRESS SCORE — manual card${RST}"
  echo "Answer from Phase 0 recon (DeFiLlama, audit pages, github, bounty payout history):"
  echo "  audit_count        = ? (# of distinct audit firms)"
  echo "  top_tier_auditor   = ? (any of: $TOP_AUDITORS)"
  echo "  adversarial_devtests = ? (tests/comments anticipating attacks: y/n)"
  echo "  audit_freshness    = ? (most recent audit < 6 months: y/n)"
  echo "  team_pedigree      = ? (elite team e.g. tBTC/Thesis, ToB, top-infra: y/n)"
  echo "  bounty_payout_history = ? (do they pay at the class you can reach? y/n/unknown)"
  echo ""
  echo "Scoring: audit_count*10 (cap 50) + top_tier(15) + adversarial(15) + fresh(10) + pedigree(10)"
  echo "Gate: >=60 HIGH (NO-GO/fresh-delta-only+optin) · 35-59 MED · <35 LOW (GO)"
  echo ""
  echo "${YEL}exit 2 — operator must fill this card before committing depth${RST}"
  exit 2
fi

# --- audit_count + auditor_tier + freshness (from audits dir filenames) ---
audit_count=0; top_tier=0; fresh=0
if [ -n "$AUDITS_DIR" ] && [ -d "$AUDITS_DIR" ]; then
  # count distinct audit firms by matching known names in pdf/md filenames
  mapfile -t auditfiles < <(find "$AUDITS_DIR" -type f \( -iname '*.pdf' -o -iname '*.md' \) 2>/dev/null)
  firms=$(printf '%s\n' "${auditfiles[@]}" | grep -oiE "$TOP_AUDITORS" | tr '[:upper:]' '[:lower:]' | sort -u)
  audit_count=$(printf '%s\n' "$firms" | grep -c . || echo 0)
  [ "$audit_count" -gt 0 ] && top_tier=1
  # freshness: any audit file with a 2026 or current-ish date in name
  if printf '%s\n' "${auditfiles[@]}" | grep -qE '202[5-9]-(0[1-9]|1[0-2])'; then
    # crude: presence of a recent-dated audit; operator refines
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

# --- compute ---
ac_pts=$(( audit_count * 10 )); [ "$ac_pts" -gt 50 ] && ac_pts=50
score=$(( ac_pts + top_tier*15 + adversarial*15 + fresh*10 ))
# team_pedigree + payout_history are operator-supplied; flag for manual top-up
notes+=("team_pedigree + bounty_payout_history NOT auto-scored — operator adds +10 each if applicable")

echo "${BOLD}=== FORTRESS SCORE: $score / 100 ===${RST}"
echo "  audit_count=$audit_count (${ac_pts}pts) · top_tier_auditor=$top_tier (×15) · adversarial_devtests=$adversarial (×15) · audit_fresh=$fresh (×10)"
for n in "${notes[@]}"; do echo "  - $n"; done
echo ""

if [ "$score" -ge 60 ]; then
  echo "${RED}${BOLD}VERDICT: HIGH FORTRESS ($score) → NO-GO or FRESH-DELTA-ONLY.${RST}"
  echo "  Do NOT enter immortal-mode deep without explicit operator opt-in: 'likely \$0, doing it for methodology/coverage.'"
  echo "  If proceeding: commit ONLY to the genuinely-fresh post-audit delta (git diff since last audit), hard timebox,"
  echo "  and an 'expected null, re-baseline EV after Phase A' checkpoint. (Mezo lesson: 5×-audited-by-Thesis = ~\$0.)"
  exit 1
elif [ "$score" -ge 35 ]; then
  echo "${YEL}${BOLD}VERDICT: MEDIUM FORTRESS ($score) → GO with EV caution.${RST}"
  echo "  Favor the fresh/post-audit delta + off-chain seam + uncovered classes. Re-baseline EV after Phase A."
  exit 0
else
  echo "${GRN}${BOLD}VERDICT: LOW FORTRESS ($score) → GO.${RST}"
  echo "  Normal EV expectation. Thin-audited / fresh-launch / off-chain-seam = where findings live."
  exit 0
fi
