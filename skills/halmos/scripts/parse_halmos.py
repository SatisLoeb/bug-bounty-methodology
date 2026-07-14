#!/usr/bin/env python3
"""
Parse Halmos JSON (+ text log) into a verdict table that REFUSES to call a vacuous check "proven".

Classification (per check_ function), driven by the real Halmos 0.3.x output:
  exitcode == 0                          -> PROVEN     (no counterexample under the bounds)
  num_models  > 0                        -> COUNTEREXAMPLE (real bug candidate; concrete inputs printed)
  "all paths have been reverted" / exit 4-> VACUOUS    (proved NOTHING — the false-green trap)
  other non-zero, no model               -> INDETERMINATE (SMT wall / timeout — not a proof)

A PROVEN check that explored <=1 path is flagged for PARTIAL-vacuity suspicion (run the canary).
Exit code: 0 only if every check is PROVEN and none is flagged; non-zero otherwise (CI-usable).
"""
import argparse
import json
import re
import sys
from collections import defaultdict

C = {"g": "\033[32m", "r": "\033[31m", "y": "\033[33m", "b": "\033[34m", "d": "\033[2m", "x": "\033[0m"}
NAME_RE = re.compile(r"(check_\w+)\s*\(")


def base(name):
    m = NAME_RE.search(name or "")
    return m.group(1) if m else (name or "?")


def parse_log(path):
    """Return {base_name: {'revert_all': bool, 'models': [lines]}} from the text log."""
    info = defaultdict(lambda: {"revert_all": False, "models": []})
    if not path:
        return info
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return info
    raw = re.sub(r"\033\[[0-9;]*m", "", raw)  # strip ANSI
    pending = []
    for line in raw.splitlines():
        if "all paths have been reverted" in line:
            info[base(line)]["revert_all"] = True
        if line.strip().startswith("Counterexample"):
            pending = []
            continue
        m = re.match(r"\s+(\S+)\s*=\s*(0x[0-9a-fA-F]+|\d+)", line)
        if m:
            pending.append(f"{m.group(1)} = {m.group(2)}")
            continue
        if "[FAIL]" in line or "[ERROR]" in line:
            if pending:
                info[base(line)]["models"] = pending
            pending = []
    return info


def classify(exitcode, num_models, revert_all):
    if exitcode == 0:
        return "PROVEN"
    if num_models and num_models > 0:
        return "COUNTEREXAMPLE"
    if revert_all or exitcode == 4:
        return "VACUOUS"
    return "INDETERMINATE"


VERDICT = {
    "PROVEN":         (C["g"], "✓ PROUVÉ (borné)"),
    "COUNTEREXAMPLE": (C["r"], "✗ CONTRE-EXEMPLE"),
    "VACUOUS":        (C["y"], "⨯ VACUITÉ — n'a RIEN prouvé"),
    "INDETERMINATE":  (C["y"], "? INDÉCIS (mur SMT / timeout)"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", required=True)
    ap.add_argument("--log", default=None)
    ap.add_argument("--loop", default="2")
    ap.add_argument("--arrays", default="0,65,1024")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    try:
        data = json.load(open(args.json, encoding="utf-8"))
    except Exception as e:
        print(f"{C['r']}[halmos] JSON illisible ({e}) — le build a-t-il échoué ? Voir le log.{C['x']}")
        sys.exit(2)

    log = parse_log(args.log)
    rows, worst = [], 0
    for suite, results in (data.get("test_results") or {}).items():
        for r in results:
            name = r.get("name", "?")
            bn = base(name)
            ex = r.get("exitcode", 1)
            nm = r.get("num_models", 0)
            paths = r.get("num_paths") or [0]
            loops = r.get("num_bounded_loops", 0)
            ra = log[bn]["revert_all"]
            verdict = classify(ex, nm, ra)
            partial = verdict == "PROVEN" and (paths[0] if paths else 0) <= 1
            rows.append({"suite": suite, "name": name, "verdict": verdict,
                         "paths": paths[0] if paths else 0, "loops": loops,
                         "models": log[bn]["models"], "partial": partial})
            if verdict != "PROVEN" or partial:
                worst = 1

    # ---- console
    print(f"\n{C['b']}== Halmos — verdicts (borne: --loop {args.loop}, arrays {args.arrays}) =={C['x']}")
    for row in rows:
        col, label = VERDICT[row["verdict"]]
        print(f"  {col}{label:30s}{C['x']} {row['name']}  {C['d']}(paths={row['paths']}, loops={row['loops']}){C['x']}")
        if row["verdict"] == "COUNTEREXAMPLE" and row["models"]:
            for mv in row["models"]:
                print(f"        {C['r']}↳ {mv}{C['x']}")
        if row["partial"]:
            print(f"        {C['y']}↳ 1 seul chemin exploré — soupçonne la VACUITÉ PARTIELLE. "
                  f"Canary: remplace assert(P) par assert(false), relance; si ça PASSE encore = vacuous.{C['x']}")
        if row["verdict"] == "VACUOUS":
            print(f"        {C['y']}↳ tous les chemins revert : le vert ne prouve RIEN. "
                  f"Desserre les vm.assume / vérifie que la cible ne revert pas toujours.{C['x']}")

    n = len(rows)
    proven = sum(1 for r in rows if r["verdict"] == "PROVEN" and not r["partial"])
    print(f"\n  {proven}/{n} prouvés nets · "
          f"{sum(1 for r in rows if r['verdict']=='COUNTEREXAMPLE')} contre-ex · "
          f"{sum(1 for r in rows if r['verdict']=='VACUOUS')} vacuité · "
          f"{sum(1 for r in rows if r['verdict']=='INDETERMINATE')} indécis · "
          f"{sum(1 for r in rows if r['partial'])} partiels-suspects")
    print(f"  {C['d']}Rappel: « prouvé » = aucun contre-exemple SOUS CETTE BORNE (--loop {args.loop}, "
          f"arrays {args.arrays}). Note la borne à côté du résultat — ce n'est pas ∀n.{C['x']}")

    # ---- proof.md artifact
    if args.out:
        md = [f"# Halmos — preuve bornée\n",
              f"**Borne (hypothèse à noter) :** `--loop {args.loop}`, array-lengths `{args.arrays}`. "
              f"« Prouvé » = aucun contre-exemple **sous cette borne**, pas ∀n.\n",
              "| check | verdict | paths | contre-exemple / note |", "|---|---|---|---|"]
        for row in rows:
            note = ""
            if row["verdict"] == "COUNTEREXAMPLE":
                note = "; ".join(row["models"]) or "(voir log)"
            elif row["verdict"] == "VACUOUS":
                note = "tous les chemins revert — ne prouve rien"
            elif row["partial"]:
                note = "1 chemin — vérifier vacuité partielle (canary)"
            md.append(f"| `{row['name']}` | {row['verdict']} | {row['paths']} | {note} |")
        open(args.out, "w").write("\n".join(md) + "\n")

    sys.exit(worst)


if __name__ == "__main__":
    main()
