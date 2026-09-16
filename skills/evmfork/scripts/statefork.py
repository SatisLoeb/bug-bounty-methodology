#!/usr/bin/env python3
"""
statefork.py - pull REAL mainnet state onto an anvil fork, then mutate ONE input to read a verdict.

The EVM twin of solfork/scripts/statefork.py. Reconstructing real MATH/valuation (an AMO exchange rate,
an ARM redemption price, a strategy's reported balance) needs REAL state - the deployed contracts reading
the deployed registry/oracle/pool storage - not hand-built dummies. On EVM this is EASIER than Solana:
`anvil --fork-url` lazy-loads every account on access, so there is no per-account clone. What this module
adds on top is the part that actually produces a verdict: locate a storage slot EMPIRICALLY, mutate ONE
input, hold the rest, and byte-compare the target's returned/logged value (the Loopscale move).

Functions (import or run pieces from your engagement script):
  launch_cmd(rpc, block=None, port=8545)      -> the exact `anvil --fork-url ...` command (pin the block!)
  pin_block(rpc)                              -> latest upstream block number (pin it for determinism)
  balance_of(token, holder)                   -> ERC20 balanceOf via the fork (int)
  mapping_slot(key, base_slot)                -> keccak slot of mapping[key] at base_slot
  allowance_slot(owner, spender, base_slot)   -> nested-mapping slot for allowance[owner][spender]
  find_balance_slot(token, holder)            -> brute the ERC20 balance mapping slot EMPIRICALLY
  set_erc20_balance(token, holder, amt, slot) -> poke a holder's balance (slot auto-found if omitted)
  mutate_and_read(read_fn, poke_fn)           -> snapshot -> poke ONE input -> read -> revert -> (before, after)

Depends on sim.py (same dir) for the JSON-RPC + cheatcodes + keccak.

Plumbing gotchas (the EVM analogs of solfork's Loopscale notes):
 - PIN --fork-block-number. An unpinned fork drifts head between calls and a re-run stops reproducing.
 - A forked oracle round is STALE vs any block.timestamp you advance (anvil warps time on mine) -> a hit
   leaning on a fresh feed is fork-only. Either DON'T advance time, or poke the feed's updatedAt slot to
   hold it consistent (find that slot with find_slot_by_probe against the aggregator).
 - PROXY storage lives at the PROXY address, not the impl - `set_storage(PROXY, ...)`, read via the proxy.
 - Packed slots: two <32B vars share one slot. setStorageAt overwrites the WHOLE slot - read it first,
   splice your field, write it back (read_slot + mask), or you clobber the neighbor.
 - Kill anvil by PORT, never `pkill -f anvil` (matches the shell's own argv -> self-kill).
 - A public --fork-url will 429 under load; use a real key via EVMFORK_RPC (helius/alchemy/infura).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim  # noqa: E402  (JSON-RPC + anvil cheatcodes + keccak, same dir)

UPSTREAM = os.environ.get("EVMFORK_RPC", "")   # the chain you fork FROM (needs a real key for bulk work)
SENTINEL = 0xDEADBEEFCAFEBABE0000000000000000000000000000000000000000C0FFEE01


# --------------------------------------------------------------------------------------------------
# launch / pin
# --------------------------------------------------------------------------------------------------
def launch_cmd(rpc=None, block=None, port=8545, extra=""):
    """The exact anvil command to run (PIN the block). Returns a string - spawn it yourself in a shell
    so you control its lifetime and can kill it by PORT."""
    rpc = rpc or UPSTREAM
    if not rpc:
        raise RuntimeError("no fork RPC: pass rpc= or set EVMFORK_RPC")
    b = f" --fork-block-number {block}" if block else ""
    # NOTE: auto-impersonate is OFF by default in anvil - do NOT pass --auto-impersonate (there is no
    # `=false` form; passing the bare flag would TURN IT ON, silently spoofing any `from`). Leave it out.
    return (f"anvil --fork-url {rpc}{b} --port {port}"
            f"{(' ' + extra) if extra else ''}").strip()


def pin_block(rpc=None):
    """Latest block on the UPSTREAM chain - pin this so the fork is deterministic across re-runs."""
    rpc = rpc or UPSTREAM
    if not rpc:
        raise RuntimeError("no upstream RPC: pass rpc= or set EVMFORK_RPC")
    return int(sim.rpc("eth_blockNumber", [], url=rpc)["result"], 16)


# --------------------------------------------------------------------------------------------------
# slot math (the EVM twin of solfork's field-offset determination)
# --------------------------------------------------------------------------------------------------
def _pad32(x):
    """address / int / hex-str -> 32 bytes (right-aligned, the EVM ABI word)."""
    if isinstance(x, int):
        v = x
    else:
        s = str(x)
        v = int(s, 16) if s.startswith("0x") else int(s)
    return v.to_bytes(32, "big")


def mapping_slot(key, base_slot):
    """Storage slot of mapping(...)[key] declared at base_slot: keccak256(pad32(key) . pad32(base_slot))."""
    return sim.keccak(_pad32(key) + _pad32(base_slot))


def allowance_slot(owner, spender, base_slot):
    """mapping(address=>mapping(address=>uint256)) at base_slot: nest owner then spender."""
    inner = mapping_slot(owner, base_slot)
    return mapping_slot(spender, int(inner, 16))


# --------------------------------------------------------------------------------------------------
# ERC20 read/write (the mutate_le twin for token balances)
# --------------------------------------------------------------------------------------------------
def balance_of(token, holder, block="latest", url=None):
    data = "0x70a08231" + _pad32(holder).hex()          # balanceOf(address)
    ok, ret = sim.call(token, data, block=block, url=url)
    if not ok:
        raise RuntimeError(f"balanceOf reverted on {token}: {ret}")
    return int(ret, 16) if ret and ret != "0x" else 0


def find_balance_slot(token, holder, max_slot=60, url=None):
    """
    EMPIRICALLY locate the ERC20 balance mapping's base slot (solidity, vyper, and packed layouts vary,
    and a recovered/assumed layout is often OFF - never hardcode it). Non-destructive: snapshots + reverts.
    Returns the base slot (int) or None. Uses a sentinel write and checks balanceOf reflects it.
    """
    snap = sim.snapshot(url=url)
    try:
        for base in range(max_slot):
            slot = mapping_slot(holder, base)
            sim.set_storage(token, slot, SENTINEL, url=url)
            try:
                if balance_of(token, holder, url=url) == SENTINEL:
                    return base
            except RuntimeError:
                pass
            sim.revert(snap, url=url)          # undo this probe
            snap = sim.snapshot(url=url)       # fresh snapshot for the next candidate
        return None
    finally:
        sim.revert(snap, url=url)


def set_erc20_balance(token, holder, amount, base_slot=None, url=None):
    """Poke a holder's ERC20 balance. Finds the slot empirically if base_slot is omitted."""
    if base_slot is None:
        base_slot = find_balance_slot(token, holder, url=url)
        if base_slot is None:
            raise RuntimeError(f"could not locate balance slot for {token} (packed? proxy? try max_slot=)")
    sim.set_storage(token, mapping_slot(holder, base_slot), amount, url=url)
    return base_slot


