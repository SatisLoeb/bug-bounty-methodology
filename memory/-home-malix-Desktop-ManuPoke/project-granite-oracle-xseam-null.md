---
name: project-granite-oracle-xseam-null
description: "Granite Protocol (Stacks/Clarity lending, Immunefi $100k, KYC) — oracle-adapter xseam = MEASURED NULL. KEY: HEAD (Pyth-Lazer, #78) is UNSHIPPED; mainnet deployed = Pyth-Core; decoder/wormhole = Trust Machines stock (not Granite). RE-SOURCE. Web frontend = only fresh payable, off SC-edge."
metadata:
  node_type: memory
  type: project
---

Granite = Stacks/Clarity BTC-lending, Immunefi **$100k max Crit** (July note's "$1M" = pool total), KYC (operator cleared). 31 assets, Last Updated 25 Jul 2026. Repo `github.com/GraniteProtocol/core-v1` @ master. Dossier+ledger `~/Desktop/BUGS/granite-audit/TARGET-DOSSIER.md`.

**Engaged intake→xseam 2026-08-27. Oracle-adapter (Perena-#83 staleness thesis) = MEASURED NULL.**

**THE SCOPE CATCH (reusable):** `core-v1` HEAD is the **Pyth-LAZER** migration (`verify-update`/`prices-for`, commits #78/#83) — **NOT deployed**. Mainnet `SP26NGV9...pyth-adapter-v1` still runs **Pyth-CORE** (`update-pyth`/`read-price`/`verify-and-update-price-feeds`). Auditing HEAD = auditing unshipped code. Always fetch the DEPLOYED source (Hiro `/v2/contracts/source/<addr>/<name>`) before spending depth — HEAD≠deployed here. [[feedback-commit-anchored-scope-pays-deployment-impact]]

**Decoder is 3rd-party:** `update-pyth` delegates to `SP1CGXWEAMG6P6FT04W66NVGJ7PQWMDAC19R7PJ0Y.{pyth-oracle-v4,pyth-storage-v4,pyth-pnau-decoder-v3,wormhole-core-v4}` = official Trust Machines Pyth-on-Stacks (shared, audited). Granite's scope lists pnau/wormhole but Granite doesn't own them. Granite's own glue = `pyth-adapter-v1` (~150 l deployed).

**Kills (attacker-reachable Critical, traced HEAD+deployed):** (1) forge `verified` REFUTED — all money-moves verify-update inline on untrusted buffer; (2) sibling-unguarded REFUTED — borrow/remove-collateral/liquidate gated, repay/add-collateral/LP/stake need no price; (3) stored-price staleness (deployed read-price, time-delta 300s) REFUTED/OOS — is-valid reverts past window, old-VAA rejected by pyth-storage prev-publish-time, window-timing = OOS "no oracle-price testing"; (4) price=0/neg/future-ts non-forgeable (Pyth-signed).

**VERDICT: RE-SOURCE.** Lending core = 6-audit-saturated (Strata/Halipot/ABA×2/Clarity-Alliance×2). Only fresh payable = `app.granite.world` web frontend (gravedigger, full web Critical tier) — off SC-edge. Don't re-drill oracle. Re-open SC only if Lazer migration deploys (already audited null at HEAD). [[project-sbtc-upshift-seam-null]] [[reference-stacks-bugbounty-landscape-2026-07]] [[feedback-findings-die-on-the-actor-not-the-mechanism]]

**WEB frontend (app.granite.world, gravedigger 2026-08-27, passive):** thin-EV, no payable fund-theft. Next.js/Railway/Cloudflare, CSP=frame-ancestors-only (no script-src) but NO XSS sink. Contract addresses config-baked (not swappable). `/api/price`=Pyth-VAA relay (non-forgeable). `/api/referrals/{challenge,claim}`=POINTS (candidate authz seam: does claim bind publicKey↔inviteeAddress? points-farming ceiling, operator-gated to confirm). Subdomain-takeover DEAD (www=claimed Webflow, notapp=mirror). Scope=app.granite.world/+/market only. RE-SOURCE off Granite (3 consecutive Stacks nulls: Zest/sBTC/Granite).
