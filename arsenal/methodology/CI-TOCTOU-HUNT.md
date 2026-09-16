# CI/CD Approval-Gate TOCTOU Hunt (Campaign 1 — "Jupyter class")

**Thesis.** The five seed advisories are patched; the value is the *pattern* reused on
other in-scope targets. For GitHub Actions the fresh, under-audited sub-population is
**not** "`pull_request_target` + untrusted checkout with no gate" — generic tools flag
that and most repos fixed it years ago. It is:

> a **privileged trigger** runs, a **maintainer authorization gate** exists (so the
> "no gate" alerts were already closed), **yet the checkout still resolves a MUTABLE ref**
> (a branch, not the SHA that was reviewed at approval time).

That is the time-of-check-to-time-of-use race: the maintainer reviews the PR and the gate
passes at **check** time; `actions/checkout` re-resolves the PR branch at **use** time; the
attacker force-pushes malicious code into the window between the two, and it runs with
secrets and a write token.

## The triad the detector looks for

| leg | signal (any of) |
|-----|-----------------|
| **Privileged trigger** | `pull_request_target`, `issue_comment`, `workflow_run`, `repository_dispatch` |
| **Authorization gate** (the *check*) | `author_association == OWNER/MEMBER/COLLABORATOR`; `contains(labels.*.name, '…')`; `startsWith(comment.body, '/ok-to-test' …)`; actor allowlist; a permission-check action/step; job `environment:` with required reviewers |
| **Mutable checkout** (the *use*) | `actions/checkout` `ref:` = `head.ref`, `github.head_ref`, `refs/pull/N/merge`, `refs/pull/N/head`, `workflow_run.head_branch`; or `repository:` = attacker fork |

**Mutable vs pinned is the whole game.** A branch ref is re-resolved at checkout → race.
`github.event.pull_request.head.sha` is the exact reviewed commit → this is the recommended
**mitigation**, so gate + `head.sha` is *not* the TOCTOU (report only if you can show the SHA
is re-derived from the branch at run time).

## Why a custom layer on top of zizmor/poutine

Validated on the local fixture corpus (`campaigns/ci-toctou/fixtures/`):

| fixture | poutine `untrusted_checkout_exec` | our detector |
|---|---|---|
| gate + `head.ref` (branch)  | 1 | **HIGH** — fresh TOCTOU |
| gate + `refs/pull/N/merge`  | 1 | **HIGH** — fresh TOCTOU |
| gate + `head.sha` (pinned)  | **1 (false-positive for TOCTOU)** | INFO — looks mitigated |
| ungated + `head.ref`        | 1 | LOW — well-known, dup risk |
| plain `pull_request` + `head.ref` | 0 | ignored — not privileged |

poutine returns **`= 1` on all four** privileged cases — it cannot separate the fresh
gated-TOCTOU from the mitigated pinned case or the mass-fixed ungated case. Our gate+ref
correlation converts "4 equal findings" into "2 HIGH worth a fork PoC, 1 INFO to skip,
1 LOW dup-risk." That is the effort/gain filter.

zizmor (`dangerous-triggers`, `artipacked`, `excessive-permissions`) and poutine
(`untrusted_checkout_exec`, `injection`) run alongside as **corroboration columns**, not as
the ranker.

## Tools

- `tools/ci-toctou-detect.py` — the gate+mutable-ref discriminator (PyYAML). Emits ranked
  JSONL. This is the value-add.
- `tools/ci-toctou-scan.sh` — orchestrator: per repo runs poutine `analyze_repo` (API,
  needs `GH_TOKEN`, auto-exported from `gh auth token`), zizmor offline, and the detector;
  sparse-clones only `.github/workflows`; merges, ranks, appends to
  `tracking/ci-toctou-flagged.jsonl`, writes `campaigns/ci-toctou/runs/<ts>/summary.md`.
- External: `zizmor` (pipx), `poutine` (go install), `gato-x` (pipx) — all installed.

## Run it

```bash
# a single repo
tools/ci-toctou-scan.sh --repo owner/name

# a list (one owner/name per line, '#' comments allowed) — the in-scope set
tools/ci-toctou-scan.sh --list inscope-repos.txt --min HIGH

# a whole org's public repos
tools/ci-toctou-scan.sh --org some-org --min MED

# a tree you already cloned
tools/ci-toctou-scan.sh --local /path/to/repo
```

Triage the `HIGH` rows first. Regression self-test any time:
`python3 tools/ci-toctou-detect.py campaigns/ci-toctou/fixtures/`.

## From HIGH candidate to payout

1. Confirm the gate and the mutable checkout are in the **same privileged job** (or a gate
   job that hands the deploy job a mutable ref).
2. Reproduce **in a fork you control** — open a PR, get the gate to pass on benign content,
   then force-push the branch to demonstrate the run executes the post-approval commit.
   A workflow diff + a description of the race window is usually enough; keep any payload
   inert (`echo`, a canary file), never touch secrets or prod.
3. Draft with `report-nerve` + `chill`; disclose through the program.

## Guardrails (non-negotiable)

- **In-scope only.** Read the program policy before running the scanner against its repos.
  Reading public workflow YAML is source review; a PoC is not — keep PoCs in your own fork.
- No exfiltration, no lateral movement, inert payloads only.
- Coordinated disclosure via the program; no publication before the fix.

## Safe pattern (what a fixed workflow looks like)

Split into two workflows: an **unprivileged** `pull_request` job builds/tests the untrusted
code with no secrets; a **privileged** `workflow_run`/`pull_request_target` job pins
`actions/checkout` to `github.event.pull_request.head.sha` captured at approval, sets a
minimal `permissions:` block, and never checks out a branch ref.
