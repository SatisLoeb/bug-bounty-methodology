#!/usr/bin/env python3
"""
ci-toctou-detect.py -- GitHub Actions approval-gate TOCTOU signature detector.

Campaign 1 (Jupyter class). The fresh, under-audited sub-population is NOT
"pull_request_target + untrusted checkout with no gate" (generic tools flag that,
most repos fixed it years ago). It is:

    privileged trigger  AND  a maintainer AUTHORIZATION GATE exists
                        AND  the checkout still resolves a MUTABLE ref
                             (a branch, not a SHA captured at approval time)

That is the time-of-check-to-time-of-use race: the maintainer reviews the PR at
approval time, the gate passes, then `actions/checkout` re-resolves the PR branch
at run time -- the attacker force-pushes malicious code into the window between.

The recommended mitigation is to pin the checkout to `github.event.pull_request.head.sha`
(the exact reviewed commit). So gate + branch-ref = candidate; gate + head.sha = mitigated.

Usage:
    ci-toctou-detect.py <path>...          # files or dirs (scans .github/workflows/*.yml)
    ci-toctou-detect.py --json <path>...   # JSONL findings on stdout
    ci-toctou-detect.py --repo owner/name --json <dir>   # tag findings with a repo slug

Exit code 0 always (a scanner, not a gate). Findings go to stdout.
"""
import sys, os, re, json, glob, argparse

# ------------------------------------------------------------------ triggers
# Triggers that run in a PRIVILEGED context (secrets + write token) while the
# ref/content is attacker-influenced.
PRIV_TRIGGERS = {
    "pull_request_target",   # classic: runs on base, secrets available, PR is attacker's
    "issue_comment",         # /ok-to-test bots; comment is attacker's, runs privileged
    "workflow_run",          # runs after an untrusted workflow, has write token
    "repository_dispatch",   # external event, custom payload
}
# workflow_call is only privileged if the caller is; noted, not scored high alone.
SOFT_TRIGGERS = {"workflow_call"}

# ------------------------------------------------------------ gate signatures
# A maintainer AUTHORIZATION GATE: the "check" half of the TOCTOU.
GATE_PATTERNS = [
    (r"author_association", "author_association check"),
    (r"\bOWNER\b|\bMEMBER\b|\bCOLLABORATOR\b", "association role compare"),
    (r"labels\.\*\.name|github\.event\.label\.name|contains\([^)]*label", "label gate"),
    (r"startsWith\(\s*github\.event\.comment\.body", "slash-command comment gate"),
    (r"/ok-to-test|/ok_to_test|/lgtm|/approve\b|/retest|/test\b|/build\b|/deploy\b", "slash-command token"),
    (r"github\.actor\s*==|contains\(\s*fromJSON|contains\(\s*'\[|allowlist|allow_list", "actor allowlist"),
    (r"check-user-permission|has-write-access|member-check|is-collaborator|permission-check", "permission-check action"),
    (r"slash-command-dispatch|peter-evans/slash-command|check-permission", "slash-dispatch/permission action"),
    (r"collaborators/.*/permission|/orgs/.*/members/", "gh api permission probe"),
]
# Job-level environment: with required reviewers is also a gate (approval protection).
ENV_GATE_KEY = "environment"

# ------------------------------------------------- checkout ref classification
CHECKOUT_ACTION = re.compile(r"actions/checkout(@|$)")

# MUTABLE branch refs -> re-resolved at checkout time -> TOCTOU race window.
MUTABLE_REF = [
    (r"github\.event\.pull_request\.head\.ref", "pull_request.head.ref (branch)"),
    (r"github\.head_ref", "github.head_ref (branch)"),
    (r"refs/pull/[^/'\"]*\}?\}?/merge", "refs/pull/N/merge (re-resolved)"),
    (r"refs/pull/[^/'\"]*\}?\}?/head", "refs/pull/N/head (re-resolved)"),
    (r"github\.event\.workflow_run\.head_branch", "workflow_run.head_branch (branch)"),
    (r"github\.event\.pull_request\.head\.label", "pull_request.head.label (branch)"),
    (r"github\.event\.comment\.[a-z_]*ref", "comment-derived ref"),
]
# PINNED sha refs -> the recommended mitigation (exact reviewed commit).
PINNED_REF = [
    (r"github\.event\.pull_request\.head\.sha", "pull_request.head.sha (pinned commit)"),
    (r"github\.event\.workflow_run\.head_sha", "workflow_run.head_sha (pinned commit)"),
    (r"github\.event\.pull_request\.merge_commit_sha", "merge_commit_sha (pinned)"),
]
# Fork-repo checkout (amplifier: pulls attacker's repo regardless of ref kind).
FORK_REPO = re.compile(r"github\.event\.pull_request\.head\.repo\.full_name")

