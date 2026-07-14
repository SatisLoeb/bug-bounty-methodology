#!/usr/bin/env python3
"""
NUKE saturation filter (v2, two-column) — the FINE de-prioritization read, hardened against the three
ways a corpus intersection lies to its operator:

  (1) VEIN-DISTANCE. A corpus hit does NOT declare "same money-path" — it declares a finding on a path
      that resembles yours at an abstraction level you didn't fix. Too-tight matching → you declare a vein
      VIERGE that has a finding phrased under another class → you dig a DUP (the costly reject-after-work).
      FIX: broaden the collision net (class OR keyword/ident overlap) and default toward COVERAGE-FP —
      output COLLISION CANDIDATES to REFUTE BY HAND, never a "taken/not-taken" verdict. A candidate is
      LABOURÉE only after you read it and confirm the SAME broken invariant.
  (2) TWO CAUSES OF EMPTINESS. Zero hits = "nobody looked" (the signal) OR "looked, judged non-exploitable,
      nothing published". The findings corpus holds only POSITIVES → mined-empty veins leave no trace. FIX:
      a SECOND column — the target's own audit-report SCOPE/COVERAGE (`--coverage <file>`, the PDF's
      "we reviewed X,Y,Z", NOT Solodit). A vein IN declared scope with no finding = MINÉ-VIDE? (a possible
      graveyard, not virgin). VIERGE-RÉEL = the intersection of both voids: no finding AND outside all
      declared scope.
  (3) EMERGENT VEINS. The negative space encodes YOUR system model, not the protocol's. It enumerates the
      fork-source's canonical money-paths → excellent at "which KNOWN vein is free", structurally BLIND to
      the integration-seam vein absent from the canonical fork. FIX: the output SAYS SO — it de-prioritizes
      the KNOWN, it is not a map of the territory; the 13th vein lives in /darkside Door-C / the upshift seam.

Importable: `compute_saturation(sig, forks, shape, corpus, coverage_text="")` -> (rows, corpus_ok).
"""
import argparse
import json
import os
import re
import sys

NUKE_TO_CORPUS = {
    "reentrancy": ["reentrancy"], "access-control": ["access-control"],
    "arithmetic/precision": ["arithmetic", "rounding"], "oracle/price": ["oracle"],
    "unchecked-return/call": ["accounting", "DoS"], "delegatecall/proxy": ["access-control"],
    "external-call-order": ["reentrancy"], "erc20-integration": ["accounting"],
    "signature/replay": ["signature-replay"], "randomness": ["DoS"], "dos/griefing": ["DoS"],
    "flashloan/economic": ["accounting", "MEV-sandwich"], "initialization": ["access-control"],
    "front-running/mev": ["MEV-sandwich"],
}
KW_TO_CORPUS = [
    ("reentran", "reentrancy"), ("authz", "access-control"), ("access", "access-control"),
    ("auth", "access-control"), ("owner", "access-control"), ("admin", "access-control"),
    ("oracle", "oracle"), ("price", "oracle"), ("staleness", "oracle"), ("round", "rounding"),
    ("precision", "rounding"), ("arith", "arithmetic"), ("overflow", "arithmetic"), ("liquidat", "liquidation"),
    ("account", "accounting"), ("fee", "accounting"), ("share", "accounting"), ("mint", "accounting"),
    ("balance", "accounting"), ("sig", "signature-replay"), ("replay", "signature-replay"),
    ("bridge", "cross-chain"), ("ibc", "cross-chain"), ("cross-chain", "cross-chain"), ("message", "cross-chain"),
    ("govern", "governance"), ("vote", "governance"), ("dos", "DoS"), ("griefing", "DoS"), ("gas", "DoS"),
    ("mev", "MEV-sandwich"), ("sandwich", "MEV-sandwich"), ("front", "MEV-sandwich"), ("slippage", "MEV-sandwich"),
]
# per-class keyword expansion for the BROAD collision net (catches findings phrased under another class).
EXPAND = {
    "oracle": ["oracle", "price", "slot0", "latestanswer", "latestrounddata", "twap", "spot", "staleness", "chainlink", "pyth"],
    "reentrancy": ["reentran", "callback", "before", "after", "cei", "checks-effects"],
    "access-control": ["access", "authz", "onlyowner", "role", "permission", "unauthor", "arbitrary", "spoof", "impersonat"],
    "accounting": ["account", "share", "balance", "mint", "burn", "fee", "reward", "debt", "collateral", "inflation", "donation"],
    "signature-replay": ["signature", "replay", "nonce", "ecrecover", "permit", "eip712", "domain"],
    "MEV-sandwich": ["mev", "sandwich", "front-run", "frontrun", "slippage", "deadline", "manipulat"],
    "cross-chain": ["bridge", "cross-chain", "message", "relayer", "emitter", "l1", "l2", "ibc", "light-client", "proof"],
    "rounding": ["round", "precision", "dust", "truncat"], "arithmetic": ["overflow", "underflow", "arith", "cast"],
    "liquidation": ["liquidat", "health", "seiz", "bad-debt"], "DoS": ["dos", "griefing", "unbounded", "gas", "revert"],
    "governance": ["govern", "vote", "proposal", "timelock", "quorum"],
}
_TOKEN = re.compile(r"[a-z0-9]+")


