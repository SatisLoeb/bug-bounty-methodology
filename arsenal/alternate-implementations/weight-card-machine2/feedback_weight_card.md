---
name: Weight Card — Mandatory Before Non-Informational Submission (machine 2 alternate)
description: Every finding claiming severity ≥ Low MUST contain at least one numerical anchor — computed dollar loss (W1) or paid precedent with dollar figure (W5). Dashboard slots W2/W3/W4 surface argumentation weakness but don't block. Complementary to Chain Proof Gate — Chain Proof answers "does the exploit execute?", Weight Card answers "is it profitable, irreversibly, market-priced at what?".
type: feedback
---

**Rule:** Before submitting any finding claiming severity ≥ Low with a dollar impact, populate the Weight Card template in REPORT-STANDARD.md Weight Accounting section. The hard gate is at least one numerical anchor via W1 (computed dollar loss) OR W5 (paid precedent with dollar figure). Both slots cannot be qualitative. An unpaid "related H1 #xxx" does not satisfy W5.

**Anti-pattern phrase grep (mechanical trigger — case-insensitive):**
```bash
grep -niE "could drain|could extract|significant funds|substantial losses|large number of users|many users affected|potentially affects|widespread impact|catastrophic|devastating|severe financial damage|exposes users to|estimated to cost|impact is significant|attacker could (drain|extract|steal)" "$DRAFT_PATH"
```

**If ≥1 match AND no numerical anchor:**
- Option A: Compute W1 from real inputs. Inputs must be cited (on-chain reads with block numbers, API readbacks with response dates, documented protocol limits). Formula must be visible.
- Option B: Run `arsenal/tools/precedent-scan.sh "<class>"` to populate W5 with paid precedents. The script emits a copy-paste-ready table block formatted for REPORT-STANDARD Weight Accounting — no reformatting needed.
- Option C: **DoS exception** — if the finding is a DoS on a critical endpoint, use W1 form (b): `downtime × req/s × affected users`. Duration must be measured or extrapolated from a reproducible PoC, not asserted.
- Option D: Downgrade severity to Informational. Remove all phrases claiming higher impact. An acknowledged Low beats a dismissed High.

**Why:** Phemex R2 (submitted 2026-04-10, marked Informative 2026-04-13) had a proven chain (trading API key called /assets/transfer successfully) but the weight was narrated: *"I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital."* Informative, 2 rep, $0. One hour later WEEX-002 was saved by Chain Proof Gate via a user question, but Phemex R2 died on a different failure mode entirely — the chain was fine, the weight was absent.

Rule #15 existed before 2026-04-13 ("honest impact quantification") but fired reactively — it punished overselling after the fact. Weight Card encodes the computation requirement proactively, via a template that cannot be filled with adjectives.

The two failure modes are orthogonal:
- **Chain incomplete** (WEEX-002 pre-edit): chain proof absent → Chain Proof Gate catches it.
- **Weight uncomputed** (Phemex R2): chain proof present but no numerical anchor → Weight Card catches it.

Both gates are needed. Neither replaces the other.

**How to apply:**
- Fill W1 OR W5 with real numbers before the draft is considered submission-ready. The rest of the draft can be in any state; the numerical anchor must be concrete.
- If the finding is smart contract with a forge-test PoC that asserts state delta → W1 auto-passes (the asserted delta IS the computed loss). Still run precedent-scan.sh for W5 to market-price.
- If the finding is pure information disclosure already at Informational/Low → Weight Card is N/A.
- Dashboard slots W2/W3/W4 are visibility tools, not blockers. Fill them where possible because emptiness surfaces argumentation weakness pre-submission.
- The precedent-scan.sh output format is critical: it must emit a copy-paste-ready W5 table directly in REPORT-STANDARD syntax. If the output requires manual reformatting, the slot gets skipped under deadline pressure.

**The absurdity test:** replace any adjective in the draft with "$3.47". If the sentence becomes absurd ("$3.47 funds could drain"), the adjective is doing the work of the argument. Put a real number there or the claim is not defensible.

**Trigger keywords to self-detect during drafting:** if I catch myself writing any of the anti-pattern phrases during the Impact section, stop immediately. Either compute W1, populate W5 via precedent-scan, or downgrade severity before continuing.

**Reference files:**
- `~/Desktop/BUGS/WEIGHT-CARD.md` — full procedure, Stages 1-4
- `~/Desktop/BUGS/PREFLIGHT-CHECK.md` criterion D8 — gating in preflight
- `~/Desktop/BUGS/REPORT-STANDARD.md` Weight Accounting section — mandatory template slot
- `~/Desktop/BUGS/CLAUDE.md` rule #37 — top-level rule
- `~/arsenal/tools/precedent-scan.sh` — fast W5 population from H1-HUNTING-PATTERNS corpus

**Not applicable to:**
- Pure information disclosure findings already claimed at Informational/Low severity.
- Smart contract findings with forge-test state delta assertions (the delta IS the anchor).
- Findings where the HTTP response IS the weight (e.g. /api/users returning 247 KYC records — count is impact).
