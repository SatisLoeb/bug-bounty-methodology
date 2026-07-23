"""
caller_reachability.py — the THIRD verdict axis for solfork gate-piercing.

Why this exists
---------------
solfork's forwarder-at-AUTH test (redeploy fwd.so at the authorized caller's
address, feed each introspection angle) proves whether an authz gate
authenticates an UNFORGEABLE context or merely a caller-id / discriminator.
But the forwarder is a PASSTHROUGH: it emits any discriminator + any params you
hand it, INCLUDING params the real authorized caller would never emit. So
"gate passes on the fork" proves the gate is satisfiable IN PRINCIPLE — it does
NOT prove an attacker can satisfy it on MAINNET, because on mainnet the attacker
does not control the code at AUTH's address: the REAL caller runs there, with
its own param logic. C1 fixed the false-HOLDS; this closes the symmetric
false-BYPASSABLE the forwarder opened.

The probe drives the REAL caller (state-forked from mainnet at its real address)
top-level, over a sweep of ONE attacker-controllable input, and measures whether
that input PROPAGATES through the real caller into the params the TARGET receives
on the CPI. Same single-input-mutation discipline as the Loopscale state-fork
null: vary one attacker input, hold the rest, read the program's own logged value.

Because the top-level IS the real caller (cloned, not spoofed), top-level
program-id == AUTH and top-level data == the caller's real disc are GENUINELY
true — a pass here is a real mainnet gate-pass (modulo sim faithfulness), not a
fork artifact.

Verdict
-------
  GATE_UNREACHABLE      no driven call reaches the target log at all
                        -> gate not satisfiable via this caller path (wrong caller
                        ix, or the forwarded-account list is wrong) -> go reverse
                        the predicate / fix the account order.
  GATE_SATISFIABLE_THIN gate passes but only one driven call survived the sweep
                        -> satisfiable via the real caller, sweep too thin to
                        judge propagation -> widen attacker_inputs.
  PARAMS_CONSTRAINED    gate passes, target logs a value, but it is INVARIANT to
                        (or moves AGAINST) the attacker input -> the real caller
                        is the guard the forwarder hid -> false-bypassable for
                        theft; if pinned at a bound, that clamp is the finding
                        boundary — quantify it.
  CALLER_REACHABLE      gate passes AND the target's logged param tracks the
                        attacker input in the attacker-favorable direction ->
                        control propagates through the real caller -> gate is
                        genuinely bypassable on mainnet -> NOW apply C2 (what
                        SEPARATELY gates the money-move?) before writing "theft".

FORK-AFFORDANCE FILTER — read every reachability verdict against the MAINNET
attacker's capability, never the fork's affordances. The fork lends you powers a
mainnet attacker lacks; each is a false-CALLER_REACHABLE vector:
  - deploy-at-AUTH  : a forwarder at AUTH invoke_signeds AUTH's PDAs and passes any
                      caller-id gate -> that is why the step-7 forwarder pass is
                      necessary-not-sufficient.
  - sigVerify:false : sim skips every Ed25519 sig the driven route needs -> a hit
                      that leaned on a skipped maker/relayer sig is fork-only. Pass
                      those signers to `required_signers=` and the verdict flags it.
  - setup-state     : cloned/hand-built accounts may encode a state no honest
                      mainnet path reaches -> a hit that depends on it is fork-only.
A HIT is cheap (one propagating axis suffices); a NULL is expensive (a 1-D
sweep-null is NOT a manifold-empty proof) -- same asymmetry as C1's "holds".

Prereq: state-fork MODE b (scripts/statefork.py)
------------------------------------------------
Clone the REAL caller program + the target program + every config/oracle/state
account BOTH need, at their mainnet addresses (do NOT --bpf-program a forwarder
here — that's the OTHER test):

  solana-test-validator --reset \
    --clone <CALLER_PID> --clone <TARGET_PID> \
    --clone <config_pdas...> --clone <oracles...> --clone <live_state_acct> \
    --url $SOLFORK_RPC --ledger <SHORT_PATH> --rpc-port 8899
  # statefork.refresh_pyth(oracle)   cloned feeds are stale vs the fork clock
  # statefork.empty_stub(pda)        for an event_authority uninit on mainnet
  # sim.ensure_payer(payer)          before driving

Hooks into your existing scripts:
  from sim import simulate      # solfork's sim.py returns (logs, err)  — a TUPLE
"""

from __future__ import annotations
import re
from dataclasses import dataclass, field
from typing import Callable

from sim import simulate  # your sim.py forces base64 + sigVerify:false +
                          # replaceRecentBlockhash and guards the false err:None

