#!/usr/bin/env bash
# corpus-query.sh — the integration point between the c4/solodit pattern bank and the hunting skills.
#
# Given a target's protocol SHAPE, emits a prioritized hunting plan from the corpus:
#   1. class-density priority  (which vuln classes pay most on this shape, + their detection_tell)
#   2. named patterns          (the P-XXX taxonomy entries for this shape, incl. the new ORACLE set)
#
# The hunting skills (firmaudit / darkside / mrrobbot / gravedigger / orca) call this at recon/Phase-0
# so depth is pointed at the highest-pay-density classes for the shape, not a flat scan.
#
# Corpus artifacts (referenced in place, NOT copied — see skill-infrastructure-topology):
#   ~/Desktop/BUGS/solodit-corpus/protocol-type-index.json   shape -> top_classes (density)
#   ~/Desktop/BUGS/solodit-corpus/class-map.json             class -> high_density + detection_tell
#   ~/Desktop/BUGS/c4-patterns/PATTERN-TAXONOMY.md           named P-XXX patterns (163, ORACLE-enriched)
#   ~/Desktop/BUGS/immunefi-corpus/{protocol-type-index,class-map}.json   OPTIONAL, own block/scale
#
# IMMUNEFI BLOCK (2026-07-31): shape/--route/--class now also emit an Immunefi audit-comp block
# (2971 findings, 53 comps) BELOW the solodit output. It is deliberately NOT merged: solodit
# severity is a contest judge's on 2 levels, Immunefi's is the PAYER's on 5 (Critical..Insight,
# Insight weighted 0). Averaging them yields a meaningless number and would corrupt the H-density
# calibration below, which 9 skills depend on. Read the two blocks side by side, never compare
# their numbers. What it adds that solodit structurally cannot express: the node classes
# (consensus / p2p-networking / mempool / state-sync / resource-exhaustion) and the `L1/L2 node`
# shape, which has no solodit equivalent and resolves through the Immunefi-only path.
# Absent corpus = block silently omitted; all pre-existing output and exit codes are unchanged.
#
# Usage:
#   corpus-query.sh <shape>          # hunting plan for a shape (fuzzy: "lending", "amm", "bridge", "perp"...)
#   corpus-query.sh --list           # list available shapes
#   corpus-query.sh --class <class>  # deep-dive one class (density + tell + examples)
#   corpus-query.sh --methods <class> # discovery METHODS for a class (how auditors found it)
#   corpus-query.sh --route <shape>  # which VEIN (skill) to activate per top class of the shape
#   corpus-query.sh <shape> --json   # machine-readable (adds an "immunefi" key; all prior keys unchanged)
#   immunefi-corpus-query.sh ...     # the Immunefi corpus direct (dup-check / severity-precedent / VSC impacts)
#
# CALIBRATION (measured on Pendle Boros blind firmaudit, 2026-06-24 — feedback_corpus_methods_beats_route_lead_with_the_tell):
#   LEAD WITH `--methods` on the top-2 classes. The detection_tell it returns is the highest-real-value output —
#   convert each tell into a concrete investigative LENS you carry into every file BEFORE pattern-matching
#   (on Boros the accounting tell "unit/domain blocks-vs-seconds" became the lens "rate-denominated cost vs
#   upfront-cash" that drove the whole hunt). Order of use: `--methods` (the HOW/lens) -> `<shape>` (density/AIM)
#   -> `--route` (directional pointer only). Do NOT expect ANY mode to NAME the bug: the payable finding on
#   audited code is the un-catalogued Door-C composition the corpus structurally cannot reach — the corpus is a
#   COMPLETENESS BACKSTOP + an AIM + a method-bank, NOT a discovery engine. Zero corpus findings on a clean target
#   is the corpus working as designed, not failing.
set -euo pipefail

