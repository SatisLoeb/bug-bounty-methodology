---
name: blockchain-monitor-poll-bottleneck
description: "blockchain_monitor poll cycle is starved under a slow remote node — polls dead escrows, no circuit-breaker, 300s per-refresh timeout; funding detection lags. TODO optimize."
metadata: 
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-03T22:41:44.791Z
---

**STATUS: FIXED + shipped to prod 2026-09-03** (commit `3b9c90c`, artefact `e46211a5`, see [[prod-graft3-live-2026-09-03]]): the poll now skips `funded` escrows whose capture completed (all release-required funding_* fields set), a circuit-breaker backs off escrows past 5 consecutive failures (permanent view_key-mismatch → ceiling immediately), and the poll-path HTTP/refresh timeout dropped 300→75/60s (the deep one-shot scan in wallet_scanner.rs kept its own 300s). Also fixed the `underfunded` cul-de-sac (added to the poll whitelist) and dropped `active` from the pending-tx query. `cargo check` green; no migration. Original analysis (kept for context) below.

The `blockchain_monitor` funding-detection poll loop (`server/src/services/blockchain_monitor.rs`, `check_escrow_funding`) becomes a bottleneck under a slow remote daemon (observed on `xmr-node.cakewallet.com:18081`, 2026-09-03 post-crash session).

**Observed sur pièces:** log says `Polling 7 funded escrows (parallel, batch_size=4)`; one batch = `Batch 1/3 completed: 4 escrows in 233.151s` (~4 min). An active escrow (`esc_0cea…`, arbitration test) got checked only ~once every 4-5 min, so `payment_detected → EscrowFunded` lagged the real on-chain unlock by up to ~5 min.

**Root causes:**
1. It polls **terminal/dead escrows** too (completed, refunded, and corrupt ones), not just active/payment_detected.
2. **No circuit-breaker:** `esc_fd050997d2cc469e` (placeholder view_key `abab…`, view-key-doesn't-match-address = permanently unmonitorable) still gets retried every cycle — logged "failed 7 consecutive times" and kept going.
3. **300s per-refresh timeout** (Step 4: "HTTP client built with 300s timeout") inside a poll loop — one hung wallet-refresh against a slow node stalls its whole batch for up to 5 min.
4. Refreshes serialize per batch against a single slow node.

**Why:** funding/unlock detection is on the critical path (buyer can't proceed until `EscrowFunded`); a slow node + dead-escrow noise multiplies the delay.

**How to apply (optimization TODO):**
- Skip escrows in terminal states (completed/refunded) in the poll query.
- Quarantine escrows that fail N consecutive times (esp. the "view_key doesn't match multisig_address" data-corruption class) instead of retrying forever.
- Cap the per-refresh timeout much lower in the poll (e.g. 20-30s), separate from any long one-shot sync path.
- Prioritize active / payment_detected escrows ahead of stale ones.
- Node health-aware selection / failover (hashvault responded fast; cakewallet slow/flaky — see the release path's round-robin BROADCAST_FALLBACK_NODES for a pattern).

Related: the server self-spawns an arbiter wallet-rpc on **port 18085** via its internal watchdog (not one of the 4 started by hand on 18082/18083/18084/18086); its cakewallet refreshes were the ones hitting the 300s timeout.
