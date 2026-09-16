#!/usr/bin/env python3
"""
NUKE aggregator — fuse Slither + Aderyn + Semgrep raw output into one triage surface.

Design axioms (mirror the operator's maxims):
  * A tool hit is a SIGNAL, never a finding. It marks a locus to PIERCE, not a verdict.
  * Cross-tool CORROBORATION (same file+line flagged by >1 engine) raises priority, never certainty.
  * NEGATIVE SPACE matters more than the hit list: the vuln classes NO tool flagged are the
    author's blind spot (the sentence they did not write). We compute and surface them explicitly.

Optional DIFF mode (--diff-map): keep only signals in changed files, tag those inside the changed
hunks (± window) as IN-DIFF, and demote/suppress the rest. Post-audit-drift focus.

Stdlib only. Defensive against missing / malformed tool JSON.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

# ---------------------------------------------------------------- severity model
SEV_RANK = {"critical": 4, "high": 3, "medium": 2, "low": 1, "info": 0}
RANK_SEV = {v: k for k, v in SEV_RANK.items()}


def norm_sev(raw, source):
    r = (raw or "").strip().lower()
    if source == "semgrep":
        return {"error": "high", "warning": "medium", "info": "low"}.get(r, "low")
    if source == "slither":
        return {"high": "high", "medium": "medium", "low": "low",
                "informational": "info", "optimization": "info"}.get(r, "info")
    if source == "aderyn":
        return {"critical": "critical", "high": "high", "medium": "medium",
                "low": "low", "nc": "info", "informational": "info"}.get(r, "low")
    # --- non-EVM sources ---
    if source == "sarif":  # golangci-lint, govulncheck, osv, gitleaks, opengrep, codeql, clippy(via clippy-sarif)
        return {"error": "high", "warning": "medium", "note": "low", "none": "info",
                "critical": "critical", "high": "high", "medium": "medium", "low": "low"}.get(r, "medium")
    if source == "cargo":  # cargo-audit / cargo-deny advisory severity (vuln default high; hygiene warnings medium)
        return {"critical": "critical", "high": "high", "medium": "medium", "low": "low",
                "none": "info", "error": "high", "warning": "medium", "help": "info", "note": "low"}.get(r, "high")
    if source == "rustc":  # dylint / solana-lints diagnostic level
        return {"error": "high", "warning": "medium", "note": "low", "help": "info"}.get(r, "low")
    if source == "sec3":  # sec3 X-Ray Sealevel detectors
        return {"critical": "critical", "high": "high", "medium": "medium", "low": "low",
                "warning": "medium", "info": "info"}.get(r, "high")
    return r if r in SEV_RANK else "low"


# ------------------------------------------------- vuln-class taxonomy (for negative space)
TAXONOMY = {
    "reentrancy":            ["reentran"],
    "access-control":        ["access", "auth", "owner", "onlyrole", "unprotected", "privilege", "tx-origin", "tx.origin", "suicidal"],
    "arithmetic/precision":  ["overflow", "underflow", "divide", "precision", "rounding", "mul", "arith"],
    "oracle/price":          ["oracle", "price", "chainlink", "twap", "spot", "getreserves"],
    "unchecked-return/call": ["unchecked", "return-value", "low-level-call", "unused-return", "ignored"],
    "delegatecall/proxy":    ["delegatecall", "proxy", "upgrade", "storage-collision", "uninitialized", "implementation"],
    "external-call-order":   ["external-call", "state-change-after", "cei", "checks-effects"],
    "erc20-integration":     ["erc20", "safetransfer", "approve", "transferfrom", "fee-on-transfer", "weird"],
    "signature/replay":      ["signature", "ecrecover", "replay", "eip712", "permit", "nonce"],
    "randomness":            ["random", "blockhash", "prevrandao", "timestamp", "block.number"],
    "dos/griefing":          ["dos", "gas", "unbounded", "loop", "griefing", "revert"],
    "flashloan/economic":    ["flashloan", "flash-loan", "donation", "first-deposit", "share", "inflation"],
    "initialization":        ["initializer", "constructor", "init"],
    "front-running/mev":     ["front-run", "frontrun", "mev", "sandwich", "slippage", "deadline"],
}


def classify(text):
    t = (text or "").lower()
    return {cls for cls, needles in TAXONOMY.items() if any(n in t for n in needles)}


# ---------------------------------------------------------------- loaders
def _load(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return json.load(f)
    except Exception:
        return None


def load_slither(workdir):
    data = _load(os.path.join(workdir, "slither.json"))
    out = []
    if not data:
        return out, (data is not None)
    for d in (data.get("results") or {}).get("detectors") or []:
        files, lines = [], []
        for el in d.get("elements") or []:
            sm = el.get("source_mapping") or {}
            fn = sm.get("filename_relative") or sm.get("filename_short") or sm.get("filename_absolute")
            if fn:
                files.append(fn)
            lines.extend(sm.get("lines") or [])
        out.append({
            "tool": "slither", "rule": d.get("check", "?"), "title": d.get("check", "?"),
            "severity": norm_sev(d.get("impact"), "slither"),
            "confidence": (d.get("confidence") or "").lower(),
            "file": files[0] if files else "?", "line": min(lines) if lines else 0,
            "desc": (d.get("description") or "").strip(),
        })
    return out, True


def load_aderyn(workdir):
    data = _load(os.path.join(workdir, "aderyn.json"))
    out = []
    if not data:
        return out, (data is not None)
    for key, bucket in data.items():
        if not key.endswith("_issues") or not isinstance(bucket, dict):
            continue
        sev_word = key.replace("_issues", "")
        for iss in bucket.get("issues") or []:
            insts = iss.get("instances") or []
            f, line = "?", 0
            if insts:
                f = insts[0].get("contract_path") or insts[0].get("file") or "?"
                line = insts[0].get("line_no") or insts[0].get("line") or 0
            out.append({
                "tool": "aderyn", "rule": iss.get("detector_name") or iss.get("title", "?"),
                "title": iss.get("title", "?"), "severity": norm_sev(sev_word, "aderyn"),
                "confidence": "", "file": f, "line": line,
                "desc": (iss.get("description") or "").strip(), "instances": len(insts),
            })
    return out, True


def load_semgrep(workdir):
    data = _load(os.path.join(workdir, "semgrep.json"))
    out = []
    if not data:
        return out, (data is not None)
    for r in data.get("results") or []:
        extra = r.get("extra") or {}
        out.append({
            "tool": "semgrep", "rule": (r.get("check_id") or "?").split(".")[-1],
            "title": (r.get("check_id") or "?").split(".")[-1],
            "severity": norm_sev(extra.get("severity"), "semgrep"),
            "confidence": ((extra.get("metadata") or {}).get("confidence") or "").lower(),
            "file": r.get("path", "?"), "line": (r.get("start") or {}).get("line", 0),
            "desc": (extra.get("message") or "").strip(),
        })
    return out, True


# ---------------------------------------------------------------- non-EVM loaders
# The generic SARIF loader is the spine: golangci-lint, govulncheck, osv-scanner, gitleaks,
# OpenGrep, CodeQL and Clippy(via clippy-sarif) all emit SARIF 2.1.0. One mapping serves all.
_SARIF_DRIVER_ALIAS = {
    "golangci-lint": "golangci", "govulncheck": "govulncheck", "osv-scanner": "osv",
    "gitleaks": "gitleaks", "opengrep": "opengrep", "semgrep": "opengrep", "codeql": "codeql",
    "clippy": "clippy", "clippy-driver": "clippy", "trivy": "trivy", "grype": "grype",
}


def _sarif_tool(driver):
    d = (driver or "sarif").strip().lower()
    return _SARIF_DRIVER_ALIAS.get(d, d.split()[0] if d else "sarif")


def load_sarif(workdir):
    """Parse EVERY *.sarif in workdir into normalized signals. Returns (signals, [tool names])."""
    out, ran = [], []
    try:
        files = [f for f in os.listdir(workdir) if f.endswith(".sarif")]
    except OSError:
        return out, ran
    for fn in sorted(files):
        data = _load(os.path.join(workdir, fn))
        if not data:
            continue
        produced = False
        for run in data.get("runs") or []:
            driver = (((run.get("tool") or {}).get("driver") or {}).get("name")) or fn[:-6]
            tool = _sarif_tool(driver)
            # rule-level default severities (CodeQL/clippy carry level on the rule, not the result)
            rule_lvl = {}
            for rule in ((run.get("tool") or {}).get("driver") or {}).get("rules") or []:
                rid = rule.get("id")
                lvl = (rule.get("defaultConfiguration") or {}).get("level")
                sec = ((rule.get("properties") or {}).get("security-severity"))
                if rid:
                    rule_lvl[rid] = (lvl, sec)
            for res in run.get("results") or []:
                produced = True
                rid = res.get("ruleId") or res.get("ruleIndex") or "?"
                lvl = res.get("level") or (rule_lvl.get(res.get("ruleId"), (None, None))[0]) or "warning"
                loc = ((res.get("locations") or [{}])[0].get("physicalLocation") or {})
                f = ((loc.get("artifactLocation") or {}).get("uri")) or "?"
                line = (loc.get("region") or {}).get("startLine", 0)
                msg = (res.get("message") or {}).get("text", "") if isinstance(res.get("message"), dict) else ""
                out.append({
                    "tool": tool, "rule": str(rid).split("/")[-1], "title": str(rid).split("/")[-1],
                    "severity": norm_sev(lvl, "sarif"), "confidence": "",
                    "file": f, "line": line or 0, "desc": (msg or "").strip(),
                })
        if produced and tool not in ran:
            ran.append(tool)
    return out, ran


def load_cargo_audit(workdir):
    """cargo audit --json : advisories on vulnerable/unmaintained/yanked crates. Anchor = Cargo.lock."""
    data = _load(os.path.join(workdir, "cargo-audit.json"))
    if not data:
        return [], (data is not None)
    out = []
    for v in ((data.get("vulnerabilities") or {}).get("list") or []):
        adv = v.get("advisory") or {}
        pkg = v.get("package") or {}
        out.append({
            "tool": "cargo-audit", "rule": adv.get("id", "RUSTSEC"),
            "title": adv.get("title", "advisory"),
            "severity": norm_sev(adv.get("severity") or "high", "cargo"), "confidence": "",
            "file": "Cargo.lock", "line": 0,
            "desc": f"{pkg.get('name','?')} {pkg.get('version','')}: {adv.get('title','')}".strip(),
        })
    warns = data.get("warnings") or {}
    for kind, lst in (warns.items() if isinstance(warns, dict) else []):
        for w in (lst or []):
            adv = (w.get("advisory") or {}) if isinstance(w, dict) else {}
            pkg = (w.get("package") or {}) if isinstance(w, dict) else {}
            out.append({
                "tool": "cargo-audit", "rule": adv.get("id", kind), "title": f"{kind}",
                "severity": "medium", "confidence": "",
                "file": "Cargo.lock", "line": 0,
                "desc": f"{kind}: {pkg.get('name','?')} {pkg.get('version','')}".strip(),
            })
    return out, True


def _load_ndjson(path):
    rows = []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for ln in f:
                ln = ln.strip()
                if not ln:
                    continue
                try:
                    rows.append(json.loads(ln))
                except ValueError:
                    continue
    except OSError:
        return None
    return rows


def load_cargo_deny(workdir):
    """cargo deny check --format json : NDJSON diagnostics (advisories/bans/sources/licenses)."""
    rows = _load_ndjson(os.path.join(workdir, "cargo-deny.json"))
    if rows is None:
        return [], False
    out = []
    for r in rows:
        if r.get("type") != "diagnostic":
            continue
        fields = r.get("fields") or {}
        out.append({
            "tool": "cargo-deny", "rule": fields.get("code") or (fields.get("message", "?").split()[0]),
            "title": (fields.get("message", "?"))[:80],
            "severity": norm_sev(fields.get("severity") or "warning", "cargo"), "confidence": "",
            "file": "Cargo.toml", "line": 0, "desc": (fields.get("message") or "").strip(),
        })
    return out, True


def load_cargo_geiger(workdir):
    """cargo geiger --output-format Json : collapse to ONE aggregate unsafe-surface signal (heat-map)."""
    data = _load(os.path.join(workdir, "cargo-geiger.json"))
    if not data:
        return [], (data is not None)
    return [{
        "tool": "cargo-geiger", "rule": "unsafe-surface", "title": "unsafe-surface",
        "severity": "info", "confidence": "", "file": "Cargo.toml", "line": 0,
        "desc": "aggregate unsafe-code surface (heat-map; contracts usually forbid unsafe -> near-zero)",
    }], True


def load_dylint(workdir):
    """solana-lints (cargo dylint --message-format=json) : rustc compiler-message diagnostics."""
    rows = _load_ndjson(os.path.join(workdir, "solana-lints.json"))
    if rows is None:
        return [], False
    out = []
    for r in rows:
        if r.get("reason") != "compiler-message":
            continue
        m = r.get("message") or {}
        code = (m.get("code") or {}).get("code")
        if not code:  # keep only real lints, drop generic build noise
            continue
        spans = m.get("spans") or []
        f, line = ("?", 0)
        prim = next((s for s in spans if s.get("is_primary")), spans[0] if spans else None)
        if prim:
            f, line = prim.get("file_name", "?"), prim.get("line_start", 0)
        out.append({
            "tool": "solana-lints", "rule": code, "title": code,
            "severity": norm_sev(m.get("level") or "warning", "rustc"), "confidence": "",
            "file": f, "line": line, "desc": (m.get("message") or "").strip(),
        })
    return out, True


def load_clippy(workdir):
    """Fallback when clippy-sarif is absent: raw `cargo clippy --message-format=json` (rustc diagnostics)."""
    rows = _load_ndjson(os.path.join(workdir, "clippy.rustc.json"))
    if rows is None:
        return [], False
    out = []
    for r in rows:
        if r.get("reason") != "compiler-message":
            continue
        m = r.get("message") or {}
        code = (m.get("code") or {}).get("code")
        lvl = m.get("level") or "warning"
        if lvl not in ("error", "warning") or not code:
            continue  # skip notes/help and uncoded build chatter
        spans = m.get("spans") or []
        prim = next((s for s in spans if s.get("is_primary")), spans[0] if spans else None)
        f, line = (prim.get("file_name", "?"), prim.get("line_start", 0)) if prim else ("?", 0)
        out.append({
            "tool": "clippy", "rule": code, "title": code,
            "severity": norm_sev(lvl, "rustc"), "confidence": "",
            "file": f, "line": line, "desc": (m.get("message") or "").strip(),
        })
    return out, True


def load_sec3_xray(workdir):
    """sec3 X-Ray : ~15 Sealevel-attack detectors. JSON report (findings array), no SARIF."""
    data = _load(os.path.join(workdir, "sec3-xray.json"))
    if not data:
        return [], (data is not None)
    items = None
    if isinstance(data, list):
        items = data
    else:
        for k in ("findings", "results", "bugs", "issues", "reports"):
            if isinstance(data.get(k), list):
                items = data[k]; break
    out = []
    for it in (items or []):
        if not isinstance(it, dict):
            continue
        f = it.get("file") or it.get("filename") or it.get("path") or "?"
        line = it.get("line") or it.get("line_start") or (it.get("location") or {}).get("line") or 0
        rule = it.get("rule") or it.get("detector") or it.get("name") or it.get("type") or "sec3"
        out.append({
            "tool": "sec3-xray", "rule": str(rule), "title": str(rule),
            "severity": norm_sev(it.get("severity") or it.get("level") or "high", "sec3"), "confidence": "",
            "file": f, "line": line or 0, "desc": (it.get("message") or it.get("description") or "").strip(),
        })
    return out, True


def load_nilaway(workdir):
    """NilAway -json : go/analysis diagnostics (nested pkg -> analyzer -> [{posn,message}])."""
    data = _load(os.path.join(workdir, "nilaway.json"))
    if not data or not isinstance(data, dict):
        return [], (data is not None)
    out = []

    def walk(node):
        if isinstance(node, dict):
            if "posn" in node and "message" in node:
                posn = str(node.get("posn", "?"))
                parts = posn.rsplit(":", 2)
                f = parts[0] if parts else posn
                line = int(parts[1]) if len(parts) >= 2 and parts[1].isdigit() else 0
                out.append({
                    "tool": "nilaway", "rule": "nilpanic", "title": "nilpanic",
                    "severity": "medium", "confidence": "", "file": f, "line": line,
                    "desc": (node.get("message") or "").strip(),
                })
            else:
                for v in node.values():
                    walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(data)
    return out, True


# non-EVM raw-JSON adapters (the SARIF spine is loaded separately via load_sarif)
NONEVM_JSON_LOADERS = [
    ("cargo-audit", load_cargo_audit), ("cargo-deny", load_cargo_deny),
    ("cargo-geiger", load_cargo_geiger), ("clippy", load_clippy),
    ("solana-lints", load_dylint), ("sec3-xray", load_sec3_xray),
    ("nilaway", load_nilaway),
]


def load_negative_space(ecosystem):
    """Curated fund-theft worklist for a non-EVM ecosystem (references/negative-space.json)."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references", "negative-space.json")
    data = _load(path) or {}
    return data.get(ecosystem)


