---
name: wickr-aws-phase0-skip
description: Wickr/AWS Wickr (H1) — Phase 0 SKIP 2026-07-04; program LIVE&paying but surface collapses (dead clients + no-pay AWS-VDP successor + dup-saturation); only re-open on a solo-provisionable classic admin.wickr.com authed console
metadata: 
  node_type: memory
  type: project
  originSessionId: 4e823388-864a-4389-9dd6-5fd94590eafb
---

**Wickr / AWS Wickr — hackerone.com/wickr (Amazon-funded H1). Day-0 target-diet SKIP, 2026-07-04.**

Handed a stale scope table (dated Jan 24 2023): www.wickr.com Ineligible; Wickr Pro/Me + per-platform Eligible; admin.wickr.com Eligible; support.wickr.com Ineligible. 6-agent Phase-0 workflow + my own browser verification.

**Program IS live and paying** — verified by my own screenshot of hackerone.com/wickr (NOT agent inference): response efficiency 91%, rewards updated 2026-06-01, Critical **$25k–$100k**, accepting reports. So the payer-engagement kill does NOT fire. (Agent verdicts split 2-vs-3 on this pivot; 3 agents wrongly inferred a dormant/no-pay AWS-VDP because they couldn't render the H1 SPA via curl/WebFetch. Execution broke the tie — see [[feedback-workflow-agents-coverage-not-verdict]].)

**Why SKIP anyway — the surface collapses independently of the paying sponsor:**
- All **10 per-platform client lines are decommissioned** = $0: Wickr Me dead 2023-12-31, Wickr Pro dead 2024-01-31 (unmigrated data deleted). The stale table lists dead products as "Eligible Critical."
- Crypto core `wickr-crypto-c` = 4-audit + AWS-internal **dup-fortress**, **non-commercial** "Public Review License," findings route to unpaid GHSA/AWS channel. Not a bounty play.
- Surviving product **AWS Wickr = an AWS managed service** → AWS VDP (no bounty) + explicitly OOS of the paid Amazon VRP + tenant-gated.
- **Only payable+reachable+in-scope surface = `admin.wickr.com`** (live "classic" Wickr Pro admin console, CloudFront→Envoy→K8s, most-resolved eligible asset 3/10) + live Wickr Pro backend (`gw-pro-prod`, `messaging-pro-prod`, `api.prod.calling`, `pro-download`, `countly`). Class = web **authz/BFLA/IDOR/tenant-isolation**.
- Dup-saturation: ~203 reports/90d vs ~10 resolved lifetime (~1-3% resolve rate).

**Binding re-open gate (the one unresolved fact):** the real admin migrated to `console.aws.amazon.com/wickr` (OOS, Mar 2025). Unknown whether a **newly solo-provisioned** AWS Wickr network still exposes a **classic `admin.wickr.com` login (in-scope, paid)** or only the AWS console (OOS, no-pay). If only the latter → the authed BFLA surface is unreachable solo → only low-EV unauth remains → stay SKIP. If a new network DOES open a classic in-scope console → it becomes a legit web BFLA/tenant-isolation engagement (Critical $25k–$100k) worth `/wide` → `/power`. I did NOT create a Wickr account (prohibited action + no-auto-orchestration) — operator must provision to lift the gate.

**Lesson:** a LIVE&PAYING program can still be a correct SKIP — EV = severity × p_bounty × **reachable-surface**, not just sponsor responsiveness. AWS-acquired products route the survivor to a no-pay VDP; only the legacy `*.vendor.com` estate sits under the old paying program, and only if still solo-provisionable. Aligns with [[feedback-target-diet-is-the-binding-constraint]] and [[ev-gate-check-program-responsiveness-not-just-severity]]. OUTCOMES id `wickr-aws-phase0-skip-2026-07-04`.
