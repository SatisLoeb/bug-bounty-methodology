---
name: lombard-offchain-web-surface-map
description: "Lombard Immunefi off-chain/web recon 2026-08-12: deposit-address derivation sound (Go+TS match); FREE unauth web surface executed-null (benign public API, non-exploitable CORS, OOS deanon endpoints); PAYABLE ore is SESSION-GATED = claimer signature service + SIWE auth + BFF RPC proxy — needs wallet onboarding + active-testing OK"
metadata: 
  node_type: memory
  type: project
  originSessionId: a3337c82-163f-4d2c-bc2a-e5d0432d849c
  modified: 2026-08-12T21:52:32.190Z
---

Lombard Finance Immunefi — off-chain/web pivot 2026-08-12 (after on-chain EVM+Solana null, see [[lombard-solana-cluster-executed-null]] + [[lombard-strategy-tranche-oos-strategy-contract]]). Web/App = **Primacy of RULES** (must hit listed asset: Home Page/Dapp); SC Crit/High = PoI. Real dApp = **https://www.lombard.finance/app/** (app.lombard.finance is Cloudflare-blocked to automated browsers; www/app works). API base **https://mainnet.prod.lombard.finance/api/v1/** (CloudFront-fronted). BFF **https://bff.prod.lombard-fi.com**.

**GitHub off-chain repos (lombard-finance org):** `sdk` (pushed daily, client), `deposit-address` (Go, BTC deposit-addr derivation), `ts-verifier` (TS mirror of derivation — user trust anchor), `ledger-utils`, `go-common`, `babylon` (Cosmos ledger), `cubesigner-sdk` (Cubist KMS — 3rd-party, OOS), `deposit-address`, `agentkit`. Ledger = Cosmos/Babylon chain; notary=consortium; keys via CubeSigner.

**deposit-address derivation = SOUND (executed diff Go vs TS).** DepositTweak = taggedHash("LombardDepositAddr"||tag || auxData[32] || 0x00 || chainId[32] || lbtcContract.Bytes() || wallet.Bytes()); auxData = taggedHash("LombardDepositAux" || version[1] || nonce[4 BE] || referrerId); segwit tweak = taggedHash("SegwitTweak"||pk[33c]||tweak) → PK + t·G. **Go and TS match on all three layers**; tweak COMMITS to destination wallet (consortium mints right recipient); verifier.ts enforces computed==expected. **One real inconsistency, NOT payable:** Go backend omits the address-length validation TS enforces (EVM=20/else=32) → latent lbtcContract||wallet concatenation ambiguity, but a collision needs a non-standard-length split and the mint target must be a valid address → forces standard lengths → no collision. Hardening note only.

**FREE (unauth) web surface = EXECUTED-NULL / OOS:**
- CORS: `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` on the API — classic NON-exploitable (wildcard≠reflected-origin ⇒ browser blocks credentialed CORS; API is public/no-creds anyway). Informational, triager-reject class. Don't submit.
- Public `/debug/*` in prod: `btc-script-to-address` (200), `evm-by-btc-address` + `btc-tx-info` (reachable, 404 on dummy). Public two-way BTC↔EVM mapping (deanon) — but PII/deanon NOT in Lombard's in-scope impacts → OOS.
- Public financial-history endpoints (no auth, any address): `address/outputs-v2`, `native-deposits`, `unstakes`, `analytics/{addr}/summary`, `referral-system/season-{1,2}/points`, `badges/season-2`, `address/exists`, `ratio`. IDOR-by-design (address is the key) financial-privacy leak → OOS impact-wise.

**claimer signature service = TESTED 2026-08-12 (collaborative authed test, user wallet 0x68eb…8eDB), verdict SOUND:**
`/api/v1/claimer/{get,save}-user-signature` + `{get,save}-user-stake-and-bake-signature` have **NO JWT/auth** (address is a query param — looked like BOLA). But **compensated by EIP-712 signature-as-auth**, executed-confirmed:
- **save-user-signature VALIDATES signer:** live write test (own addr + garbage 65-byte sig) → `HTTP 400 {"code":3,"message":"Invalid signature: signer does not match recovered address"}`. So you can only store a signature YOU signed → attacker can't squat/grief a victim (no victim key). Griefing DISCONFIRMED.
- **theft CLOSED:** the stored sigs are `feeApproval(chainId,fee,expiry)` (verifyingContract=LBTC, NO recipient — fee→protocol only) or an ERC-2612 permit whose only consumer is `StakeAndBake.sol` — which is `onlyRole(CLAIMER_ROLE)` and binds `owner = $.lbtc.mint(mintPayload,proof)` (consortium-attested recipient); shares→owner. A leaked permit can't be weaponized (attacker can't call the role-gated consumer; everything owner-bound).
- **get-user-signature no-auth READ** leaks pending owner-bound sigs+amount+nonce = OOS info-disclosure (useless to attacker, not a listed impact). "one active signature per user" = code 6.
NULL — the no-JWT is a design (signature IS the auth), not a defect. Also `sdk/.../storeNetworkFeeSignature`, `signNetworkFee.ts` (feeApproval builder).
2. **SIWE auth:** `/api/v2/auth/wallet/` + `/v2/auth/wallet/verify` + `/v2/auth/token/revoke` → JWT (auth.ts: "EVM EOAs/Sui/Solana verify sync → JWT; poll async verify for on-chain sig check"). Auth bypass here → impersonate → access claimer sigs.
3. **BFF RPC proxy:** `bff.prod.lombard-fi.com/multi-rpc/proxy/{eth,base,bsc}` (POST) — SSRF candidate; chain is a fixed path segment (likely allowlisted). Also `/opportunities-api`.

**Resume trigger / next step:** the paying surface is behind SIWE-JWT + POST (writes). To pursue = burner-wallet onboarding + operator OK for active testing of authed/POST endpoints (claimer IDOR, auth-flow, RPC-proxy SSRF). Matches the pattern in [[ethena-web-immunefi-freesurface-null]] + [[polymarket-fresh-surface-perps-rfq]]: free surface null, payable ore session-gated. Hardcoded frontend addr seen: 0x68eb4074aAebdb9423a625F026d55f8F09Cf8eDB (default/featured, note only).
