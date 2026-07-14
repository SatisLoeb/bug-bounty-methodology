---
name: re-verification-monitor
description: Daily cron logic for active disclosures. Per disclosure, register a job that checks HTTP endpoint status (404 patched, 200 still live, 503 ambiguous), JS bundle hash + grep for leaked secrets, on-chain implementation slot via eth_getStorageAt on EIP-1967 slot, SIWE nonce stability. State machine awaiting_ack → acked → partially_patched → fully_patched → engagement_closed. Suggests follow-up timing automatically.
---

# Re-verification monitor -- daily check logic for active disclosures

## Why this exists

The Upshift FORTRESS email worked because the patch verification was passive, fast (~30 minutes), and time-stamped to the active engagement window. Without a structured re-verification process, the verification itself becomes a friction point and the fortress window closes.

This file encodes the cron logic so any active disclosure can be monitored automatically. The output is a daily drift report that surfaces:
- New patches landing (good signal -- triggers fortress follow-up if just-acked)
- Primitives that flipped from live to patched
- Primitives that flipped from patched back to live (regression -- urgent)
- New surfaces that appeared (post-patch refactor surface)

## Per-disclosure registration

When you transition an engagement to `acked` state, register a re-verification job at:

```
~/Desktop/BUGS/<target>-recon/re-verification/
├── DISCLOSURE-MANIFEST.yaml         # what to check, how often
├── daily-checks/
│   ├── 2026-04-25.yaml              # one file per day
│   ├── 2026-04-26.yaml
│   └── ...
└── drift-alerts/
    └── 2026-04-25-W16-still-live.md # written when something changes state
```

### DISCLOSURE-MANIFEST.yaml schema

```yaml
target: upshift_finance
state: acked
state_entered: 2026-04-23T19:44:00Z
acker: "Alex Elkrief (Co-CEO)"
ack_channel: email
ack_email_thread: alex@augustdigital.io
disclosure_email_sent: 2026-04-22T15:17:00Z
fortress_email_sent: 2026-04-25T02:00:00Z
fortress_window_open_until: 2026-05-02T02:00:00Z  # 7d after fortress
delivery_format_chosen: null  # awaiting Alex's response

primitives:
  - id: F1
    name: "Unauthenticated POST /integrations/methods → on-chain state mod"
    type: http_endpoint
    detection:
      method: POST
      url: https://api.upshift.finance/integrations/methods
      body: '{}'
      expected_patched_status: 404
      expected_live_status: 422
      live_evidence: "422 with 'Field required' body schema errors"
    severity: critical
    chains_with: [W34]

  - id: W34
    name: "Hardcoded executor master password in JS bundle"
    type: js_bundle_grep
    detection:
      bundle_url: https://app.augustdigital.io/assets/index-{HASH}.js
      bundle_hash_url: https://app.augustdigital.io/  # parse current hash from index.html
      grep_patterns:
        - 'VITE_APP_MASTER_PASSWORD:"[a-f0-9]{64}"'
        - '0adfa598343b1c94cb14122baa4e5242ff62f7741109b66486db05bf79fa741c'  # the leaked literal
      expected_patched: "0 matches"
      expected_live: "1+ matches"
    severity: critical

  - id: W26
    name: "Hardcoded Slack webhook URL in JS bundle"
    type: webhook_validity
    detection:
      url: https://hooks.slack.com/services/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
      method: POST
      body: '{"text":"test"}'
      expected_patched_status: 404
      expected_live_status: 200
    severity: medium

  - id: W16
    name: "SIWE static nonce (not rotated post-use)"
    type: siwe_nonce_stability
    detection:
      nonce_url: https://api.upshift.finance/users/{ADDRESS}/nonce
      addresses_to_test:
        - 0xE0b7DEab801D864650DEc58CbD1b3c441D058C79  # operator
        - 0x931250786dFd106B1E63C7Fd8f0d854876a45200  # executor
      stability_check: "two consecutive GETs return identical value"
      expected_patched: "two GETs return different values"
      expected_live: "two GETs return identical value"
    severity: high

  - id: F3
    name: "NAV manipulation getChangePercentage(0) bypass"
    type: on_chain_implementation
    detection:
      contract: 0xE9B725010A9E419412ed67d0fA5f3A5f40159D32  # coreUSDC vault
      chain: ethereum
      rpc: https://ethereum-rpc.publicnode.com
      eip1967_implementation_slot_check:
        slot: 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        expected_pre_patch_value: 0xf2cd14f02b4fdc0d26681fbc7f60a11b8378f96d
      function_call_check:
        function: "getChangePercentage(uint256,uint256)"
        args: [0, 1000000000000]
        expected_pre_patch_return: 0  # the bug: returns 0 when current is 0
        expected_post_patch_return: 999  # control: function works correctly when fixed
    severity: high

  - id: W29
    name: "AWS Lambda body validator gap"
    type: lambda_endpoint
    detection:
      url: https://lakejdgkzc.execute-api.eu-west-1.amazonaws.com/logUpshiftDeposit
      method: POST
      body: '{}'
      expected_patched_status: 400  # body validator rejects empty body
      expected_live_status: 200  # original behavior accepted fabricated deposits
      ambiguous_status: 500  # body validator added but unclear if write-protected
    severity: high

  - id: W32
    name: "Staging backend with prod-adjacent data"
    type: staging_endpoint
    detection:
      url: https://backend.staging.fractalprotocol.org
      method: GET
      expected_patched_status: 404  # taken offline permanently
      expected_live_status: 200
      ambiguous_status: 503  # could be temporary down
    severity: medium
```

