---
name: feedback-measure-the-severity-separating-artifact
description: measure the artifact that SEPARATES severity tiers, not just the one that proves the mechanism
metadata:
  type: feedback
---

Before building PoCs, identify what artifact SEPARATES the severity tiers for this bug class, then measure THAT — not just whatever proves the mechanism exists.

**Why:** ENS Finding #1 (migration grants ROLE_SET_RESOLVER to an unvalidated subgraph controller) was Confirmed real by the project (Immunefi even escalated it as Critical) but rated **Insight**, and the project's own words were: "The report shows no stale-state race (a controller revoked between page load and submit), which is what separates the Medium variant (89249) from this design one." My measured chain proved construction (classifyName→grantRoles calldata) + grant-landing (Sepolia fork, status 1) — the MECHANISM. But the tier boundary (Insight vs Medium) was the STALE RACE, which I only reasoned (Path B), never measured. I measured two legs and neither was the severity-determining one. Outcome: Confirmed Insight + Chief Finding (paid), but measuring the stale-race instead could have reached the Medium tier (89249) — the missing artifact was the difference between a small Insight reward and a larger Medium one.

**How to apply:** for any finding, before writing the PoC, ask "what single fact moves this from Low→Medium→High→Critical for this class?" and make that the measured artifact. For a race/staleness finding, that's the demonstrated race (state changing between read and use), not the downstream effect. Composes with [[cosmos-evm-no-payable-venue]] and [[feedback-in-scope-asset-list-is-literal]]: venue → scope-anchor → severity-separating artifact are three separate gates, all checked before deep PoC work.