# ---------------------------------------------------------------- diff map
def basename(p):
    return os.path.basename(p) if p and p != "?" else p


def load_diff(path, window):
    d = _load(path)
    if not d:
        return None
    return {"ranges": d.get("ranges", {}), "files": d.get("files", []),
            "range": d.get("range", "?"), "window": window}


def sig_in_diff(sig, diff):
    if not diff:
        return False
    for s, e in diff["ranges"].get(basename(sig["file"]), []):
        if s - diff["window"] <= sig["line"] <= e + diff["window"]:
            return True
    return False


# ---------------------------------------------------------------- clustering
def cluster(signals, window=3):
    buckets = defaultdict(list)
    for s in signals:
        buckets[basename(s["file"])].append(s)
    clusters = []
    for fname, sigs in buckets.items():
        sigs.sort(key=lambda x: x["line"])
        cur = []
        for s in sigs:
            if cur and s["line"] - cur[-1]["line"] > window:
                clusters.append(_mk_cluster(fname, cur)); cur = []
            cur.append(s)
        if cur:
            clusters.append(_mk_cluster(fname, cur))
    return clusters


def _mk_cluster(fname, sigs):
    tools = sorted({s["tool"] for s in sigs})
    best = max(SEV_RANK[s["severity"]] for s in sigs)
    return {
        "file": fname, "line": min(s["line"] for s in sigs),
        "line_max": max(s["line"] for s in sigs),
        "severity": RANK_SEV[best], "sev_rank": best,
        "corroboration": len(tools), "tools": tools,
        "in_diff": any(s.get("_in_diff") for s in sigs),
        "rules": sorted({s["rule"] for s in sigs}),
        "titles": sorted({s["title"] for s in sigs}),
        "descriptions": [s["desc"] for s in sigs if s.get("desc")][:4],
    }


