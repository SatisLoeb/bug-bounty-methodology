#!/usr/bin/env python3
"""
recover-abi.py <ADDR> [chainId] [rpc]

The EVM twin of solfork/scripts/recover-idl.py. Two paths, in order:
 (A) VERIFIED SOURCE - Sourcify (keyless) then Etherscan v2 (needs ETHERSCAN_API_KEY). Writes abi.json and
     a selectors.json map {selector -> "sig"} for functions + custom ERRORS + event topics. The error map
     is what lets sim.decode_revert NAME a custom-error revert instead of printing a bare selector.
 (B) FALLBACK when unverified (the closed case): extract 4-byte selectors from the deployed bytecode's
     dispatch (every `PUSH4 <sel>` candidate), then resolve each against 4byte.directory (keyless). A hit
     maps a selector -> a real signature. This recovers the DISPATCH, not the storage LAYOUT (find slot
     offsets EMPIRICALLY with statefork.find_balance_slot / a probe - see SKILL step 4).

chainId: 1 mainnet (default), 8453 Base, 42161 Arbitrum, 10 Optimism. rpc: for the bytecode fallback
(arg 3, else EVMFORK_RPC, else the local fork, else publicnode).

Requires: `cast` on PATH (for bytecode + keccak). stdlib only otherwise.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request

SIG_SPLIT = re.compile(r"[,()]")


def sh(*args):
    return subprocess.run(list(args), capture_output=True, text=True).stdout.strip()


def http(url, timeout=30):
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "evmfork"}), timeout=timeout)
        return r.read().decode()
    except Exception:
        return ""


def keccak_hex(text):
    return sh("cast", "keccak", text)          # keccak256 of a utf8 string -> 0x..


def selector_of(sig):
    return keccak_hex(sig)[:10]


def topic_of(sig):
    return keccak_hex(sig)


def canon(item):
    """Build the canonical signature 'name(type1,type2,...)' from an ABI fragment."""
    def typ(inp):
        if inp["type"].startswith("tuple"):
            inner = ",".join(typ(c) for c in inp.get("components", []))
            return f"({inner}){inp['type'][5:]}"
        return inp["type"]
    return f"{item['name']}({','.join(typ(i) for i in item.get('inputs', []))})"


def from_abi(abi):
    """selectors.json content from a full ABI: functions+errors by 4-byte selector, events by 32-byte topic."""
    fns, errs, evs = {}, {}, {}
    for it in abi:
        t = it.get("type")
        if t in ("function",) and it.get("name"):
            fns[selector_of(canon(it))] = canon(it)
        elif t == "error" and it.get("name"):
            errs[selector_of(canon(it))] = canon(it)
        elif t == "event" and it.get("name"):
            evs[topic_of(canon(it))] = canon(it)
    return {"functions": fns, "errors": errs, "events": evs}


def sourcify(addr, chain):
    for match in ("full_match", "partial_match"):
        body = http(f"https://repo.sourcify.dev/contracts/{match}/{chain}/{addr}/metadata.json")
        if body:
            try:
                return json.loads(body)["output"]["abi"], match
            except Exception:
                pass
    return None, None


def etherscan(addr, chain):
    key = os.environ.get("ETHERSCAN_API_KEY")
    if not key:
        return None
    body = http(f"https://api.etherscan.io/v2/api?chainid={chain}&module=contract&action=getabi"
                f"&address={addr}&apikey={key}")
    try:
        j = json.loads(body)
        if j.get("status") == "1":
            return json.loads(j["result"])
    except Exception:
        pass
    return None


def extract_selectors_from_bytecode(code_hex):
    """Every PUSH4 (0x63) immediate is a selector candidate in the dispatch table. Over-collects; 4byte filters."""
    b = bytes.fromhex(code_hex[2:] if code_hex.startswith("0x") else code_hex)
    out, i, n = set(), 0, len(b)
    while i < n:
        op = b[i]
        if op == 0x63 and i + 5 <= n:            # PUSH4
            out.add("0x" + b[i + 1:i + 5].hex())
            i += 5
            continue
        if 0x60 <= op <= 0x7f:                    # PUSH1..PUSH32 - skip the immediate
            i += 1 + (op - 0x5f)
            continue
        i += 1
    # drop degenerate values
    return sorted(s for s in out if s not in ("0x00000000", "0xffffffff"))


def resolve_4byte(sel):
    body = http(f"https://www.4byte.directory/api/v1/signatures/?hex_signature={sel}")
    try:
        res = json.loads(body).get("results", [])
        # 4byte returns newest first; prefer the OLDEST id (least likely to be a spoof collision)
        res.sort(key=lambda r: r.get("id", 0))
        return [r["text_signature"] for r in res]
    except Exception:
        return []


def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    addr = sh("cast", "to-check-sum-address", sys.argv[1]) or sys.argv[1]
    chain = sys.argv[2] if len(sys.argv) > 2 else "1"
    rpc = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("EVMFORK_RPC")
    if not rpc:
        rpc = "http://127.0.0.1:8545" if sh("cast", "block-number", "--rpc-url", "http://127.0.0.1:8545") else "https://ethereum.publicnode.com"

    print(f"# recover-abi {addr} chain={chain}")
    abi, src = sourcify(addr, chain)
    if not abi:
        abi = etherscan(addr, chain)
        src = "etherscan" if abi else None

    if abi:
        json.dump(abi, open("abi.json", "w"), indent=2)
        sels = from_abi(abi)
        json.dump(sels, open("selectors.json", "w"), indent=2)
        print(f"VERIFIED via {src}: abi.json ({len(abi)} items), selectors.json "
              f"({len(sels['functions'])} fns, {len(sels['errors'])} errors, {len(sels['events'])} events)")
        if sels["errors"]:
            print("  custom errors (feed as sim.decode_revert errmap):")
            for s, sig in list(sels["errors"].items())[:20]:
                print(f"    {s}  {sig}")
        return

    # (B) fallback: bytecode selectors + 4byte
    code = sh("cast", "code", addr, "--rpc-url", rpc)
    if not code or code == "0x":
        print("UNVERIFIED and no bytecode (EOA/self-destructed?) - nothing to recover."); return
    cands = extract_selectors_from_bytecode(code)
    print(f"UNVERIFIED: {len(cands)} PUSH4 selector candidates in bytecode; resolving via 4byte.directory")
    resolved = {}
    for sel in cands:
        sigs = resolve_4byte(sel)
        if sigs:
            resolved[sel] = sigs
    json.dump({"selectors_candidates": cands, "resolved": resolved}, open("selectors.json", "w"), indent=2)
    print(f"  resolved {len(resolved)}/{len(cands)} -> selectors.json")
    for sel, sigs in list(resolved.items())[:30]:
        print(f"    {sel}  {sigs[0]}" + (f"  (+{len(sigs)-1} collisions)" if len(sigs) > 1 else ""))
    print("  NOTE: a selector hit LOCATES a handler; a collision list is ambiguous - confirm by driving it "
          "on the fork (sim.call) and reading the revert/behavior, never by picking the first name.")


if __name__ == "__main__":
    main()
