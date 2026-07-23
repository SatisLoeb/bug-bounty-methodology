---
name: feedback-verify-before-working-no-theater
description: "How to work with this operator — verify state by execution before acting, never fabricate a need or perform behavioral theater"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 676ee768-18be-4105-b623-333fd6940088
---

The operator corrected me repeatedly in one session for three linked failure modes:

1. **Not verifying state before working.** I treated "3186 Solodit findings pulled this morning" as a clean source on the README's word; he said "tu es certain que ça s'est fait correctement il faut verifier ce qu'on a vraiment" — execution found 134 dupes + a 1200-char excerpt cap. Same for the corpus identity: I diffed against the wrong corpus without checking which one existed.
2. **Hallucinating a need that doesn't exist.** I drafted a Deribit defense comment he never asked for (he'd sent the report context to LOG an OUTCOMES row, not to mount a defense). He called it "une halucination d'un besoin qui n'existe pas et du theatre comportementale."
3. **Behavioral theater.** Wrapping a non-request in elaborate strategy/process. He cuts it with "fait ce que je te dit."

**Why:** he is an expert operator who drives precisely; he wants execution against verified reality, not narration or invented scope.

**How to apply:** before acting on any claimed state (a file's contents, a pull's result, which artifact exists), run the check and paste the observed output — Read/grep/curl/parse, not the README's or my own assumption. Confirm what the actual ask is before producing artifacts; if he sent context, ask whether it's for logging, analysis, or action rather than assuming the most elaborate one. No preamble, no manufactured deliverables. Relates to the standing order [[CLAUDE.md]] §"NEVER TRUST AGENT/WORKFLOW OUTPUT" — the same verify-by-execution discipline applies to my own assumptions, not just agents.
