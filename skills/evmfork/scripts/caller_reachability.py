#!/usr/bin/env python3
"""
caller_reachability.py - the THIRD verdict axis for evmfork gate-piercing (Correction 3).

Why this exists
---------------
evmfork's step-7 impersonation test (`anvil_impersonateAccount(AUTH)` / `anvil_setCode` a forwarder at
AUTH, feed each angle) proves whether an authz gate authenticates an UNFORGEABLE context or merely a
msg.sender / calldata prefix. But impersonation is a PASSTHROUGH: from AUTH you send ANY calldata,
INCLUDING params the real authorized contract at AUTH would never emit. So "gate passes on the fork" proves
the gate is satisfiable IN PRINCIPLE - it does NOT prove an attacker can satisfy it on MAINNET, where the
attacker does not control AUTH's code: the REAL caller runs there, with its own param logic. C1 fixed the
false-HOLDS; this closes the symmetric false-BYPASSABLE impersonation opened.

The probe drives the REAL caller (already present in a `--fork-url` state-fork, at its real address - do
NOT impersonate it and do NOT setCode over it; that is step 7) from an attacker EOA, over a sweep of ONE
attacker-controllable input, and measures whether that input PROPAGATES through the real caller into the
value the TARGET receives / the state it moves. Because the top-level tx hits the real caller's real code,
a pass here is a real mainnet gate-pass (modulo sim faithfulness), not a fork artifact.

Verdict
-------
  GATE_UNREACHABLE      no driven call produced a target value at all (every call reverted, or read_value
                        saw nothing) -> gate not satisfiable via this caller path (wrong caller fn, or the
                        forwarded account/arg list is wrong) -> reverse the predicate / fix the call.
  GATE_SATISFIABLE_THIN gate passed but only one swept point produced a value -> satisfiable via the real
                        caller, sweep too thin to judge propagation -> widen `inputs`.
  PARAMS_CONSTRAINED    gate passes, target value is INVARIANT to (or moves AGAINST / clamps at a bound
                        under) the attacker input -> the real caller is the guard impersonation hid ->
                        false-bypassable for theft; a clamp at a bound IS the finding boundary - quantify it.
  CALLER_REACHABLE      gate passes AND the target value tracks the attacker input in the attacker-favorable
                        direction -> control propagates through the real caller -> genuinely bypassable on
                        mainnet -> NOW apply C2 (what SEPARATELY gates the money-move?) before "theft".

FORK-AFFORDANCE FILTER - read every reachability verdict against the MAINNET attacker's capability, never
the fork's affordances. anvil lends powers a mainnet attacker lacks; each is a false-CALLER_REACHABLE vector:
  - impersonation / setCode : if your `drive` sends FROM the caller's own address or plants code, that is
                              step 7, NOT this - drive from a fresh attacker EOA or the verdict is fork-only.
  - setStorageAt / setBalance: a hit that only works because you pre-poked a slot the real caller reads is
                              fork-only UNLESS a real writer sets it - find that writer.
  - stale fork block         : a hit leaning on a stale oracle round the real path would reject is fork-only.
A HIT is cheap (one propagating point suffices); a NULL is EXPENSIVE - a 1-D sweep-null is NOT a
manifold-empty proof (may need a multi-input combo or another caller entrypoint). To WALK on a null,
reverse from code that no input reaches the branch, never infer it from a single slice.

Prereq: state-fork mode (scripts/statefork.py)
----------------------------------------------
  anvil --fork-url $EVMFORK_RPC --fork-block-number <N> --port 8545   # real caller + target both live
Provide two closures over YOUR target:
  drive(x)      -> (ok: bool, detail: str)   sends the REAL CALLER's attacker-reachable fn with input x
                                             (sim.send from an attacker EOA). ok=False on a top-level revert.
  read_value()  -> int | None                reads the value the TARGET received / the state it moved,
                                             AFTER drive - from an event, a post-state slot diff, or
                                             `trace_forwarded_calldata()` (the most precise: pull the exact
                                             arg the caller forwarded to the target via debug_traceCall).
The probe snapshots before each drive and reverts after, so the fork is clean between points.

Hooks: `from sim import ...` (JSON-RPC + cheatcodes) ; `import statefork` (snapshot/revert live in sim).
"""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field
from typing import Callable, Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402


@dataclass
class ProbePoint:
    attacker_input: float
    target_value: Optional[float]      # None => driven call reverted / target moved nothing
    detail: str = ""
    logs: list = field(default_factory=list)


