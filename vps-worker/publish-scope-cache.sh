#!/usr/bin/env bash
# publish-scope-cache.sh — VPS role in the bridge: fetch scope data the cloud sandbox cannot reach
# (its egress blocks program sites) and commit it into this repo. The cloud drainer clones the repo
# at run start and reads bridge/scope-cache/*. Run from cron every 30-60 min.
# Cantina's list endpoint already carries assetGroups (scope), allowedSeverities, totalRewardPot,
# kycRequired, submissionFee, status — so the list IS the scope source (detail endpoints 404).
set -uo pipefail
REPO="${REPO_DIR:-$HOME/bug-bounty-methodology}"
cd "$REPO" || { echo "repo not found: $REPO"; exit 1; }
git pull -q --rebase origin master 2>/dev/null || true
mkdir -p bridge/scope-cache
TS=$(date -u +%FT%TZ)
RAW=$(curl -s -m 25 "https://cantina.xyz/api/v0/opportunities?type=bounty" || true)
if printf '%s' "$RAW" | python3 -c 'import sys,json;json.load(sys.stdin)' 2>/dev/null; then
  printf '%s' "$RAW" | TS="$TS" python3 -c 'import sys,json,os
d=json.load(sys.stdin)
it=d.get("items") or []
if not it and isinstance(d.get("groups"),list): it=[x for g in d["groups"] for x in (g.get("items") or [])]
out={"fetched_at":os.environ["TS"],"source":"https://cantina.xyz/api/v0/opportunities?type=bounty","count":len(it),"items":it}
print(json.dumps(out,indent=1,sort_keys=True))' > bridge/scope-cache/cantina-bounties.json
  echo "$TS cantina ok ($(python3 -c "import json;print(json.load(open('bridge/scope-cache/cantina-bounties.json'))['count'])") bounties)" >> bridge/scope-cache/publish.log
else
  echo "$TS cantina fetch FAILED" >> bridge/scope-cache/publish.log
fi
git add bridge/scope-cache
if git diff --cached --quiet; then echo "$TS no change"; else
  git commit -q -m "scope-cache: refresh $TS" && git push -q origin master && echo "$TS published"
fi