# ---------------------------------------------------------------- reporting
def write_reports(workdir, clusters, all_signals, ran, target, diff=None, dropped=0,
                  neg_space=None, ecosystem="evm"):
    if diff:
        clusters.sort(key=lambda c: (c["in_diff"], c["sev_rank"], c["corroboration"], len(c["tools"])), reverse=True)
    else:
        clusters.sort(key=lambda c: (c["sev_rank"], c["corroboration"], len(c["tools"])), reverse=True)

    # negative space
    silent_detail = None
    if neg_space:
        # non-EVM with a curated map: NO scanner sees the fund-theft classes — the worklist IS the deliverable.
        silent_detail = sorted(neg_space.get("silent_classes", []),
                               key=lambda c: SEV_RANK.get(c.get("severity", "low"), 1), reverse=True)
        silent = [c.get("class", "?") for c in silent_detail]
    elif ecosystem != "evm":
        # non-EVM without a curated map (e.g. bare Rust): don't misapply the EVM taxonomy.
        silent_detail = []
        silent = []
    else:
        # EVM: subtract classes a tool spoke from the taxonomy (in diff mode, over IN-DIFF signals only).
        ns_sigs = [s for s in all_signals if s.get("_in_diff")] if diff else all_signals
        spoken = set()
        for s in ns_sigs:
            spoken |= classify(s["rule"] + " " + s["title"] + " " + s.get("desc", ""))
        silent = [c for c in TAXONOMY if c not in spoken]

    counts = defaultdict(int)
    for c in clusters:
        counts[c["severity"]] += 1
    corroborated = [c for c in clusters if c["corroboration"] >= 2]

    # ---- signals.json
    payload = {
        "target": target, "ecosystem": ecosystem, "tools_ran": ran,
        "mode": "diff" if diff else "full",
        "totals": {"raw_signals": len(all_signals), "clusters": len(clusters),
                   "by_severity": dict(counts), "corroborated_clusters": len(corroborated)},
        "silent_classes": silent, "silent_detail": silent_detail, "clusters": clusters,
    }
    if diff:
        payload["diff"] = {"range": diff["range"], "window": diff["window"],
                           "changed_files": diff["files"],
                           "in_diff_clusters": sum(1 for c in clusters if c["in_diff"]),
                           "suppressed_outside_changed_files": dropped}
    with open(os.path.join(workdir, "signals.json"), "w") as f:
        json.dump(payload, f, indent=2)

    # ---- signals.md
    md = []
    if diff:
        md.append(f"# NUKE — surface DIFF · `{diff['range']}`\n")
        md.append(f"> ⚠️ **Un signal n'est PAS un finding.** Mode diff : seuls les fichiers changés sont "
                  f"analysés, et seuls les signaux DANS le patch (± {diff['window']} lignes de contexte) "
                  f"sont priorisés. Le pré-existant est démoté/supprimé — c'est le cadrage *post-audit drift*. "
                  f"Promotion = artefact Foundry exécuté (`TRIAGE.md`).\n")
        md.append(f"**Range :** `{diff['range']}`  ·  **fichiers .sol changés :** {len(diff['files'])}  ·  "
                  f"**outils :** {', '.join(ran) or '(aucun)'}  ")
        md.append(f"**Signaux hors fichiers changés (supprimés) :** {dropped}\n")
    else:
        md.append(f"# NUKE — surface de signaux · `{target}`\n")
        md.append("> ⚠️ **Un signal n'est PAS un finding.** Chaque ligne est une *hypothèse non exécutée* : "
                  "le lieu où un scanner a vu de la fumée. Un gate/detector signale qu'un contrôle EXISTE là, "
                  "jamais qu'il TIENT. Promotion = artefact Foundry exécuté (`TRIAGE.md`).\n")
        md.append(f"**Outils exécutés :** {', '.join(ran) if ran else '(aucun)'}  ")
    md.append(f"**Signaux (fichiers en scope) :** {len(all_signals)} → **clusters :** {len(clusters)} "
              f"(high/med/low/info = {counts['high']+counts['critical']}/{counts['medium']}/{counts['low']}/{counts['info']})  ")
    md.append(f"**Corroborés (≥2 outils) :** {len(corroborated)}\n")

    if diff:
        in_diff = [c for c in clusters if c["in_diff"]]
        pre_exist = [c for c in clusters if not c["in_diff"]]
        md.append("## 🎯 DANS LE PATCH — introduit ou touché par le diff (percer EN PREMIER)\n")
        if not in_diff:
            md.append("_Aucun signal d'outil dans les lignes changées. Ne conclus rien : le patch peut "
                      "introduire un bug de logique qu'aucune règle ne voit — vois l'espace négatif._\n")
        for i, c in enumerate(in_diff, 1):
            md.append(f"### {i}. `{c['file']}:{c['line']}` — **{c['severity'].upper()}** "
                      f"{'★'*c['corroboration']} `{'+'.join(c['tools'])}`")
            md.append(f"- **rules:** {', '.join('`'+r+'`' for r in c['rules'])}")
            if c["descriptions"]:
                md.append(f"- {c['descriptions'][0][:280]}")
            md.append("")
        md.append("## 🕓 Pré-existant dans les fichiers touchés (contexte — l'audit initial l'a peut-être déjà vu)\n")
        for c in pre_exist:
            md.append(f"- `{c['file']}:{c['line']}` — {c['severity']} `{'+'.join(c['tools'])}` — {', '.join(c['rules'][:3])}")
        if not pre_exist:
            md.append("_(aucun)_")
        md.append("")
        top = in_diff
    else:
        md.append("## 🔴 Priorité — corroborés ou haute sévérité (percer EN PREMIER)\n")
        top = [c for c in clusters if c["corroboration"] >= 2 or c["sev_rank"] >= 3]
        if not top:
            md.append("_Aucun cluster corroboré ni high. Ne conclus rien : les scanners sont muets sur la "
                      "logique métier — vois l'espace négatif._\n")
        for i, c in enumerate(top, 1):
            md.append(f"### {i}. `{c['file']}:{c['line']}` — **{c['severity'].upper()}** "
                      f"{'★'*c['corroboration']} `{'+'.join(c['tools'])}`")
            md.append(f"- **rules:** {', '.join('`'+r+'`' for r in c['rules'])}")
            if c["descriptions"]:
                md.append(f"- {c['descriptions'][0][:280]}")
            md.append("")
        md.append("## ⚪ Reste des signaux (contexte)\n")
        for c in [x for x in clusters if x not in top]:
            md.append(f"- `{c['file']}:{c['line']}` — {c['severity']} `{'+'.join(c['tools'])}` — {', '.join(c['rules'][:3])}")
        md.append("")

    if silent_detail is not None:
        # non-EVM: the fund-theft worklist IS the deliverable — no scanner covers these classes.
        cov = (neg_space or {}).get("mechanical_covered", [])
        md.append("## 🕳️ Espace négatif — les classes de VOL qu'AUCUN scanner ne voit  (LE livrable)\n")
        md.append(f"> Sur **{(neg_space or {}).get('label', ecosystem)}**, le barrage ne couvre que le *substrat "
                  f"mécanique* : {', '.join(cov) if cov else 'deps/panics/overflow/secrets'}. **Aucun outil ne "
                  f"voit l'authz, la reentrancy, la sig-scope d'un bridge, la logique métier.** Un barrage vert "
                  f"ne dit RIEN ici. Chaque entrée = une CLASSE DE VOL à chasser à la main. `gate → moving on` "
                  f"interdit. Promotion = artefact exécuté (`TRIAGE.md`).\n")
        if not silent_detail:
            md.append("_(pas de carte d'espace négatif curée pour cet écosystème — les scanners couvrent le "
                      "substrat mécanique ; route la logique métier vers `/darkside` à la main.)_")
        cur_sev = None
        for c in silent_detail:
            sev = (c.get("severity") or "low").upper()
            if sev != cur_sev:
                md.append(f"\n### {sev}\n"); cur_sev = sev
            vein = c.get("vein", "")
            md.append(f"- [ ] **{c.get('class','?')}**" + (f"  → propose `{vein}`" if vein else ""))
            if c.get("money"):
                md.append(f"    - 💰 *vol :* {c['money']}")
            if c.get("tell"):
                md.append(f"    - 🔎 *où :* {c['tell']}")
        md.append("")
    else:
        md.append("## 🕳️ Espace négatif — classes qu'AUCUN outil n'a touchées"
                  + (" DANS LE PATCH" if diff else "") + "\n")
        md.append("> C'est ici que vit le bug que l'auteur n'a pas écrit. "
                  + ("Le patch touche du code mais reste *muet* sur ces classes — a-t-il introduit l'une d'elles ?"
                     if diff else
                     "Les scanners sont *silencieux* sur ces classes — soit absentes, soit trop sémantiques pour eux.")
                  + " **Chasse-les à la main.**\n")
        md += ([f"- [ ] **{c}**" for c in silent] or
               ["_Toutes les classes ont au moins un signal (rare — vérifie la couverture)._"])
        md.append("")
    with open(os.path.join(workdir, "signals.md"), "w") as f:
        f.write("\n".join(md))

    # ---- TRIAGE.md skeleton
    tri = ["# NUKE — TRIAGE (promotion = artefact exécuté, jamais hand-reading)\n",
           "Pour CHAQUE signal prioritaire : angles de percée puis preuve. `gate → moving on` interdit — "
           "un gate qui rejette ton chemin = creuse PLUS fort (authn≠authz · sibling non gardé · "
           "gate satisfaisable · fuite différentielle · math du gate).\n"]
    for i, c in enumerate(top, 1):
        tri.append(f"## {i}. `{c['file']}:{c['line']}` [{c['severity'].upper()}] {'+'.join(c['tools'])}"
                   + ("  ‹DANS LE PATCH›" if diff and c.get("in_diff") else ""))
        tri.append(f"- **Classe / rule:** {', '.join(c['rules'])}")
        tri.append("- **Hypothèse (ce que le scanner suppose):** ")
        tri.append("- **Input / state que l'auteur n'a PAS imaginé:** ")
        tri.append("- **Angle de percée tenté:** ")
        tri.append("- **Artefact EXÉCUTÉ (forge test / cast call / trace):** ```\n\n```")
        tri.append("- **Delta observé (avant→après, chiffré):** ")
        tri.append("- **Verdict:** ☐ finding réel  ☐ mort (gate tient, prouvé)  ☐ à re-sourcer\n")
    with open(os.path.join(workdir, "TRIAGE.md"), "w") as f:
        f.write("\n".join(tri))

    # ---- stdout summary
    mode = f"diff {diff['range']}" if diff else "full"
    extra = f", {sum(1 for c in clusters if c['in_diff'])} in-diff, {dropped} suppressed" if diff else ""
    print(f"[aggregate:{mode}] {len(all_signals)} signals -> {len(clusters)} clusters "
          f"(high={counts['high']+counts['critical']} med={counts['medium']} low={counts['low']} info={counts['info']}), "
          f"{len(corroborated)} corroborated{extra}, {len(silent)} silent classes.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workdir", required=True)
    ap.add_argument("--target", default="?")
    ap.add_argument("--ecosystem", default="evm",
                    help="evm | cosmwasm | cosmos-go | solana (selects loaders + negative-space map)")
    ap.add_argument("--diff-map", default=None)
    ap.add_argument("--diff-window", type=int, default=0)
    args = ap.parse_args()

    eco = args.ecosystem
    neg_space = None
    all_sigs, ran = [], []
    if eco == "evm":
        for name, loader in (("slither", load_slither), ("aderyn", load_aderyn), ("semgrep", load_semgrep)):
            sigs, present = loader(args.workdir)
            if present:
                ran.append(name)
            all_sigs.extend(sigs)
    else:
        # non-EVM: SARIF spine (many tools) + raw-JSON adapters, plus the curated negative-space worklist.
        sarif_sigs, sarif_ran = load_sarif(args.workdir)
        all_sigs.extend(sarif_sigs)
        ran.extend(sarif_ran)
        for name, loader in NONEVM_JSON_LOADERS:
            sigs, present = loader(args.workdir)
            if present and name not in ran:
                ran.append(name)
            all_sigs.extend(sigs)
        neg_space = load_negative_space(eco)

    diff = load_diff(args.diff_map, args.diff_window) if args.diff_map else None
    dropped = 0
    if diff:
        changed = set(diff["ranges"].keys()) | {basename(f) for f in diff["files"]}
        kept = []
        for s in all_sigs:
            if basename(s["file"]) in changed:
                s["_in_diff"] = sig_in_diff(s, diff)
                kept.append(s)
        dropped = len(all_sigs) - len(kept)
        all_sigs = kept
        # partition BEFORE clustering so a cluster never straddles the patch boundary
        # (line-proximity clustering would otherwise merge a patch bug with an adjacent pre-existing one)
        in_d = [s for s in all_sigs if s.get("_in_diff")]
        pre = [s for s in all_sigs if not s.get("_in_diff")]
        clusters = cluster(in_d) + cluster(pre)
    else:
        clusters = cluster(all_sigs)

    write_reports(args.workdir, clusters, all_sigs, ran, args.target, diff=diff, dropped=dropped,
                  neg_space=neg_space, ecosystem=eco)


if __name__ == "__main__":
    main()