# FORK-EXCLUSION guard: an `if:` condition that restricts the privileged job to
# SAME-REPO events, so a fork PR (the attacker) never reaches it. This is a STRONG
# mitigation for pull_request_target / workflow_run -- downgrade to INFO, not a race.
FORK_EXCLUSION = [
    (r"head_repository\.full_name\s*==\s*github\.repository", "workflow_run.head_repository == repo (fork-excluded)"),
    (r"head\.repo\.full_name\s*==\s*github\.repository", "head.repo.full_name == repo (fork-excluded)"),
    (r"github\.repository\s*==\s*[^=]*head\.repo\.full_name", "repo == head.repo.full_name (fork-excluded)"),
    (r"github\.repository\s*==\s*[^=]*head_repository\.full_name", "repo == head_repository.full_name (fork-excluded)"),
    (r"head\.repo\.fork\s*==\s*false|!\s*github\.event\.pull_request\.head\.repo\.fork", "head.repo.fork == false (fork-excluded)"),
    (r"pull_request\.head\.repo\.owner\.login\s*==\s*github\.repository_owner", "head.repo.owner == repo owner (fork-excluded)"),
]


def find_fork_exclusion(blob):
    for pat, label in FORK_EXCLUSION:
        m = re.search(pat, blob, re.I)
        if m:
            return label
    return None


