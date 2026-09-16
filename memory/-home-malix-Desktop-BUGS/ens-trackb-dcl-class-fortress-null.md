---
name: ens-trackb-dcl-class-fortress-null
description: ENS Immunefi Track B (web) is an executed fortress-null for the Decentraland case/normalization-desync class; RE-SOURCE to less-audited signed-auth backends
metadata: 
  node_type: memory
  type: project
  originSessionId: 0f40804f-42c9-469c-8520-53f0dfa30241
  modified: 2026-08-11T09:37:39.881Z
---

**Engagement (2026-08-11):** picked ENS ($250k, no-KYC, Triaged) as #1 analog to replicate the Decentraland
case-sensitivity signed-auth bug ([[decentraland-casebug-class-immunefi-targets]]). Cloned the 3 in-scope/adjacent
repos to `~/Desktop/BUGS/ens-web-audit/`: ens-metadata-service, ens-app-v3, ens-avatar-worker (=euc.li backend).
Hunted 5 seams (my hand-reads + a 5-agent workflow + my own adraffy/viem differential). **VERDICT: earned
NULL-COÛTEUX — the DCL class does NOT reproduce as a payable (Med+) finding; ENS hardened every instance.**

**Executed-attack ledger (all DEAD):**
- **S1 signed avatar/header upload (purest DCL twin, `euc.li`/ens-avatar-worker):** path-name, signed message.name,
  and owner-checked name are the SAME JS variable; body schema has no `name` field so message.name is server-derived
  from the path (`routes/avatar.ts:85-107`, `utils/eth.ts:44-49`); `avatar.ts:99 if(name!==normalize(name)) 400`;
  `verifiedAddress===owner` strict `!==` fail-closed (l125); available-branch writes address-keyed unregistered
  bucket that promotion only reads under the CURRENT owner (`media.ts:63-71`) → no pre-seed impersonation. EIP-712
  domain omits chainId/verifyingContract but every replay still passes the per-network owner check with the same
  recovered address. Also OOS-risk (euc.li not a listed asset). DEAD.
- **S2 avatar SVG DOMPurify → XSS:** app renders avatar ONLY as `<img src>`/CSS bg/canvas/`<image href>` = browser
  script-inert; metadata.ens.domains direct nav wrapped in `<iframe srcdoc sandbox>` WITHOUT allow-scripts + CSP
  scriptSrc excludes unsafe-inline. metadata.ens.domains XSS is a scope carve-out = LOW anyway. DEAD.
- **S3 raw on-chain label → SVG/HTML:** tokenId route is namehash-bound (`domain.ts:72`, ensjs normalizes per-label);
  live-proved `keccak256("Vitalik")` tokenId → 404 "does not match namehash of Vitalik.eth"; SVG `${domain}` sink
  receives labelhash-encoded `[0x..].eth` not raw; 35.6k-codepoint sweep: NO normalize-stable codepoint beautifies
  into `< > " ' & / \ ; = space`. DEAD.
- **S4 app record→DOM sink:** `OtherProfileButton` `isLink = startsWith('http(s)')` allowlist; socials/verification/
  contenthash links are FIXED-prefix (`getSocialData.ts`, `contenthash.ts` all `https://...`); React escapes attribute
  values → only `javascript:` scheme would XSS and it's gated out. DEAD.
- **S5 normalization/version skew:** EXECUTED differential — adraffy 1.11.0(metadata) vs 1.11.1(app) vs viem-bundled
  (worker): **109 accept/reject divergences but 0 MAPPING divergences over ~20k codepoints** (both-accept ⇒ identical
  output). So no identity-collision/wrong-resolution; only an `is_normalized` anti-phishing-badge inconsistency =
  LOW, on the metadata.ens.domains LOW carve-out surface. Guards fail closed (`name===ens_normalize(name)` +
  namehash-binding). DEAD as Med+. (One un-executed thread: multi-codepoint ZWJ/NSM sequences — low EV, not chased.)

**LESSON (sharpens the RE-SOURCE heuristic):** the DCL class = off-chain signed-auth + normalization-desync, which is
EXACTLY what a mature decade-audited web3 team hardens. Depth pays only where ore remains → RE-SOURCE this class to
LESS-audited / closed-source / newer signed-auth backends, NOT blue-chips. Ranked next targets for this class:
**galagames** (walletsrv.gala.games = custodial wallet backend, closed-source, the literal DCL topology twin,
client→wallet-service→authz, far less audited than ENS) > **aster/hashflow/hibachi/edgex** (signed order/quote APIs,
several no-KYC) > **0x** ($1M but blue-chip/hardened like ENS). Harness kept at ~/Desktop/BUGS/ens-web-audit/.
See [[feedback-depth-is-an-edge-only-where-ore-remains]], [[feedback-audited-target-hunt-invariant-not-class]].
