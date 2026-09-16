#!/usr/bin/env python3
"""
sim.py - reusable driver for building + executing calls against a local anvil fork (evmfork).

The EVM twin of solfork/scripts/sim.py. Talks RAW JSON-RPC to anvil (no web3 dependency), decodes the
target's OWN revert reason (Error(string) / Panic(uint256) / a custom-error selector via your step-2 map)
- the analog of solfork reading the program's logs - and GUARDS the silent-failure gotchas that otherwise
cost a session.

Import it from your probe script:
    import sim
    ok, ret = sim.call(TARGET, calldata_hex, from_=ATTACKER, overrides=None)   # eth_call, decoded revert
    ok, rcpt, logs = sim.send(TARGET, calldata_hex, from_=OWNER)               # tx + receipt + events
    sim.impersonate(AUTH); sim.set_storage(TARGET, slot, value)               # fork cheatcodes

Encapsulates the gotchas:
 - a reverting eth_call comes back as a JSON-RPC {"error": ...} with the revert bytes in error["data"],
   NOT as a false-success 0x return -> naive `resp["result"]` KeyErrors or reads a false ok. call() decodes it.
 - eth_sendTransaction from a non-owned account needs anvil_impersonateAccount FIRST, and the sender needs
   gas -> send() impersonates + set_balance()es the sender unless told not to.
 - a tx can MINE SUCCESSFULLY yet have reverted (receipt.status == 0x0); send() re-runs it as eth_call at
   the same state to recover the revert reason instead of reporting a false ok.
 - state overrides go in the 4th eth_call param ({addr:{balance,code,stateDiff,state,nonce}}); call() wires it.

Assumes anvil is running (default http://127.0.0.1:8545). Set EVMFORK_LOCAL to override.
"""
import json
import os
import subprocess
import time
import urllib.request

LOCAL = os.environ.get("EVMFORK_LOCAL", "http://127.0.0.1:8545")

# Known selectors for the two builtin revert shapes (keccak256 of the signatures, first 4 bytes).
_ERROR_STRING = "08c379a0"   # Error(string)
_PANIC        = "4e487b71"   # Panic(uint256)


# --------------------------------------------------------------------------------------------------
# transport
# --------------------------------------------------------------------------------------------------
def rpc(method, params, url=None):
    """One JSON-RPC round-trip. Returns the FULL response dict (keeps 'error' so callers can inspect it)."""
    url = url or LOCAL
    req = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    r = urllib.request.urlopen(
        urllib.request.Request(url, json.dumps(req).encode(), {"Content-Type": "application/json"}),
        timeout=60,
    )
    return json.loads(r.read())


def _hx(v):
    """int -> '0x..' ; already-hex str passes through ; None -> None."""
    if v is None:
        return None
    if isinstance(v, int):
        return hex(v)
    s = str(v)
    return s if s.startswith("0x") else "0x" + s


def _need(resp, what="rpc"):
    if "error" in resp:
        raise RuntimeError(f"{what} failed: {resp['error']}")
    return resp["result"]


# --------------------------------------------------------------------------------------------------
# keccak / selector convenience (shells to `cast` - Foundry is present when anvil is)
# --------------------------------------------------------------------------------------------------
def keccak(data):
    """keccak256 of bytes or a hex/utf8 string, as '0x..'. Uses an installed lib if present, else `cast`."""
    if isinstance(data, str) and not data.startswith("0x"):
        raw = data.encode()
    elif isinstance(data, str):
        raw = bytes.fromhex(data[2:])
    else:
        raw = bytes(data)
    for mod, fn in (("eth_hash.auto", "keccak"), ("Crypto.Hash.keccak", None)):
        try:
            if mod == "eth_hash.auto":
                from eth_hash.auto import keccak as _k  # type: ignore
                return "0x" + _k(raw).hex()
            from Crypto.Hash import keccak as _kmod       # type: ignore
            h = _kmod.new(digest_bits=256); h.update(raw); return "0x" + h.hexdigest()
        except Exception:
            pass
    # fallback: cast keccak (accepts a 0x-hex string)
    out = subprocess.run(["cast", "keccak", "0x" + raw.hex()], capture_output=True, text=True)
    return out.stdout.strip()


