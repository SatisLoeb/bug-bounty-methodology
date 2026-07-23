#!/usr/bin/env python3
"""
recover-idl.py <PROGRAM_ID> [prog.so]

Two paths, in order:
 (A) On-chain Anchor IDL  — fetch the "anchor:idl" PDA, strip header, zlib-decompress -> idl.json.
 (B) FALLBACK when the IDL PDA is empty (deliberate closed-source teams skip `anchor idl init`):
     reconstruct the instruction dispatch by BRUTE-FORCING discriminators.
     ix disc  = sha256("global:<ix_name>")[:8]      account disc = sha256("account:<Name>")[:8]
     event disc = sha256("event:<Name>")[:8]
     The wordlist of names comes from the SOURCE PATHS `strings prog.so` already gave you
     (programs/<x>/src/instructions/<name>.rs -> <name>), plus a builtin CamelCase/snake bank.
     We grep the .so for each computed 8-byte discriminator: a HIT maps a name -> a real handler.
     (Account LAYOUTS still need disasm or a community deserializer — this recovers the dispatch,
      not the borsh field offsets. See SKILL step 5 for empirical offset determination.)

No anchor CLI needed. Requires: solders, and either `solana` on PATH or urllib to an RPC.
"""
import sys, json, base64, zlib, hashlib, re, subprocess, urllib.request

RPC = "https://api.mainnet-beta.solana.com"  # override with SOLFORK_RPC env for a real key

def rpc(method, params):
    import os
    url = os.environ.get("SOLFORK_RPC", RPC)
    req = {"jsonrpc":"2.0","id":1,"method":method,"params":params}
    r = urllib.request.urlopen(urllib.request.Request(url, json.dumps(req).encode(),
        {"Content-Type":"application/json"}), timeout=40)
    return json.loads(r.read())

def disc(kind, name):
    return hashlib.sha256(f"{kind}:{name}".encode()).digest()[:8]

def snake_to_camel(s):
    return "".join(p.capitalize() for p in s.split("_"))

def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(1)
    pid_s = sys.argv[1]
    so = sys.argv[2] if len(sys.argv) > 2 else None
    from solders.pubkey import Pubkey
    pid = Pubkey.from_string(pid_s)

    # ---------- (A) on-chain IDL ----------
    base, _ = Pubkey.find_program_address([], pid)
    idl_addr = Pubkey.create_with_seed(base, "anchor:idl", pid)
    print(f"[A] anchor:idl PDA = {idl_addr}")
    try:
        v = rpc("getAccountInfo", [str(idl_addr), {"encoding":"base64"}])["result"]["value"]
        if v:
            raw = base64.b64decode(v["data"][0]); body = raw[8:]
            ln = int.from_bytes(body[32:36], "little")
            idl = json.loads(zlib.decompress(body[36:36+ln]))
            json.dump(idl, open("idl.json", "w"))
            print(f"[A] ON-CHAIN IDL recovered -> idl.json  "
                  f"({len(idl.get('instructions',[]))} ix, {len(idl.get('accounts',[]))} accounts, "
                  f"v{idl.get('metadata',{}).get('version') or idl.get('version')})")
            return
        print("[A] IDL PDA is EMPTY -> falling back to discriminator brute-force")
    except Exception as e:
        print(f"[A] IDL fetch failed ({e!r}) -> fallback")

    # ---------- (B) fallback: brute-force discriminators ----------
    if not so:
        print("[B] need prog.so for the fallback: recover-idl.py <PID> prog.so"); sys.exit(2)
    blob = open(so, "rb").read()
    strings = subprocess.run(["strings", "-n", "5", so], capture_output=True, text=True).stdout
    # names from source paths: .../instructions/<name>.rs and .../<name>.rs
    names = set()
    for m in re.finditer(r"/([a-z0-9_]+)\.rs", strings):
        names.add(m.group(1))
    for m in re.finditer(r"instructions/([a-z0-9_/]+)", strings):
        names.add(m.group(1).split("/")[-1])
    # also any snake_case token that looks like an ix name
    for m in re.finditer(r"\b([a-z][a-z0-9_]{3,40})\b", strings):
        names.add(m.group(1))
    names = {n for n in names if "_" in n or n.islower()}
    print(f"[B] {len(names)} candidate names from strings")
    hits_ix, hits_acct = [], []
    for n in names:
        d = disc("global", n)
        if d in blob:
            hits_ix.append((n, d.hex()))
        cam = snake_to_camel(n)
        da = disc("account", cam)
        if da in blob:
            hits_acct.append((cam, da.hex()))
    print(f"[B] INSTRUCTION discriminator hits ({len(hits_ix)}):")
    for n, h in sorted(hits_ix): print(f"     {h}  global:{n}")
    print(f"[B] ACCOUNT discriminator hits ({len(hits_acct)}):")
    for n, h in sorted(set(hits_acct)): print(f"     {h}  account:{n}")
    json.dump({"instructions":[{"name":n,"discriminator":list(bytes.fromhex(h))} for n,h in hits_ix],
               "accounts":[{"name":n,"discriminator":list(bytes.fromhex(h))} for n,h in set(hits_acct)]},
              open("idl-reconstructed.json","w"))
    print("[B] -> idl-reconstructed.json (dispatch only; reverse layouts from disasm — SKILL step 5)")

if __name__ == "__main__":
    main()