BUGS="${BUGS_ROOT:-$HOME/Desktop/BUGS}"
PTI="$BUGS/solodit-corpus/protocol-type-index.json"
CMAP="$BUGS/solodit-corpus/class-map.json"
TAX="$BUGS/c4-patterns/PATTERN-TAXONOMY.md"
C4F="$BUGS/c4-corpus/findings.jsonl"          # has discovery_how (the METHOD) per finding
SOLF="$BUGS/solodit-corpus/findings.jsonl"    # discovery_how backfilled

# Immunefi audit-competition corpus — OPTIONAL, and rendered as its OWN block on a
# SEPARATE scale. It is never merged into high_density: solodit severity is a contest
# judge's on 2 levels, Immunefi's is the PAYER's on 5 (incl. Critical and a zero-weight
# Insight). Averaging the two produces a number that means nothing, and the existing
# density calibration (Pendle Boros, 2026-06-24) is load-bearing for 9 skills.
IMFPTI="$BUGS/immunefi-corpus/protocol-type-index.json"
IMFCMAP="$BUGS/immunefi-corpus/class-map.json"

for f in "$PTI" "$CMAP" "$TAX"; do
  [ -f "$f" ] || { echo "FATAL: corpus artifact missing: $f" >&2; exit 1; }
done

MODE="shape"; ARG=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --list) MODE="list";;
    --class) MODE="class"; shift; ARG="${1:-}";;
    --methods|--how) MODE="methods";;
    --route) MODE="route";;
    --json) JSON=1;;
    -h|--help) sed -n '2,10p;27,35p' "$0"; exit 0;;   # intro + Usage block
    *) ARG="$1";;
  esac
  shift || true
done

export PTI CMAP TAX C4F SOLF IMFPTI IMFCMAP MODE ARG JSON
python3 - <<'PY'
import json, os, re, sys
pti = json.load(open(os.environ["PTI"]))
cmap = json.load(open(os.environ["CMAP"]))
tax_text = open(os.environ["TAX"], encoding="utf-8", errors="ignore").read()
mode = os.environ["MODE"]; arg = os.environ["ARG"].strip(); as_json = os.environ["JSON"] == "1"


def _opt(envkey):
    p = os.environ.get(envkey)
    if p and os.path.exists(p):
        try:
            return json.load(open(p, encoding="utf-8"))
        except Exception:
            return None
    return None


imf_pti = _opt("IMFPTI")     # Immunefi shape -> classes; None when the corpus is absent
imf_cmap = _opt("IMFCMAP")


def imf_shape(q):
    """Resolve a shape name against the Immunefi index. Its vocabulary is nearly the
    same as solodit's (same SHAPE_TELLS lineage) with two deltas: `stablecoin/RWA`
    vs `stablecoin`, and `L1/L2 node`, which solodit has no equivalent for."""
    if not imf_pti or not q:
        return None
    if q in imf_pti:
        return q
    ql = q.lower()
    for k in imf_pti:
        toks = re.split(r"[/ ]", k.lower())
        if ql == k.lower() or ql in toks or any(ql in t or t in ql for t in toks if t):
            return k
    return None


def imf_rows(shape, limit=8):
    sh = imf_shape(shape)
    if not sh:
        return None, []
    rows = []
    for tc in imf_pti[sh].get("top_classes", [])[:limit]:
        c = tc.get("class")
        cm = (imf_cmap or {}).get(c, {})
        rows.append({"class": c, "n": tc.get("n"), "weight": tc.get("weight"),
                     "crit_high_share": cm.get("crit_high_share"),
                     "detection_tell": cm.get("detection_tell", "")})
    return sh, rows


