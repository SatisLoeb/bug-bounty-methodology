#!/bin/bash
# pattern-scan.sh — Automated vulnerability pattern scanner
# Usage: ./pattern-scan.sh <target_dir> [--type vault|dex|bridge|lending|staking|all] [--lang sol|rs|go|cairo]
#
# Runs categorized grep patterns against a codebase and outputs candidates
# ranked by severity. Filters known false positives (OZ imports, test files, interfaces).

set -uo pipefail

TARGET_DIR="${1:-.}"
TYPE="all"
LANG="sol"
VERBOSE=0

# Parse args
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) TYPE="$2"; shift 2 ;;
    --lang) LANG="$2"; shift 2 ;;
    --verbose|-v) VERBOSE=1; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# File extension based on language
case "$LANG" in
  sol) EXT="*.sol" ;;
  rs)  EXT="*.rs" ;;
  go)  EXT="*.go" ;;
  cairo) EXT="*.cairo" ;;
  *) EXT="*.sol" ;;
esac

# Exclusion patterns
EXCLUDE="--exclude-dir=node_modules --exclude-dir=target --exclude-dir=lib --exclude-dir=.git --exclude-dir=test --exclude-dir=tests --exclude-dir=mock --exclude-dir=mocks --exclude-dir=script --exclude-dir=scripts"

found=0
total=0

scan() {
  local severity="$1"
  local category="$2"
  local pattern_name="$3"
  local grep_pattern="$4"
  local fp_signal="${5:-}"

  total=$((total + 1))

  local results
  results=$(grep -rn $EXCLUDE --include="$EXT" -E "$grep_pattern" "$TARGET_DIR" 2>/dev/null | head -20)

  if [[ -n "$results" ]]; then
    local count
    count=$(echo "$results" | wc -l)
    found=$((found + 1))

    case "$severity" in
      CRITICAL) echo -e "${RED}[$severity]${NC} $category — $pattern_name ($count hits)" ;;
      HIGH)     echo -e "${YELLOW}[$severity]${NC} $category — $pattern_name ($count hits)" ;;
      MEDIUM)   echo -e "${CYAN}[$severity]${NC} $category — $pattern_name ($count hits)" ;;
      *)        echo -e "${GREEN}[$severity]${NC} $category — $pattern_name ($count hits)" ;;
    esac

    if [[ $VERBOSE -eq 1 ]]; then
      echo "$results" | sed 's/^/  /'
    else
      echo "$results" | head -3 | sed 's/^/  /'
      [[ $count -gt 3 ]] && echo "  ... and $((count - 3)) more"
    fi

    if [[ -n "$fp_signal" ]]; then
      echo -e "  ${GREEN}FP check:${NC} $fp_signal"
    fi
    echo ""
  fi
}

echo "========================================"
echo " Pattern Scanner v1.0"
echo " Target: $TARGET_DIR"
echo " Type: $TYPE | Lang: $LANG ($EXT)"
echo "========================================"
echo ""