def read_slot(addr, slot, url=None):
    return int(sim.get_storage(addr, slot, url=url), 16)


# --------------------------------------------------------------------------------------------------
# the ONE-input-mutation harness (the Loopscale byte-compare move, executed)
# --------------------------------------------------------------------------------------------------
def mutate_and_read(read_fn, poke_fn, url=None):
    """
    Non-destructive one-input mutation:
      before = read_fn()          # e.g. the ARM redemption price / AMO exchange rate / strategy balance
      <snapshot>
      poke_fn()                   # mutate ONE input (a pool sqrtPrice, an oracle answer, a totalAssets slot)
      after = read_fn()
      <revert>                    # fork restored - run the next probe from clean state
    Returns (before, after). Unchanged => that input does NOT feed the value (NULL, per the affordance
    filter, a 1-D null is not a manifold-empty proof); changed => it does (quantify the delta).
    read_fn/poke_fn are your closures over sim.call/set_storage for THIS target.
    """
    before = read_fn()
    snap = sim.snapshot(url=url)
    try:
        poke_fn()
        after = read_fn()
    finally:
        sim.revert(snap, url=url)
    return before, after


def sweep(read_fn, poke_fn, inputs, url=None):
    """1-D sweep: for each x in inputs, poke x and read the target value. Returns [(x, value_or_None)].
    A HIT is cheap (one propagating point suffices); a NULL is EXPENSIVE - widen inputs / add a 2nd axis
    before walking on it (fork-affordance filter, HIT/NULL asymmetry)."""
    out = []
    for x in inputs:
        snap = sim.snapshot(url=url)
        try:
            poke_fn(x)
            try:
                out.append((x, read_fn()))
            except Exception as e:
                out.append((x, None))
                _ = e
        finally:
            sim.revert(snap, url=url)
    return out


if __name__ == "__main__":
    print(__doc__)
