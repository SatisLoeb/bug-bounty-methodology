#!/usr/bin/env bash
# Deterministic, browser-less program resolver. Prints JSON on stdout.
# Cantina -> public API ; Immunefi -> local JSON mirror ; GitHub -> repo id.
set -uo pipefail
URL="${1:?usage: rapide-resolve.sh <program-url>}"
IMMUNEFI_MIRROR="${IMMUNEFI_MIRROR:-$HOME/immunefi-mirror}"
low=$(printf '%s' "$URL" | tr 'A-Z' 'a-z')
case "$low" in
  *cantina.xyz*)
    curl -s -m 15 "https://cantina.xyz/api/v0/opportunities?type=bounty" \
    | URL="$URL" python3 -c "import sys,json,os,re
u=os.environ['URL'].lower(); m=re.search(r'/(bounties|competitions)/([^/?#]+)',u); slug=(m.group(2) if m else '')
try: d=json.load(sys.stdin)
except Exception: print(json.dumps({'platform':'Cantina','error':'api'})); sys.exit()
it=d.get('items') or d.get('opportunities') or d.get('data') or []
if not it and isinstance(d.get('groups'),list): it=[x for g in d['groups'] for x in (g.get('items') or [])]
if not it and isinstance(d,list): it=d
norm=lambda s:re.sub(r'[^a-z0-9]','',str(s).lower())
ns=norm(slug)
hit=[o for o in it if ns and ns in norm(str(o.get('slug',''))+str(o.get('title',''))+str(o.get('name','')))]
out=hit or it
print(json.dumps({'platform':'Cantina','slug':slug,'matched':bool(hit),'matches':[{'name':o.get('title') or o.get('name'),'slug':o.get('slug') or o.get('id'),'maxReward':o.get('maxReward') or o.get('maxRewardUsd') or o.get('reward')} for o in out[:5]]}))" 2>/dev/null \
    || echo '{"platform":"Cantina","error":"resolve"}'
    ;;
  *immunefi.com*)
    slug=$(printf '%s' "$URL" | sed -E 's#.*/bug-bounty/([^/?#]+).*#\1#')
    if [ -d "$IMMUNEFI_MIRROR" ]; then
      f=$(grep -rliE "\"?id\"?[^A-Za-z0-9]{0,4}$slug|/$slug([\"/]|$)" "$IMMUNEFI_MIRROR" 2>/dev/null | head -1)
      if [ -n "$f" ]; then echo "{\"platform\":\"Immunefi\",\"slug\":\"$slug\",\"file\":\"$f\"}"; sed -n '1,400p' "$f"
      else echo "{\"platform\":\"Immunefi\",\"slug\":\"$slug\",\"needs_browser\":true,\"note\":\"not found in mirror\"}"; fi
    else echo "{\"platform\":\"Immunefi\",\"slug\":\"$slug\",\"needs_browser\":true,\"note\":\"mirror absent at $IMMUNEFI_MIRROR\"}"; fi
    ;;
  *github.com*)
    echo "{\"platform\":\"GitHub\",\"repo\":\"$(printf '%s' "$URL" | sed -E 's#.*github.com/([^/]+/[^/?#]+).*#\1#' | sed 's/\.git$//')\"}"
    ;;
  *) echo "{\"platform\":\"Other\",\"url\":\"$URL\",\"needs_browser\":true}";;
esac
