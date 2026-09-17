---
name: ens-critical-chief-cold-reengagement
description: "ENS Critical Confirmed Chief win (#92483) + the method that produced it — repeated cold blackbox re-engagement; bounds the speed corollary"
metadata: 
  node_type: memory
  type: project
  originSessionId: 92bde771-2461-462b-95e1-e8bacc979742
  modified: 2026-09-17T01:27:27.464Z
---

**The win (verified, dated):** Immunefi ENS audit competition (start 2026-08-18, end 2026-09-14, $70k pool). Operator's report **#92483 — "Migrate to v2, hand your name's resolver to a third party the app never validated" = Critical / Confirmed / Chief Finding.** Submitted **2026-09-10, only 4 days before close** (screenshot "7 days ago" from 09-17 confirms). Chief = lead of the cluster, full reward, not a shared dup. App-layer SEAM: the app never validates the resolver on the v2 migration path. This is the operator's biggest recent result and the live counterexample to the Sept-2026 NO-GO string.

**Method that produced it — REPEATED COLD BLACKBOX RE-ENGAGEMENT.** Operator audited ENS **three separate times as three different engagements**, each in a blackbox environment with ZERO info carried from the prior passes, approaching it each time as if never seen. The finding "il fallait aller le chercher" — surfaced only on a later cold pass, not pass 1.

**Why it works (operationalizes the 2nd Maxim):** "the better you understand the code, the more you've adopted the dev's mental model = maximum blindness." A warm reader who already "understands" ENS stops looking where the bug lives. Forcing a cold re-read N times refuses to let pass-1 understanding calcify into agreement with the dev, so each pass re-hunts the silence. The field did ONE warm pass, missed the corner → operator is Chief. Cold re-engagement is the countermeasure to understanding-blindness, made repeatable.

**Bounds the SPEED COROLLARY (playbook §6, born of RSK #90518 corpse).** "Délai n'ajoute aucune qualité, repro propre → soumets" holds only for DISCOVERABLE/CONTESTED findings where dup-privé races you. This win is the counter-instance: late submit (window's last quarter), Chief anyway, because the DIFFERENTIATED corner had no race — Chief-on-late is the PROOF nobody else found it in 27 days. Rule with the missing boundary: **speed for the shallow/contested; depth-over-time (cold re-engagement) for the differentiated corner.** See [[feedback-competition-dup-risk-discoverable-findings]].

**Cost condition (venue gate):** 3× re-engagement = 3 full audits for one finding — only pays on a FRESH high-ceiling comp with a differentiated corner where Chief takes full reward. On a farmed program it's burned effort. Pairs with [[venue-landscape-2026-09]] (fresh comps are bursty, not permanent-zero; ENS was a live window that just closed).

**Corrects stale prior:** earlier ENS memory ([[feedback-measure-the-severity-separating-artifact]], [[feedback-competition-dup-risk-discoverable-findings]]) logged an ENS finding as Insight/dup — that was a DIFFERENT, weaker ENS submission; #92483 is the Critical Chief. ENS was NOT a dead/farmed target; my census framing of it was wrong.

Open thread to capture: what did the 3rd cold pass LOOK AT (the angle) that the warm 1st/2nd pass had stopped looking at — that is the transferable core.
