---
name: grunt-audit-findings-are-known-issues
description: "For the 3FLabs/grunt audit, every finding in the in-repo audit PDFs is a known issue / out of scope"
metadata: 
  node_type: memory
  type: project
  originSessionId: bf6ddb8f-4538-4dca-aedc-0075b7f034a2
---

On the **3FLabs/grunt** engagement, the user ruled: **every finding present in the in-repo audit reports
(ChainSecurity ×2, Cantina ×2 under `audits/`) is a KNOWN ISSUE = out of scope** — INCLUDING the
Acknowledged / RiskAccepted / PartiallyFixed ones, and including any re-derivation (new impact/actor/TVL)
of them.

**Why:** bug-bounty scope rules — prior-audit findings (any disposition) don't pay; only genuinely novel
bugs count.

**How to apply:** discard anything that maps to an audit finding id (3.x.x, CS-GRUNT-*, CS-GRUNTFUND-*,
NOTE-10.*). This overrides the firmaudit default that "Acknowledged = still-live, re-derive new impact."
Hunt only: (a) POST-AUDIT un-reviewed code (the delta after the audit base — e.g. levered-slice perf fee
#190, SyncAllocatorDeposit #196, Pareto pricing reads #191), and (b) novel composition / unwritten-invariant
bugs no audit saw (Door C). F-1 (USCCFund raw-balance) == audit 3.3.1 → KNOWN → dropped.