def print_imf_block(shape, tells=False):
    """Own scale, own header, printed BELOW the solodit output — additive, never merged."""
    sh, rows = imf_rows(shape)
    if not rows:
        return
    n = imf_pti[sh].get("finding_count", "?")
    print(f"\n-- IMMUNEFI audit-comps (payer-assigned severity, {n} findings on this shape) --")
    print(f"   ranked by PAYOUT-WEIGHT C=4 H=3 M=2 L=1 I=0 — a DIFFERENT scale from H-dens above, do not compare the numbers")
    for i, r in enumerate(rows, 1):
        ch = r["crit_high_share"]
        ch = f"{ch:.2f}" if isinstance(ch, (int, float)) else "  ?"
        print(f"  {i:2}. {r['class']:20} n={r['n']:<5} wgt={r['weight']:<6} C+H={ch}")
        if tells and r["detection_tell"]:
            print(f"      tell: {r['detection_tell']}")
    if any(r["class"] == "logic" for r in rows):
        print("   note: `logic` is the untagged RESIDUE (31.5%), not a class.")
    print(f"   deep-dive: immunefi-corpus-query.sh --route '{sh}'  ·  --class <class>")

# shape -> taxonomy P-prefix (the named-pattern bucket). ORACLE is cross-cutting, always appended.
SHAPE_PREFIX = {
    "AMM/DEX": "DEX", "lending": "LEND", "vault/yield": "VAULT", "staking/LST": "STAKE",
    "bridge/cross-chain": "BRIDGE", "perp/derivatives": "DERIV", "governance/DAO": "GOV",
    "stablecoin": "LEND", "NFT/gaming": "MISC", "other": "MISC",
}

# class -> the VEIN (dictated skill / door) that empirically finds this class.
# Derived from the corpus method-signatures (2026-06: accounting=enumerate-siblings,
# oracle=diff-vs-reference, rounding=symbolic-expand, access-control=become-actor).
CLASS_VEIN = {
    "accounting":        "mrrobbot:check-matrix  (enumerate sibling paths, find the asymmetric one)",
    "liquidation":       "mrrobbot:Phase-3       (optimize the liquidatable position; per-collateral formula)",
    "rounding":          "extract                (symbolic-expand the share formula; div-before-mul; dust/decimals boundary)",
    "oracle":            "invfuzz                (differential vs Uniswap/Chainlink ref + staleness/min-max boundary)",
    "price-manipulation":"invfuzz + mrrobbot     (diff vs reference; spot priced in the same block)",
    "access-control":    "power                  (enumerate powers; ungated sibling; authz != authn)",
    "reentrancy":        "mrrobbot:check-matrix  (CEI per state-writer; cross-fn / read-only)",
    "arithmetic":        "extract                (cast/underflow at 0 / max boundary; unchecked blocks)",
    "arithmetic-overflow":"extract               (boundary 0 / max; unchecked blocks)",
    "share-inflation":   "extract                (first-depositor; virtual-shares offset; donation)",
    "first-depositor":   "extract                (totalSupply==0 branch; rounding-to-zero)",
    "signature-replay":  "power + gravedigger    (what's in the signed hash: chainId / nonce / actor bound?)",
    "MEV-sandwich":      "mrrobbot               (value priced from a same-block manipulable spot; missing slippage)",
    "front-running-MEV": "mrrobbot               (same-block ordering; missing commit-reveal)",
    "slippage":          "mrrobbot               (missing / forgeable minOut on swap / redeem)",
    "cross-chain":       "firmaudit:Path-A       (validate BOTH source chain AND sender; ghost message)",
    "DoS":               "darkside + mrrobbot    (Door-A untested griefing sibling / unbounded loop) — quantify $",
    "griefing":          "darkside               (untested griefing sibling) — needs a $ figure for severity",
    "governance":        "darkside + mrrobbot    (timelock / quorum composition)",
    "input-validation":  "power + mrrobbot:check-matrix (the unvalidated field a sibling validates)",
    "flash-loan":        "extract + mrrobbot     (the inflated state + the atomic invariant)",
    "fee-manipulation":  "extract                (fee math directionality; deducted-but-not-sent)",
    "initialization":    "power:become-the-actor (uninit clone/impl; re-init gap)",
    "upgradeability":    "darkside:0.5.5         (deployed-layer: EIP-1967 admin; impl drift)",
    "timelock-bypass":   "darkside + firmaudit:Phase-T (the governance chain)",
    "timing":            "darkside:temporal-axis (edge/transition state; same-block; first/last actor)",
    "logic":             "darkside:Door-C        (the no-CWE composition bug)",
    "other":             "firmaudit:Phase-S      (no class fits → name the seam nobody owns)",
}
DEFAULT_VEIN = "firmaudit:Phase-S (name the seam) / darkside Door-C"

