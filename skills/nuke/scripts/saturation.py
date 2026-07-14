#!/usr/bin/env python3
"""
NUKE saturation filter (v3, vein-granular) — the FINE de-prioritization read.

v2 made COLLISION a retriever (candidates to refute by hand, not a verdict) — correct. But the three
matchers AROUND it still consumed the CLASS WORD, never the VEIN itself, so the "fine" filter went
class-coarse exactly where it had to be fine. v3 closes that single root, four ways:

  (1) COLLISION was class-granular: kw_net used label-tokens + EXPAND[class], never the vein's mechanism.
      Two veins of one class (stale-oracle vs spot-manip) shared the same net → one oracle finding put
      ALL oracle veins in SUSPECT; and EXPAND on dense classes (accounting→balance,fee,mint,share…) hit a
      huge slice of the corpus → discriminating power INVERTED (blind where the corpus is dense, i.e. where
      the repo looks class-guarded and hides virgin veins). FIX: feed the vein's own mechanism tokens
      (from `money`+`tell`, the grep-level idents like get_price_no_older_than / total_shares /
      SubMsg::reply) into the net, and SCALE the collision threshold with corpus density — a DENSE class
      demands a match on a SPECIFIC vein token, a RARE class keeps the broad OR. Where the negative-space
      is class-only (EVM silent_classes carry no money/tell), a dense-class collision is kept but flagged
      `resolution: class-only` — labeled-unresolved, never silently promoted to precise SUSPECT nor
      silently dropped to false-VIERGE.
  (2) COVERAGE (column 2) had the same defect AND it EXCLUDES (worse): class-word-in-prose → "we reviewed
      the vault accounting" nuked every accounting vein to MINÉ-VIDE?, dropping real virgins out of the
      dig-list. FIX: coverage matches CODE-LOCATION, not the class word — extract only code-shaped tokens
      (file paths, Contract names, fn idents) from the audit scope and match the vein's OWN code idents
      against them. Prose-only scope → module matching is inert (and said so), never an exclusion.
  (3) SILENT FALSE-VIERGE: fork_findings fills by substring; a mis-named/niche fork matches ZERO findings →
      every vein VIERGE, visually identical to a real virgin target. FIX: count fork matches, warn LOUD
      when a fork matched 0 ("probably a fork name absent from the corpus, NOT a virgin target").
  (4) RESIDUAL CLASSIFIERS demoted inside VIERGE: `payable` (VIERGE(low-pay)) and map_class→["other"]
      (novel label) both re-buried the emergent-seam vein the CAVEAT says is absent. FIX: keep them at
      VIERGE rank and ANNOTATE ("hors pay-class du shape" / "label novel → couture émergente"); the novel
      seam sorts FIRST inside VIERGE, never below.

Importable: `compute_saturation(sig, forks, shape, corpus, coverage_text="")` -> (rows, info).
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
# per-class BROAD net (the class-coarse arm — only decisive for RARE classes; on dense classes it is the
# noise the vein-net must override).
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
_WORD = re.compile(r"[a-z0-9_]+")
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]{2,}(?:\(\))?")
_PATH = re.compile(r"[A-Za-z0-9_./-]+\.(?:sol|rs|go|move|cairo|vy|ts)\b")
# generic DeFi/class prose — present in a huge fraction of findings, so USELESS as a vein discriminator.
GENERIC = set("""oracle price prices fee fees share shares balance balances mint mints burn amount amounts
account accounts accounting reward rewards debt collateral asset assets token tokens vault vaults value
values check checks state states user users owner owners admin config configs update updates set sets get
gets with without before after when then that this from into over under call calls send sends transfer
transfers withdraw withdraws deposit deposits redeem redeems borrow borrows repay repays swap swaps pool
pools fund funds pay pays paid could should would will must does missing wrong incorrect return returns
function functions contract contracts module modules address addresses caller sender receiver protocol""".split())


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


def code_tokens(text):
    """STRICT code-location tokens ONLY: file paths, snake_case, CamelCase idents, `::` paths. NO prose
    words. Used for the coverage column (column 2) and for the vein's location side, so a MINÉ-VIDE? verdict
    means the scope NAMED the vein's code location — never that a class word appeared in an English sentence."""
    t = text or ""
    out = set()
    for m in _PATH.findall(t):
        low = m.lower()
        out.add(low)
        out.add(low.rsplit("/", 1)[-1])
    for m in _IDENT.findall(t):
        if ("_" in m) or ("::" in m) or (re.search(r"[a-z][A-Z]", m) is not None):
            out.add(m.rstrip("()").lower())
    return out


