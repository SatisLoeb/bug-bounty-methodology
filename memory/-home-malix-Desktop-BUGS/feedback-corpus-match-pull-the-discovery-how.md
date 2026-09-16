---
name: feedback-corpus-match-pull-the-discovery-how
description: "When a corpus pattern matches a target surface, always pull its discovery_how (the reproducible METHOD), not just the pattern label"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ca8b34fa-8fd2-45f5-86fb-0070e17b52af
  modified: 2026-08-27T21:00:54.695Z
---

When querying the corpus (`~/arsenal/tools/corpus-query.sh` + the c4/solodit/immunefi `findings.jsonl`) and a pattern MATCHES the target's surface, do not stop at the pattern label/description — **also pull HOW that finding was actually discovered** (`discovery_how` field per finding, or `--methods <class>`), and convert it into a concrete investigative procedure carried into the code.

**Why:** the pattern name is the WHAT (a tell); the `discovery_how` is the COMMANDABLE technique — "trace the WRITES of the mutating action vs the READS in the distribute path, diff which mappings stay stale, simulate action→time→distribute" is reproducible; "P-STAKE-005 checkpoint bug" is not. The operator asked for this explicitly (Intuition engagement, 2026-08-27): "quand tu trouve un match regarde aussi comment il a été trouvé." Matches the existing corpus calibration ([[boros-tooling-calibration]] / feedback_corpus_methods_beats_route: lead with `--methods`, the detection_tell is the highest-value output → turn each tell into a lens BEFORE pattern-matching).

**How to apply:** on any corpus match → (1) grep the 3 findings.jsonl banks for the source finding's `discovery_how`; (2) if none logged (pure pattern-taxonomy entry), the pattern description is the tell; (3) also pull `--methods <class>` for the matched class; (4) write the METHOD (procedure), not the pattern name, into the engagement's lens file; (5) drive that procedure into the live surface by hand. The corpus AIMS the drill, never NAMES the bug ([[feedback-corpus-coverage-gate-lead-dont-improvise]]).