def patterns_for(prefix):
    out = []
    for m in re.finditer(r"^### (P-%s-\d+):\s*(.+)$" % re.escape(prefix), tax_text, re.M):
        out.append((m.group(1), m.group(2).strip()))
    return out

def resolve_shape(q):
    if q in pti: return q
    ql = q.lower()
    # fuzzy: input is a substring of a key token, or vice-versa
    for k in pti:
        toks = re.split(r"[/ ]", k.lower())
        if ql == k.lower() or ql in toks or any(ql in t or t in ql for t in toks if t):
            return k
    return None

if mode == "methods":
    from collections import Counter, defaultdict
    methods = defaultdict(Counter)
    def _norm(s): return re.sub(r"\s+", " ", (s or "").strip())[:220]
    for path, classkey in ((os.environ.get("C4F"), "class"), (os.environ.get("SOLF"), "classes")):
        if not path or not os.path.exists(path): continue
        for line in open(path, encoding="utf-8", errors="ignore"):
            line = line.strip()
            if not line: continue
            try: r = json.loads(line)
            except: continue
            dh = _norm(r.get("discovery_how"))
            if not dh: continue
            # skip corpus-enrichment provenance (it is HOW the pattern was catalogued, not how the bug was found)
            if "non-C4 corpus mapping" in dh or "novelty-verify" in dh or "adversarial novelty" in dh: continue
            cls = r.get(classkey)
            if isinstance(cls, list): cls = cls[0] if cls else "?"
            methods[str(cls)][dh] += 1
    total = sum(sum(c.values()) for c in methods.values())
    if not total:
        print("no discovery_how in either corpus yet (solodit backfill pending?). c4-corpus has it; check $C4F.", file=sys.stderr); sys.exit(1)
    if arg:
        hit = arg if arg in methods else next((k for k in methods if arg.lower() in k.lower()), None)
        if not hit:
            print(f"no methods for class '{arg}'. classes: {', '.join(sorted(methods))}"); sys.exit(1)
        c = methods[hit]
        if as_json:
            print(json.dumps({"class": hit, "methods": [{"how": h, "n": n} for h, n in c.most_common()]})); sys.exit(0)
        print(f"== DISCOVERY METHODS — class: {hit}  ({sum(c.values())} findings) ==\n")
        for h, n in c.most_common(15): print(f"  [{n:>3}x] {h}")
        sys.exit(0)
    if as_json:
        print(json.dumps({cls: [{"how": h, "n": n} for h, n in c.most_common(5)] for cls, c in methods.items()})); sys.exit(0)
    print(f"== DISCOVERY METHOD BANK — how these bugs were FOUND, by class ({total} findings with a method) ==\n")
    for cls in sorted(methods, key=lambda k: -sum(methods[k].values())):
        c = methods[cls]
        print(f"-- {cls} ({sum(c.values())} findings) — top methods:")
        for h, n in c.most_common(3): print(f"     [{n}x] {h}")
    print(f"\n  deep-dive: corpus-query.sh --methods <class>   (source: c4-corpus + solodit discovery_how)")
    sys.exit(0)

