---
name: remaining-backlog-2026-09-04
description: "Post-Grafts-1+2+3 backlog (no blockers): #1 vault DR (arbiter share single-copy on local Redis, infra risk), Graft 2 site-1 (UX), arbiter-out-of-relay (long-term), PROTOCOL.md refresh."
metadata: 
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-04T00:55:14.920Z
---

Remaining backlog as of 2026-09-04, after Grafts 1+2+3 shipped to prod ([[prod-graft3-live-2026-09-03]]). Short, known, no blockers. Priority order:

1. **Vault DR — the most serious remaining item (infra, NOT crypto).** The arbiter's per-escrow FROST
   key_package (its 2-of-3 share) is generated at DKG `part3` and stored **only** in the local Redis
   vault (`server/src/services/arbiter_watchdog/key_vault.rs`). It is NOT re-derivable from
   `ARBITER_VAULT_MASTER_PASSWORD` (the master password derives the arbiter *identity*, not the
   group-key *share*, which depends on the DKG exchanges with that specific buyer/vendor). **Failure
   mode if Redis is lost with no off-machine backup:** consensual releases (buyer+vendor) still work,
   but **disputed escrows become unresolvable** (winner+arbiter needs the lost share → 2-of-3
   unreachable → funds stuck). Bounded (disputes only) but real fund-loss risk. **Mitigation:**
   off-machine ENCRYPTED backup of the vault (arbiter key_packages), encrypted under the vault master
   password (already the KDF root) — no crypto-model change. (Re-derivable share / backup arbiter /
   social recovery are heavier and tension with the threshold model.)

2. **Graft 2 site 1** — early per-partial reject at submission (`submit_partial_signature`), naming
   the role before the second signer acts. UX/timing only; safety is already the reference verifier +
   the site-2 attribution shipped in `5852422`. Needs the first/second-order plumbing on a bare site
   (see the Graft 2 commit body + agent trace).

3. **Arbiter out of the relay process** — long-term chantier (decouple the auto-signing arbiter from
   the relay server process).

4. **PROTOCOL.md refresh** — reflect the Graft 3 DKG envelope (identity-signed + encrypted round-2)
   and the Graft 1 nonce DLEQ. PROTOCOL.md is already stale vs `escrow_clsag.rs`
   ([[protocol-md-stale-vs-escrow-clsag]]).

Also tracked separately: reproducible builds ([[reproducible-builds-gap-2026-09-04]]) — binary via
BUILD=1 next build; WASM verifiability chantier scoped in `DOX/HARDENING-PLAN-wasm-verifiability.md`.
