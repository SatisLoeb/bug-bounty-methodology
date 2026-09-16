---
name: sky-fresh-surface-audit
description: Sky (ex-Maker) Immunefi fresh surfaces (pas + diamond-pau PAU facets) — measured NO-GO, form-null in prod + audited-at-scope-commit
metadata:
  type: project
---

Sky Immunefi (`sky`): SC Critical up to $10M (10% funds, $150k floor), NO KYC, PoC req, **Primacy of Rules**,
255 assets. Folder `sky/`. Audited 2026-09-15, 18-finder fanout (wf_cb38dd85).

**Verdict: MEASURED NO-GO on the fresh surface.** No payable finding.
- **Fresh veins**: pas (BeamState/Configurator/Timelock/PASMom), diamond-pau (25 facets + Beacon + PAUFactory),
  SBEBeam/FarmOwner, stUSDS spells, star-guard, subproxy-methods.
- **SCOPE EDGE (literal)**: diamond-pau in-scope = 25 facet impls + Beacon + PAUFactory ONLY. Core
  (Controller/ALMProxy/AccessControls/**RateLimits**/ControllerSharedStorage) UNLISTED → OOS. So rate-limit
  enforcement (the whole trust model) lands OOS. aave-v4/dual-pool/nfat-*/psm3 + all I*Facet interfaces = OOS.
- **Exec model**: constrained ALLOCATOR keeper → facet → ALMProxy.doCall (funds) bounded per-key by RateLimits;
  **unset key REVERTS** (`RateLimits/zero-maxAmount`); auditors STIPULATE in writing "compromised allocator
  contained by rate limits" (ChainSecurity v1.14 SC1) → allocator findings pre-capped below Critical.
- **Two premise-falsifications (verified myself)**: (1) pas is NOT 0-audit — Cantina reviewed it at the exact
  scope commit `947e71cd` → 0 Crit/High/Med/Low; my "0-audit" rank was a flaky-clone error (checked pas/audit
  before it cloned, never re-checked). (2) Materiality ~$0 on-chain: only deployed in-scope PAU = Grove,
  ALMProxy `0x0DcD9298…A153` holds 0 USDS/1wei USDC/0 ETH, `integrations()`=4 facets (USDS/PSM/BASIN/UNIV3),
  NONE async/AMM → 21/25 facets form-null. Real $590M JTRSY on LEGACY non-diamond proxy `0x491EDFB0…` (unlisted).
- **6 gated Mediums each dup/trusted/immaterial**: BeamState loosening (dup ChainSecurity PAS), Curve swap
  undercharge (dup CS-SKYDPAU-041, remediated), withdraw exhaustion (dup Cantina v1.11), Centrifuge 3-way
  (recipient=Sky's own admin addr, $0), etc. **Octane v1.12 adversarial engagement** already ran same exercise:
  0C/0H, 26 acknowledged.
- **v1.14→scope(dev v1.15-beta) delta diffed**: in-scope impl changes trivial (comments) or defensive
  (UniswapV4Facet added hooks==0 require + slippage-bounded swap key derivation). New aave-v4/dual-pool = OOS.

**RE-ARM**: when Sky wires+FUNDS async/AMM facets (ERC4626/7540/Centrifuge/Curve/Aave/Pendle) into a deployed
in-scope PAU diamond (watch PAUFactory + integrations() growth) → 21 form-null facets become live. Method:
Immunefi RSC decode; audit-corpus at repos' own audit/ dirs (89 PDFs, 33 diamond-pau + 4 pas); on-chain via
cast + publicnode. LESSON: re-check audit dirs after a flaky clone before ranking a repo "0-audit".
See [[pyth-network-audit]] [[feedback-in-scope-asset-list-is-literal]].
