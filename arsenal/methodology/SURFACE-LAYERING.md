# Surface Layering — multi-surface hunting on single-program targets

**Purpose:** When a bounty program covers multiple attack surfaces (smart contracts + web app + API + infrastructure), the naive approach treats each surface as a separate target. Surface layering treats them as **layered surfaces of the same program** — findings on one surface inform hunts on adjacent surfaces.

**Origin:** Polymarket Cantina #197 ($10K Medium, 2026-04-21). The program had both SC contest ($5M pool) and Web2 contest ($250K pool). The Web2 finding (relayer-v2-local unauth `/submit`) was discovered while recon'ing the smart contract scope. Without surface layering, the finding would have been missed — the SC audit would have ended with "no critical", and the Web2 surface would have been treated as a separate later engagement.

---

## The layering rule

**If a target has a bounty on surface X, always check adjacent surfaces Y and Z of the same program.**

For every bounty program, explicitly enumerate ALL surfaces, not just the one the bounty page emphasizes:

| Primary scope | Adjacent surfaces to check |
|---------------|----------------------------|
| Smart contract (SC) | Web frontend that interacts with the SC; API that serves frontend; relayer infra; keeper bots; proxy admin UI; indexer/subgraph |
| Web application | Backend API; JS bundle (secrets, config endpoints, routes); CORS configuration; IdP/SSO flow; infrastructure (CDN, DNS, cloud metadata) |
| API / REST | GraphQL (often co-deployed); WebSocket; client-side bundles for API key exposure; admin/internal endpoints with different auth |
| Bridge / cross-chain | Relayer infrastructure; validator rotation; replay protection TTL; each chain's deployed contracts; oracle network; monitoring/alerts |
| Wallet / custody | Signing infrastructure (HSM, cloud KMS); frontend for key handling; signing-server API; cold-storage procedures |
| DeFi protocol | All of the above: contracts + frontend + API + relayer + keeper bots + indexer + subgraph + oracle + admin multisig UI |

## The multiplier

Surface layering does NOT multiply recon time proportionally to surface count. It multiplies **in exchange for ~20% additional recon time**:

- 8h SC recon → 10h SC+Web recon
- 20h SC audit → 24h SC+Web audit
- Polymarket: ~12h on SC yielded no Criticals. 2h additional Web recon (bundles + routes + auth probe) yielded F-W003 Critical→Medium $10K.

ROI: 2h of Web recon generated 50-80% of the session's total bounty.

---

## Layering checklist by primary surface

### Primary = smart contract

1. **Frontend bundle scan** (§F2 of DEFI-FULLSTACK-CHECKLIST). Extract all API endpoints, config constants, hardcoded keys, crypto derivation constants.
2. **API authentication inventory.** For every endpoint the frontend calls: is there a token? What is the scope? Are destructive routes weaker than reads?
3. **Relayer/paymaster infra.** If the SC uses a meta-transaction pattern, the relayer is a separate attack surface:
   - Is the relayer's signing key a single EOA or a multisig?
   - Is the relayer's endpoint authenticated? (Polymarket lesson: unauth `/submit` drains gas pool)
   - What's the validation pipeline between user signature and relayer tx?
4. **Keeper/bot wallets** (CLAUDE.md rule #28). Who calls `harvest()`, `rebalance()`, `liquidate()`? Approvals unlimited? Same key on multiple chains?
5. **Indexer / subgraph.** Off-chain data source that frontend trusts. Can it be poisoned? Does the backend verify?
6. **Admin / proxy UI.** If a separate admin panel exists (like Boards Beyond Institution), it has its own supply-chain + auth surface.

### Primary = web application

1. **API endpoint IDOR/auth matrix** (§F1 DEFI-FULLSTACK, H1 patterns 001-004).
2. **Underlying smart contract** if the web app touches one. Check:
   - Contract address(es) deployed via this app
   - Whether app-level access control matches contract-level access control
   - Whether the frontend enforces a check the contract doesn't (frontend-only = bypass)
3. **DNS + subdomain enumeration** (§F3 DEFI-FULLSTACK). Discover internal/staging/admin subdomains.
4. **Infrastructure exposure:** cloud metadata endpoints, RPC proxy (rule #26), Redis, Kubernetes dashboards.
5. **SSO / IdP:** OAuth2/OIDC flow, SAML, JWT issuance (JWT Arsenal if triggered).

### Primary = bridge / cross-chain

1. **Source validation on EVERY chain the bridge touches.** Rule #23.
2. **Relayer off-chain:** who signs? What's the key management? Is there a frontend for operators?
3. **Replay protection TTL** on each chain.
4. **Monitoring infrastructure** — bridge teams often run Grafana/Prometheus that's publicly CT-logged.
5. **Express path vs normal path** validation symmetry (Axelar CrossCurve $3M lesson).

### Primary = infrastructure / supply chain

1. **Working backward:** what application uses this infra? The vulnerability flow is infra → app → user.
2. **Adjacent cloud surfaces:** if a Grafana is exposed, is the Prometheus metric endpoint also exposed?
3. **Same-account AWS enumeration:** if you find one misconfigured S3 bucket, scan sibling buckets in the same naming pattern.
4. **Dependency graph:** a vulnerable package in one product likely ships in others from the same vendor.

---

## Integration with the lifecycle

Surface layering is **not a separate skill**. It is a discipline applied within the existing gravedigger / mrrobbot workflow:

- **Phase 1 (Protocol Intelligence):** when listing the protocol's assets, do not stop at "contracts on mainnet." Enumerate ALL surfaces the program covers.
- **Phase 2 (Surface Mapping):** map each surface independently. Do not skip Web2 if your primary interest is SC.
- **Phase 3 (Kill Gate):** a finding on surface X may kill on X but survive on Y. Re-examine every killed finding through the lens of adjacent surfaces.
- **Phase 5 (Attack Chains):** cross-surface chains are the highest-value findings. Smart contract drainable only via a Web2-extracted admin token = cross-surface chain.

---

## Heuristic: what to expect per surface

| Surface | Volume of findings | Typical payout tier | Depth required |
|---------|-------------------|--------------------|-----------------|
| SC (mature protocol) | Low — competition saturates | Critical $50K-$250K, Medium $5K-$25K | Deep (2-4 weeks per contest) |
| SC (new deployment) | Medium | Same tiers | Medium (1 week) |
| Web2 (API + auth) | High | Medium $2K-$25K, High $10K-$75K | Shallow (1-3 days) |
| Relayer / paymaster | Low-Medium | High $10K-$100K | Medium (2-5 days) |
| Frontend bundle (secrets, config) | High | Low-Medium $500-$5K | Shallow (few hours) |
| Infrastructure (CDN, DNS, cloud) | Medium | Low-Medium $500-$10K | Shallow-medium |
| Supply chain (deps, CI) | Low | Medium-High $5K-$50K | Medium-deep |

**Implication:** on programs saturated in SC (104+ submissions = rule #30), the SC surface yields near-zero additional findings per hour. Layering to Web2/relayer/supply-chain produces a 3-5x better $/hour in that regime.

---

## Anti-pattern: silo'd hunting

Do not submit findings on one surface and "come back later" for the adjacent surfaces. Three reasons:
1. Context window is lost (you've paged out the protocol internals; re-loading costs 4-6h).
2. Deadlines move (contest ends, bounty tier caps).
3. Another hunter fills the gap (a Web2 finding on a Critical SC program will be found by the 3rd researcher through if you wait).

**Rule:** if you found something on surface X, before submitting, spend 2-4 hours scanning the adjacent surfaces Y and Z. Submit findings as a single session, ordered by strength (strongest first per Phase 7).
