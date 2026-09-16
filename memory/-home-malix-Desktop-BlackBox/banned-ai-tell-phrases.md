---
name: banned-ai-tell-phrases
description: "Words/phrases that read as Claude/LLM output — ban from reports AND chat, not just in chill"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: fcc7d312-e6c4-471a-a52c-b9b70879eda2
  modified: 2026-08-22T10:42:23.871Z
---

Running ban-list of phrases the user flags as obvious AI/Claude tells. Avoid in external-facing writeups AND in chat to the user (the user notices them in conversation too).

- **"load-bearing" / "load bearing"** — flagged 2026-08-22 as "typically Claude." Use plain alternatives: "the claim the whole thing rests on", "the key step", "critical to X", or just name the thing directly.

**Why:** these are high-frequency LLM markers; they undercut the anti-AI voice that [[report-no-self-devaluation]] and the chill/report-nerve skills work to build, and the user clocks them in chat too.

**How to apply:** add new offenders here as the user calls them out; extends the chill skill's forbidden-patterns (F1-F12) with a personal ban-list. Grep drafts for each entry before finalizing. Don't just swap synonyms mechanically — rewrite the sentence so the point stands on its own.
