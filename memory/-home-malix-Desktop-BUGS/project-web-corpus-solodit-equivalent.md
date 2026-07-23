---
name: project-web-corpus-solodit-equivalent
description: "Deferred goal: build a Solodit-equivalent WEB/API findings corpus to enrich gravedigger's thin web pattern bank, mirroring how solodit-corpus enriched the SC side"
metadata: 
  node_type: memory
  type: project
  originSessionId: 676ee768-18be-4105-b623-333fd6940088
---

The corpus (c4-corpus + solodit-corpus) is **SC-only**: 4670 findings / 163 named patterns / 4588
discovery methods, wired into the SC hunting skills via `corpus-query <shape> | --route | --methods`.
The **WEB/API side is thin** by comparison — gravedigger routes to `H1-HUNTING-PATTERNS` (~60 patterns)
+ `precedent-scan.sh`, with no structured class-density / detection_tell / discovery_how bank.

**Goal (when there's time — not urgent):** find/build a "Solodit-for-web" — a structured corpus of
disclosed WEB/API bug-bounty findings, classified by web vuln class (IDOR/BOLA · SSRF · auth-bypass ·
XSS · race · business-logic · cache · GraphQL · JWT/OAuth · AI/LLM prompt-injection), each with a
`detection_tell` and a `discovery_how` (the method from the writeup) — mirroring exactly how
solodit-corpus was built (pull → classify → backfill discovery_how → corpus-query --route/--methods).
Wire it into gravedigger + `corpus-query` so a web target gets the same 4-layer plan (density → tell →
pattern → method) the SC side has.

**Candidate sources to evaluate together (the brainstorm starting point):**
- HackerOne hacktivity (public disclosed reports — the richest, the writeup often states the method).
- pentester.land "list of bug bounty writeups" (huge aggregated index).
- PortSwigger Research / Web Security Academy (high-quality technique writeups).
- Bugcrowd VRT (Vulnerability Rating Taxonomy — the class-map/taxonomy backbone) + OWASP WSTG/API-Top-10.
- Intigriti / YesWeHack disclosed reports · openbugbounty.org · existing HackerOne-reports datasets (GitHub/Kaggle).

The build mirrors the SC corpus pipeline (solodit-corpus/{pull,normalize,build_classmap,prep_enrich}.py +
the discovery_how backfill workflow). Decided 2026-06-24 during the Boros engagement, after observing the
corpus is "SC-oriented" and the web side under-served. Relates to [[skill-infrastructure-topology]]
(where the corpus + corpus-query live).

**STATUS 2026-06-27: GROUNDED BUILD PLAN written → `~/Desktop/BUGS/web-corpus/BUILD-PLAN.md`** (source-eval
workflow verified every pull mechanism live). Key finding: the pipeline CLONES not scrapes — existing mirrors
already defeated the H1 anti-bot wall. T1 sources = HF `Hacker0x01/hackerone_disclosed_reports` (12,618 full-body,
frozen May-2024, no $) + `ajaysenr/HackerOne-Disclosed-Reports` (9,642, daily-current = the recency delta) +
`pentester.land/writeups.json` (6,421 pre-tagged, the non-H1 diversifier) + `reddelexc/hackerone-reports` (the $
join-key). T3 backbone = Bugcrowd-VRT + OWASP-API-Top10/WSTG + CWE (anchor classes, don't derive). Sequence:
Phase-0 backbone ½d → Phase-1 v0 (HF+pentesterland turnkey, ship web-corpus-query) 1d → Phase-2 recency+money ½d
→ Phase-3 discovery_how backfill (the product, multi-day) → Phase-4 wire. KEY DIFFERENCE from SC: web product =
`discovery_how` (probe recipe) ranked by PAYOUT-density NOT count (count-sorted web class-map lies: XSS@$200 vs
one BOLA@$20K).

**STATUS 2026-06-27: BUILT (v1, Phases 0-3 DONE) → `~/Desktop/BUGS/web-corpus/`.** Pipeline (idempotent, re-runnable):
`build_backbone.py` (VRT-anchored skeleton) → `normalize-web.py` (HF parquet + pentesterland + ajaysenr + reddelexc,
synonym-mapped) → `build_density.py` (2-axis + re-merges discovery) → `enrich-discovery-how.py` (samples method-rich
bodies) → distillation workflow → `discovery-methods.json`. **Corpus: 15,696 findings · 24 VRT-anchored classes ·
292 discovery_how recipes · real severity + $ (2 axes).** Query: `./web-corpus-query.sh [<shape> | --class <c> |
--route <c> | --methods <c>]` — 4 modes mirroring `corpus-query.sh`. Validated the thesis in data: ATO/SQLi/RCE are
the high-$ + high-severity earners; XSS leads by count but Hdns 0.26 (count lies, on both axes).

**STATUS 2026-06-27: COMPLETE (all 4 phases DONE + WIRED).** Phase 4: `web-corpus-query.sh` symlinked into
`~/arsenal/tools/` (peer of `corpus-query.sh`, resolves via readlink -f); 63 H1 `P-H1-*` patterns cross-linked
(`named-patterns.json`, surfaced in `--route`); wired into `target-router.sh` (Web/API section emits the 4 modes),
`intake/SKILL.md` (Phase 2 pulls web-corpus for WEB shapes), `gravedigger/SKILL.md` (pattern bank = web-corpus, lead
with `--methods`); `refresh.sh` for monthly re-pull. Any web target now auto-gets the 4-layer plan. Pipeline idempotent
(`refresh.sh`). **Phase-3b DONE: discovery_how extended to the pentester.land external-blog slice** (fetch+distill
workflow, 198 writeups fetched w/ wayback-fallback, +192 recipes, source-tagged) → **484 total recipes (292 H1-PoC +
192 blog), ~20/class**; blog recipes are named-CVE-grade (reportlab sandbox-escape, Struts2 OGNL, VSCode markdown
command-URI fence-escape). Corpus is v1.1, production-ready, fully wired. See `web-corpus/STATUS.md`.
