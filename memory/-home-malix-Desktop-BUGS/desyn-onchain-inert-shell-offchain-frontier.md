---
name: desyn-onchain-inert-shell-offchain-frontier
description: "DeSyn Protocol audit (self-hosted bounty, 20-50k Crit): on-chain fund class = inert phantom-accounting shell (exhausted, NULL); real EV is off-chain (Splice Canton custodial wallet + redemption reconciliation + airdrop), session-gated; the poke found what /intake's corpus never could"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2cdfc0cd-9aef-429a-9b17-40fee338f79c
---

DeSyn Protocol (desyn.io, self-hosted bounty, Crit 20-50k USDC, scope=DesynLab GitHub + *.desyn.io). Worked 2026-07-01 via /intake → mandatory manual poke. Workspace: `~/Desktop/BUGS/desyn-audit/` (VEINS-LEDGER.md = full dossier).

**The poke > corpus lesson, re-proven:** /intake's corpus classified it "Balancer vault, hunt accounting/rounding" — would have missed everything. The cold poke (deployed-contracts→subgraph→CT-subdomains→config.js→keeper-tx-forensics→app-browser) found the REAL target none of it named.

**Architecture (executed):** DeSyn is a multi-chain (~13 BTC-L2s + ETH) leveraged/RWA asset manager. Each fund = CRP(shares, bytecode 24397 IDENTICAL across all funds) + bPool(dust) + off-chain strategy. The BIG fund = **denzoBTC2 "$246M" on BNB** (CRP 0xa73354449E7EA1CC3aA59C827235bD51A07Bb4a3, bPool 0x34fE5b..., enzoBTC=Lorenzo-WBTC, controller=3-of-4 Gnosis Safe 0xC7d9...). ETH mainnet funds (soETH 0x38a3, CLOSED 3x 0xf5361c) are DORMANT decoys.

**ON-CHAIN = EARNED NULL (exhausted, executed on 3 funds + browser-unblocked BSC):**
- All funds are INERT PHANTOM-ACCOUNTING SHELLS: `bPool.getBalance` returns `_records[t].balance` set by admin `rebindPure` (controller-only, NO token backing); actual token balance = dust. Real deposits/redemptions BYPASS on-chain joinPool (only dust "Auto Join Small" on-chain) → 100% off-chain backend-mediated.
- The operator's decisive frame: "shell = architecture (RWA), not a bug — WHERE does an invariant BREAK? is there an on-chain OP reading a broken/divergent price for a value consequence?" Ran the 3 pistes → ALL REFUTED: oracle unread on-chain (getNormalizedWeight=display+reverts for enzoBTC; snapshot=CLOSED-only, funds are OPEN); dust bPool never read as price (pricing uses record, gulp admin-gated); record is faithful/admin-set, untrusted can't diverge it. enzoBTC concentrated 99.9% in 2 Lorenzo-infra addresses, NOT a drainable DeSyn module → H-D dead.
- My over-claims (convertToWeth ungated, TBillSimple.swap ungated, "shell=bug", free-mint) ALL refuted by execution — discipline held.

**REAL EV = OFF-CHAIN, session-gated (untested, NOT null):**
- **H-I Splice Canton custodial wallet** — `wallet.validator.desyn.io/api/validator` (Splice v0.6.7, Auth0 desyn-validator.us.auth0.com aud canton.network.global). Live Canton Coin custodial. `/v0/wallet/balance`+`/v0/admin/users`=401 → post-Auth0 party↔wallet BFLA. THE true custodial-authz surface. Near-twin of [[wallet-tg-telegram-bfla-engagement]].
- **H-H redemption reconciliation** — api.desyn.io off-chain queue (add_redeem→send_redeem_profit→handleRedeemClose, cancel, redeem_day, clump). Hypotheses: share-not-locked double-spend / cancel-after-settle / rate-timing / replay. Server-side.
- **H-G airdrop** (`user_data/airdrop/reward`) — where yield actually flows.
- BLOCKER: authed test needs account-creation/SIWE-signing (I can't: prohibited + don't sign) OR a BscScan key (Etherscan V2 free + Infura DON'T cover chain 56). → OPERATOR must provision a session. Re-open here when he does.

**Tooling notes:** cast source works for ETH via ETHERSCAN_API_KEY (V2) but NOT BSC (free tier excludes chain 56). Chrome (claude-in-chrome) renders BscScan JS tables + passes Cloudflare via the user session — the way to read BSC transfer/holder tables without a key. Related: [[feedback-apparatus-is-packaging-not-discovery]], [[feedback-audited-target-hunt-invariant-not-class]], [[feedback-closure-bias-expand-voies-hunt-seams]].
