---
name: avalabs-target-state
description: "Ava Labs (Immunefi avalabs, Web&App) target state — near-fortress, fan-out result"
metadata: 
  node_type: memory
  type: project
  originSessionId: bc465f84-7337-4d09-aead-c6f01b71fc91
  modified: 2026-08-21T22:02:48.899Z
---

Ava Labs — Immunefi program `avalabs` (Web & App category ONLY; distinct from `avalanche` = the SC/blockchain program). Max $10k, PoC+KYC, live since 2023-12 (mature/farmed → invisible-dup risk elevated, see [[farmed-program-dup-baserate]]).

2026-08-21: whole-surface fan-out, 13 subagents (11 + 2 follow-ups: glacier, pvm-builder) + operator Bash verification. **Near-fortress, 0 clean payable Critical/High.** Everything Cloudflare-fronted + hardened. **MODEL CAVEAT: the fan-out actually ran on `claude-opus-4-8` (verified by grepping the "model" field in all 15 subagent transcripts), NOT Fable 5. This is NOT a provisioning gap — Fable 5 IS available on this account (confirmed in the /model picker, labeled "Most capable for your hardest and longest-running tasks"). Real causes: (1) the per-call `model:"fable"` alias is silently DROPPED for subagents (harness quirk — `sonnet` routes fine to claude-sonnet-5, but `fable`/`opus` fall through), and (2) the fallback is the INHERITED main-session model, which was Opus 4.8 at run time. Findings still valid. FIX (applied): set `env.CLAUDE_CODE_SUBAGENT_MODEL="claude-opus-5"` (full ID, precedence #1 — user chose Opus 5 as the floor over Fable) in ~/.claude/settings.json AND set the MAIN session model to Fable so the inherited fallback is also Fable; needs a RESTART; verify with `grep '"model"' tasks/*.output`. LESSON: never trust an agent's self-report of its model — the /model picker is the source of truth for what is provisioned, and the Agent-tool `model` alias is unreliable for subagents (use the full-ID env var).**

Per-surface (all executed-not-conceded):
- backstage.avax-dev.network = Cloudflare Access fortress (0 unauth byte; 55 probes, forged CF-JWT/cookie/service-token all 302). Origin-bypass needs disallowed mass scan.
- api.avax.network / api.avax-test.network = reflect-arbitrary-Origin + ACAC:true CORS (CONFIRMED by me via curl) but **OOS** (public RPC, only __cf_bm cookie, no confidential data). keystore/admin 404, metrics 405.
- glacier-api / data-api / build.avax.network = same CORS but **header-authed** (x-glacier-api-key/Bearer, never cookie) → no ambient cred → theft impossible; build.avax.network cookie-auth is clean (no CORS reflect, SameSite=Lax, __Host/__Secure). All 3 OOS by scope-listing anyway.
- explorer.avax.network ≡ subnets.avax.network (SAME SPA build index-w2w166B4.js) = fortress: 0 app-level HTML sinks in 337 chunks, React auto-escape + DOMPurify on NFT names, static shell (no reflection), CSP no unsafe-inline/eval + object-src none + frame-src self. C1 previewUri sanitizer-bypass (skips @braintree/sanitize-url for data:image/svg+xml & data:application/json) = KILLED 4 ways (render sink is `<img>` inert + no HTML sink for decoded fields + CSP blocks iframe/object). Latent cross-slice: CSP script-src whitelists *.avax.network → a JS-hosting/takeoverable avax subdomain would be script-exec on explorer (doubly-gated, none found).
- faucet.avax-test.network → core.app/tools/testnet-faucet (UI moved; host = Express+WAF). Open-redirect/SSRF/XSS/CSRF all killed (hardcoded dest, config-map not URL, WAF, captcha+coupon).
- stats+notify = fortress. notify access-token emailed-to-bound-address, no IDOR selector, wildcard-no-cred CORS. RESIDUAL (operator-gated): notify /access token FORGEABILITY untested (needs 1 captcha solve + email inbox → request /access twice same email, diff tokens; deterministic ⇒ lead). Indirect evidence = strong (43-byte high-entropy, uniform 400).
- avax.network/www/avalabs.org = static Astro-Vercel-Contentful / Webflow-Cloudflare. Open-redirect (host fixed), XSS (static), API proxies (thin Glacier, no SSRF/IDOR), forms (Iterable public/internal-recipient), secrets (404/403) all killed.
- AvalancheJS (master) = near-fortress. Signed-digest==submitted-bytes holds, CSPRNG, correct HD/bech32, bounded deser. 4 real defects all KILLED (test-only or rejected-tx). PVM/AVM etna-builder spend/change/UTXO all SOUND (empty changeAddresses → rejected tx, not misroute).
- Avalanche-Wallet-SDK (dev; legacy Avalanche Wallet discontinued 2024-03-06, weak in-prod-use) = near-clean. CSPRNG mnemonic, PBKDF2-200k AES-GCM keystore, no key leak. One legacy-only V2-V5 weak pass_hash (needs stolen file, by-design).
- Core extension (ava-labs/core-extension, public) = fortress. Origin from browser-trusted connection.sender.url + cross-check + per-connection closure; 0 XSS sinks; displayData==signingData (core-vm-modules build-tx-approval-request); no externally_connectable/web_accessible_resources. BRIDGE Critical KILLED in source: Fusion recipient = getAddressForChain(net, activeAccount) = connected acct's OWN addr; URL params from/to/amount where `to`=token-selector not address; malicious quote can't redirect (targetAddress separate self-bound arg).

**THE lead — C1 (Core): `*.core.app` takeover = CRITICAL via isSyncDomain.** core-extension: isSyncDomain treats every *.core.app as first-party → canSkipApproval true w/ NO gesture → connect.ts silently connects ALL accounts → CORE_METHODS (addAccount/selectAccount/WALLET_SET_SETTINGS/contacts/ETH_SEND_TRANSACTION_BATCH). Mechanism CONFIRMED. Gate = existence of dangling *.core.app record → **NONE FOUND** (4 CT sources; fide=live Webflow, info=live HubSpot, redesign.*=NXDOMAIN; crt.sh was DOWN → completeness caveat). Latent amplifier / informational; RE-CHECK when crt.sh up or on any new *.core.app CNAME.

ONLY submittable = **report.avax.network** dangling Webflow (cdn.webflow.com 404 while siblings 200) = LOW (subdomain-takeover w/o wallet interaction; NOT core.app so no isSyncDomain amp). Plausible; dup-risk moderate-high; needs actual Webflow-claim PoC (operator-gated outward action). buy.avax.network = CF-1016 dangling origin but target hidden → unprovable.

Browser-gated residuals (low-EV): core.app faucet render-sink XSS (CSP-nonce likely caps at markup-injection not JS); Core approval fail-OPEN when isSimulationSuccessful===false + selector-collision `To` render (by-design/dup-heavy blind-signing).

RE-SOURCE. Reopen triggers: new *.core.app CNAME / any dangling *.core.app (→ C1 Critical); crt.sh-up re-enum; new cookie-authed endpoint on api.avax.network (→ CORS Critical); notify token proven deterministic.