AccountMeta = tuple[str, bool, bool]   # (pubkey, is_signer, is_writable)
DEFAULT_CU = 1_400_000                  # intent-settlement + oracle math blows past 200k


@dataclass
class ProbePoint:
    attacker_input: float
    target_value: float | None          # None => driven call errored / target logged nothing
    err: str | None = None
    logs: list[str] = field(default_factory=list)


@dataclass
class Verdict:
    label: str
    points: list[ProbePoint]
    note: str

    def __str__(self) -> str:
        series = ", ".join(
            f"{p.attacker_input:g}->{'ERR' if p.target_value is None else format(p.target_value, 'g')}"
            for p in self.points
        )
        return f"[{self.label}] {self.note}\n  series: {series}"


def _run(caller_pid: str, data: bytes, metas: list[AccountMeta], cu: int):
    """
    Adapter to sim.simulate's ACTUAL return shape. solfork's sim.py returns a
    TUPLE (logs, err) — NOT a dict — and already guards the RPC 'error' branch
    (it returns (["RPC-ERROR: ..."], <error>) on a malformed request). So just
    unpack the tuple; do NOT .get() it (that AttributeErrors on the first call).
    """
    logs, err = simulate(caller_pid, data, metas, cu=cu)
    return err, logs


def extract_logged_value(logs: list[str], field_regex: str) -> float | None:
    """
    Pull the numeric the TARGET logs receiving on the CPI (e.g. the fill amount
    the settlement/pool program actually got). That line is emitted by the INNER
    (CPI'd) program, AFTER the caller's own logs, so scan every line and let the
    LAST match win. field_regex must capture ONE numeric group, e.g.
        r'out_amount[=:\\s]+(\\d+)'
        r'Fill executed:.*amount[=:\\s]+(\\d+)'

    If the closed target logs nothing usable, swap this for a STATE-delta read:
    getAccountInfo the target's state account before/after (sim can return post-
    sim account data) and diff the field the CPI writes — same propagation signal.
    """
    pat = re.compile(field_regex)
    val = None
    for line in logs:
        m = pat.search(line)
        if m:
            val = float(m.group(1))
    return val


def probe_caller_reachability(
    caller_pid: str,
    caller_ix_builder: Callable[[float], tuple[bytes, list[AccountMeta]]],
    attacker_inputs: list[float],
    target_log_regex: str,
    favorable: str = "increasing",   # direction of the TARGET's received value that BENEFITS the attacker
    rel_tol: float = 1e-9,           # |span| <= rel_tol*scale is treated as "no propagation"
    cu: int = DEFAULT_CU,
    required_signers: list[str] | None = None,   # signers the driven route needs that sim SKIPS (sigVerify:false)
) -> Verdict:
    """
    Drive the REAL caller top-level over a sweep of ONE attacker-controlled input,
    reading the value the TARGET logs receiving on the CPI.

    caller_ix_builder(x) -> (data, metas) builds the REAL caller's
    attacker-reachable instruction for attacker input x.

    #1 GOTCHA: `metas` must list EVERY account the call touches INCLUDING the
    target program id and every account the caller forwards to the target via CPI
    — a Solana CPI can only use accounts already present in the top-level tx. A
    missing forwarded account -> AccountNotFound BEFORE the gate is reached, which
    reads exactly like GATE_UNREACHABLE. Build this list from the CALLER's
    recovered interface (its CPI account order), NOT the target's IDL.
    """
    assert favorable in ("increasing", "decreasing")
    assert len(attacker_inputs) >= 2, "sweep needs >=2 values to judge propagation"

    points: list[ProbePoint] = []
    for x in attacker_inputs:
        data, metas = caller_ix_builder(x)
        err, logs = _run(caller_pid, data, metas, cu)
        val = None if err else extract_logged_value(logs, target_log_regex)
        points.append(ProbePoint(x, val, str(err) if err else None, logs))

    got = [p for p in points if p.target_value is not None]

    if not got:
        errs = sorted({p.err for p in points if p.err})
        return Verdict("GATE_UNREACHABLE", points,
            "no driven call reached the target log. Either the gate is not satisfiable via this "
            "caller path, or the caller ix / forwarded-account list is wrong (check the CPI account "
            f"order — see #1 GOTCHA). Distinct errors: {errs}")

    if len(got) == 1:
        return Verdict("GATE_SATISFIABLE_THIN", points,
            "the gate PASSES with the real caller (one driven call reached the target), but only one "
            "point survived the sweep — too thin to judge param propagation. Widen attacker_inputs.")

    vals = [p.target_value for p in got]
    span = max(vals) - min(vals)
    scale = max(1.0, max(abs(v) for v in vals))

    if span <= rel_tol * scale:
        return Verdict("PARAMS_CONSTRAINED", points,
            "gate PASSES with the real caller, but the target's received value is INVARIANT to the "
            "attacker input — the real caller sanitizes/fixes the param the forwarder let you spoof. "
            "False-bypassable for theft. (If the value is pinned at a bound rather than truly fixed, "
            "that clamp is the caller's guard — quantify it; it is the finding boundary.) NOTE: this null "
            "is only over THIS single-input slice — NOT proof the reachability manifold is empty. Before you "
            "RE-SOURCE, reverse from the caller code that NO input reaches the favorable branch, or widen the "
            "sweep (multi-input combo / a different caller route). A 1-D null that walks you off a real bypass "
            "is v1-fd3n one level up.")

    # monotone-favorable propagation, dependency-free: sign of cov(attacker_input, received_value)
    xs, ys = [p.attacker_input for p in got], vals
    xbar, ybar = sum(xs) / len(xs), sum(ys) / len(ys)
    cov = sum((a - xbar) * (b - ybar) for a, b in zip(xs, ys))
    sign = 1.0 if favorable == "increasing" else -1.0

    if cov * sign > 0:
        note = ("gate PASSES and the target's received value tracks the attacker input in the "
                "attacker-favorable direction — control propagates through the REAL caller to the CPI. "
                "The gate is genuinely bypassable on mainnet. NOW apply C2: what SEPARATELY gates the "
                "money-move (token-owner constraint, per-tx signature, nonce)? 'gate bypassable' != theft.")
        if required_signers:
            note += (" # sigVerify:false SKIPPED these signatures the driven route requires: "
                     f"{required_signers}. This CALLER_REACHABLE is a SIM ARTIFACT unless the mainnet "
                     "attacker can PRODUCE each — a maker/relayer sig you can't forge is fork-only "
                     "reachability. Confirm per-signer before writing 'reachable'.")
        return Verdict("CALLER_REACHABLE", points, note)

    return Verdict("PARAMS_CONSTRAINED", points,
        "gate PASSES and the value moves, but AGAINST the attacker (the caller transforms the input "
        "adversely — slippage / clamp / fee). Not favorably reachable; quantify the transform bound.")