def selector(signature):
    """'transfer(address,uint256)' -> '0x<4 bytes>'. For building a step-2 custom-error map, or calldata."""
    return keccak(signature)[:10]


# --------------------------------------------------------------------------------------------------
# anvil cheatcodes
# --------------------------------------------------------------------------------------------------
def set_balance(addr, wei=10**24, url=None):
    _need(rpc("anvil_setBalance", [addr, _hx(wei)], url), "anvil_setBalance")


def set_storage(addr, slot, value, url=None):
    """Poke ONE 32-byte storage slot (the mutate_le twin). slot/value as int or 0x-hex (32-byte padded)."""
    def pad32(x):
        h = _hx(x)[2:]
        return "0x" + h.rjust(64, "0")
    _need(rpc("anvil_setStorageAt", [addr, pad32(slot), pad32(value)], url), "anvil_setStorageAt")


def get_storage(addr, slot, block="latest", url=None):
    return _need(rpc("eth_getStorageAt", [addr, _hx(slot), block], url), "eth_getStorageAt")


def set_code(addr, code_hex, url=None):
    _need(rpc("anvil_setCode", [addr, _hx(code_hex)], url), "anvil_setCode")


def impersonate(addr, fund=True, url=None):
    _need(rpc("anvil_impersonateAccount", [addr], url), "anvil_impersonateAccount")
    if fund:
        set_balance(addr, url=url)


def stop_impersonate(addr, url=None):
    _need(rpc("anvil_stopImpersonatingAccount", [addr], url), "anvil_stopImpersonatingAccount")


def set_next_timestamp(ts, url=None):
    _need(rpc("anvil_setNextBlockTimestamp", [_hx(ts)], url), "anvil_setNextBlockTimestamp")


def mine(url=None):
    _need(rpc("anvil_mine", [], url), "anvil_mine")


def snapshot(url=None):
    return _need(rpc("evm_snapshot", [], url), "evm_snapshot")


def revert(snap_id, url=None):
    return _need(rpc("evm_revert", [snap_id], url), "evm_revert")


# --------------------------------------------------------------------------------------------------
# revert decoding - the "read the target's own words" core
# --------------------------------------------------------------------------------------------------
def decode_revert(data, errmap=None):
    """
    data: revert-return hex ('0x..' or ''). errmap: {selector('0xabcdef12'): 'MyError(uint256)'} from step 2.
    Returns a human string. Never raises - a malformed body still yields the raw selector.
    """
    if not data or data in ("0x", "0x0"):
        return "revert (no data / require without reason)"
    body = data[2:] if data.startswith("0x") else data
    if len(body) < 8:
        return f"revert (short data 0x{body})"
    sel = body[:8].lower()
    rest = body[8:]
    try:
        raw = bytes.fromhex(rest)
    except ValueError:
        raw = b""
    if sel == _ERROR_STRING:
        try:
            off = int.from_bytes(raw[0:32], "big")
            ln = int.from_bytes(raw[off:off + 32], "big")
            s = raw[off + 32:off + 32 + ln].decode("utf-8", "replace")
            return f'Error("{s}")'
        except Exception:
            return f"Error(string) [malformed] 0x{rest}"
    if sel == _PANIC:
        try:
            code = int.from_bytes(raw[0:32], "big")
            meanings = {0x01: "assert", 0x11: "over/underflow", 0x12: "div/mod by zero",
                        0x21: "bad enum", 0x22: "bad storage bytes", 0x31: "pop empty array",
                        0x32: "array OOB", 0x41: "alloc too much", 0x51: "bad internal fn"}
            return f"Panic(0x{code:02x}: {meanings.get(code, 'unknown')})"
        except Exception:
            return f"Panic [malformed] 0x{rest}"
    name = (errmap or {}).get("0x" + sel) or (errmap or {}).get(sel)
    return f"{name or 'CustomError'} [0x{sel}]" + (f" args=0x{rest}" if rest else "")


