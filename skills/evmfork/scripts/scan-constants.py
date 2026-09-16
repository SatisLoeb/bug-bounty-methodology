#!/usr/bin/env python3
"""
scan-constants.py <ADDR> [rpc] [--slots N] [--grep 0xADDR,...]

The EVM twin of solfork/scripts/scan-pubkeys.py. Finds the hardcoded addresses / oracles / role hashes a
gate compares against - the constants you must then reverse the USAGE of (a hit LOCATES the constant; it
lies about HOW the gate uses it - reverse the compare before concluding, Correction 1).

Two sources:
  1. IMMUTABLES / hardcoded addresses in the deployed bytecode - every `PUSH20 <addr>` immediate, plus any
     PUSH32 whose low 20 bytes look like an address (immutables are inlined into runtime code, NOT storage).
  2. STORAGE slots 0..N (eth_getStorageAt) - flags a slot that decodes to a plausible address (nonzero, top
     12 bytes zero) or to a known role/keccak constant.
Optionally --grep a set of addresses you already suspect (an oracle, the owner, a registry) and report
which source holds each - the fast "is THIS address wired in here?" check.

rpc: arg 2 (or --rpc), else EVMFORK_RPC, else the local fork, else publicnode. Requires `cast`.
"""
import re
import subprocess
import sys


def sh(*args):
    return subprocess.run(list(args), capture_output=True, text=True).stdout.strip()


def looks_like_addr(word_hex):
    """32-byte word -> address if top 12 bytes are zero and low 20 are nonzero."""
    w = word_hex[2:] if word_hex.startswith("0x") else word_hex
    w = w.rjust(64, "0")
    return w[:24] == "0" * 24 and int(w[24:], 16) != 0


def as_ascii(word_hex):
    """If a PUSH32 word is a right-zero-padded printable string (an inlined require() message / short
    string literal), return it; else None. Turns hash-looking noise into the actual gate messages."""
    w = word_hex[2:] if word_hex.startswith("0x") else word_hex
    try:
        b = bytes.fromhex(w).rstrip(b"\x00")
    except ValueError:
        return None
    if len(b) < 3:
        return None
    if all(32 <= c < 127 for c in b):
        return b.decode("ascii")
    return None


def push_immediates(code_hex):
    """Return (push20_addresses, push32_words) from runtime bytecode, skipping PUSH immediates correctly."""
    b = bytes.fromhex(code_hex[2:] if code_hex.startswith("0x") else code_hex)
    a20, w32, i, n = [], [], 0, len(b)
    while i < n:
        op = b[i]
        if 0x60 <= op <= 0x7f:
            ln = op - 0x5f
            imm = b[i + 1:i + 1 + ln]
            if op == 0x73 and len(imm) == 20:                       # PUSH20 = an address literal
                a20.append("0x" + imm.hex())
            elif op == 0x7f and len(imm) == 32:                     # PUSH32 = word (role hash or padded addr)
                w32.append("0x" + imm.hex())
            i += 1 + ln
            continue
        i += 1
    return a20, w32


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(1)
    addr = args[0]
    rpc = None
    nslots = 24
    grep = []
    i = 1
    while i < len(args):
        if args[i] == "--slots":
            nslots = int(args[i + 1]); i += 2
        elif args[i] == "--grep":
            grep = [x.strip().lower() for x in args[i + 1].split(",") if x.strip()]; i += 2
        elif args[i] in ("--rpc",):
            rpc = args[i + 1]; i += 2
        elif not args[i].startswith("--"):
            rpc = args[i]; i += 1
        else:
            i += 1
    if not rpc:
        import os
        rpc = os.environ.get("EVMFORK_RPC") or (
            "http://127.0.0.1:8545" if sh("cast", "block-number", "--rpc-url", "http://127.0.0.1:8545")
            else "https://ethereum.publicnode.com")

    addr = sh("cast", "to-check-sum-address", addr) or addr
    code = sh("cast", "code", addr, "--rpc-url", rpc)
    print(f"# scan-constants {addr}  ({rpc})")
    if not code or code == "0x":
        print("no bytecode (EOA/self-destructed)"); return

    a20, w32 = push_immediates(code)
    uniq20 = sorted(set(a.lower() for a in a20))
    addr_from32 = sorted(set(("0x" + w[-40:]).lower() for w in w32 if looks_like_addr(w)))
    rest = [w for w in w32 if not looks_like_addr(w)]
    ascii_msgs = sorted(set(a for a in (as_ascii(w) for w in rest) if a))
    role_hashes = sorted(set(w.lower() for w in rest if as_ascii(w) is None))

    print(f"\n## bytecode immutables / hardcoded addresses (PUSH20): {len(uniq20)}")
    for a in uniq20:
        print(f"  {a}")
    if addr_from32:
        print(f"\n## address-shaped PUSH32 words: {len(addr_from32)}")
        for a in addr_from32:
            print(f"  {a}")
    if ascii_msgs:
        print(f"\n## inlined string literals (require() messages / gate labels): {len(ascii_msgs)} "
              f"(these NAME the checks - map each to its guard)")
        for a in ascii_msgs:
            print(f'  "{a}"')
    if role_hashes:
        print(f"\n## PUSH32 constants (role hashes / keccak literals): {len(role_hashes)} "
              f"(gate compares against these - reverse the usage)")
        for w in role_hashes[:20]:
            print(f"  {w}")

    print(f"\n## storage slots 0..{nslots-1} that decode to an address")
    for s in range(nslots):
        raw = sh("cast", "storage", addr, hex(s), "--rpc-url", rpc)
        if raw and looks_like_addr(raw):
            print(f"  slot {s:>3}: 0x{raw[-40:]}")

    if grep:
        print("\n## --grep report (is each suspected address wired in here?)")
        blob = code.lower()
        stored = {}
        for s in range(nslots):
            raw = sh("cast", "storage", addr, hex(s), "--rpc-url", rpc)
            if raw and looks_like_addr(raw):
                stored[("0x" + raw[-40:]).lower()] = s
        for g in grep:
            where = []
            if g[2:] in blob:
                where.append("bytecode")
            if g in stored:
                where.append(f"storage slot {stored[g]}")
            print(f"  {g}: {', '.join(where) if where else 'NOT FOUND (not a constant here - may be passed in / derived)'}")

    print("\nNOTE: a hit LOCATES a constant, not HOW a gate uses it. Reverse the compare (source/decompile "
          "or drive it on the fork) before writing any verdict - Correction 1.")


if __name__ == "__main__":
    main()