### Daily check execution

```bash
#!/usr/bin/env bash
# ~/arsenal/audit-lifecycle/bin/upshift-reverify.sh
# Run daily at 02:00 UTC (low-traffic window for protocols)

set -e

TARGET="$1"
MANIFEST="$HOME/Desktop/BUGS/${TARGET}-recon/re-verification/DISCLOSURE-MANIFEST.yaml"
TODAY=$(date -u +%Y-%m-%d)
OUTPUT="$HOME/Desktop/BUGS/${TARGET}-recon/re-verification/daily-checks/${TODAY}.yaml"

mkdir -p "$(dirname "$OUTPUT")"

echo "date: ${TODAY}" > "$OUTPUT"
echo "target: ${TARGET}" >> "$OUTPUT"
echo "checks:" >> "$OUTPUT"

# Iterate over primitives in the manifest
yq -r '.primitives[].id' "$MANIFEST" | while read -r PID; do
  ptype=$(yq -r ".primitives[] | select(.id == \"$PID\") | .type" "$MANIFEST")

  case "$ptype" in
    http_endpoint)
      url=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.url" "$MANIFEST")
      method=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.method" "$MANIFEST")
      body=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.body" "$MANIFEST")
      status=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" -H "Content-Type: application/json" -d "$body")
      ;;
    js_bundle_grep)
      hash_page=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.bundle_hash_url" "$MANIFEST")
      bundle_pattern=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.bundle_url" "$MANIFEST")
      # Parse current bundle hash from the index.html
      current_hash=$(curl -s "$hash_page" | grep -oP 'index-[A-Za-z0-9]+\.js' | head -1)
      bundle_url=$(echo "$bundle_pattern" | sed "s/{HASH}/${current_hash#index-}/" | sed 's/\.js\.js/.js/')
      grep_pattern=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.grep_patterns[0]" "$MANIFEST")
      match_count=$(curl -s "$bundle_url" | grep -cE "$grep_pattern" || echo 0)
      status="match_count=${match_count}"
      ;;
    webhook_validity)
      url=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.url" "$MANIFEST")
      status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" -d '{"text":"reverify-noop"}')
      ;;
    siwe_nonce_stability)
      nonce_url=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.nonce_url" "$MANIFEST")
      addr=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.addresses_to_test[0]" "$MANIFEST")
      url=$(echo "$nonce_url" | sed "s/{ADDRESS}/${addr}/")
      n1=$(curl -s "$url" | jq -r '.nonce')
      sleep 2
      n2=$(curl -s "$url" | jq -r '.nonce')
      if [ "$n1" = "$n2" ]; then
        status="stable_nonce_still_live"
      else
        status="rotating_nonce_patched"
      fi
      ;;
    on_chain_implementation)
      contract=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.contract" "$MANIFEST")
      rpc=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.rpc" "$MANIFEST")
      slot=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.eip1967_implementation_slot_check.slot" "$MANIFEST")
      pre_patch=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.eip1967_implementation_slot_check.expected_pre_patch_value" "$MANIFEST")
      current=$(cast storage "$contract" "$slot" --rpc-url "$rpc" 2>/dev/null | tail -1)
      # Implementation slot returns 32 bytes, address is the last 20
      current_addr=$(echo "$current" | sed 's/^0x000000000000000000000000//')
      if [ "0x${current_addr}" = "${pre_patch}" ]; then
        status="impl_unchanged_still_live"
      else
        status="impl_changed_to_${current_addr}"
      fi
      ;;
    lambda_endpoint|staging_endpoint)
      url=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.url" "$MANIFEST")
      method=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.method" "$MANIFEST")
      body=$(yq -r ".primitives[] | select(.id == \"$PID\") | .detection.body // \"\"" "$MANIFEST")
      if [ "$method" = "POST" ]; then
        status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" -H "Content-Type: application/json" -d "$body")
      else
        status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
      fi
      ;;
  esac

  cat >> "$OUTPUT" <<EOF
  - id: ${PID}
    type: ${ptype}
    status: ${status}
    timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
done

# Compare against yesterday's check (if exists) and write drift alerts
YESTERDAY=$(date -u -d "yesterday" +%Y-%m-%d)
YESTERDAY_FILE="$HOME/Desktop/BUGS/${TARGET}-recon/re-verification/daily-checks/${YESTERDAY}.yaml"

if [ -f "$YESTERDAY_FILE" ]; then
  yq -r '.checks[].id' "$OUTPUT" | while read -r PID; do
    today_status=$(yq -r ".checks[] | select(.id == \"$PID\") | .status" "$OUTPUT")
    yesterday_status=$(yq -r ".checks[] | select(.id == \"$PID\") | .status" "$YESTERDAY_FILE" 2>/dev/null || echo "no_data")

    if [ "$today_status" != "$yesterday_status" ] && [ "$yesterday_status" != "no_data" ]; then
      DRIFT_FILE="$HOME/Desktop/BUGS/${TARGET}-recon/re-verification/drift-alerts/${TODAY}-${PID}-drift.md"
      cat > "$DRIFT_FILE" <<EOF
# Drift alert -- ${TARGET} -- ${PID} -- ${TODAY}

Yesterday status: ${yesterday_status}
Today status:    ${today_status}

Direction: $(if [[ "$today_status" =~ patched|404|0|rotating ]]; then echo "TOWARD_PATCHED (good)"; elif [[ "$today_status" =~ live|200|stable|unchanged ]]; then echo "TOWARD_LIVE (regression)"; else echo "AMBIGUOUS"; fi)

Recommended action:
$(if [[ "$today_status" =~ patched|404|0|rotating ]]; then
    echo "- Update DISCLOSURE-MANIFEST.yaml state if all primitives now patched"
    echo "- If this is the first patch and engagement is in 'acked' state, prepare Stage 4 fortress email"
    echo "- If engagement is in 'partially_patched' state, mention in next regular comms"
  elif [[ "$today_status" =~ live|200|stable|unchanged ]]; then
    echo "- URGENT: regression detected, primitive flipped from patched to live"
    echo "- Verify the regression is real (not a deploy in progress)"
    echo "- If confirmed, send same-day notice to acker email -- 'flagging that <primitive> appears to have regressed since <date>, possibly during a deploy'"
  else
    echo "- Investigate the ambiguous status (could be deploy in progress, intermittent failure, or partial patch)"
    echo "- Re-check in 4 hours; if still ambiguous, document and continue normal cadence"
  fi)
EOF
      echo "DRIFT: $PID changed status -- written to $DRIFT_FILE"
    fi
  done
fi

echo "Re-verification check for ${TARGET} complete: $OUTPUT"
```

