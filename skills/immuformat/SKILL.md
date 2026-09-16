---
name: immuformat
description: >-
  Immunefi-specific report FORMAT and section ORDER. Use whenever drafting or assembling a bug bounty report for
  submission to an Immunefi program (bugs.immunefi.com), or when the user asks to "format for Immunefi", "the Immunefi
  section order", "immuformat", or reviews an Immunefi submission's structure. Encodes the canonical Immunefi form
  fields (Target / Category / Impact(s) verbatim / PoC Link) and the fixed description section order (Brief/Intro →
  Vulnerability Details → Impact Details → Recommended Fix → References → Proof of Concept), plus the per-section
  conventions distilled from a gold-standard accepted report. This is the CONTAINER and ORDER layer; it composes with
  report-nerve (the rigor: killshot, chain-factoring, negative space, weight accounting) and chill (the voice for human
  triagers). Load it alongside report-nerve when the platform is Immunefi; report-nerve alone leaves the sections in
  HackerOne/Cantina order, which Immunefi triagers do not expect.
---

# immuformat — Immunefi report format & section order

The purpose of this skill is narrow and load-bearing: **put the report in the exact shape an Immunefi triager expects,
in the exact order, with the section-specific moves that make each part land.** Get the rigor from `report-nerve` and
the voice from `chill`; get the *Immunefi container* from here. When both are active, this skill decides the section
ORDER and HEADERS; report-nerve decides what rigor fills each; chill decides the sentences.

Calibration source: a Decentraland `builder-api` report (split-normalisation auth bypass, scene-signature case-flip,
five services, measured state-modifying write) that was accepted. Every convention below is drawn from it. When in
doubt about "how much / what shape," match that report.

---

## Form fields (top of the submission, before the description)

- **Target** — the exact in-scope asset URL/host, copied from the scope table (e.g. `https://builder-api.decentraland.org`,
  or a GitHub `tree/<tag>` URL for a code asset). One asset — the one you MEASURED an effect on if several share the bug.
- **Category** — the scope view: `Websites & Apps` or `Blockchain/DLT`.
- **Impact(s)** — the impact line **copied verbatim** from the program's in-scope impact list. Never paraphrase it;
  the triager matches your report against that exact string. Pick the one your PoC actually demonstrates.
- **PoC Link** — a **secret gist** URL (see report-nerve gist hygiene: secret, don't share the link elsewhere, delete
  after the report closes).

---

## Description — the six sections, in THIS order (do not reorder)

Immunefi's description template is these six headers. Use them verbatim as `##`/bold headers. The PoC is its own field
on the form but is written last and in the same document.

### 1. Brief/Intro
One tight paragraph — the killshot in prose. Name the control, the exact split/defect in one breath, the MEASURED
impact, and the breadth. It must stand alone: a triager who reads only this paragraph knows what broke, that you proved
it, and how far it reaches. Gold example opens: *"builder-server rejects AuthChains … that rejection compares … with a
case-sensitive ===, while the signature … is verified over a payload folded to lowercase … any scene a player walks into
can issue authenticated requests as that player … I measured PUT /v1/projects/{uuid} accepted and persisted … and the
same defect exists in four further in-scope services."* Empirical verb ("I measured"), no hedge, breadth stated.

### 2. Vulnerability Details
The mechanism, proven. This section has a recurring internal sub-structure — use the ones that apply, as bold
sub-headers:

