# bridge/ — the scope-data bus between the VPS and the cloud drainer

Two environments, two capabilities, one repo in between:
- **Cloud routine `bounty-intake-drain`** (claude.ai context): can read/write the Bounty Intake queue
  (ArtifactData) and can `git clone` GitHub, but its egress BLOCKS program sites.
- **VPS**: has full egress (Cantina API, etc.) and push rights, but no ArtifactData.

So the VPS *publishes* here (`vps-worker/publish-scope-cache.sh`, cron), and the cloud drainer
*clones this repo + the public Immunefi mirror at run start* and resolves scope from them.

- `scope-cache/cantina-bounties.json` — Cantina live bounties (assetGroups, allowedSeverities,
  totalRewardPot, kycRequired, submissionFee, status). Refreshed by the VPS.
- Immunefi is NOT cached here: the cloud clones the public mirror
  `infosec-us-team/Immunefi-Bug-Bounty-Programs-Unofficial` directly (`project/<slug>.json`).

- `cloud-drain-prompt.txt` — the deployed prompt of the cloud routine `bounty-intake-drain`
  (trigger `trig_019PiWsVmHiuTWNEtCqmzZNr`, hourly at :24). Edit here, then push it to the routine with
  RemoteTrigger action=update. On-demand drain: RemoteTrigger action=run.

## Validated 2026-09-26 (end-to-end, real data)
- Immunefi leg: `immunefi.com/bug-bounty/1inch-aqua/` → `project/1inch-aqua.json` → 31 verbatim assets,
  8 verbatim impacts, GO card written.
- Cantina leg: `cantina.xyz/bounties/polymarket` → scope-cache match → 45 assets / 4 tiers + Web&App,
  known-issues, 980 findings, RE-SOURCE card written.
- Operator memory is consulted first (`/tmp/mb/memory/`), so recorded fortress-null / held-finding verdicts
  override the mirror's generic audit pointer.