### Cron registration

```bash
# Add to user crontab via crontab -e
# Run daily at 02:00 UTC (low-traffic window)
0 2 * * * /home/malix/arsenal/audit-lifecycle/bin/upshift-reverify.sh upshift_finance >> /home/malix/Desktop/BUGS/upshift-recon/re-verification/cron.log 2>&1
```

The cron job is per-target. Each active disclosure gets its own line. When an engagement closes (`engagement_closed` state), remove the cron line and archive the daily-checks directory.

## State machine triggers from drift alerts

| Drift pattern | Suggested state transition | Suggested action |
|---|---|---|
| All primitives flip to patched | `partially_patched` → `fully_patched` | Send Stage 4 fortress email within 24h |
| 1+ primitive flips from live to patched, others still live | `acked` → `partially_patched` | Update memory file, no immediate action; mention in next regular comms |
| 1+ primitive flips from patched back to live | `partially_patched` or `fully_patched` → regression | URGENT: same-day notice to acker email -- regression detected |
| New surface appears (e.g., new admin route in JS bundle) | No state change | Note in PS of next outbound comms; offer pre-launch review of new surface |
| `acked` state silent for 14+ days with no drift | `acked` → `re_verification_due` | Send Stage 3 re-verification email at next checkpoint |

## What to monitor beyond the original primitives