- **The two halves that disagree** (or "The root cause"): show BOTH sides of the defect with `file:line` and a code
  quote each — the guard AND the thing it fails to bind. Name the anti-pattern class in prose ("split-normalisation
  authorization class"; "ordered-container mismatch"; "unbound-token"). Per report-nerve: name the pattern, not the
  symptom.
- **The same defect in N in-scope services** (breadth, when it applies): a table. Columns:
  `Host | Service | Location (file:line) | Honest response | Bypassed response`. Label each cell **(measured)** or
  **(source)** — honesty about what you ran vs what you read is the credibility multiplier. File against the host where
  you MEASURED a state change; list the others as source-confirmed.
- **How the attacker obtains the primitive** (reachability): trace where the attacker gets the capability, and prove it
  is not gated — ideally across ALL runtimes/paths ("four of four official runtimes will sign a request aimed at any
  host"). Completeness ("N of N") kills the "but maybe one path is safe" objection.
- **Provenance: this is a bypass of a control you shipped deliberately** (when the control was added on purpose): cite
  the introducing commit/PR and date. This turns the vendor's own code into the threat-model proof — "this code exists
  because [the thing you did] is already treated here as a vulnerability." (Same move as report-nerve's BP2-024 pivot:
  an audited/deliberate control is a recevability ASSET here, used to prove the threat is in-scope — not a liability.)
- **What this is not** (negative space, mandatory when nearby exclusions exist): take each nearby exclusion or
  look-alike impact BY NAME, one short paragraph, and distinguish precisely why it does not apply. Then name the one
  exclusion (if any) that argues in YOUR favor and quote it. This is where the report pre-empts the close.
- **Duplicate check** (the dedup discipline, in-body for Immunefi): describe the TRACE the program leaves when it closes
  this class of bug (a defensive `well_known_issues.md` entry; an unmerged fix branch; a silent redeploy). Show you
  looked for it across every relevant repo/branch, with dates. End honestly: "absence of a note is not proof nobody
  reported this, but there is no trace across N repositories." (This is the public-channel half of Gate 4; the private
  prior-submission is irreducible and invisible — do not claim it cannot exist.)

