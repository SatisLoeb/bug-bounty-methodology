---
name: feedback-carveout-does-not-prove-wildcard
description: An explicitly out-of-scope subdomain does NOT prove the parent domain asset grants subdomains — settle wildcard scope from the raw asset identifier string before mapping an estate
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 39a5b3a4-4f73-4978-9b3d-9425d8f24dbd
  modified: 2026-07-29T10:52:30.948Z
---

On a bounty program listing **bare** domain assets (`anfcorp.com`, not `*.anfcorp.com`), do **not** infer
that subdomains are in scope from the presence of an explicitly *out-of-scope* subdomain. Settle it from
the raw asset identifier string **before** spending recon on the subdomain estate.

**Why:** A&F HackerOne, 2026-07-29. The scope table listed `nonmerchvendorprofile.anfcorp.com` and
`applications.abercrombie.com/` as separate INELIGIBLE assets. I read that as proof the parent granted the
subtree — *"you don't carve out a subdomain unless the parent grants it"* — and on that basis mapped 222
CT names, fingerprinted 49 live hosts, and built a whole thesis around the corporate estate (istio B2B
portals, GlobalSCAPE EFT, AEM publish tier, GitLab, Apigee).

The inference was wrong. Live H1 GraphQL and `arkadiyt/bounty-targets-data` both return four bare URL
assets with **no `*.` anywhere**, and the dataset demonstrably preserves wildcards (168 of 33,890 URL
assets carry a literal `*`). The killing evidence was **behavioural**: `corporate.abercrombie.com` was
added in 2024 as its own asset *while `abercrombie.com` was already in scope*. If the bare domain covered
its subtree, that addition would have been a no-op. Programs carve out subdomains to say "don't bother",
which is worth doing precisely **because** people would otherwise test them — the carve-out is evidence
about researcher behaviour, not about scope grammar.

**How to apply:**
1. Before enumerating any estate, pull the raw asset identifiers — `arkadiyt/bounty-targets-data`
   (`data/hackerone_data.json`, `data/wildcards.txt`, `data/domains.txt`) settles it in one curl and works
   without a platform session. A wildcard appears verbatim as `*.example.com`.
2. Prove the dataset *can* express what you are looking for before trusting its absence — count how many
   other assets in the same corpus carry a `*`. An absence in a corpus that never records the thing is
   not evidence.
3. Check whether a subdomain was **added as its own asset** while its parent was already listed. That is
   the behavioural proof that scope is enumerated, not inherited.
4. Treat a carve-out as a signal about where researchers go, not about what the parent grants.

Cost of the error: a full passive estate map that was already out of scope by the time it was drawn. The
scope check costs one request and must come first.

Relates to [[project-abercrombie-fitch-h1-intake]], [[feedback-read-both-or-clauses-in-exclusions]] and
[[feedback-report-count-distribution-picks-the-asset]] (rank by saturation only *after* scope is settled —
per-asset report counts are meaningless across assets that are not comparable in size).