# ============================================================
# VAULT / ERC4626 PATTERNS
# ============================================================
if [[ "$TYPE" == "vault" || "$TYPE" == "all" ]]; then
  echo -e "${CYAN}=== VAULT / ERC4626 PATTERNS ===${NC}"
  echo ""

  scan "HIGH" "P-VAULT-001" "First depositor inflation (totalSupply == 0)" \
    "totalSupply.*==.*0|_mint.*==.*0|totalAssets.*balanceOf" \
    "Safe if virtual shares (OZ _decimalsOffset), dead shares, or seeded vault"

  scan "HIGH" "P-VAULT-002" "Rounding direction in preview functions" \
    "previewWithdraw|previewMint|previewRedeem|previewDeposit|mulDivUp|mulDivDown|convertToShares|convertToAssets" \
    "Safe if rounding matches OZ reference (deposit/redeem DOWN, withdraw/mint UP)"

  scan "HIGH" "P-VAULT-004" "Fee-on-transfer token mismatch" \
    "transferFrom.*amount\);\s*$|safeTransferFrom.*amount\)" \
    "Safe if balance delta pattern used (received = balanceOf - balanceBefore)"

  scan "HIGH" "P-VAULT-005" "Reward timing — first staker claims all" \
    "totalRewards.*totalShares.*==.*0|rewardPerShare|rewardPerToken" \
    "Safe if rewards only accumulate after first deposit"

  scan "MEDIUM" "P-VAULT-007" "Withdrawal burns full shares despite illiquidity" \
    "_withdraw.*burn.*shares|value.*=.*available|withdrawMaxLoss" \
    "Safe if share burn proportional to actual received"

  scan "HIGH" "P-VAULT-008" "Strategy migration residual tokens" \
    "migrate|setStrategy|switchStrategy|withdraw.*totalAssets" \
    "Safe if migration asserts zero remaining balance"

  scan "HIGH" "P-VAULT-009" "Price ignores pending withdrawals" \
    "price.*totalSupply|totalAssets.*\/.*totalSupply|pendingWithdraw|requestWithdraw" \
    "Safe if requestWithdraw burns tokens or excludes from supply"

  scan "MEDIUM" "P-VAULT-010" "Missing slippage on vault interactions" \
    "\.deposit\(.*address\(this\)\)|\.redeem\(.*address\(this\)\)|minOut.*=.*0" \
    "Safe if user-specified minShares/minAssets exists"

  scan "HIGH" "P-VAULT-012" "Unrestricted harvest enables fee evasion" \
    "harvest|_deployedAmount|performanceFee|public.*harvest|external.*harvest" \
    "Safe if harvest restricted to onlyOwner/onlyKeeper"

  scan "HIGH" "P-VAULT-013" "Self-transfer duplicates shares" \
    "transfer_share|transferShare|_transfer.*share" \
    "Safe if require(from != to) or balance delta nets zero"

  scan "MEDIUM" "P-VAULT-015" "Deflation attack — insufficient virtual offset" \
    "virtual.*offset|_decimalsOffset|OFFSET|10\*\*" \
    "Safe if offset >= 10^(decimals/2)"
fi

# ============================================================
# LENDING PATTERNS
# ============================================================
if [[ "$TYPE" == "lending" || "$TYPE" == "all" ]]; then
  echo -e "${CYAN}=== LENDING PATTERNS ===${NC}"
  echo ""

  scan "HIGH" "P-LEND-001" "Stale state after flash loan" \
    "flash_loan|flashLoan|flash.*borrow" \
    "Safe if accrueInterest called before flash loan callback"

  scan "HIGH" "P-LEND-002" "Emission sync gap — rewards before balance change" \
    "update_emissions|accrueReward|_updateReward|rewardPerToken" \
    "Safe if every balance-mutating path calls reward sync first"

  scan "HIGH" "P-LEND-003" "Utilization bypass on withdrawal" \
    "withdraw.*utilization|maxUtilization|utilizationRate" \
    "Safe if post-withdrawal utilization check exists"

  scan "MEDIUM" "P-LEND-011" "Oracle price staleness" \
    "latestRoundData|getPrice|getPriceUnsafe|stalePrice|maxStaleness" \
    "Safe if staleness threshold enforced with revert"

  scan "HIGH" "P-LEND-012" "Liquidation bonus exceeds collateral value" \
    "liquidat.*bonus|liquidat.*discount|liquidat.*incentive" \
    "Safe if bonus capped to collateral value"

  scan "MEDIUM" "P-LEND-017" "Interest rate model edge cases" \
    "interestRate|borrowRate|supplyRate|utilizationRate|kink" \
    "Check boundary conditions at 0%, kink, and 100% utilization"
fi

# ============================================================
# DEX / AMM PATTERNS
# ============================================================
if [[ "$TYPE" == "dex" || "$TYPE" == "all" ]]; then
  echo -e "${CYAN}=== DEX / AMM PATTERNS ===${NC}"
  echo ""

  scan "HIGH" "P-DEX-001" "Balance vs reserve asymmetry in mint/burn" \
    "balanceOf|getReserves|_reserve" \
    "Compare: mint() and burn() use same source of truth?"

  scan "HIGH" "P-DEX-004" "Fee calculated but not deducted" \
    "fee.*=.*amount.*feePercent|feeRate|feeBps" \
    "Trace: is fee subtracted from transfer amount?"

  scan "MEDIUM" "P-DEX-005" "Dust orders block operations" \
    "amount.*-=.*fill|remainingAmount|partialFill" \
    "Safe if minimum remaining enforced"

  scan "HIGH" "P-DEX-007" "Memory vs storage struct mutation" \
    "Order memory|Position memory|Node memory|struct.*memory" \
    "Safe if all mutations on storage refs or written back"
