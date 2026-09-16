---
name: decentra
description: >-
  The PRECISION STANDARD for security reports. Encodes the transferable rigor that made report #87537 read the way it
  did (Confirmed + paid) so that EVERY future report — any target, any finding class, web or on-chain — carries the same
  precision, not the same subject. This is a quality bar and a discipline, not a program dossier and not a template:
  finding-class-agnostic and target-agnostic by design. Its single invariant is "every sentence is exactly as strong as
  its evidence — never stronger, never weaker", and the principles below are that invariant made operational. Use
  whenever drafting or revising any serious external security report, or when the user says "decentra", "avec la
  précision habituelle", "écris-le comme d'habitude / comme #87537", "même rigueur", "encode ma précision". decentra
  COMPOSES the stack and owns none of its machinery: structural rigor and the closing-gate greps are report-nerve; voice
  is chill; the Immunefi container/section order is immuformat. decentra is the standard those three serve — the layer
  that decides how precise each sentence has to be, calibrated on #87537 as the worked example of the bar being met.
---

# decentra — the precision standard for security reports

The job is to encode **precision**, not a subject. Not "how to write a Decentraland auth-bypass report" but "how to
write ANY report with the exactness that gets a report Confirmed on the first read." The standard is one line, and every
principle below is that line made operational:

> **Every sentence is exactly as strong as its evidence. Never stronger (that is an overclaim the triager will find and
> use against the whole report). Never weaker (that is a concession that gives away severity you earned).**

Precision is not verbosity, not hedging, and not confidence. It is the exact match between what you write and what you
can show. A precise report is often shorter and always more bankable than an impressive one.

Calibration: report #87537 (Decentraland `builder-api`, split-normalisation auth bypass, Confirmed + paid 2026-08-10).
It is cited below only as the **worked example of the bar being met** — the illustrations are there to show the
principle in the wild, not to make this skill about that finding or that program. The principles transfer to a reentrancy
bug, an IDOR, a signature-malleability, a price-oracle manipulation, or a deanonymization, unchanged.

---

## Load order (decentra is the standard, the stack is the machinery)

- **report-nerve** — structural rigor: killshot, chain-of-custody comment, Chain Acceptance block, weight accounting,
  anti-pattern naming, the closing-gate greps, the 250-line budget. Most of the precision principles below have a
  mechanical enforcement point in report-nerve; decentra is the standard those enforcements serve.
