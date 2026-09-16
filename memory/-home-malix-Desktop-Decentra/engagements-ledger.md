---
name: engagements-ledger
description: "Where the authoritative record of past bug-bounty/audit engagements lives, and the top confirmed wins"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 356020ee-d70f-46f0-b012-256db3060b38
  modified: 2026-09-09T16:56:11.179Z
---

The authoritative structured ledger of submitted findings is `~/Desktop/BUGS/OUTCOMES.jsonl` (103 findings across 86 protocols; fields: protocol, finding, severity_claimed, outcome, date_submitted, payout_usd — note payout_usd is currently NOT populated). Narrative wins/losses with actual paid amounts are in `~/Desktop/BUGS/PLAYBOOK.md`. A consolidated human-readable inventory tiered by status is at `~/Desktop/BUGS/ENGAGEMENTS-INVENTORY.md` (compiled 2026-09-09).

Confirmed paid: Decentraland #87537 (Critical, $8k), Upshift Finance ($10k direct), Royco Day (Cantina), Transak #3619539 (~$3k), Request Finance F18 ($1k), Mt Pelerin #88293 (High), protobufjs GHSA-q6x5-8v7m-xcrf. dHEDGE #92214 still awaiting triage — see [[dhedge-92214-submitted]].

Operator handles: MalikX / SatisLoeb (Cantina, gists), Xvush (GHSA/CVE).

Caveat: the report IDs in `H1-HUNTING-PATTERNS.md` (Dropbox, PayPal, Shopify, etc.) are PUBLIC reports by OTHER researchers used as pattern examples — not the operator's own engagements.