def _revert_from_error(err, errmap):
    """anvil puts the revert bytes in error['data'] (sometimes nested / prefixed). Pull + decode it."""
    d = err.get("data") if isinstance(err, dict) else None
    if isinstance(d, dict):
        d = d.get("data") or d.get("result")
    if isinstance(d, str) and d.startswith("0x"):
        return decode_revert(d, errmap)
    msg = err.get("message", "") if isinstance(err, dict) else str(err)
    # geth/anvil sometimes inline "execution reverted: <reason>"
    return msg or "execution reverted (no data)"


# --------------------------------------------------------------------------------------------------
# call / send
# --------------------------------------------------------------------------------------------------
def call(to, data, from_=None, value=0, block="latest", overrides=None, errmap=None, url=None):
    """
    eth_call. Returns (ok: bool, result_hex_or_revert_string).
    overrides: {addr: {"balance"|"code"|"nonce": ..., "stateDiff"|"state": {slot: value}}} - wired as the
    4th eth_call param so you can pierce a gate WITHOUT mutating fork state (subtract it per the affordance filter).
    """
    tx = {"to": to, "data": _hx(data)}
    if from_:
        tx["from"] = from_
    if value:
        tx["value"] = _hx(value)
    params = [tx, block]
    if overrides:
        norm = {}
        for a, o in overrides.items():
            oo = {}
            for k, v in o.items():
                if k in ("stateDiff", "state"):
                    oo[k] = {(_hx(s)): (_hx(val)) for s, val in v.items()}
                else:
                    oo[k] = _hx(v) if k in ("balance", "nonce") else v
            norm[a] = oo
        params.append(norm)
    resp = rpc("eth_call", params, url)
    if "error" in resp:
        return False, _revert_from_error(resp["error"], errmap)
    return True, resp.get("result", "0x")


def wait_receipt(txhash, timeout=30, url=None):
    end = time.time() + timeout
    while time.time() < end:
        resp = rpc("eth_getTransactionReceipt", [txhash], url)
        r = resp.get("result")
        if r:
            return r
        time.sleep(0.2)
    raise TimeoutError(f"no receipt for {txhash} in {timeout}s")


def send(to, data, from_, value=0, gas=None, auto_impersonate=True, errmap=None, url=None):
    """
    eth_sendTransaction + receipt. Returns (ok: bool, receipt_or_None, logs_or_revert_string).
    - impersonates + funds `from_` unless auto_impersonate=False (a fork affordance - subtract it in the verdict).
    - if the tx mines but REVERTS (status 0x0), re-runs it as eth_call to recover the reason (no false ok).
    """
    if auto_impersonate:
        impersonate(from_, fund=True, url=url)
    tx = {"from": from_, "to": to, "data": _hx(data)}
    if value:
        tx["value"] = _hx(value)
    if gas:
        tx["gas"] = _hx(gas)
    resp = rpc("eth_sendTransaction", [tx], url)
    if "error" in resp:
        return False, None, _revert_from_error(resp["error"], errmap)
    rcpt = wait_receipt(resp["result"], url=url)
    if int(rcpt.get("status", "0x0"), 16) != 1:
        ok, reason = call(to, data, from_=from_, value=value, errmap=errmap, url=url)
        return False, rcpt, (reason if not ok else "reverted (status 0x0, no reason recovered)")
    return True, rcpt, rcpt.get("logs", [])


def trace_call(to, data, from_=None, block="latest", tracer=None, url=None):
    """debug_traceCall - read SLOADs / internal steps to reconstruct math when there is no event to read."""
    tx = {"to": to, "data": _hx(data)}
    if from_:
        tx["from"] = from_
    cfg = {"tracer": tracer} if tracer else {}
    return _need(rpc("debug_traceCall", [tx, block, cfg], url), "debug_traceCall")


if __name__ == "__main__":
    print(__doc__)