### 3. Impact Details
The concrete consequences at real scale. Lead with the capability in one sentence ("any scene a player walks into can
act as that player against five APIs, any method/path, any body"). Then enumerate the REACHABLE routes you read from
source but **deliberately did not exercise** (ethical restraint stated), each with its internal check and why the bypass
satisfies it. Keep measured vs source-read separate. Keep precise claims precise — if a route's name overstates its
effect, correct it in prose ("POST /collections/:id/publish does NOT spend MANA; it is a post-publication sync"). Close
with the structural point (why the bug is invisible to review, why the seam has no owner). Anchor magnitude in the
class's native unit (funds, accounts reachable, hosts, traffic) per report-nerve's impact-ledger.

### 4. Recommended Fix
Concrete and layered: (a) the minimal patch (the exact lines), (b) the SYSTEMIC fix (fix the seam, not the instance —
"five services share one bug because each reimplemented it; patch the shared middleware"), (c) standardise on the safe
pattern the vendor already wrote elsewhere if one exists ("validateAuthMetadata is a fail-closed allowlist in the same
file"), (d) any defense-in-depth that ends the class (bind host+body into the signed payload). Imperative voice.

### 5. References
Bulleted, each a single verifiable fact with a URL or `repo/path:line`. Include the introducing-commit link, the source
locations for every claim, and the runtimes/services touched. End with the disclosure line:
"No prior public disclosure found. [the empty/stale well-known-issues file] … no fix branch touching [the sink] as of
[date]."

### 6. Proof of Concept
Written last, richest section. Sub-blocks in this order:

- **What the PoC does** — one paragraph: self-contained, throwaway keypair each run, what it sends, the single variable
  that differs between blocked and accepted (isolate the one bit that flips).
- **Measured output** — verbatim wire output, **baseline first (control works) THEN the bypass (control defeated)**.
  The baseline proving the guard fires on honest input is what makes the bypass meaningful. Paste real HTTP status +
  body, trimmed. Use a third host/endpoint where the failure MOVES BETWEEN LAYERS rather than disappearing, if you have
  one — it's the cleanest proof the guard was passed.
- **The state-modifying artifact** (the killshot evidence): the persisted row / on-chain tx / server-side artifact,
  full and quoted, showing the attribution (the address the request was accepted AS). "Acceptance produced a persistent
  server-side artefact retrievable by a separate request, not a transient 200."
- **Chain acceptance verification** (mandatory for auth-class; from report-nerve): Ethical variant used · Target
  endpoint · **What this proves** (one sentence) · **What this does NOT prove** (one sentence — the honest limit, e.g.
  "I did not present a victim's AuthChain, so I did not write to a victim's account; the middleware attributes to
  whichever address the chain names, and obtaining a victim signature is the runtimes' job").
- **Testing conduct** (Immunefi expects this for live-host web testing): throwaway identity only, no third-party data,
  which endpoints were read-only/empty-body-safe, which destructive routes were deliberately NOT exercised. **Disclose
  any artefact left behind** proactively ("I would rather flag it than have you find it"). If the program's
  prohibited-activities clause seems to forbid live testing, address it head-on: quote the clause, show the Web&App
  rules require a demonstrated PoC, resolve the tension by minimal live exercise, and offer to re-file in another
  evidence form if they read it differently.
- **The script** — the full runnable PoC inline (also in the gist). Self-contained, one `pip install` line, no config,
  cleans up after itself.

---

## Composition (what this skill does NOT do)

- **Rigor** (killshot construction, weight accounting, chain-factoring, anti-pattern naming discipline, the
  closing-gate greps for self-flagellation / severity-concession / unverified-path): `report-nerve`. Load it too.
- **Voice** (contractions, hedges on inferences only, no em-dashes, human-tired-researcher tone to pass anti-AI
  screening): `chill`. Immunefi uses human triagers, so apply chill unless the program is a formal private audit.
- **Scope/severity validation and the KILLED-FINDINGS pattern match**: the intake/recevability gates (Phase 0, the 5
  gates). immuformat assumes the finding already passed those; it only shapes the write-up.

Typical flow: pass the 5 gates → report-nerve builds the killshot + rigor → **immuformat orders it into the six
Immunefi sections + the PoC sub-blocks** → chill styles the prose → closing-gate greps → gist (secret) → submit.

---

## Pre-submission checklist (Immunefi-specific, on top of report-nerve's)

- [ ] Impact(s) field is the program's impact string **verbatim**, and the PoC demonstrates that exact impact.
- [ ] Target is the single asset where the effect was MEASURED (not merely source-confirmed).
- [ ] Six description sections present, in order: Brief/Intro · Vulnerability Details · Impact Details · Recommended
      Fix · References · Proof of Concept.
- [ ] Every breadth-table cell and every impact claim is labelled measured vs source.
- [ ] "What this is not" names each nearby exclusion/look-alike BY NAME and distinguishes it; the favorable exclusion
      is quoted.
- [ ] Duplicate-check paragraph: the public-channel trace was searched (fix branches, well-known-issues, `git log -S`
      on the sink across in-scope tags AND a PR/issue scan whose bodies you read — a fix PR body referencing an
      Immunefi submission is the strongest dup signal), dates given, "no trace / absence-not-proof" stated honestly.
- [ ] PoC block: baseline-then-bypass, the persisted artifact quoted with its attribution, Chain-acceptance
      what-it-proves/what-it-does-not, Testing-conduct with any left-behind artefact disclosed.
- [ ] `file:line` references verified against the IN-SCOPE tag/branch (not `main`) — a triager who clicks must land
      exactly on the cited line.
- [ ] PoC gist is secret; plan to delete it when the report closes.
- [ ] Live-host-testing clause addressed if the program's prohibited-activities text could be read to forbid it.

---

## The one-line reminder

Immunefi order = **Brief/Intro → Vulnerability Details → Impact Details → Recommended Fix → References → Proof of
Concept**; form fields = **Target · Category · Impact(s) verbatim · PoC Link (secret gist)**; and the PoC always runs
**baseline first, then the bypass**, ending on the **persisted, attributed artifact**.