def as_list(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def trigger_names(on):
    """`on:` may be a str, a list, or a dict. Return the set of trigger names."""
    if isinstance(on, str):
        return {on}
    if isinstance(on, list):
        return set(map(str, on))
    if isinstance(on, dict):
        return set(map(str, on.keys()))
    return set()


def find_gates(blob):
    """Return list of (label, snippet) gate hits found anywhere in a text blob."""
    hits = []
    for pat, label in GATE_PATTERNS:
        m = re.search(pat, blob, re.I)
        if m:
            hits.append((label, m.group(0)[:60]))
    return hits


def classify_checkout_ref(ref_str):
    """Return ('mutable'|'pinned'|'unknown', detail) for a checkout ref value."""
    s = str(ref_str)
    for pat, label in MUTABLE_REF:
        if re.search(pat, s):
            return "mutable", label
    for pat, label in PINNED_REF:
        if re.search(pat, s):
            return "pinned", label
    return "unknown", s[:60]


def walk_steps(job):
    return as_list(job.get("steps"))


def analyze_workflow(path, repo=None):
    try:
        import yaml
        with open(path, "r", errors="replace") as fh:
            raw = fh.read()
        doc = yaml.safe_load(raw)
    except Exception as e:
        return [{"file": path, "error": f"parse: {e}"}]
    if not isinstance(doc, dict):
        return []

    # PyYAML turns the bare key `on:` into boolean True. Recover it.
    on = doc.get("on", doc.get(True))
    trigs = trigger_names(on)
    priv = sorted(trigs & PRIV_TRIGGERS)
    soft = sorted(trigs & SOFT_TRIGGERS)
    if not priv and not soft:
        return []  # not an attacker-influenced privileged workflow

    findings = []
    jobs = doc.get("jobs", {}) or {}

    # Pre-compute which jobs are GATE JOBS (their `if` or a step carries a maintainer
    # authorization gate). The exec-job that checks out untrusted code is often a
    # SEPARATE job gated cross-job via `needs:` (the classic slash-command shape:
    # check-permission -> needs -> run). Propagate the gate across `needs`.
    gate_jobs = set()
    for jid, jb in jobs.items():
        if not isinstance(jb, dict):
            continue
        blob = str(jb.get("if", ""))
        for st in as_list(jb.get("steps")):
            if isinstance(st, dict):
                blob += "\n" + str(st.get("if", "")) + "\n" + str(st.get("name", "")) + "\n" + str(st.get("uses", ""))
        # a collaborator/permission-check github-script step also gates
        if find_gates(blob) or re.search(
                r"getCollaboratorPermissionLevel|check-user-permission|has-write-access|"
                r"collaborators/[^/]*/permission|actions-cool/check-user-permission",
                json.dumps(jb)):
            gate_jobs.add(jid)

    for job_id, job in jobs.items():
        if not isinstance(job, dict):
            continue
        needs = job.get("needs")
        needs = needs if isinstance(needs, list) else ([needs] if needs else [])
        inherited_gate = any(n in gate_jobs for n in needs)
        job_if = str(job.get("if", ""))
        env_gate = ENV_GATE_KEY in job and bool(job.get(ENV_GATE_KEY))

        # Collect checkout steps and their ref classification within this job.
        checkouts = []
        step_if_blob = job_if
        gate_step_before = False
        for st in walk_steps(job):
            if not isinstance(st, dict):
                continue
            uses = str(st.get("uses", ""))
            name = str(st.get("name", ""))
            sif = str(st.get("if", ""))
            step_if_blob += "\n" + sif + "\n" + name
            # a permission/label check *step* preceding checkout counts as a gate
            if find_gates(name + "\n" + uses + "\n" + sif):
                gate_step_before = True
            if CHECKOUT_ACTION.search(uses):
                withblk = st.get("with", {}) or {}
                ref = withblk.get("ref", "")
                repo_field = str(withblk.get("repository", ""))
                kind, detail = classify_checkout_ref(ref) if ref else ("unknown", "(default ref)")
                fork = bool(FORK_REPO.search(repo_field)) or bool(FORK_REPO.search(str(ref)))
                checkouts.append({
                    "step": name or uses,
                    "ref": str(ref),
                    "ref_kind": kind,
                    "ref_detail": detail,
                    "fork_repo_checkout": fork,
                    "gate_before_in_job": gate_step_before,
                })

        if not checkouts:
            continue

        # Runtime-resolved PR ref: a checkout `ref` that is a STEP OUTPUT (steps.X.outputs.Y)
        # fed by a github-script/run step that resolves the PR head at run time
        # (pulls.get(...).head.sha, github.head_ref, etc.). This is mutable-equivalent even
        # though it looks like a sha -- the reviewed commit is NOT pinned at approval time,
        # so a force-push after the gate wins the race. Reclassify such refs as mutable.
        job_blob = json.dumps(job)
        pr_resolve = re.search(
            r"pulls\.get|\.head\.sha|\.head\.ref|github\.head_ref|head_ref|"
            r"pull_request\.head|event\.issue\.number", job_blob)
        for c in checkouts:
            if c["ref_kind"] in ("unknown", "pinned") and re.search(
                    r"steps\.[A-Za-z0-9_-]+\.outputs\.", c["ref"]) and pr_resolve:
                c["ref_kind"] = "mutable"
                c["ref_detail"] = "runtime-resolved PR ref via step output (force-push race)"

        # Gate detection: job-level `if`, any step `if`/name, or env protection.
        gate_hits = find_gates(step_if_blob)
        gate_present = bool(gate_hits) or env_gate or inherited_gate or any(c["gate_before_in_job"] for c in checkouts)
        gate_labels = sorted({h[0] for h in gate_hits}) + (["environment protection"] if env_gate else []) \
            + (["inherited gate via needs:"] if inherited_gate else [])
        # Fork-exclusion guard: same-repo `if` condition -> fork PR never reaches this job.
        fork_excl = find_fork_exclusion(step_if_blob)

        for c in checkouts:
            mutable = c["ref_kind"] == "mutable"
            pinned = c["ref_kind"] == "pinned"
            untrusted = mutable or pinned or c["fork_repo_checkout"] or (
                c["ref_kind"] == "unknown" and c["fork_repo_checkout"]
            )
            # Only report privileged + some untrusted checkout signal.
            if not (priv and (mutable or pinned or c["fork_repo_checkout"])):
                continue

            # ---- scoring ----
            if fork_excl:
                # Same-repo guard: the untrusted fork PR cannot reach this privileged job.
                sev, cls = "INFO", f"fork-excluded ({fork_excl}); untrusted fork PR cannot reach this job"
            elif priv and gate_present and mutable:
                sev, cls = "HIGH", "gate+mutable-ref TOCTOU (fresh sub-population)"
            elif priv and mutable and not gate_present:
                sev, cls = "LOW", "ungated untrusted checkout (well-known; dup risk)"
            elif priv and gate_present and pinned:
                sev, cls = "INFO", "gate+pinned-sha (looks mitigated; verify sha not re-resolved)"
            elif priv and pinned and not gate_present:
                sev, cls = "MED", "ungated untrusted-code-exec via pinned attacker sha"
            else:
                sev, cls = "LOW", "untrusted checkout (review)"
            if c["fork_repo_checkout"] and sev in ("HIGH", "MED"):
                cls += " +fork-repo"

            findings.append({
                "repo": repo,
                "file": os.path.relpath(path),
                "trigger": priv or soft,
                "job": job_id,
                "severity": sev,
                "class": cls,
                "gate_present": gate_present,
                "gate_signals": gate_labels,
                "checkout_step": c["step"],
                "checkout_ref": c["ref"],
                "ref_kind": c["ref_kind"],
                "ref_detail": c["ref_detail"],
                "fork_repo_checkout": c["fork_repo_checkout"],
                "fork_excluded": fork_excl,
            })
    return findings


def iter_workflow_files(paths):
    for p in paths:
        if os.path.isfile(p):
            yield p
            continue
        if not os.path.isdir(p):
            continue
        # If p is itself a workflows dir, yield its yaml directly.
        if os.path.basename(os.path.normpath(p)) == "workflows":
            for pat in ("*.yml", "*.yaml"):
                yield from glob.glob(os.path.join(p, pat))
            continue
        # Otherwise recurse and pick up every .github/workflows/*.y*ml beneath p.
        for root, dirs, files in os.walk(p):
            # skip vendored/noise dirs for speed
            dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "vendor", "target")]
            if root.replace("\\", "/").endswith(".github/workflows"):
                for fn in files:
                    if fn.endswith((".yml", ".yaml")):
                        yield os.path.join(root, fn)