- **chill** — voice: the tired-competent-researcher register that carries precise content without reading as AI. On for
  any program with human triagers (default on; dial per chill's own triggers).
- **immuformat** — container: the six Immunefi sections and their order. Load it when, and only when, the target is an
  Immunefi program; for HackerOne / Cantina / Sherlock / C4 / GHSA use report-nerve's native order.
- **decentra** (this) — the precision bar the other three are held to.

decentra changes nothing about which sections exist or how sentences sound. It changes how much each sentence is allowed
to claim.

---

## The precision principles

Each is the invariant applied to one recurring decision. Read them as "here is a place a report usually claims too much
or too little, and here is the exact calibration." The one-line #87537 illustration shows the principle met; it is not
the principle.

1. **Measured vs source, on every empirical claim.** Tag what you ran (measured) apart from what you read (source), in
   the table cell and in the prose. Never let a source-read pass as a measurement. This single honesty is the largest
   credibility multiplier in the report, because it tells the triager exactly which claims they can re-run and which they
   are trusting you on. *#87537: every breadth-table cell carried `(measured)` or `(source)`; the report was filed against
   the one host where a write was actually observed.* Prevents: the triager finding one asserted-not-shown claim and
   discounting all the others.

2. **Bound your own severity on everything you did not fully prove.** Name the high-impact route or escalation, then
   explicitly decline to claim it ("not traced, not claiming reachable"; "not demonstrated against a victim"), and on
   what you DO claim, state the ceiling ("not unbounded"; "self-inflicted"; "fails closed"). Under-claiming the untraced
   is what makes the measured claims bankable. *#87537 did this ~7 times; it is the report's dominant tone.* Prevents:
   an overclaim collapsing under triager pressure and dragging the real finding down with it.

3. **A capability claim cites an artifact, never a name or a structure.** "X exposes Y" / "the session reads Z" / "this
   writes" must point to a pasted response body, a measured status, an on-chain artifact — not a route name, a bundle
   entry, or the shape of the thing. Structure is a hypothesis; the observed artifact is the conclusion. If you cannot
   show the body, downgrade the sentence to an honest description or cut it. *(report-nerve Rule 4 is the mechanical
   enforcement; this is the standard it serves.)* Prevents: the Helix-#134 failure — four capabilities inferred from
   route names, all collapsing when the bodies were finally pulled.

4. **Name the class precisely, and prove its boundary by enumeration.** Do not write "missing auth"; name the exact
   anti-pattern ("split-normalisation authorization", "unbound-payload", "bearer-of-ID"). Then do not assert the class,
   prove its edge: probe the neighbouring inputs and show exactly where the control's boundary falls. *#87537 tried
   `dcl:explorer`, an arbitrary string, the empty string, a suffixed variant, and the key removed, to show the guard
   fired on exactly one literal — which is what licensed the "split-normalisation" name.* Prevents: a class claim the
   triager waves away as "maybe it is broader/narrower than you think."

5. **Negative space, at two levels.** Mechanism level: say what the bug is NOT ("not a crypto break, not a forgery; the
   signature is genuine, it just covers less than the request") so it cannot be mis-filed as a weaker or different class.
   Scope level: take each nearby exclusion or look-alike BY NAME and distinguish it, then quote the one that argues in
   your favour. Honest limits build credibility faster than any amount of overclaiming. *#87537 distinguished three
   named exclusions and quoted the favourable one.* Prevents: mis-classification downward, and the pre-emptable close.

6. **When a name overstates the effect, deny AND re-anchor.** Correct the route-name inflation, then immediately re-state
   the residual TRUE (smaller) capability, so the correction is a sharpening, not a retreat. *#87537: "POST
   /collections/:id/publish does NOT spend the owner's MANA ... it is a post-publication sync; the outward effect is a
   forum post in the owner's name."* Prevents: an impact section that reads as a walkback and bleeds severity.

7. **Root-cause to the seam, not the symptom.** State the structural cause as an ownerless assumption: each side
   defensible in isolation, the bug living in the belief neither side wrote down. This is the difference between a
   symptom a patch closes narrowly and a class a patch closes at the root. *#87537: "createPayload folding case is
   defensible in isolation, comparing with === is defensible in isolation; the defect exists only in the seam, and the
   seam has no owner."* Prevents: a narrow patch that leaves the class alive (and a report that reads as shallow).

8. **Prior-art precision.** Hunt the trace the program leaves when it closes this class (a well-known-issues entry, an
   unmerged fix branch, a `git log -S` on the sink), give dates, and end on "absence of a note is not proof nobody
   reported this." If the finding sits near your own prior work, make the distinctness argument load-bearing (distinct
   root cause, separately measurable, survives the other patch). Prevents: a close as duplicate / already-known.

9. **Provenance as self-proof, when it is available.** When the vendor's own code or history proves the threat is in
   scope — an introducing commit, a control shipped on purpose, a value the client computes and the server ignores —
   cite it, and turn "you already treat this as a vulnerability" into the argument. Prevents: a threat-model debate you
   could have foreclosed.

10. **Baseline-then-contrast — only when the finding HAS a contrast.** When the control genuinely works on honest input
    and fails on the exploit input, show both with one variable isolated; the working baseline is what makes the bypass
    mean something. When there is nothing to contrast (the property is broken by construction, e.g. a field that is never
    covered at all), do NOT force the mold — prove the property directly instead. Forcing an "honest baseline" onto a
    finding that has none produces an incoherent section that undermines its own claim. *(This is a judgment lesson: the
    moves are calibrated to specific finding shapes and do not all transfer; match the move to the finding, never the
    finding to the move.)* Prevents: the incoherent baseline the verify pass caught on the body-binding test.

11. **Fix precision, and fix coherence.** Give the minimal patch plus one structural fix, in prose. Then check the fix
    against the whole system you just mapped: it must not re-introduce a defect the program already knows about, must not
    recreate the very anti-pattern you are reporting, and must actually be complete (if a shared component needs the
    change, say all consumers need it, not one). The precision of the report extends to the precision of the
    recommendation. *(Lesson from the body-binding test: a first-draft fix bolted new fields onto the same case-folding
    join that caused the original bug.)* Prevents: a fix the triager rejects as naive, which taints the finding.

12. **Register carries the precision; it does not fight it.** The content is exact; the prose is a tired competent
    researcher, not a consulting deliverable. The killshot and every empirical assertion stay clean and unhedged (they
    are facts); hedges attach only to inferences. Precision and the human voice are the same discipline seen twice: say
    exactly what you can show, in the words of someone who actually did the work. *(chill owns the mechanics; decentra
    requires that the voice never softens a measured claim nor dresses up an unmeasured one.)*

**The meta-rule over all twelve:** when a principle would have you claim more than you can show, the principle loses —
cut the claim. When it would have you concede more than the evidence forces, the principle loses — hold the line. The
invariant at the top is the only thing that never yields.

---

## Applying the standard (judgment, not a checklist to fill)

- These principles are a **bar**, not a template. #87537 met the bar with a five-service auth chain; a one-endpoint
  finding meets the same bar with five precise lines. Size the report to the finding (chill Principle 0), then hold every
  line to the invariant.
- **Do not force a move that does not fit the finding's shape** (principle 10 generalised). A move that was precise for a
  case-flip can be imprecise for a reentrancy or an oracle bug. The bar is the invariant; the moves are how it usually
  gets met, not a list to complete.
- **Precision cuts both ways in triager responses** (report-nerve's discipline): no self-flagellation, no unsolicited
  severity concession, no unverified path mentioned as if it were a claim. A path enters a comment only with a PoC pass
  or a documented kill at `file:line`.

---

## The precision gate (run before any report is final)

This sits on top of report-nerve's / chill's / immuformat's own checklists; it is the invariant, checked directly.

- [ ] Every empirical sentence is labelled measured or source, and no source-read is phrased as a measurement.
- [ ] Every "X exposes / reads / writes / is identical" points to a shown body or measured artifact, not a name (grep
      the draft for `\{\.\.\.\}` and for capability verbs sitting next to a route name).
- [ ] Every high-impact route you did not fully prove is explicitly not-claimed; every claim you keep has its ceiling
      stated.
- [ ] The class is named precisely and its boundary is shown (enumeration / baseline), not asserted — and any
      baseline-then-contrast actually has a contrast to show.
- [ ] The recommended fix does not recreate the reported anti-pattern or a known-adjacent one, and names all consumers
      if the fix is in a shared component.
- [ ] report-nerve closing-gate greps clean (self-flagellation / severity-concession / unverified-path / body
      placeholder); chill F1 em-dashes at zero.
- [ ] The report is sized to the finding; nothing is claimed to fill a section.

---

## Composition (who owns the machinery)

- **Structural rigor + the closing-gate greps + triager discipline**: report-nerve.
- **Voice**: chill.
- **Immunefi container/order** (only when the program is Immunefi): immuformat.
- **The precision bar those three are held to**: decentra.

decentra owns no sections, no sentences, no scope facts. It owns the standard: *every sentence exactly as strong as its
evidence.* If a program-specific scope dossier is ever wanted (hosts, `file:line`, exclusions for a particular target),
that is a separate, per-target artifact, not this skill — this skill stays finding- and target-agnostic on purpose.

## The one-line reminder

Write every sentence exactly as strong as its evidence: label measured vs source, bound every unproved claim, cite
artifacts not names, name the class and prove its edge, root-cause to the ownerless seam, and never force a move the
finding's shape does not support. #87537 is what the bar looks like when it is met; the bar is the point, not the report.

## Skill metadata

- **Version**: 2.0 (re-scoped from a Decentraland dossier to the general precision standard)
- **Calibrated on**: report #87537 (Confirmed + paid, 2026-08-10) as the worked example of the bar being met; and on the
  verify-pass lessons from applying the standard to a differently-shaped finding (principles 10 and 11).
- **Composes**: report-nerve (rigor) + chill (voice) + immuformat (Immunefi container). decentra is the standard, not the
  machinery.
- **Maintainer**: user (malix / SatisLoeb / MalikX31 contexts).
- **Note**: the earlier Decentraland-specific dossier (v1.1) is preserved separately; it is a per-target scope artifact,
  not part of this skill.