if __name__ == "__main__":
    # ---- WORKED SHAPE: intent-settlement / relayer-fill target (an SVM spoke pool,
    #      a solver-settlement program). Fill in from your recovered interfaces. ----
    #
    #   TARGET = settlement/pool program whose "must be filled by the authorized
    #            solver/relayer" gate you already showed satisfiable-on-fork with fwd.so
    #   CALLER = that authorized solver/relayer program, CLONED from mainnet (real code)
    #   attacker input = the ONE quantity you-as-user/maker steer through the caller
    #            (quote out_amount, a limit price, a fill size)
    #   target_log_regex = the value the TARGET logs receiving on the CPI
    #
    import struct, hashlib

    CALLER_PID = "REPLACE_authorized_solver_or_relayer_pid"
    TARGET_PID = "REPLACE_settlement_or_pool_pid"

    def disc(name: str) -> bytes:                       # anchor global ix discriminator
        return hashlib.sha256(f"global:{name}".encode()).digest()[:8]

    # accounts the CALLER's fill ix touches, IN ITS CPI ORDER, incl. TARGET_PID +
    # every account it forwards to the target. From the caller's recovered interface.
    CALLER_FILL_ACCOUNTS: list[AccountMeta] = [
        # ("<payer>",            True,  True),
        # ("<user_or_maker>",    True,  False),
        # (TARGET_PID,           False, False),
        # ("<target_state_pda>", False, True),
        # ("<oracle>",           False, False),
        # ...
    ]

    def build_caller_fill(out_amount: float) -> tuple[bytes, list[AccountMeta]]:
        # borsh: 8-byte disc + attacker-steered arg(s). Adapt layout to the caller's ix.
        data = disc("fill") + struct.pack("<Q", int(out_amount))
        return data, CALLER_FILL_ACCOUNTS

    sweep = [1_000_000, 2_000_000, 5_000_000, 10_000_000, 50_000_000]   # attacker asks for more out
    # required_signers: the maker/relayer sigs the driven route needs but sim skips (sigVerify:false).
    # On Aori: the MAKER quote signature. On Across: the relayer authorization. List them so a HIT flags.
    verdict = probe_caller_reachability(
        caller_pid=CALLER_PID,
        caller_ix_builder=build_caller_fill,
        attacker_inputs=sweep,
        target_log_regex=r"(?:out_amount|amount_out|filled)[=:\s]+(\d+)",
        favorable="increasing",   # attacker benefits if the target credits MORE out than it should
        required_signers=["MAKER_or_RELAYER_pubkey_the_route_needs"],
    )
    print(verdict)