if mode == "route":
    shape = resolve_shape(arg) if arg else None
    if not shape:
        print(f"unknown shape '{arg}'. Run --list for available shapes.", file=sys.stderr); sys.exit(1)
    # method-depth available per class (count discovery_how across c4 + solodit)
    from collections import Counter
    mcount = Counter()
    for path, classkey in ((os.environ.get("C4F"), "class"), (os.environ.get("SOLF"), "classes")):
        if not path or not os.path.exists(path): continue
        for line in open(path, encoding="utf-8", errors="ignore"):
            line = line.strip()
            if not line: continue
            try: r = json.loads(line)
            except: continue
            dh = (r.get("discovery_how") or "").strip()
            if not dh or "non-C4 corpus mapping" in dh or "novelty-verify" in dh or "adversarial novelty" in dh: continue
            cls = r.get(classkey)
            if isinstance(cls, list): cls = cls[0] if cls else "?"
            mcount[str(cls)] += 1
    info = pti[shape]
    rows = []
    for tc in info.get("top_classes", [])[:10]:
        cls = tc.get("class"); cm = cmap.get(cls, {})
        rows.append({"class": cls, "n": tc.get("n"), "high_density": cm.get("high_density"),
                     "methods": mcount.get(cls, 0), "vein": CLASS_VEIN.get(cls, DEFAULT_VEIN),
                     "detection_tell": cm.get("detection_tell", "")})
    if as_json:
        _sh, _ir = imf_rows(shape)
        out = {"shape": shape, "route": rows}
        if _ir:
            out["immunefi"] = {"shape": _sh, "scale": "payout_weight C4/H3/M2/L1/I0", "route": _ir}
        print(json.dumps(out, indent=1)); sys.exit(0)
    print(f"== CORPUS ROUTE — shape: {shape}  → which VEIN (skill) to activate per class ==\n")
    print(f"  {'#':>2}  {'class':18} {'n':>5} {'Hdns':>5} {'meth':>5}   VEIN")
    for i, r in enumerate(rows, 1):
        hd = r["high_density"]; hd = f"{hd:.2f}" if isinstance(hd, (int, float)) else "  ?"
        print(f"  {i:>2}. {r['class']:18} {r['n']:>5} {hd:>5} {r['methods']:>5}   {r['vein']}")
    if rows:
        t2 = rows[:2]
        print(f"\n  DEPTH ROUTE (point Pass-1 here first): " + "   |   ".join(
            f"{r['class']} -> {r['vein'].split()[0]}" for r in t2))
    if any(r["class"] in ("oracle", "price-manipulation") for r in rows):
        print(f"  cross-cutting: oracle/price present -> invfuzz (differential vs reference lib).")
    print_imf_block(shape)
    print(f"\n  then: corpus-query --methods <class>  (the techniques) · corpus-query {shape}  (the named patterns)")
    sys.exit(0)

if mode == "list":
    print("Available shapes (protocol_type) in the corpus:")
    for k in sorted(pti, key=lambda x: -pti[x].get("finding_count", 0)):
        print(f"  {k:22} ({pti[k].get('finding_count',0)} findings)")
    if imf_pti:
        extra = [k for k in imf_pti if not resolve_shape(k)]
        if extra:
            print("\nImmunefi-only shapes (no solodit equivalent — query these via the immunefi block):")
            for k in sorted(extra, key=lambda x: -imf_pti[x].get("finding_count", 0)):
                print(f"  {k:22} ({imf_pti[k].get('finding_count',0)} findings)")
    sys.exit(0)

