#!/usr/bin/env python3
"""
sim.py — reusable driver for building + simulating instructions against a local solfork validator.

Import it from your probe script:
    import sim
    logs, err = sim.simulate(program_id, data_bytes, [(pubkey, is_signer, is_writable), ...],
                             cu=1_400_000, payer_json="payer.json")

Encapsulates the gotchas that silently cost a session:
 - simulateTransaction MUST get encoding:base64 + sigVerify:false + replaceRecentBlockhash,
   else the RPC errors and `result` is ABSENT -> naive parsing reads a false err:None.
 - the FEE PAYER must exist on the fork (airdrop it first; sim.ensure_payer()).
 - raise the CU limit (CLMM/oracle math blows past 200k) — prepend set_compute_unit_limit.
"""
import json, base64, urllib.request, subprocess
from solders.pubkey import Pubkey
from solders.instruction import Instruction, AccountMeta
from solders.message import Message
from solders.transaction import Transaction
from solders.keypair import Keypair
from solders.hash import Hash
from solders.compute_budget import set_compute_unit_limit

LOCAL = "http://127.0.0.1:8899"

def lrpc(method, params, url=LOCAL):
    req = {"jsonrpc":"2.0","id":1,"method":method,"params":params}
    r = urllib.request.urlopen(urllib.request.Request(url, json.dumps(req).encode(),
        {"Content-Type":"application/json"}), timeout=30)
    return json.loads(r.read())

def ensure_payer(path="payer.json", url=LOCAL):
    import os
    if not os.path.exists(path):
        subprocess.run(["solana-keygen","new","--no-bip39-passphrase","-s","-o",path],
                       capture_output=True)
    kp = Keypair.from_bytes(bytes(json.load(open(path))))
    subprocess.run(["solana","airdrop","100",str(kp.pubkey()),"-u",url], capture_output=True)
    return kp

def simulate(program_id, data, metas, cu=1_400_000, payer_json="payer.json", url=LOCAL):
    """metas = list of (pubkey_str, is_signer, is_writable). Returns (logs, err)."""
    payer = ensure_payer(payer_json, url)
    ams = [AccountMeta(Pubkey.from_string(p), s, w) for (p, s, w) in metas]
    ix = Instruction(Pubkey.from_string(program_id), bytes(data), ams)
    bh = Hash.from_string(lrpc("getLatestBlockhash", [{"commitment":"processed"}], url)["result"]["value"]["blockhash"])
    ixs = ([set_compute_unit_limit(cu)] if cu else []) + [ix]
    tx = Transaction.new_unsigned(Message.new_with_blockhash(ixs, payer.pubkey(), bh))
    raw = base64.b64encode(bytes(tx)).decode()
    cfg = {"sigVerify": False, "replaceRecentBlockhash": True, "commitment": "processed",
           "encoding": "base64"}
    res = lrpc("simulateTransaction", [raw, cfg], url)
    if "error" in res:                       # <-- the silent-failure guard
        return [f"RPC-ERROR: {res['error']}"], res["error"]
    v = res.get("result", {}).get("value", {})
    return (v.get("logs") or []), v.get("err")

if __name__ == "__main__":
    print(__doc__)
