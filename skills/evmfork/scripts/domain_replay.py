#!/usr/bin/env python3
"""
domain_replay.py - EIP-712 signature / domain replay (evmfork step 10).

Every "domains can't collide" / "signatures can't be replayed" claim is REASONED until this executes it.
Three moves:

  1. domain <addr> [rpc]            - read DOMAIN_SEPARATOR() and, if present, eip712Domain() (ERC-5267),
                                      and FLAG the SEC-MGR-010 class: a domain that OMITS chainId (0) or
                                      verifyingContract (0x0) is cross-context replayable by construction.
  2. diff <addr1> <addr2> ... [rpc] - read every DOMAIN_SEPARATOR and report COLLISIONS. Two deployments
                                      with the SAME separator => a signature accepted by one is accepted by
                                      the other (OKX 7-mainnet / Across / multi-deploy replay class).
  3. replay_across(submit, targets) - (import) the two-fork execution: capture a signed message valid on
                                      A, then SUBMIT it to A and to B and assert execute-vs-reject. `submit`
                                      is your closure (the sig-consuming tx differs per target) taking a
                                      (target_addr, url) and returning (ok, detail). Stand up two forks:
                                        anvil --fork-url $RPC_A --port 8545   # chain/deployment A
                                        anvil --fork-url $RPC_B --port 8546   # chain/deployment B
                                      capture the sig on A, then replay_across(submit, [(A,8545),(B,8546)]).

Requires `cast`. Programmatic API + CLI. sim.py used only by replay_across (execution).
"""
import os
import subprocess
import sys


def sh(*args):
    return subprocess.run(list(args), capture_output=True, text=True)


def _rpc(rpc):
    if rpc:
        return rpc
    if os.environ.get("EVMFORK_RPC"):
        return os.environ["EVMFORK_RPC"]
    if sh("cast", "block-number", "--rpc-url", "http://127.0.0.1:8545").returncode == 0:
        return "http://127.0.0.1:8545"
    return "https://ethereum.publicnode.com"


def domain_separator(addr, rpc=None):
    r = sh("cast", "call", addr, "DOMAIN_SEPARATOR()(bytes32)", "--rpc-url", _rpc(rpc))
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def eip712_domain(addr, rpc=None):
    """ERC-5267 eip712Domain() -> dict, or None if unsupported. Names the SEC-MGR-010 omissions."""
    sig = "eip712Domain()(bytes1,string,string,uint256,address,bytes32,uint256[])"
    r = sh("cast", "call", addr, sig, "--rpc-url", _rpc(rpc))
    if r.returncode != 0 or not r.stdout.strip():
        return None
    lines = [l.strip() for l in r.stdout.strip().splitlines() if l.strip()]
    if len(lines) < 5:
        return None
    d = {"fields": lines[0], "name": lines[1].strip('"'), "version": lines[2].strip('"'),
         "chainId": lines[3], "verifyingContract": lines[4]}
    try:
        d["chainId_int"] = int(d["chainId"].split()[0])
    except Exception:
        d["chainId_int"] = None
    return d


def audit_domain(addr, rpc=None):
    sep = domain_separator(addr, rpc)
    dom = eip712_domain(addr, rpc)
    flags = []
    if dom:
        if dom.get("chainId_int") in (0, None):
            flags.append("chainId OMITTED/zero -> cross-CHAIN replay (a sig from any chain is valid here)")
        vc = dom.get("verifyingContract", "").lower()
        if vc in ("0x0000000000000000000000000000000000000000", ""):
            flags.append("verifyingContract OMITTED/zero -> cross-CONTRACT replay (a sib deployment's sig is valid)")
    return {"address": addr, "domain_separator": sep, "eip712Domain": dom, "flags": flags}


def diff_domains(addrs, rpc=None):
    """Read every separator; group by value; a group of size>1 is a replay-collision set."""
    seps = {}
    for a in addrs:
        s = domain_separator(a, rpc)
        seps.setdefault(s, []).append(a)
    collisions = {s: v for s, v in seps.items() if s and len(v) > 1}
    return {"separators": seps, "collisions": collisions}


def replay_across(submit, targets):
    """
    submit: callable(target_addr, url) -> (ok: bool, detail: str)  - sends the sig-consuming tx to `target`
            on the fork at `url`, using a signature you captured on A. ok=True means the sig was ACCEPTED.
    targets: [(addr, port), ...]  - each a fork (deployment A, deployment B, ...).
    Returns [{target, url, accepted, detail}]. A sig accepted on >1 target with distinct (chain/contract)
    binding is the replay finding.
    """
    out = []
    for addr, port in targets:
        url = f"http://127.0.0.1:{port}"
        ok, detail = submit(addr, url)
        out.append({"target": addr, "url": url, "accepted": ok, "detail": detail})
    return out


def main():
    a = sys.argv[1:]
    if not a or a[0] in ("-h", "--help"):
        print(__doc__); sys.exit(0 if a else 1)
    cmd = a[0]
    rpc = None
    if "--rpc" in a:
        rpc = a[a.index("--rpc") + 1]; a = [x for j, x in enumerate(a) if j not in (a.index("--rpc"), a.index("--rpc") + 1)]

    if cmd == "domain":
        rep = audit_domain(a[1], rpc)
        print(f"# {rep['address']}")
        print(f"  DOMAIN_SEPARATOR : {rep['domain_separator']}")
        if rep["eip712Domain"]:
            d = rep["eip712Domain"]
            print(f"  name/version     : {d['name']} / {d['version']}")
            print(f"  chainId          : {d['chainId']}")
            print(f"  verifyingContract: {d['verifyingContract']}")
        else:
            print("  eip712Domain()   : not exposed (pre-ERC-5267 or custom domain)")
        for f in rep["flags"]:
            print(f"  !! {f}")
        if not rep["flags"] and rep["eip712Domain"]:
            print("  (domain binds chainId + verifyingContract - no by-construction cross-context replay)")
    elif cmd == "diff":
        addrs = [x for x in a[1:] if x.startswith("0x")]
        rep = diff_domains(addrs, rpc)
        print("# DOMAIN_SEPARATOR by address")
        for s, v in rep["separators"].items():
            print(f"  {s}  <- {', '.join(v)}")
        if rep["collisions"]:
            print("\n!! COLLISIONS (same separator => a signature for one is valid on the others):")
            for s, v in rep["collisions"].items():
                print(f"  {s}\n    {', '.join(v)}")
        else:
            print("\n(no separator collisions across the given set)")
    else:
        print(__doc__); sys.exit(1)


if __name__ == "__main__":
    main()
