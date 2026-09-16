#!/usr/bin/env python3
"""
scan-pubkeys.py prog.so [extra_base58_id ...]

Parse .rodata + .data.rel.ro out of the sBPF ELF and search for embedded 32-byte pubkey
constants — the values gates compare against (authorized-caller program, oracle, mint,
counterparty program). A known-programs bank is checked by default; add your own suspects.

WARNING (SKILL correction): an embedded program-id being present does NOT tell you HOW the
gate uses it. On fd3n the embedded JUP6Lkb was compared against the TOP-LEVEL instruction's
program-id AND its data[0..8] had to be a route discriminator — the constant alone lied about
the predicate. Use this to LOCATE the constant, then hand-reverse the compare (SKILL step 7).
"""
import sys, subprocess
from solders.pubkey import Pubkey

KNOWN = {
 # aggregators / routers
 "JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4":"Jupiter Aggregator v6",
 # AMMs used as CLMM collateral / swap counterparties
 "whirLbMiicVdio4qvUfM5KAg6Ct8VwpYzGff3uctyCc":"Orca Whirlpool",
 "CAMMCzo5YL8w4VFF8KVHrK22GGUsp5VTaW7grrKgrWqK":"Raydium CLMM",
 # oracles
 "rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ":"Pyth Receiver",
 "SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f":"Switchboard",
 "SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv":"Switchboard OnDemand",
 # token programs / common mints
 "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA":"SPL Token",
 "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb":"Token-2022",
 "So11111111111111111111111111111111111111112":"wSOL",
 "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v":"USDC",
}

def sec_bytes(so, sec):
    out = subprocess.run(["llvm-objdump-19","-s","-j",sec,so], capture_output=True, text=True).stdout
    b = bytearray()
    for line in out.splitlines():
        p = line.split()
        if len(p) >= 2 and len(p[0]) >= 4 and all(c in "0123456789abcdef" for c in p[0]):
            for x in p[1:5]:
                if len(x) == 8 and all(c in "0123456789abcdef" for c in x):
                    b += bytes.fromhex(x)
    return bytes(b)

def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    so = sys.argv[1]
    extra = {a: "(user-supplied)" for a in sys.argv[2:]}
    blob = sec_bytes(so, ".rodata") + sec_bytes(so, ".data.rel.ro")
    print(f"scanned {len(blob)} bytes of .rodata + .data.rel.ro")
    for k, name in {**KNOWN, **extra}.items():
        kb = bytes(Pubkey.from_string(k))
        i = blob.find(kb)
        print(f"  {name:26s} {'FOUND @'+str(i) if i>=0 else '-'}  {k}")
    print("NB: a hit LOCATES the constant; hand-reverse the compare before concluding what the gate checks.")

if __name__ == "__main__":
    main()
