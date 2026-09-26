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