The original primitives are the obvious targets. The monitor should also watch for:

### New surface appearance

Run this against the JS bundle daily:

```bash
# Track route inventory delta
TODAY_ROUTES=$(curl -s https://app.target.io/assets/index-CURRENT.js | grep -oE '/[a-z][a-z0-9/_-]+/[a-z][a-z0-9/_-]+' | sort -u)
YESTERDAY_ROUTES=$(cat ~/Desktop/BUGS/<target>-recon/re-verification/route-inventory/$(date -u -d "yesterday" +%Y-%m-%d).txt)
diff <(echo "$YESTERDAY_ROUTES") <(echo "$TODAY_ROUTES")
```

When new routes appear, they are a fresh hunting surface -- often the post-patch refactor introduces NEW bugs while fixing the old ones. The fortress email should offer a passive review of new surface. The re-verification monitor surfaces the routes; you decide whether to investigate.

### Bundle hash rotation without secret rotation

If the bundle hash changes (rebuild) but the leaked secret persists in the new bundle, this is a silent regression -- the team rebuilt but did not rotate. This happened on Upshift between March and April. The monitor should explicitly flag this case.

### EIP-1967 implementation slot upgrades on watched contracts

For every contract in the disclosure scope, watch the implementation slot. Any change is a potential patch. The monitor should:
1. Note the new implementation address
2. Pull the bytecode and run a passive diff against the old implementation
3. If the patched function has changed (signature/selectors), flag for re-verification of F-class findings

```bash
# Per watched contract
CONTRACT="0xE9B725010A9E419412ed67d0fA5f3A5f40159D32"
RPC="https://ethereum-rpc.publicnode.com"

# Get current implementation
OLD_IMPL=$(cat ~/Desktop/BUGS/<target>-recon/re-verification/impl-tracking/$CONTRACT.txt 2>/dev/null || echo "0x0")
NEW_IMPL=$(cast storage $CONTRACT 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $RPC)

if [ "$OLD_IMPL" != "$NEW_IMPL" ]; then
  echo "IMPLEMENTATION CHANGED: $CONTRACT $OLD_IMPL → $NEW_IMPL"
  # Pull both bytecodes, diff, flag changed functions
  cast code $OLD_IMPL --rpc-url $RPC > /tmp/old.bin
  cast code $NEW_IMPL --rpc-url $RPC > /tmp/new.bin
  diff /tmp/old.bin /tmp/new.bin > /tmp/impl-diff.txt
  echo "$NEW_IMPL" > ~/Desktop/BUGS/<target>-recon/re-verification/impl-tracking/$CONTRACT.txt
fi
```

## Memory file integration

When the monitor produces a drift alert, update `~/.claude/projects/-home-malix-Desktop-BUGS/memory/project_<target>.md` with the new patch verification table. The memory file should always reflect the most recent re-verification state.

When the engagement transitions from `engagement_active` → `engagement_closed`, update the memory file to:
- Mark all primitives as resolved
- Move the project to "alumni" status (archived but available for future re-engagement)
- Document the final ex-gratia outcome (if any)
- Encode lessons in `feedback_<target>_<lesson>.md` files

See MEMORY-PROTOCOL.md for the full memory update protocol.

## When to retire the cron

The cron job retires when:
1. All primitives in DISCLOSURE-MANIFEST.yaml are confirmed patched + 30 days of no regression
2. The engagement state is `engagement_closed`
3. The protocol team has explicitly confirmed the disclosure is closed on their side

After retirement, run a final re-verification once at day +90 to confirm long-term stability. Document the final state in the memory file.

## Signal handling

The monitor produces three signal types:

- **Patch signal:** primitive flipped from live to patched. Triggers fortress email or partial-patch comms.
- **Regression signal:** primitive flipped from patched to live. Triggers same-day urgent notice.
- **New surface signal:** new route or new contract appeared. Triggers offer of passive pre-launch review.

The monitor does NOT auto-send any communications. It produces drift alerts; the human decides whether and how to respond. This is by design -- automated outbound to a security contact is a hostile act if mis-timed.