@dataclass
class Verdict:
    label: str
    points: list
    note: str

    def __str__(self) -> str:
        series = ", ".join(
            f"{p.attacker_input:g}->{'X' if p.target_value is None else format(p.target_value, 'g')}"
            for p in self.points
        )
        return f"[{self.label}] {self.note}\n  series: {series}"


def _trend(points):
    """Direction target_value moves as attacker_input rises, over the valid points.
    Returns 'invariant' | 'with' (up-up) | 'against' (up-down) | 'nonmonotone'."""
    valid = [(p.attacker_input, p.target_value) for p in points if p.target_value is not None]
    if len(valid) < 2:
        return "thin"
    valid.sort(key=lambda t: t[0])
    vals = [v for _, v in valid]
    if all(abs(v - vals[0]) < 1e-30 for v in vals):
        return "invariant"
    agree = disagree = 0
    for (x0, v0), (x1, v1) in zip(valid, valid[1:]):
        dx, dv = x1 - x0, v1 - v0
        if dx == 0 or dv == 0:
            continue
        if (dx > 0) == (dv > 0):
            agree += 1
        else:
            disagree += 1
    if agree and not disagree:
        return "with"
    if disagree and not agree:
        return "against"
    return "nonmonotone"


def probe(drive: Callable[[float], tuple], read_value: Callable[[], Optional[float]],
          inputs, favorable: str = "with", url=None) -> Verdict:
    """
    Sweep ONE attacker input through the REAL caller and classify propagation into the target.
    favorable: 'with' => attacker wins when the target value RISES with the input (e.g. more tokens out);
               'against' => attacker wins when it FALLS with the input. Set it to what "in your favor" means.
    """
    points = []
    for x in inputs:
        snap = sim.snapshot(url=url)
        try:
            ok, detail = drive(x)
            if not ok:
                points.append(ProbePoint(x, None, detail))
                continue
            try:
                v = read_value()
            except Exception as e:               # read failure is not a gate pass
                v = None
                detail = f"read_value error: {e}"
            points.append(ProbePoint(x, (None if v is None else float(v)), detail))
        finally:
            sim.revert(snap, url=url)

    n_valid = sum(1 for p in points if p.target_value is not None)
    if n_valid == 0:
        return Verdict("GATE_UNREACHABLE", points,
                       "no driven call produced a target value - wrong caller fn / arg list, or the gate "
                       "genuinely rejects this path. Reverse the predicate before walking on the null.")
    if n_valid == 1:
        return Verdict("GATE_SATISFIABLE_THIN", points,
                       "only one point produced a value - satisfiable via the real caller, sweep too thin. "
                       "Widen inputs before judging propagation.")
    t = _trend(points)
    if t == "invariant":
        return Verdict("PARAMS_CONSTRAINED", points,
                       "target value is INVARIANT to the attacker input - the real caller clamps/ignores it "
                       "(the guard impersonation hid). False-bypassable for theft.")
    if t == favorable:
        return Verdict("CALLER_REACHABLE", points,
                       f"target value tracks the input in the favorable ('{favorable}') direction -> control "
                       "propagates through the real caller -> genuinely bypassable. NOW apply C2 (what "
                       "SEPARATELY gates the money-move?).")
    if t in ("with", "against"):
        return Verdict("PARAMS_CONSTRAINED", points,
                       f"target value moves '{t}', OPPOSITE to attacker-favorable ('{favorable}') - the real "
                       "caller pushes it against you (a clamp at a bound IS the finding boundary - quantify it).")
    return Verdict("PARAMS_CONSTRAINED", points,
                   "non-monotone response - not a clean propagation; widen the sweep or add a second axis, "
                   "and reverse the caller's param logic before any verdict (NULL is expensive).")


def trace_forwarded_calldata(caller, data, target, from_=None, block="latest", url=None):
    """
    The PRECISE propagation reader: run the caller call under a call-tracer and pull the calldata the caller
    forwarded to `target` in its internal CALL. Slice the arg you care about from the returned hex to feed
    read_value. (The EVM twin of "read the param the target logs receiving on the CPI".)
    Returns the innermost input hex to `target`, or None if the caller never called target on this path.
    """
    trace = sim.trace_call(caller, data, from_=from_, block=block,
                           tracer={"tracer": "callTracer"} if False else "callTracer", url=url)
    tl = target.lower()
    found = [None]

    def walk(node):
        if not isinstance(node, dict):
            return
        if str(node.get("to", "")).lower() == tl and node.get("input"):
            found[0] = node["input"]           # keep the LAST (deepest) call to target
        for c in node.get("calls", []) or []:
            walk(c)

    walk(trace)
    return found[0]


if __name__ == "__main__":
    print(__doc__)
