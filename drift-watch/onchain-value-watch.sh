#!/usr/bin/env bash
# onchain-value-watch.sh — the A6 channel: watch ON-CHAIN ECONOMIC STATE, not code.
# The HEAD-drift (ls-remote) and impl-drift (EIP-1967) watchers are blind to funding/supply/TVL.
# Several HELD/PARKED findings re-arm ONLY on an on-chain value crossing a threshold:
#   - StackingDAO #88777 (Critical insolvency, SUBMITTED): pool grows => more $ at risk; a v3 deploy
#     = migration/patch = payout-or-cutover signal; the dormant redesign token going >0 = cutover imminent.
#   - StackingDAO second-pass register: stbtc-token supply >0 => the pre-launch stBTC surface is LIVE (re-hunt).
#   - Stacks pox-5 (NULL-COUTEUX): get-total-sbtc-staked >0 => dormant-theft class re-arms (re-derive vs ToB #7301).
# READ-ONLY. Public Hiro node (Stacks) — no keys, no writes, no code exec. Stacks reads run LOCALLY
# (cloud egress blocks non-configured hosts — same reason A5 runs local, see cloud-routine-prompt.txt).
# Usage: ./onchain-value-watch.sh            check vs baseline, alert on change/crossing
#        ./onchain-value-watch.sh --baseline re-freeze current values (after acting)
set -uo pipefail
DIR=~/Desktop/drift-watch/onchain
API="${STACKS_API:-https://api.hiro.so}"
MODE="${1:-check}"
mkdir -p "$DIR"
BASE="$DIR/stacks-values.baseline"   # key \t value \t note
ALERTS=""

SDAO=SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG
POX=SP000000000000000000002Q6VF78
SBTC=SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4

dec(){ python3 -c "import sys,json
try:
 r=json.load(sys.stdin); h=r.get('result','') or ''
 h=h[2:] if h.startswith('0x') else h
 if h.startswith('0701'): print(int(h[4:36],16))
 elif h.startswith('01'): print(int(h[2:34],16))
 else: print('ERR')
except Exception: print('ERR')"; }
ro(){ curl -s -m 25 -X POST "$API/v2/contracts/call-read/$1/$2/$3" \
        -H 'Content-Type: application/json' -d "{\"sender\":\"$1\",\"arguments\":[]}" | dec; }
exists(){ curl -s -m 20 -o /dev/null -w '%{http_code}' "$API/v2/contracts/interface/$1/$2"; }

# key -> current value (a supply/stake uint, or the http_code for *_exists probes)
declare -A CUR
CUR[sdao.ststxbtc-token-v2.supply]=$(ro $SDAO ststxbtc-token-v2 get-total-supply)
CUR[sdao.ststxbtc-token.supply]=$(ro $SDAO ststxbtc-token get-total-supply)
CUR[sdao.stbtc-token.supply]=$(ro $SDAO stbtc-token get-total-supply)
CUR[sdao.tracking-v3.exists]=$(exists $SDAO ststxbtc-tracking-v3)
CUR[sdao.token-v3.exists]=$(exists $SDAO ststxbtc-token-v3)
CUR[pox5.total-sbtc-staked]=$(ro $POX pox-5 get-total-sbtc-staked)
CUR[sbtc.supply]=$(ro $SBTC sbtc-token get-total-supply)

# notes per key (why it matters)
declare -A NOTE
NOTE[sdao.ststxbtc-token-v2.supply]="#88777 drainable pool — growth = more \$ at risk (submitted Critical)"
NOTE[sdao.ststxbtc-token.supply]="dormant redesign token; >0 = migration cutover imminent => submit/escalate FAST"
NOTE[sdao.stbtc-token.supply]="pre-launch stBTC surface; >0 = LIVE => re-hunt the stbtc-reserve/staker family"
NOTE[sdao.tracking-v3.exists]="200 = v3 DEPLOYED = patch/migration of the #88777 seam => payout-or-cutover signal"
NOTE[sdao.token-v3.exists]="200 = v3 token DEPLOYED => cutover of the double-count fix"
NOTE[pox5.total-sbtc-staked]="pox-5 dormant-theft re-arm; >0 = re-derive theft vs ToB #7301 (now CLOSED/fixed)"
NOTE[sbtc.supply]="Stacks sBTC TVL context (denominator for both StackingDAO + pox-5 impact)"

if [ "$MODE" = "--baseline" ] || [ ! -f "$BASE" ]; then
  : > "$BASE"
  for k in "${!CUR[@]}"; do printf "%s\t%s\t%s\n" "$k" "${CUR[$k]}" "${NOTE[$k]}" >> "$BASE"; done
  sort -o "$BASE" "$BASE"
  echo "onchain-value-watch: baseline frozen $(date -u +%Y-%m-%d) ($(wc -l < "$BASE") signals)"; exit 0
fi

declare -A OLD
while IFS=$'\t' read -r k v _; do OLD[$k]="$v"; done < "$BASE"

for k in "${!CUR[@]}"; do
  cur="${CUR[$k]}"; old="${OLD[$k]:-NEW}"
  [ "$cur" = "ERR" ] && { ALERTS+="READ-ERR $k (Hiro timeout/parse) — retry"$'\n'; continue; }
  if [[ "$k" == *.exists ]]; then
    # 404 -> 200 = a v3 contract just deployed
    if [ "$old" = "404" ] && [ "$cur" = "200" ]; then
      ALERTS+="DEPLOY   $k  404 -> 200  | ${NOTE[$k]}"$'\n'
    fi
    continue
  fi
  [ "$old" = "NEW" ] && { ALERTS+="NEW-KEY  $k = $cur | ${NOTE[$k]}"$'\n'; continue; }
  # crossing zero (0 -> >0) = the classic 'fire-when-funded' trigger
  if [ "$old" = "0" ] && [ "$cur" != "0" ]; then
    ALERTS+="FUNDED   $k  0 -> $cur  | ${NOTE[$k]} [RE-ARM FIRED]"$'\n'; continue
  fi
  # material growth (>=25%) on an already-funded pool = rising impact
  if [ "$old" != "0" ] && [ "$cur" != "$old" ]; then
    grew=$(python3 -c "o=$old;c=$cur;print(1 if abs(c-o)>=o*0.25 else 0)" 2>/dev/null || echo 0)
    [ "$grew" = "1" ] && ALERTS+="GROW>=25% $k  $old -> $cur  | ${NOTE[$k]}"$'\n'
  fi
done

TODAY=$(date -u +%Y-%m-%d)
if [ -z "$ALERTS" ]; then echo "onchain-value-watch: NO on-chain drift, $TODAY"; else
  echo "=== ON-CHAIN VALUE DRIFT $TODAY ==="; printf "%s" "$ALERTS"
  echo "Next: FUNDED/DEPLOY => re-open the named finding NOW; GROW => update impact \$ in the report."
fi