def _load(p):
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception:
        return None


def map_class(label):
    if label in NUKE_TO_CORPUS:
        return NUKE_TO_CORPUS[label]
    t = (label or "").lower()
    hits = [c for kw, c in KW_TO_CORPUS if kw in t]
    return list(dict.fromkeys(hits)) or ["other"]


def kw_net(label, ccls):
    kws = set(w for w in _TOKEN.findall((label or "").lower()) if len(w) >= 4)
    for c in ccls:
        kws.update(EXPAND.get(c, [c]))
    return kws


def veins_of(sig):
    sd = sig.get("silent_detail") or []
    if sd:
        return [(c.get("class", "?"), c.get("vein", "")) for c in sd]
    return [(c, "") for c in (sig.get("silent_classes") or [])]


def compute_saturation(sig, forks, shape, corpus_dir, coverage_text=""):
    forks = [f.strip().lower() for f in (forks or []) if f and f.strip()]
    cmap = _load(os.path.join(corpus_dir, "class-map.json")) or {}
    pti = _load(os.path.join(corpus_dir, "protocol-type-index.json")) or {}
    findings_path = os.path.join(corpus_dir, "findings.jsonl")
    corpus_ok = os.path.isfile(findings_path)
    cover_tokens = set(w for w in _TOKEN.findall((coverage_text or "").lower()) if len(w) >= 4)

    # COLUMN 1 — collect the (small) set of corpus findings on THIS target/fork; keep full text for the net.
    fork_findings = []
    if corpus_ok and forks:
        with open(findings_path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                hay = (str(d.get("protocol", "")) + " " + str(d.get("title", "")) + " " +
                       " ".join(d.get("tags", []) or []) + " " + str(d.get("slug", ""))).lower()
                if not any(fk in hay for fk in forks):
                    continue
                text = (str(d.get("title", "")) + " " + str(d.get("root_cause", "")) + " " +
                        " ".join(d.get("code_idents", []) or []) + " " + " ".join(d.get("tags", []) or [])).lower()
                fork_findings.append({"classes": set(d.get("classes") or []), "text": text,
                                      "protocol": d.get("protocol", "?"), "title": (d.get("title", "") or "")[:80],
                                      "link": d.get("link", "")})

    shape_top = set()
    if shape:
        sh = pti.get(shape) or pti.get(shape.lower()) or {}
        tc = (sh.get("top_classes") or []) if isinstance(sh, dict) else []
        shape_top = set(e.get("class") if isinstance(e, dict) else e for e in tc)

    rows = []
    for label, vein in veins_of(sig):
        ccls = map_class(label)
        kws = kw_net(label, ccls)
        # BROAD collision: class-overlap OR keyword/ident overlap (catches other-phrasing dups)
        collisions = [f for f in fork_findings
                      if (f["classes"] & set(ccls)) or any(k in f["text"] for k in kws)]
        global_total = sum((cmap.get(c, {}) or {}).get("total", 0) for c in ccls)
        payable = bool(shape_top & set(ccls)) if shape_top else (global_total > 0)
        tell = next(((cmap.get(c, {}) or {}).get("detection_tell") for c in ccls if (cmap.get(c, {}) or {}).get("detection_tell")), "")
        # COLUMN 2 — declared audit coverage (the "looked, nothing published" signal)
        in_scope = bool(cover_tokens) and (any(k in cover_tokens for k in kws) or any(c.lower() in cover_tokens for c in ccls))

        if not forks and not cover_tokens:
            verdict = "?"
        elif collisions:
            verdict = "SUSPECT"        # ≥1 collision candidate → REFUTE by reading before deprioritizing
        elif in_scope:
            verdict = "MINÉ-VIDE?"     # in declared scope, no finding → possible graveyard, not virgin
        else:
            verdict = "VIERGE" if payable else "VIERGE(low-pay)"
        rows.append({"label": label, "vein": vein, "corpus_classes": ccls, "n_collision": len(collisions),
                     "global_total": global_total, "payable": payable, "in_scope": in_scope,
                     "verdict": verdict, "tell": tell,
                     "candidates": [(f["protocol"], f["title"], f["link"]) for f in collisions[:3]]})
    order = {"VIERGE": 0, "VIERGE(low-pay)": 1, "MINÉ-VIDE?": 2, "?": 3, "SUSPECT": 4}
    rows.sort(key=lambda r: (order.get(r["verdict"], 3), r["n_collision"], -r["global_total"]))
    return rows, corpus_ok


CAVEAT = ("> ⚠ **Ce filtre dé-priorise le CONNU, il n'est pas une carte du territoire.** Il énumère les "
          "money-paths canoniques du fork-source → aveugle à la 13ᵉ veine (artefact d'intégration propre à "
          "cette cible, absente du fork). La couture inter-composants (off-chain↔on-chain, lang-A↔lang-B) "
          "n'apparaît PAS ici → `/darkside` Door-C + le seam `/upshift`. « VIERGE » = libre parmi le connu, "
          "jamais « inexploré ».")


def render_md(rows, forks, shape, corpus_ok, has_coverage):
    fk = ",".join(forks) if forks else "(non précisé)"
    md = [f"# NUKE saturation (2 colonnes) — quelle VEINE est vierge ?  · fork: `{fk}`" +
          (f" · shape: `{shape}`" if shape else ""),
          "> Le corpus ne dit pas « pris / pas pris » — il donne des **candidats de collision à réfuter à la "
          "main**. **SUSPECT** = un finding ressemble → LIS-le, ne déprioris QUE si l'invariant cassé DIFFÈRE. "
          "**MINÉ-VIDE?** = dans le scope d'audit déclaré mais aucun finding → cimetière probable, pas vierge. "
          "**VIERGE** = ni collision ni scope déclaré = les deux vides = la vraie brèche non-surveillée.\n",
          CAVEAT + "\n"]
    if not corpus_ok:
        md.append("> ⚠ corpus introuvable — colonne 1 (findings) indisponible.\n")
    if not has_coverage:
        md.append("> ⚠ colonne 2 absente : passe `--coverage <fichier>` (la section scope/coverage du RAPPORT "
                  "d'audit de la cible, pas Solodit) pour distinguer VIERGE-réel de MINÉ-VIDE. Sans elle, un "
                  "« VIERGE » peut être un cimetière non écrit.\n")
    cur = None
    for r in rows:
        if r["verdict"] != cur:
            md.append(f"\n## {r['verdict']}\n"); cur = r["verdict"]
        line = f"- [ ] **{r['label']}**" + (f"  → `{r['vein']}`" if r["vein"] else "")
        line += f"  · {r['n_collision']} collision(s) fork · {r['global_total']} global" + (" · in-scope" if r["in_scope"] else "")
        md.append(line)
        if r["verdict"].startswith("VIERGE") and r["tell"]:
            md.append(f"    - 🔎 *tell (le HOW) :* {r['tell']}")
        if r["verdict"] == "SUSPECT":
            for p, t, link in r["candidates"]:
                md.append(f"    - 🚧 réfute: [{p}] {t}" + (f"  {link}" if link else ""))
    md.append("")
    return "\n".join(md)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--signals", required=True)
    ap.add_argument("--fork", default="")
    ap.add_argument("--shape", default="")
    ap.add_argument("--coverage", default="", help="path to the TARGET's audit-report scope/coverage text (column 2)")
    ap.add_argument("--corpus", default=os.path.expanduser("~/Desktop/BUGS/solodit-corpus"))
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    try:
        sig = json.load(open(args.signals, encoding="utf-8"))
    except Exception as e:
        print(f"[saturation] signals.json illisible: {e}", file=sys.stderr); sys.exit(2)
    if not veins_of(sig):
        print("[saturation] aucune veine dans signals.json.", file=sys.stderr); sys.exit(0)
    cov_text = ""
    if args.coverage and os.path.isfile(args.coverage):
        cov_text = open(args.coverage, encoding="utf-8", errors="replace").read()
    forks = [f.strip() for f in args.fork.split(",") if f.strip()]
    rows, corpus_ok = compute_saturation(sig, forks, args.shape, args.corpus, cov_text)
    out = args.out or os.path.join(os.path.dirname(args.signals), "saturation.md")
    open(out, "w", encoding="utf-8").write(render_md(rows, forks, args.shape, corpus_ok, bool(cov_text)))
    c = {}
    for r in rows:
        c[r["verdict"]] = c.get(r["verdict"], 0) + 1
    print(f"[saturation] {len(rows)} veines · " + " · ".join(f"{k}:{v}" for k, v in sorted(c.items())) + f" → {out}")


if __name__ == "__main__":
    main()
