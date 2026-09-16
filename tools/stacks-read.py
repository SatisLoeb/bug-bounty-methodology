#!/usr/bin/env python3
"""
Stacks on-chain read helper (Hiro API) — generic, reusable across engagements.
Enforces the playbook V2 mandate: verify every governance-settable premise LIVE.
Self-contained: c32 address decode + Clarity principal arg encoding + call-read + uint/tuple parse.

Usage examples:
  python3 query.py rate                # stSTX exchange rate
  python3 query.py buckets             # stx-reserve-v2 buckets + supplies
  python3 query.py tracking            # ststxbtc tracking state + sBTC pool balance
  python3 query.py holder <SPADDR>     # tracked vs real balances for a Zest user
  python3 query.py call <contract> <fn> [<argSP>...]   # generic read-only (SP args -> principal)
"""
import json, urllib.request, urllib.error, re, sys, time

DEP = "SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG"
SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token"
API = "https://api.hiro.so"
C32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'

def c32_decode(addr):
    b = addr[1:].upper().replace('O', '0').replace('L', '1').replace('I', '1')
    ver = C32.index(b[0]); num = 0
    for ch in b[1:]:
        num = num * 32 + C32.index(ch)
    d = num.to_bytes(24, 'big')
    return ver, d[:20]

def arg_principal(addr):
    """Standard principal 'SP...' -> 0x05; contract 'SP....name' -> 0x06."""
    if '.' in addr:
        a, name = addr.split('.', 1)
        ver, h = c32_decode(a)
        return '0x06' + bytes([ver]).hex() + h.hex() + bytes([len(name)]).hex() + name.encode().hex()
    ver, h = c32_decode(addr)
    return '0x05' + bytes([ver]).hex() + h.hex()

def call(contract, fn, args=None, sender=DEP):
    """contract = 'name' (assumes DEP address) or 'ADDR.name'."""
    addr, name = (contract.split('.', 1) if '.' in contract else (DEP, contract))
    body = json.dumps({"sender": sender, "arguments": args or []}).encode()
    url = f"{API}/v2/contracts/call-read/{addr}/{name}/{fn}"
    req = urllib.request.Request(url, data=body, headers={'Content-Type': 'application/json'})
    for _ in range(4):
        try:
            return json.load(urllib.request.urlopen(req))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(1); continue
            return {'okay': False, 'err': f"{e.code} {e.read().decode()[:150]}"}
        except Exception as e:
            return {'okay': False, 'err': str(e)}
    return {'okay': False, 'err': 'retries exhausted'}

def as_uint(result):
    h = result.get('result', '') if isinstance(result, dict) else result
    h = h[2:] if h.startswith('0x') else h
    if h[:4] == '0701':
        return int(h[4:36], 16)
    if h[:2] == '01':
        return int(h[2:34], 16)
    return None

def tuple_uints(result):
    h = result.get('result', '') if isinstance(result, dict) else result
    h = h[2:] if h.startswith('0x') else h
    return [int(m, 16) for m in re.findall(r'01([0-9a-f]{32})', h)]

def cmd_rate():
    print("stSTX rate (get-stx-per-ststx):", as_uint(call("data-stx-v2", "get-stx-per-ststx")))
    print("stSTX rate up (get-stx-per-ststx-up):", as_uint(call("data-stx-v2", "get-stx-per-ststx-up")))

def cmd_buckets():
    for fn in ["get-total-stx", "get-stx-balance", "get-stx-staking", "get-stx-for-ststxbtc",
               "get-stx-for-ststxbtc-idle", "get-stx-for-withdrawals", "get-stx-for-withdrawals-ststxbtc",
               "get-escrowed-ststxbtc"]:
        print(f"stx-reserve-v2.{fn}:", as_uint(call("stx-reserve-v2", fn)))
    print("ststx-token supply:", as_uint(call("ststx-token", "get-total-supply")))
    print("ststxbtc-token-v2 supply:", as_uint(call("ststxbtc-token-v2", "get-total-supply")))

def cmd_tracking():
    print("cumm-reward:", as_uint(call("ststxbtc-tracking-data-v2", "get-cumm-reward")))
    print("tracked total-supply:", as_uint(call("ststxbtc-tracking-data-v2", "get-total-supply")))
    print("next-holder-index:", as_uint(call("ststxbtc-tracking-data-v2", "get-next-holder-index")))
    print("claims-enabled:", call("ststxbtc-tracking-v2", "get-claims-enabled").get('result'))
    bal = urllib.request.urlopen(f"{API}/extended/v1/address/{DEP}.ststxbtc-tracking-v2/balances")
    ft = json.load(bal).get('fungible_tokens', {})
    for k, v in ft.items():
        if 'sbtc' in k.lower():
            print("tracking-v2 sBTC pool balance (sats):", v.get('balance'))

def cmd_holder(u):
    zest = arg_principal(DEP + ".position-zest-v6")
    su = arg_principal(u)
    wb = as_uint(call("ststxbtc-token-v2", "get-balance", [su]))
    zr = as_uint(call("position-zest-v6", "get-holder-balance", [su]))
    au = tuple_uints(call("ststxbtc-tracking-data-v2", "get-holder-position", [su, su]))
    az = tuple_uints(call("ststxbtc-tracking-data-v2", "get-holder-position", [su, zest]))
    amt_u = au[0] if au else 0
    amt_z = az[0] if az else 0
    print(f"user {u}")
    print(f"  wallet real={wb}  zest real={zr}")
    print(f"  tracked (u,u)={amt_u}  tracked (u,zest)={amt_z}")
    print(f"  tracked_total={amt_u + amt_z}  real_total={(wb or 0)+(zr or 0)}  diff(tracked-real)={amt_u+amt_z-((wb or 0)+(zr or 0))}")

def cmd_call(contract, fn, argaddrs):
    args = [arg_principal(a) for a in argaddrs]
    r = call(contract, fn, args)
    print("okay:", r.get('okay'), "err:", r.get('err', ''))
    print("result:", r.get('result', ''))
    print("as_uint:", as_uint(r), " tuple_uints:", tuple_uints(r))

if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        print(__doc__); sys.exit(0)
    c = a[0]
    if c == "rate": cmd_rate()
    elif c == "buckets": cmd_buckets()
    elif c == "tracking": cmd_tracking()
    elif c == "holder": cmd_holder(a[1])
    elif c == "call": cmd_call(a[1], a[2], a[3:])
    else: print(__doc__)
