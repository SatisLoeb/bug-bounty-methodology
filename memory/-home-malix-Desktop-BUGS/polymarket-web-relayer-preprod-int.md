---
name: polymarket-web-relayer-preprod-int
description: Polymarket web surface —
metadata: 
  node_type: memory
  type: project
  originSessionId: cefd795d-d46a-4cfc-8ba3-63e0d8d04ec7
---

Polymarket WEB surface (Cantina bounty). Web infra subdomains ARE in-scope (proven: #197 relayer-v2-local finding was accepted+paid $10k Medium). The productive web class = **auth-gateway asymmetry between sibling endpoints** (prod gated, preprod/`-local` sibling unauth, shared backend) — needs NO funded account (unlike the Perps/CLOB money-logic seams in [[polymarket-fresh-surface-perps-rfq]]).

**2026-07-02 recon (method = #197: CT-log subdomain enum → probe sibling auth posture → bundle-mine for backend hosts):**
- `relayer-v2-local` = DOWN/000 → #197 REMEDIATED (endpoint removed, as Jon promised).
- `preprod-public.polymarket.com` = live Vercel frontend serving PROD data (codename "sliders"); its bundle references `data-api-preprod-int.polymarket.com` (503 now).
- Guessed-sibling sweep found live: `data-api-staging`(200, empty DB), `gamma-api-staging`(301), **`relayer-v2-preprod-int.polymarket.com`(200)**.

**FINDING (`~/Desktop/BUGS/polymarket-audit/FINDING-relayer-preprod-int-auth-asymmetry.md`):** `relayer-v2-preprod-int` reproduces #197's asymmetry that remediation missed — `GET /transactions`=200 `[]` UNAUTH vs prod=401; `/relay-payload?address=X&type=PROXY`=200 unauth (step 1 of #197 chain). **Disconfirmer (CHECKPOINT 8, ran both ways):** 45 /address polls → preprod-int=2 signers, prod=38, overlap=∅ DISJOINT → NOT #197's $2.3M (not the prod pool); BUT the 2 signers hold ~$30k REAL mainnet MATIC (0x8027ca0c=29981, 0x829bdef2=29988 MATIC, thousands of mainnet txs) → honest impact = ~$30k mainnet gas-drain + preprod DoS. Severity Low–Med; strongest framing = **incomplete remediation of accepted #197** (class still open on a missed sibling). 

**/submit EXECUTED (operator-authorized 2026-07-02):** unauth POST /submit (SDK-built, fresh EOA 0xe239cdc5) → HTTP 200 → MINED mainnet tx 0xdf82e28f… block 89510197 status 0x1 gas 230479, **gas paid by preprod signer 0x829bdef2** (real $15k hot wallet), to RelayHub; baseline identical body→prod=401. #197 chain fully reproduced. **proxyWallet-trust escalation REFUTED:** proxyWallet=0x..dEaD → 400 "invalid proxyWallet field" (server validates → no victim-fund-theft, stays gas-drain). FINDING COMPLETE + ready to submit. PoC at scratchpad/preprod-poc/poc.js. Also: 3 recovery apps (arbitrum/base/bnb-recovery) STILL hardcode dead v2-local → broken tools + reinforces "incomplete remediation".

**Next web worklist (unauth, no account):** retry data-api-preprod-int (503 intermittent — if UP+unauth serving prod-equiv data = IDOR/leak); mine perpetuals-preview/recovery/xtracker/ticker bundles for THEIR preprod-int backends; the #197 proxyWallet-trust escalation (server trusts client proxyWallet → skips on-chain check → gas-drain becomes fund-theft Critical) — test on preprod-int since it's unauth-reachable.