if mode == "class":
    c = cmap.get(arg)
    if not c:
        # fuzzy class match
        hit = next((k for k in cmap if arg.lower() in k.lower()), None)
        c = cmap.get(hit) if hit else None
        arg = hit or arg
    if not c:
        print(f"unknown class '{arg}'. Known: {', '.join(cmap)}"); sys.exit(1)
    imf_c = (imf_cmap or {}).get(arg)
    if as_json:
        out = {"class": arg, **c}
        if imf_c:
            out["immunefi"] = {k: imf_c[k] for k in
                               ("total", "by_severity", "payout_weight", "crit_high_share", "detection_tell")
                               if k in imf_c}
        print(json.dumps(out)); sys.exit(0)
    print(f"== CLASS: {arg} ==")
    print(f"  H/M: {c.get('high')}/{c.get('medium')}  |  H-density: {c.get('high_density')}")
    print(f"  detection_tell: {c.get('detection_tell','')}")
    for ex in (c.get("examples") or [])[:4]:
        print(f"    ex: {ex.get('title','')[:80]}")
    if imf_c:
        bs = imf_c.get("by_severity", {})
        print(f"\n  -- IMMUNEFI (payer severity, separate scale) --")
        print(f"     n={imf_c.get('total')}  " + " ".join(f"{k}={v}" for k, v in bs.items())
              + f"  |  payout-weight={imf_c.get('payout_weight')}  C+H={imf_c.get('crit_high_share')}")
        if imf_c.get("detection_tell") and imf_c["detection_tell"] != c.get("detection_tell"):
            print(f"     tell: {imf_c['detection_tell']}")
        print(f"     exemplars: immunefi-corpus-query.sh --class {arg}")
    sys.exit(0)

# mode == shape
shape = resolve_shape(arg) if arg else None
if not shape:
    # solodit has no such shape — but Immunefi may (e.g. `L1/L2 node`, which is the
    # coverage this corpus adds). Emit the Immunefi block alone rather than failing.
    _sh, _rows = imf_rows(arg)
    if _rows:
        print(f"== shape '{_sh}' exists ONLY in the Immunefi corpus (no solodit equivalent) ==")
        print_imf_block(arg, tells=True)
        sys.exit(0)
    print(f"unknown shape '{arg}'. Run --list for available shapes.", file=sys.stderr); sys.exit(1)
info = pti[shape]
top = info.get("top_classes", [])
prefix = SHAPE_PREFIX.get(shape, "MISC")
named = patterns_for(prefix)
oracle = patterns_for("ORACLE")

# enrich each top class with density + tell from class-map
prio = []
for tc in top:
    cls = tc.get("class"); cm = cmap.get(cls, {})
    prio.append({"class": cls, "n": tc.get("n"),
                 "high_density": cm.get("high_density"),
                 "detection_tell": cm.get("detection_tell", "")})

if as_json:
    out = {"shape": shape, "finding_count": info.get("finding_count"),
           "class_priority": prio, "named_patterns": [{"id": i, "title": t} for i, t in named],
           "oracle_patterns": [{"id": i, "title": t} for i, t in oracle]}
    _sh, _ir = imf_rows(shape)
    if _ir:
        out["immunefi"] = {"shape": _sh, "scale": "payout_weight C4/H3/M2/L1/I0", "class_priority": _ir}
    print(json.dumps(out, indent=1))
    sys.exit(0)

print(f"== CORPUS HUNTING PLAN — shape: {shape}  ({info.get('finding_count','?')} findings in corpus) ==\n")
print("CLASS-DENSITY PRIORITY (hunt these first; highest pay-density on this shape):")
for i, p in enumerate(prio[:10], 1):
    hd = p["high_density"]; hd = f"{hd:.2f}" if isinstance(hd, (int, float)) else "?"
    print(f"  {i:2}. {p['class']:16} n={p['n']:<5} H-dens={hd}")
    if p["detection_tell"]:
        print(f"      tell: {p['detection_tell']}")
print_imf_block(shape, tells=True)
print(f"\nNAMED PATTERNS for this shape (P-{prefix}-*, from PATTERN-TAXONOMY.md):")
if named:
    for i, t in named:
        print(f"  {i}: {t}")
else:
    print(f"  (no P-{prefix} patterns; rely on the class-density tells above)")
print(f"\nCROSS-CUTTING — ORACLE (check on ANY shape with a price/oracle input):")
for i, t in oracle:
    print(f"  {i}: {t}")
print(f"\nSource: protocol-type-index.json + class-map.json + PATTERN-TAXONOMY.md (163 patterns)")
PY
