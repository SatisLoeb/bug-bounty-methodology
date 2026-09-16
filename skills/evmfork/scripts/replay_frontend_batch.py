#!/usr/bin/env python3
"""
replay_frontend_batch.py <batch.json> [--rpc URL]

The step solfork LACKS. On a web3-app target the in-scope surface is the calldata the APP builds - the bug
class is "what the UI DISPLAYS != what the wallet SIGNS != what executes on-chain" (redirect deposit/
withdraw, wrong recipient/amount/chain, a migration that bricks the name). This script REPLAYS the app's
exact captured calldata on a state-fork and diffs a set of state WATCHES pre vs post, so the brick/hijack/
wrong-amount is proven by the executed state delta, never inferred from reading the encoder.

Capture the calldata one of two ways, then feed it here as batch.json:
  (1) run the app's OWN exported encoder in node (buildXBatch / createXData -> the {to,data,value} calls), or
  (2) intercept eth_sendTransaction / the wallet request from a headless playwright session / DevTools HAR.

batch.json shape:
{
  "from":   "0x<the user/victim the app signs as>",
  "calls":  [ {"to":"0x..","data":"0x..","value":"0"}, ... ],   # executed in order (the app's batch)
  "watches":[                                                    # view-calls read before AND after
    {"label":"name owner", "to":"0xREG", "data":"0x<ownerOf/getOwner calldata>",
     "decode":"address", "expect":"0x<the address the UI SHOWED>"},
    {"label":"user balance","to":"0xTOKEN","data":"0x70a08231<user padded>","decode":"uint"}
  ]
}
A watch whose AFTER value != its `expect` (the displayed intent) is the finding: executed != displayed.
An owner that becomes the attacker = hijack; a resolver/owner zeroed = brick; a balance moved wrong = theft.

Non-destructive: snapshots before, reverts after, so you can re-run variants. Requires sim.py (same dir).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402


def _decode(hexval, how):
    if hexval is None or hexval == "0x":
        return None
    if how == "uint":
        return int(hexval, 16)
    if how == "address":
        return "0x" + hexval[-40:]
    if how == "bool":
        return int(hexval, 16) != 0
    return hexval  # raw


def read_watches(watches, url=None):
    out = {}
    for w in watches:
        ok, ret = sim.call(w["to"], w["data"], url=url)
        out[w["label"]] = (_decode(ret, w.get("decode", "raw")) if ok else f"REVERT: {ret}")
    return out


def replay(batch, url=None):
    """Execute the captured calls in order on the fork, diffing watches. Returns a report dict."""
    watches = batch.get("watches", [])
    frm = batch["from"]
    before = read_watches(watches, url=url)

    snap = sim.snapshot(url=url)
    exec_log = []
    try:
        for i, c in enumerate(batch["calls"]):
            val = int(str(c.get("value", "0")), 0) if c.get("value") else 0
            ok, rcpt, info = sim.send(c["to"], c["data"], from_=frm, value=val, url=url)
            exec_log.append({"i": i, "to": c["to"], "ok": ok,
                             "detail": (info if not ok else f"gas={int(rcpt.get('gasUsed','0x0'),16)}")})
            if not ok:
                # the app's own batch reverted on the fork - the encoder built a call that cannot execute
                break
        after = read_watches(watches, url=url)
    finally:
        sim.revert(snap, url=url)

    def _norm(v):
        return v.lower() if isinstance(v, str) else v

    rows, findings = [], []
    for w in watches:
        lbl = w["label"]
        b, a = before.get(lbl), after.get(lbl)
        row = {"watch": lbl, "before": b, "after": a}
        if "expect" in w:
            exp = _decode(w["expect"], w.get("decode", "raw")) if (
                isinstance(w["expect"], str) and w["expect"].startswith("0x")) else w["expect"]
            row["expect"] = exp
            row["mismatch"] = _norm(a) != _norm(exp)
            if row["mismatch"]:
                findings.append(f'{lbl}: executed -> {a}  but UI DISPLAYED -> {exp}  (executed != displayed)')
        elif b != a:
            row["changed"] = True
        rows.append(row)
    return {"before": before, "after": after, "exec": exec_log,
            "watch_rows": rows, "findings": findings}


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__); sys.exit(0 if len(sys.argv) > 1 else 1)
    rpc = None
    if "--rpc" in sys.argv:
        rpc = sys.argv[sys.argv.index("--rpc") + 1]
    batch = json.load(open(sys.argv[1]))
    rep = replay(batch, url=rpc)

    print("== executed batch ==")
    for e in rep["exec"]:
        print(f"  [{e['i']}] {e['to']}  {'OK ' + e['detail'] if e['ok'] else 'REVERT ' + e['detail']}")
    print("\n== state watches (before -> after) ==")
    for r in rep["watch_rows"]:
        tail = ""
        if "expect" in r:
            tail = f"   expect={r['expect']}   {'*** MISMATCH ***' if r.get('mismatch') else 'ok'}"
        print(f"  {r['watch']:24s} {r['before']} -> {r['after']}{tail}")
    print("\n== findings ==")
    if rep["findings"]:
        for f in rep["findings"]:
            print(f"  !! {f}")
    else:
        print("  (no displayed-vs-executed mismatch on the watched state - widen the watches or the batch is faithful)")


if __name__ == "__main__":
    main()