def mech_tokens(text):
    """Vein-DISCRIMINATING tokens for the collision net (column 1): strict code idents PLUS distinctive
    long words (staleness, discriminator, reentrancy…). Looser than code_tokens because collision recall
    matters more there; generic class prose is still dropped — it cannot discriminate veins."""
    t = text or ""
    out = set(code_tokens(t))
    for m in _IDENT.findall(t):
        w = m.rstrip("()").lower()
        if len(w) >= 6 and w not in GENERIC:
            out.add(w)
    return out


def veins_of(sig):
    """Each vein carries its class label AND, when the negative space is curated (non-EVM), the mechanism
    fields money/tell that make it VEIN-granular. EVM silent_classes are plain class strings (money/tell
    empty) → the filter labels their dense-class collisions `class-only`, never fakes precision."""
    sd = sig.get("silent_detail") or []
    if sd:
        return [{"label": c.get("class", "?"), "vein": c.get("vein", ""),
                 "money": c.get("money", ""), "tell": c.get("tell", "")} for c in sd]
    return [{"label": c, "vein": "", "money": "", "tell": ""} for c in (sig.get("silent_classes") or [])]


def compute_saturation(sig, forks, shape, corpus_dir, coverage_text=""):
    forks = [f.strip().lower() for f in (forks or []) if f and f.strip()]
    cmap = _load(os.path.join(corpus_dir, "class-map.json")) or {}
    pti = _load(os.path.join(corpus_dir, "protocol-type-index.json")) or {}
    findings_path = os.path.join(corpus_dir, "findings.jsonl")
    corpus_ok = os.path.isfile(findings_path)

    # density cut: a class at/above the MEDIAN class-total is "dense" — there, a bare class-word collision
    # is near-meaningless, so we demand a specific vein token. Self-calibrates as the corpus grows.
    totals = sorted((v or {}).get("total", 0) for v in cmap.values() if isinstance(v, dict))
    dense_cut = totals[len(totals) // 2] if totals else 300

    # coverage column 2 = STRICT CODE-LOCATION tokens only (file paths / Contract / fn idents), NOT prose.
    cover_code = code_tokens(coverage_text)
    cover_prose_only = bool((coverage_text or "").strip()) and not cover_code

    # COLUMN 1 — the (small) set of corpus findings on THIS target/fork; keep full text for the net.
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
    n_fork = len(fork_findings)

    shape_top = set()
    if shape:
        sh = pti.get(shape) or pti.get(shape.lower()) or {}
        tc = (sh.get("top_classes") or []) if isinstance(sh, dict) else []
        shape_top = set(e.get("class") if isinstance(e, dict) else e for e in tc)

    rows = []
    for v in veins_of(sig):
        label = v["label"]
        ccls = map_class(label)
        global_total = sum((cmap.get(c, {}) or {}).get("total", 0) for c in ccls)
        dense = global_total >= dense_cut

        # two nets: class-coarse (broad synonyms) and vein-specific (REAL mechanism idents from money+tell).
        # The label is NOT a mechanism source — its only distinctive token is the class word itself, too
        # literal to appear in a finding merely TAGGED that class (that was the v3.0 false-VIERGE bug). So
        # `mech` comes strictly from the curated money/tell; a coarse vein (EVM silent_classes) has none and
        # is resolved at CLASS level, flagged, never force-tightened into a false-VIERGE.
        class_net = set()
        for c in ccls:
            # "other" is the map_class fallback for a novel label — it has no meaningful synonyms and the
            # literal token "other" spuriously matches "another"/"other" in prose. Never seed the net with it
            # (that would give the emergent-seam vein a phantom collision and re-bury it — defeats fix #4).
            if c and c != "other":
                class_net.update(EXPAND.get(c, [c]))
        mech = mech_tokens((v.get("money", "") + " " + v.get("tell", "")))
        has_mech = bool(mech)

        collisions = []
        for f in fork_findings:
            class_hit = bool(f["classes"] & set(ccls)) or any(k in f["text"] for k in class_net)
            vein_hit = any(k in f["text"] for k in mech) if has_mech else False
            if dense:
                # dense class: a bare class-word collision is near-meaningless. If we HAVE mechanism tokens,
                # demand a SPECIFIC match (restores vein resolution). If we DON'T (coarse vein), keep the
                # class-level collision but flag it `class-only` — labeled-unresolved, never false-VIERGE.
                hit = vein_hit or (class_hit and not has_mech)
            else:
                hit = class_hit or vein_hit
            if hit:
                collisions.append(f)
        resolution = "class-only" if (dense and not has_mech) else "specific"

        payable = bool(shape_top & set(ccls)) if shape_top else (global_total > 0)
        tell = v.get("tell") or next(((cmap.get(c, {}) or {}).get("detection_tell")
                                      for c in ccls if (cmap.get(c, {}) or {}).get("detection_tell")), "")

        # COLUMN 2 — CODE-LOCATION overlap (not class prose): does one of the vein's own STRICT code idents
        # appear in the audit scope's code-shaped tokens? EVM veins with no idents → never wrongly excluded.
        vein_loc = code_tokens((v.get("money", "") + " " + v.get("tell", "")))
        in_scope = bool(cover_code) and bool(vein_loc & cover_code)

        if not forks and not cover_code:
            verdict = "?"
        elif collisions:
            verdict = "SUSPECT"        # collision candidates → REFUTE by reading before deprioritizing
        elif in_scope:
            verdict = "MINÉ-VIDE?"     # vein's code location IS in declared scope, no finding → graveyard?
        else:
            verdict = "VIERGE"         # both voids: no collision AND code-location not in declared scope

        notes = []
        if verdict == "VIERGE":
            if ccls == ["other"]:
                notes.append("label novel → couture émergente ? (la 13ᵉ veine — /darkside Door-C)")
            elif not payable:
                notes.append("hors pay-class typique du shape")
        if verdict == "SUSPECT" and resolution == "class-only":
            notes.append("collision CLASSE-seule (negative-space grossier, pas de token-veine) — désambiguïse à la main")

        rows.append({"label": label, "vein": v.get("vein", ""), "corpus_classes": ccls,
                     "n_collision": len(collisions), "global_total": global_total, "dense": dense,
                     "payable": payable, "in_scope": in_scope, "resolution": resolution,
                     "verdict": verdict, "tell": tell, "notes": notes,
                     "candidates": [(f["protocol"], f["title"], f["link"]) for f in collisions[:3]]})

    def _sort_key(r):
        vorder = {"VIERGE": 0, "MINÉ-VIDE?": 1, "?": 2, "SUSPECT": 3}
        sub = 0
        if r["verdict"] == "VIERGE":
            if r["corpus_classes"] == ["other"]:
                sub = -1                      # emergent seam first
            elif not r["payable"]:
                sub = 1                       # low-pay last within VIERGE (annotated, NOT a separate rank)
        return (vorder.get(r["verdict"], 2), sub, r["n_collision"], -r["global_total"])

    rows.sort(key=_sort_key)
    info = {"corpus_ok": corpus_ok, "n_fork": n_fork, "has_coverage": bool(cover_code),
            "cover_prose_only": cover_prose_only, "dense_cut": dense_cut, "n_forks": len(forks)}
    return rows, info


CAVEAT = ("> ⚠ **Ce filtre dé-priorise le CONNU, il n'est pas une carte du territoire.** Il énumère les "
          "money-paths canoniques du fork-source → aveugle à la 13ᵉ veine (artefact d'intégration propre à "
          "cette cible, absente du fork). La couture inter-composants (off-chain↔on-chain, lang-A↔lang-B) "
          "n'apparaît PAS ici → `/darkside` Door-C + le seam `/upshift`. « VIERGE » = libre parmi le connu, "
          "jamais « inexploré ».")


def _fork0_warn(info):
    return (info["n_forks"] > 0 and info["n_fork"] == 0 and info["corpus_ok"])


def render_md(rows, forks, shape, info):
    fk = ",".join(forks) if forks else "(non précisé)"
    md = [f"# NUKE saturation (v3, vein-granulaire) — quelle VEINE est vierge ?  · fork: `{fk}`" +
          (f" · shape: `{shape}`" if shape else ""),
          "> Le corpus donne des **candidats de collision à réfuter**, pas un verdict. **SUSPECT** = un "
          "finding ressemble → LIS-le, ne déprioris QUE si l'invariant cassé DIFFÈRE. **MINÉ-VIDE?** = la "
          "LOCALISATION CODE de la veine est dans le scope d'audit déclaré, aucun finding → cimetière "
          "probable. **VIERGE** = ni collision ni localisation-in-scope = les deux vides = la vraie brèche.\n",
          CAVEAT + "\n"]
    if _fork0_warn(info):
        md.append(f"> 🛑 **FORK MATCH = 0** — `{fk}` ne matche AUCUN finding du corpus. Le tout-VIERGE "
                  "ci-dessous est **du bruit, pas un signal** : nom de fork probablement absent/mal orthographié "
                  "dans le corpus, PAS une cible vierge. Corrige le nom (ou accepte que le corpus ignore ce "
                  "fork) avant de faire confiance à quoi que ce soit ici.\n")
    if not info["corpus_ok"]:
        md.append("> ⚠ corpus introuvable — colonne 1 (findings) indisponible.\n")
    if not info["has_coverage"]:
        if info["cover_prose_only"]:
            md.append("> ⚠ colonne 2 (coverage) fournie mais **prose seule** — aucun token code-localisé "
                      "(fichier/Contrat/fn). Le matching module est INACTIF : impossible de distinguer "
                      "MINÉ-VIDE de VIERGE. Donne un scope qui NOMME les modules/fichiers revus.\n")
        else:
            md.append("> ⚠ colonne 2 absente : passe `--coverage <fichier>` (section scope du RAPPORT d'audit "
                      "de la cible, pas Solodit). Sans elle, un « VIERGE » peut être un cimetière non écrit.\n")
    cur = None
    for r in rows:
        if r["verdict"] != cur:
            md.append(f"\n## {r['verdict']}\n"); cur = r["verdict"]
        line = f"- [ ] **{r['label']}**" + (f"  → `{r['vein']}`" if r["vein"] else "")
        dens = "dense" if r["dense"] else "rare"
        line += f"  · {r['n_collision']} collision(s) fork · {r['global_total']} global ({dens})"
        line += (" · loc∈scope" if r["in_scope"] else "")
        md.append(line)
        for n in r["notes"]:
            md.append(f"    - ⚑ {n}")
        if r["verdict"] == "VIERGE" and r["tell"]:
            md.append(f"    - 🔎 *tell (le HOW) :* {r['tell'][:300]}")
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
    rows, info = compute_saturation(sig, forks, args.shape, args.corpus, cov_text)
    out = args.out or os.path.join(os.path.dirname(args.signals), "saturation.md")
    open(out, "w", encoding="utf-8").write(render_md(rows, forks, args.shape, info))
    c = {}
    for r in rows:
        c[r["verdict"]] = c.get(r["verdict"], 0) + 1
    if _fork0_warn(info):
        print(f"[saturation] 🛑 fork '{args.fork}' → 0 finding corpus matché — tout-VIERGE = BRUIT, "
              "pas signal (nom de fork absent du corpus ?).", file=sys.stderr)
    else:
        print(f"[saturation] fork '{args.fork or '(aucun)'}' → {info['n_fork']} findings corpus matchés "
              f"· dense-cut={info['dense_cut']}", file=sys.stderr)
    print(f"[saturation] {len(rows)} veines · " + " · ".join(f"{k}:{v}" for k, v in sorted(c.items())) + f" → {out}")


if __name__ == "__main__":
    main()
