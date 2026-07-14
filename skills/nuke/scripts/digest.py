#!/usr/bin/env python3
"""
NUKE → intake bridge. Turn a signals.json into `nuke-digest.md`: an intake PRE-FILL that maps the
barrage's detected/corroborated classes and its NEGATIVE SPACE to ranked hunting veins, in the shape
intake's Classification / Corpus-ROUTE / RECOMMENDED-SKILL(S) sections expect.

It does NOT decide or hunt. It grounds intake's routing in what the code actually contains:
  - corroborated / high-severity classes present = concrete LEADS (dig here, with file:line).
  - silent classes (negative space) = the highest-value MANUAL-hunt directions.
Respects U-1: this is a suggestion artifact; the operator (via intake) confirms and launches.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

# class/keyword -> the operator's vein skill (aligned with nuke/references/routing.md).
# ORDER MATTERS: the dominant, specific vuln must win over a co-located generic keyword — else a
# reentrancy cluster carrying a stray "underflow" rule, or a tx.origin cluster carrying an
# "unsafe-erc20-operation" rule, gets misrouted to /extract. Specific classes are checked FIRST.
def vein_for(text):
    t = (text or "").lower()
    # 1. strong state/proxy vulns -> darkside (win over any co-located arith/erc20 noise)
    if any(k in t for k in ["reentran", "delegatecall", "proxy", "upgrade", "selfdestruct", "suicidal"]):
        return "/darkside"
    # 2. authorization -> power
    if any(k in t for k in ["tx-origin", "tx.origin", "access-control", "unprotected", "access", "auth",
                            "arbitrary-send", "privilege", "onlyowner", "role", "initializer", "initialization"]):
        return "/power"
    # 3. value/oracle math -> extract (strong: oracle/flashloan/manipulation)
    if any(k in t for k in ["oracle", "price", "flashloan", "flash-loan", "manipulation", "twap"]):
        return "/extract"
    # 4. signatures -> power
    if any(k in t for k in ["signature", "ecrecover", "replay", "permit", "nonce"]):
        return "/power"
    # 5. off-chain / MEV seam -> upshift
    if any(k in t for k in ["front-run", "frontrun", "mev", "slippage", "deadline", "sandwich", "keeper", "operator", "off-chain"]):
        return "/upshift"
    # 6. arithmetic / token math -> extract
    if any(k in t for k in ["overflow", "underflow", "precision", "rounding", "divide", "arith",
                            "share", "inflation", "donation", "first-deposit", "erc20", "erc4626",
                            "erc-4626", "safetransfer", "fee-on-transfer", "exact-balance"]):
        return "/extract"
    # 7. remaining state/dos hygiene -> darkside (dig)
    return "/darkside"

VEIN_WHY = {
    "/extract":  "veine MATH-EXTRACTIBLE (value/oracle/arith) — chaîne de gates par vitesse-de-mort, fork si le gate qui tue survit",
    "/power":    "veine AUTHZ — mesure la distance pouvoir↔autorisation par exécution depuis un acteur non-privilégié",
    "/darkside": "coins sombres — ce que les devs ont testé vs oublié ; réentrance/proxy/état",
    "/upshift":  "seam on-chain↔off-chain (keeper/operator/MEV/slippage)",
    "/invfuzz":  "ré-implémentation d'une math de référence — harness différentiel exécuté",
    "/wide":     "cible multi-surface — allocation de profondeur d'abord",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--signals", required=True)
    ap.add_argument("--out", default=None)
    ap.add_argument("--fork", default="", help="target/fork-source names for the saturation cross-check (e.g. gmx,fulcrom)")
    ap.add_argument("--shape", default="", help="protocol shape for the payable prior (perp/derivatives, lending, AMM/DEX ...)")
    ap.add_argument("--coverage", default="", help="path to the target's audit-report scope/coverage text (column 2)")
    ap.add_argument("--corpus", default=os.path.expanduser("~/Desktop/BUGS/solodit-corpus"))
    args = ap.parse_args()
    try:
        d = json.load(open(args.signals, encoding="utf-8"))
    except Exception as e:
        print(f"[digest] signals.json illisible: {e}", file=sys.stderr)
        sys.exit(2)

    target = d.get("target", "?")
    mode = d.get("mode", "full")
    clusters = d.get("clusters", [])
    silent = d.get("silent_classes", [])
    silent_detail = d.get("silent_detail")  # non-EVM: carries a curated per-class vein (authoritative)

    # leads from clusters (present in code) — keep the strongest per vein.
    # Route ONLY on real signal: medium+ severity OR cross-tool corroboration. Info/low singletons
    # (naming-convention, solc-version, unused-var …) are noise and must not drive vein selection.
    SEV_RANK = {"critical": 4, "high": 3, "medium": 2, "low": 1, "info": 0}
    lead_by_vein = defaultdict(list)
    score = defaultdict(float)
    for c in clusters:
        sev = c.get("severity", "info")
        corr = c.get("corroboration", 1)
        if SEV_RANK.get(sev, 0) < 2 and corr < 2:
            continue
        text = " ".join(c.get("rules", []) + c.get("titles", []))
        v = vein_for(text)
        indiff = c.get("in_diff", False)
        lead_by_vein[v].append((sev, corr, c.get("file", "?"), c.get("line", 0),
                                "+".join(c.get("tools", [])), c.get("rules", [])[:2], indiff))
        w = {"critical": 3, "high": 3, "medium": 1.5, "low": 0.4, "info": 0.1}.get(sev, 0.1)
        score[v] += w * (1 + 0.5 * (corr - 1)) * (1.5 if indiff else 1)

    # negative space directions (silent classes) — high value, boost their vein.
    # non-EVM carries a curated per-class vein (silent_detail); prefer it over the keyword heuristic.
    silent_by_vein = defaultdict(list)
    if silent_detail:
        for c in silent_detail:
            v = c.get("vein") or vein_for(c.get("class", ""))
            silent_by_vein[v].append(c.get("class", "?"))
            score[v] += 1.2
    else:
        for cls in silent:
            v = vein_for(cls)
            silent_by_vein[v].append(cls)
            score[v] += 1.2  # a silent, plausible class is a prime manual-hunt direction

    ranked = sorted(score, key=lambda v: score[v], reverse=True)

    md = [f"# NUKE digest — pré-remplissage intake · `{target}`",
          f"_(mode {mode} · à lire par /intake en Phase 0 : ancre la Classification + le Corpus-ROUTE dans ce que le code CONTIENT)_\n",
          "> U-1 : c'est une SUGGESTION rangée, pas un lancement. /intake confirme, l'opérateur lance.\n"]

    # saturation enrichment (operator supplies --fork/--shape): fold VIERGE veins (with the HOW) to the TOP,
    # demote LABOURÉE (already taken on this fork/target). The fine de-prioritization read the operator wants.
    if args.fork:
        try:
            import saturation as _sat
            _cov = ""
            if args.coverage and os.path.isfile(args.coverage):
                _cov = open(args.coverage, encoding="utf-8", errors="replace").read()
            _forks = [x.strip() for x in args.fork.split(",") if x.strip()]
            _rows, _info = _sat.compute_saturation(d, _forks, args.shape, args.corpus, _cov)
            _vierge = [r for r in _rows if r["verdict"] == "VIERGE"]
            _mined = [r for r in _rows if r["verdict"] == "MINÉ-VIDE?"]
            _susp = [r for r in _rows if r["verdict"] == "SUSPECT"]
            md.append("## 🎯 VEINES VIERGES (corpus 2-colonnes, vein-granulaire) — creuse ici, le HOW inclus\n")
            md.append(f"> Croisé avec le corpus sur `{args.fork}`" + (f" (shape `{args.shape}`)" if args.shape else "")
                      + (" + coverage code-localisée" if _info.get("has_coverage") else
                         (" · ⚠ coverage prose-seule → matching module INACTIF" if _info.get("cover_prose_only")
                          else " · ⚠ colonne coverage absente (`--coverage <scope>`) → un VIERGE peut être un cimetière"))
                      + ". **Le corpus donne des candidats à réfuter, pas un verdict.** Dé-priorise le CONNU — la 13ᵉ veine (couture d'intégration) n'est PAS ici → `/darkside` Door-C / `/upshift`.\n")
            if _sat._fork0_warn(_info):
                md.append(f"> 🛑 **FORK MATCH = 0** : `{args.fork}` ne matche aucun finding du corpus → le tout-VIERGE "
                          "ci-dessous est du BRUIT (nom de fork absent/mal orthographié), PAS une cible vierge. Corrige avant de creuser.\n")
            if _vierge:
                for r in _vierge:
                    md.append(f"- [ ] **{r['label']}**" + (f"  → `{r['vein']}`" if r.get("vein") else "") +
                              f"  ({r['n_collision']} collision / {r['global_total']} global"
                              + (", dense" if r.get("dense") else "") + ")")
                    for n in r.get("notes", []):
                        md.append(f"    - ⚑ {n}")
                    if r.get("tell"):
                        md.append(f"    - 🔎 {r['tell'][:280]}")
            else:
                md.append("- _(aucune veine des deux-vides — tout le barrage a une collision ou est dans le scope déclaré)_")
            if _susp:
                md.append("\n> 🚧 **SUSPECT — réfute AVANT de déprioriser** (un finding ressemble ; ne déprioris que si l'invariant cassé DIFFÈRE) : "
                          + ", ".join(f"`{r['label']}`×{r['n_collision']}" + ("⟨classe-seule⟩" if r.get("resolution") == "class-only" else "") for r in _susp))
            if _mined:
                md.append("> ⚰ **MINÉ-VIDE?** (localisation-code dans le scope d'audit, aucun finding → cimetière probable) : "
                          + ", ".join(f"`{r['label']}`" for r in _mined))
            md.append("")
        except Exception as _e:
            md.append(f"> _(saturation indisponible : {_e})_\n")

    md.append("## Classes détectées (leads concrets — creuse ici, artefact exécuté avant finding)\n")
    any_lead = False
    for v in ranked:
        leads = lead_by_vein.get(v, [])
        highs = [l for l in leads if l[0] in ("high", "critical")]
        show = highs or leads
        if not show:
            continue
        any_lead = True
        for sev, corr, f, ln, tools, rules, indiff in sorted(show, key=lambda x: (x[0] != "critical", x[0] != "high", -x[1]))[:3]:
            tag = " ‹PATCH›" if indiff else ""
            md.append(f"- **{sev.upper()}** `{f}:{ln}` {'★'*corr} `{tools}` → **{v}**{tag}  ({', '.join(rules)})")
    if not any_lead:
        md.append("- _(aucun cluster high/corroboré — le lead est dans l'espace négatif ci-dessous)_")
    md.append("")

    md.append("## Espace négatif (directions de chasse MANUELLE — les scanners sont muets ici)\n")
    if silent:
        for v in ranked:
            cs = silent_by_vein.get(v, [])
            if cs:
                md.append(f"- **{v}** ← {', '.join('`'+c+'`' for c in cs)}")
        # veins with no silent class but present in ranking are skipped here
    else:
        md.append("- _(toutes les classes ont au moins un signal — vérifie la couverture)_")
    md.append("")

    md.append("## RECOMMENDED VEIN(S) — rangées (à fusionner dans le dossier intake)\n")
    for i, v in enumerate([v for v in ranked if score[v] > 0][:4], 1):
        why = VEIN_WHY.get(v, "")
        n_lead = len(lead_by_vein.get(v, []))
        n_sil = len(silent_by_vein.get(v, []))
        basis = []
        if n_lead: basis.append(f"{n_lead} lead(s) détecté(s)")
        if n_sil: basis.append(f"{n_sil} classe(s) muette(s)")
        md.append(f"{i}. **{v}** — {why}  \n   _base : {', '.join(basis) or 'signal faible'} (score {score[v]:.1f})_")
    if mode == "diff":
        md.append("\n> Mode diff : priorise les leads ‹PATCH› — c'est ce que le changement a introduit/touché.")
    md.append("")

    out = args.out or os.path.join(os.path.dirname(args.signals), "nuke-digest.md")
    open(out, "w", encoding="utf-8").write("\n".join(md))
    print(f"[digest] → {out}  ({len([v for v in ranked if score[v]>0])} veines rangées, "
          f"{len(silent)} classes muettes)")


if __name__ == "__main__":
    main()
