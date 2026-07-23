#!/usr/bin/env python3
"""
statefork.py — pull REAL mainnet state onto the fork, then mutate ONE input to read a verdict.

This is the mode the name "solfork" implies but SKILL step 5 originally omitted: reconstructing the
real MATH/valuation needs REAL accounts (config PDAs, oracles, a live account holding the target
state), not hand-built dummies. Fake accounts are fine for piercing a stateless gate (InvalidCaller);
they are NOT fine for /extract — reconstructed math on dummy state may not match prod.

Functions (import or run pieces from your engagement script):
  fetch_accounts(pubkeys, outdir, rpc)      -> writes accts/<pk>.json  (--account file format)
  refresh_pyth(path, offsets=(93,101))      -> set publish_time/prev to now (hold PRICE constant)
  mutate_le(path, offset, nbytes, newval)   -> overwrite a little-endian field (e.g. whirlpool
                                               sqrt_price_x64 @65, or a Pyth price @73)
  read_le (path, offset, nbytes, signed)    -> decode a field to sanity-check the offset first

Then: solana-test-validator --reset --ledger /tmp/f  (SHORT path — long paths trip SUN_LEN)
        --bpf-program <PID> prog.so  [--bpf-program <counterparty> other.so ...]
        --account <pk> accts/<pk>.json  (repeat)   --rpc-port 8899

Plumbing gotchas proven on Loopscale (2026-07-21):
 - Public RPC 429/403s the bulk --clone; use a real key (SOLFORK_RPC=helius...) or fetch_accounts()
   one-by-one with backoff and load via --account files.
 - A referenced PDA that is uninitialized on mainnet (e.g. Anchor event_authority) returns null ->
   add it as an EMPTY system account stub, or the runtime says AccountNotFound.
 - Cloned oracle accounts are STALE vs the fork's live clock -> refresh_pyth() (keep the price).
 - The recovered-IDL struct size can be OFF from deployed -> find field offsets EMPIRICALLY
   (locate a known pubkey/mint in the data, or an owner==<program> account) before decoding.
"""
import json, base64, time, struct, os, urllib.request

def _rpc(method, params):
    url = os.environ.get("SOLFORK_RPC", "https://api.mainnet-beta.solana.com")
    for _ in range(5):
        try:
            req = {"jsonrpc":"2.0","id":1,"method":method,"params":params}
            r = urllib.request.urlopen(urllib.request.Request(url, json.dumps(req).encode(),
                {"Content-Type":"application/json"}), timeout=40)
            return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code in (429, 403): time.sleep(2); continue
            raise
    return {}

def fetch_accounts(pubkeys, outdir="accts"):
    os.makedirs(outdir, exist_ok=True); ok = []
    for a in pubkeys:
        v = _rpc("getAccountInfo", [a, {"encoding":"base64","commitment":"confirmed"}]).get("result",{}).get("value")
        if not v:
            print(f"  MISSING {a}  (uninitialized on mainnet? add an empty stub if referenced)"); continue
        sz = len(base64.b64decode(v["data"][0]))
        json.dump({"pubkey": a, "account": {"lamports": v["lamports"], "data": v["data"],
                   "owner": v["owner"], "executable": v["executable"], "rentEpoch": 0, "space": sz}},
                  open(f"{outdir}/{a}.json", "w"))
        ok.append(a); time.sleep(0.35)
    print(f"fetched {len(ok)}/{len(pubkeys)} -> {outdir}/")
    return ok

def empty_stub(pubkey, outdir="accts", lamports=1_000_000):
    json.dump({"pubkey": pubkey, "account": {"lamports": lamports, "data": ["","base64"],
               "owner": "11111111111111111111111111111111", "executable": False,
               "rentEpoch": 0, "space": 0}}, open(f"{outdir}/{pubkey}.json", "w"))

def _load(path):
    d = json.load(open(path)); return d, bytearray(base64.b64decode(d["account"]["data"][0]))
def _save(path, d, raw):
    d["account"]["data"] = [base64.b64encode(bytes(raw)).decode(), "base64"]; json.dump(d, open(path, "w"))

def read_le(path, off, n, signed=False):
    _, raw = _load(path); return int.from_bytes(raw[off:off+n], "little", signed=signed)

def mutate_le(path, off, n, newval):
    d, raw = _load(path); raw[off:off+n] = int(newval).to_bytes(n, "little", signed=(newval < 0)); _save(path, d, raw)

def refresh_pyth(path, offsets=(93, 101), now=None):
    """PriceUpdateV2 (rec5EK): publish_time@93, prev_publish_time@101 (verification_level=Full=1B).
       price@73 (i64), conf@81, expo@89. Set timestamps to now; leave price to hold it constant."""
    now = now or int(time.time()); d, raw = _load(path)
    for off in offsets: raw[off:off+8] = struct.pack("<q", now)
    _save(path, d, raw)

if __name__ == "__main__":
    print(__doc__)
