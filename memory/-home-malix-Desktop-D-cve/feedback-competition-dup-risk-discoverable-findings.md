---
name: feedback-competition-dup-risk-discoverable-findings
description: in a competition, a finding the audit found or that is discoverable day-1 is dup-capped; weight this hard in go/no-go
metadata:
  type: feedback
---

In an audit COMPETITION with a shared pool, a finding that the project's own audit already surfaced, or that is discoverable on day 1, carries very high PRIVATE-duplicate risk (other competitors filed it early, invisibly). Entering late compounds it.

**Why:** ENS Finding #1 was in a heavily-duplicated cluster (89314 filed 18 Aug opening day, + 89336, 91602 dups, + a separate Medium variant 89249). It was rated Insight, BUT my report was designated **Chief Finding** (the best/canonical report of the Insight cluster) and IS paid a reward — report quality won the rewarded slot over the earlier-dated reports ("only the best report of a given Insight is rewarded"). So the outcome was a paid, recognized Insight, NOT zero. Correction to an earlier in-session claim of "likely no payout": being the best writeup can capture the Chief/rewarded slot even in a duplicated cluster. Still: the finding was highly discoverable (QA-01 signposted it), so it capped at Insight tier; depth on a differentiated corner would have been worth more than a clean writeup of a crowded finding.

**How to apply:** in a competition, discount a finding's expected value by its discoverability × time-since-launch. A signposted/audit-adjacent finding entered weeks late is likely dup-capped regardless of PoC quality. Spend depth on the DIFFERENTIATED corner (the less-obvious surface others skip), not the discoverable one. This is the go/no-go weight, upstream of all the report-quality gates.
