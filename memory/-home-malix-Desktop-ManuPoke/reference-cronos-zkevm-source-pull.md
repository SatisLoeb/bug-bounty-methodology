---
name: reference-cronos-zkevm-source-pull
description: "How to pull verified contract source from the Cronos zkEVM explorer for local NUKE barrage (API endpoint, key source, UA/proxy gotchas) — for the Cronos zkEVM bug bounty (Amply, H2, Fulcrom, Veno)."
metadata: 
  node_type: memory
  type: reference
  originSessionId: a62cfad9-335c-409f-86e0-a0898ae7594a
---

Cronos zkEVM bug bounty (Amply Finance = Aave-v3 fork, H2 = Uni-v2/v3 + Pancake MasterChef fork,
Fulcrom = GMX-v1 fork, Veno = LST + cross-chain bridges). All in-scope contracts are Critical, verified
on the CUSTOM Cronos explorer (not standard Blockscout). Chain-id 388.

**Getting verified source (the recipe that works — discovered 2026-07-13 after a long dead-end hunt):**
- API base: `https://explorer-api.zkevm.cronos.org` — Etherscan-compatible, pattern `/api/v1/{module}/{camelCaseAction}`.
- Source endpoint: `GET /api/v1/contract/getSourceCode?address=<addr>&apikey=<KEY>` →
  `result.sourceCode` is a **standard-json** string `{"sources":{"<path>":{"content":...}}}`, plus
  `result.{contractName,compilerVersion,evmVersion,proxy,implementation,zkSolcVersion,viaIr}`.
- **Key source: `developers.zkevm.cronos.org/user/apikeys` — NOT blockscout.com.** A blockscout.com
  key (`api.blockscout.com`) does NOT cover Cronos zkEVM ("Network not supported" / 401 on the instance).
- **GOTCHA 1 — User-Agent:** the API 403s `Python-urllib`. Send a browser UA (`Mozilla/5.0`). curl works by default.
- **GOTCHA 2 — proxies:** most contracts are ERC1967/Transparent proxies; the scope address returns
  only the proxy source. Check `result.proxy=="1"` and re-fetch `result.implementation` for the real logic.
- Dead ends (don't retry): the CDN `explorer-statics.cronos.org/<s3FileKey>` is 404 (content is served
  via signed URLs); Sourcify has none of these (chain 388 `match:null`); the frontend
  `explorer.zkevm.cronos.org` is SSR (source NOT in `__NEXT_DATA__`, only abi/bytecode/s3FileKeys).

**Puller:** `scratchpad/pull_verified.py` — `--base <api> --keyfile <f> --out <dir> Name=0xaddr ...`.
Resolves proxy→impl, writes the std-json `sources` tree under `<out>/sources/` preserving import paths,
generates remappings for `@`-prefixed roots + a `foundry.toml` (src=sources, pinned solc/evm). Then
`nuke <out>`. Key stored session-only at `scratchpad/.zkkey` (dev-portal key, not a secret credential).

Fulcrom pull (2026-07-13): 10/12 core with source (56 files) — Vault/VaultPriceFeedV2/FastPriceFeed/
FlpManager/PositionRouter/PositionManager/Router/ShortsTracker/VaultUtils/USDG. **OrderBook impl
(0x7AE282c8) and CronosOracle impl (0x240C3830) are UNVERIFIED** — opaque surface on a Critical scope,
a signal in itself. Fulcrom hunt vein = /extract (GMX-fork oracle keeper + FLP mint/redeem asymmetry).
See [[project-nuke-static-barrage-skill]].
