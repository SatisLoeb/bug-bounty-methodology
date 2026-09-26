# vps-worker — VPS side of the Bounty Intake bridge

**What the VPS does now: publish scope data.** It does NOT drain the queue.
(Proven 2026-09-26: a headless `claude -p` on the VPS has no `ArtifactData` tool on any version —
the artifact database is reachable only from a claude.ai-context session. The drainer is therefore
the cloud routine `bounty-intake-drain`; see `../bridge/README.md`.)

## The bridge in one line
Paste link on the page → queue (artifact db) → hourly cloud routine clones this repo + the Immunefi
mirror, resolves real scope, writes the card → board updates. The VPS keeps `bridge/scope-cache/`
fresh for the platforms the cloud cannot fetch (Cantina).

## Deploy on the VPS (one time)
```bash
git clone https://github.com/SatisLoeb/bug-bounty-methodology ~/bug-bounty-methodology
# make sure `git push` works non-interactively from the VPS (SSH key or token in the remote URL)
cd ~/bug-bounty-methodology/vps-worker && ./publish-scope-cache.sh     # first publish
(crontab -l 2>/dev/null; echo "*/30 * * * * $HOME/bug-bounty-methodology/vps-worker/publish-scope-cache.sh >> $HOME/bug-bounty-methodology/bridge/scope-cache/cron.log 2>&1") | crontab -
```
Log: `bridge/scope-cache/publish.log`.

## Files
- `publish-scope-cache.sh` — the VPS job (Cantina list → `bridge/scope-cache/cantina-bounties.json`, commit, push).
- `rapide-resolve.sh` — browser-less resolver kept for ad-hoc use on the VPS.
- `drain-prompt.md`, `worker.sh`, `verify.sh`, `install.sh`, systemd units — the earlier VPS-drainer
  attempt, superseded (kept for reference; `verify.sh` will report ArtifactData FAIL by design).
