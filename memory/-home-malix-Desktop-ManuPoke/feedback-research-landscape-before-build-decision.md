---
name: feedback-research-landscape-before-build-decision
description: "When extending tooling/arsenal, run a research workflow to map the landscape BEFORE asking build/architecture decisions."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 57f794ea-c79f-4e82-a039-ae933c905aa5
---

When the task is to extend/improve tooling (e.g. make [[project-nuke-static-barrage-skill]] cover non-EVM), the user does NOT want an immediate AskUserQuestion about architecture (extend-in-place vs sibling skill, which ecosystems). He wants a multi-agent **research workflow FIRST** to study the actual ecosystem of options, then decide from evidence.

**Why:** decisions about his personal arsenal must be grounded in a verified map of what tools actually exist (anti-vaporware / anti-SaaS-gated), not in my priors. He rejected a premature decision-question and said "lance d'abord un workflow pour étudier l'écosystème."

**How to apply:** on any "extend/choose tooling" turn, launch a Workflow that inventories + adversarially verifies the option space (and computes the negative space) before proposing a direction. Ultracode is on for this project — default to orchestrating a workflow for substantive work. Only ask the architecture decision once the survey is in.