SEV_ORDER = {"HIGH": 0, "MED": 1, "INFO": 2, "LOW": 3}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--json", action="store_true", help="emit JSONL")
    ap.add_argument("--repo", default=None, help="tag findings with owner/name")
    ap.add_argument("--min", default="LOW", choices=list(SEV_ORDER), help="min severity to print")
    args = ap.parse_args()

    seen = set()
    all_f = []
    for f in iter_workflow_files(args.paths):
        if f in seen:
            continue
        seen.add(f)
        for fi in analyze_workflow(f, repo=args.repo):
            if "error" in fi:
                if args.json:
                    print(json.dumps(fi))
                continue
            all_f.append(fi)

    minrank = SEV_ORDER[args.min]
    all_f = [f for f in all_f if SEV_ORDER.get(f["severity"], 9) <= minrank]
    all_f.sort(key=lambda x: (SEV_ORDER.get(x["severity"], 9), x.get("repo") or "", x["file"]))

    if args.json:
        for fi in all_f:
            print(json.dumps(fi))
        return

    color = {"HIGH": "\033[1;31m", "MED": "\033[0;33m", "INFO": "\033[0;36m", "LOW": "\033[0;37m"}
    nc = "\033[0m"
    for fi in all_f:
        c = color.get(fi["severity"], "")
        print(f"{c}[{fi['severity']}]{nc} {fi.get('repo') or ''} {fi['file']} :: job={fi['job']}")
        print(f"        class   : {fi['class']}")
        print(f"        trigger : {', '.join(fi['trigger'])}")
        print(f"        gate    : {fi['gate_present']}  {fi['gate_signals']}")
        print(f"        checkout: [{fi['ref_kind']}] {fi['checkout_ref'] or '(default)'}  -> {fi['ref_detail']}")
        if fi["fork_repo_checkout"]:
            print(f"        fork    : checks out attacker fork repo")
    print(f"\n== {len(all_f)} finding(s); HIGH={sum(1 for f in all_f if f['severity']=='HIGH')} "
          f"MED={sum(1 for f in all_f if f['severity']=='MED')} "
          f"INFO={sum(1 for f in all_f if f['severity']=='INFO')} "
          f"LOW={sum(1 for f in all_f if f['severity']=='LOW')}", file=sys.stderr)


if __name__ == "__main__":
    main()
