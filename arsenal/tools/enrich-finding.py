#!/usr/bin/env python3
"""
enrich-finding.py — On-Chain State Enrichment for Findings

Queries on-chain state to quantify impact: TVL, token balances,
admin parameters, oracle prices.

Usage:
    python3 enrich-finding.py --address 0x... --chain ethereum --type vault
    python3 enrich-finding.py --protocol "morpho blue" --type lending
"""

import sys
import json
import subprocess

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


RPC_URLS = {
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "base": "https://base-rpc.publicnode.com",
    "arbitrum": "https://arbitrum-one-rpc.publicnode.com",
    "polygon": "https://polygon-bor-rpc.publicnode.com",
    "optimism": "https://optimism-rpc.publicnode.com",
    "bsc": "https://bsc-rpc.publicnode.com",
    "avalanche": "https://avalanche-c-chain-rpc.publicnode.com",
}


def get_tvl_from_defillama(protocol_name):
    """Get TVL from DeFiLlama."""
    if not HAS_REQUESTS:
        return None

    try:
        resp = requests.get("https://api.llama.fi/protocols", timeout=15)
        for p in resp.json():
            if protocol_name.lower() in p.get("name", "").lower() or \
               protocol_name.lower() in p.get("slug", "").lower():
                return {
                    "name": p["name"],
                    "tvl": p.get("tvl", 0),
                    "chains": p.get("chains", []),
                    "category": p.get("category", ""),
                }
    except:
        pass
    return None


def cast_call(address, sig, chain="ethereum"):
    """Call a contract function via cast."""
    rpc = RPC_URLS.get(chain, RPC_URLS["ethereum"])
    try:
        result = subprocess.run(
            ["cast", "call", address, sig, "--rpc-url", rpc],
            capture_output=True, text=True, timeout=15
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except:
        return None


def cast_storage(address, slot, chain="ethereum"):
    """Read storage slot via cast."""
    rpc = RPC_URLS.get(chain, RPC_URLS["ethereum"])
    try:
        result = subprocess.run(
            ["cast", "storage", address, slot, "--rpc-url", rpc],
            capture_output=True, text=True, timeout=15
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except:
        return None


def enrich_vault(address, chain="ethereum"):
    """Enrich a vault/ERC4626 finding."""
    data = {}

    total_assets = cast_call(address, "totalAssets()(uint256)", chain)
    total_supply = cast_call(address, "totalSupply()(uint256)", chain)
    decimals = cast_call(address, "decimals()(uint8)", chain)
    asset = cast_call(address, "asset()(address)", chain)
    name = cast_call(address, "name()(string)", chain)

    data["name"] = name
    data["asset"] = asset
    data["decimals"] = int(decimals) if decimals else 18
    data["total_assets_raw"] = total_assets
    data["total_supply_raw"] = total_supply

    if total_assets and decimals:
        dec = int(decimals)
        data["total_assets"] = int(total_assets, 16) / (10 ** dec) if total_assets.startswith("0x") else int(total_assets) / (10 ** dec)

    if total_supply and decimals:
        dec = int(decimals)
        data["total_supply"] = int(total_supply, 16) / (10 ** dec) if total_supply.startswith("0x") else int(total_supply) / (10 ** dec)

    if data.get("total_assets") and data.get("total_supply") and data["total_supply"] > 0:
        data["share_price"] = data["total_assets"] / data["total_supply"]

    return data


def enrich_lending(address, chain="ethereum"):
    """Enrich a lending protocol finding."""
    data = {}
    # Common lending protocol calls
    data["total_supply"] = cast_call(address, "totalSupply()(uint256)", chain)
    data["total_borrow"] = cast_call(address, "totalBorrow()(uint256)", chain)
    return data


def enrich_token(address, chain="ethereum"):
    """Enrich a token finding."""
    data = {}
    data["name"] = cast_call(address, "name()(string)", chain)
    data["symbol"] = cast_call(address, "symbol()(string)", chain)
    data["total_supply"] = cast_call(address, "totalSupply()(uint256)", chain)
    data["decimals"] = cast_call(address, "decimals()(uint8)", chain)
    data["owner"] = cast_call(address, "owner()(address)", chain)
    return data


def generate_impact_section(protocol_data, onchain_data, finding_type):
    """Generate an impact quantification section for the report."""
    lines = []
    lines.append("## Impact Quantification\n")

    if protocol_data:
        tvl = protocol_data.get("tvl", 0)
        lines.append(f"**Protocol:** {protocol_data.get('name', 'Unknown')}")
        lines.append(f"**TVL:** ${tvl/1e6:.1f}M" if tvl else "**TVL:** Unknown")
        lines.append(f"**Category:** {protocol_data.get('category', 'Unknown')}")
        lines.append(f"**Chains:** {', '.join(protocol_data.get('chains', []))}")
        lines.append("")

    if onchain_data:
        if finding_type == "vault":
            if onchain_data.get("total_assets"):
                lines.append(f"**Vault total assets:** {onchain_data['total_assets']:,.2f}")
            if onchain_data.get("total_supply"):
                lines.append(f"**Vault total shares:** {onchain_data['total_supply']:,.2f}")
            if onchain_data.get("share_price"):
                lines.append(f"**Share price:** {onchain_data['share_price']:.6f}")
            if onchain_data.get("name"):
                lines.append(f"**Vault name:** {onchain_data['name']}")
        elif finding_type == "token":
            for k, v in onchain_data.items():
                if v:
                    lines.append(f"**{k}:** {v}")

    return "\n".join(lines)


def main():
    address = None
    chain = "ethereum"
    finding_type = "vault"
    protocol_name = None

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--address":
            address = args[i + 1]; i += 2
        elif args[i] == "--chain":
            chain = args[i + 1]; i += 2
        elif args[i] == "--type":
            finding_type = args[i + 1]; i += 2
        elif args[i] == "--protocol":
            protocol_name = args[i + 1]; i += 2
        else:
            i += 1

    if not address and not protocol_name:
        print("Usage: python3 enrich-finding.py --address 0x... --chain ethereum --type vault")
        print("       python3 enrich-finding.py --protocol 'morpho blue' --type lending")
        sys.exit(1)

    print("=" * 50)
    print(" On-Chain State Enrichment")
    print("=" * 50)

    # Get protocol TVL
    protocol_data = None
    if protocol_name:
        print(f"\n[1] Querying DeFiLlama for {protocol_name}...")
        protocol_data = get_tvl_from_defillama(protocol_name)
        if protocol_data:
            print(f"  Found: {protocol_data['name']} — ${protocol_data.get('tvl',0)/1e6:.1f}M TVL")
        else:
            print("  Not found on DeFiLlama")

    # Get on-chain data
    onchain_data = {}
    if address:
        print(f"\n[2] Querying on-chain state for {address} on {chain}...")
        if finding_type == "vault":
            onchain_data = enrich_vault(address, chain)
        elif finding_type == "lending":
            onchain_data = enrich_lending(address, chain)
        elif finding_type == "token":
            onchain_data = enrich_token(address, chain)

        for k, v in onchain_data.items():
            if v is not None:
                print(f"  {k}: {v}")

    # Generate impact section
    print(f"\n[3] Generated impact section:")
    print(generate_impact_section(protocol_data, onchain_data, finding_type))


if __name__ == "__main__":
    main()