fi

# ============================================================
# BRIDGE PATTERNS
# ============================================================
if [[ "$TYPE" == "bridge" || "$TYPE" == "all" ]]; then
  echo -e "${CYAN}=== BRIDGE PATTERNS ===${NC}"
  echo ""

  scan "CRITICAL" "P-BRIDGE-001" "Duplicate signature in quorum" \
    "signatories|validators|votes|quorum|threshold.*sig" \
    "Safe if duplicate signer tracking exists"

  scan "CRITICAL" "P-BRIDGE-002" "Message type filtering excludes value" \
    "msg.kind|msgType|IpcMsgKind|skipSupply|totalValue|messageType" \
    "Safe if all value-carrying types accounted"

  scan "HIGH" "P-BRIDGE-003" "Hash mismatch storage vs lookup" \
    "toHash|toTracingId|hashMessage|messageHash|receiptHash" \
    "Compare field sets in storage hash vs lookup hash"

  scan "CRITICAL" "P-BRIDGE-006" "Arbitrary call via user-controlled data" \
    "_to\.call|bridgeData|RelayTxData|arbitraryCall|\.call\(.*data" \
    "Safe if target whitelisted or no assets held"

  scan "HIGH" "P-BRIDGE-007" "Cross-layer message size amplification" \
    "data.*field|MsgInitiate|MsgFinalize|maxTxSize|mempool.*limit" \
    "Safe if L1 data field has size limit"

  scan "HIGH" "P-BRIDGE-008" "Permissionless registration" \
    "function register|createSubnet|createBridge|createPool" \
    "Safe if restricted to authorized callers"
fi

# ============================================================
# ACCESS CONTROL PATTERNS (all types)
# ============================================================
if [[ "$TYPE" != "none" ]]; then
  echo -e "${CYAN}=== ACCESS CONTROL PATTERNS ===${NC}"
  echo ""

  scan "CRITICAL" "P-DERIV-001" "Unprotected initializer" \
    "function init\b|function initialize\b" \
    "Safe if initializer modifier or initialized state check"

  scan "HIGH" "GENERAL" "Missing reentrancy guard on ETH transfer" \
    "\.call\{value|\.transfer\(|sendValue\(" \
    "Safe if nonReentrant on all paths or CEI pattern"

  scan "MEDIUM" "GENERAL" "Unchecked return value" \
    "\.call\(|\.send\(|\.transfer\(" \
    "Safe if return value checked (bool success)"
fi

# ============================================================
# GOVERNANCE / veToken PATTERNS
# ============================================================
if [[ "$TYPE" == "staking" || "$TYPE" == "all" ]]; then
  echo -e "${CYAN}=== GOVERNANCE / STAKING PATTERNS ===${NC}"
  echo ""

  scan "HIGH" "P-GOV-001" "Deposit before share calculation" \
    "totalStaked.*\+=|totalDeposited.*\+=" \
    "Safe if share calc happens BEFORE total increment"

  scan "MEDIUM" "P-GOV-002" "Dust vote griefing" \
    "function vote|function allocate|votingPower" \
    "Safe if minimum vote threshold enforced"
fi

# ============================================================
# MATH PATTERNS
# ============================================================
echo -e "${CYAN}=== MATH PATTERNS ===${NC}"
echo ""

scan "HIGH" "P-MATH-002" "Function accepts invalid domain" \
  "function ln|function log|function sqrt|function exp" \
  "Safe if input validation (require x > 0) at entry"

scan "MEDIUM" "GENERAL" "Unchecked arithmetic in critical path" \
  "unchecked.*\{|overflow|underflow" \
  "Review each unchecked block for overflow potential"

# ============================================================
# SUMMARY
# ============================================================
echo "========================================"
echo -e " Scan complete: ${RED}$found${NC} patterns matched out of $total checked"
echo "========================================"
