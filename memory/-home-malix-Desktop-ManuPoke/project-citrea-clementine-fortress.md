---
name: project-citrea-clementine-fortress
description: Citrea/Clementine (HackenProof) — thought thin-competition (BitVM niche), actually a Sigma Prime v2.0 + Cantina-competition fortress. First-pass thin-seam hunt = EXECUTED NULL. RE-SOURCE.
metadata:
  type: project
---

Citrea (BitVM Bitcoin rollup) + Clementine (two-way-peg bridge). HackenProof, KYC+PoC required, AI-no-PoC rejected.
Crit $25k-250k / High $10k-25k. Difficulty signal: **473 submissions, $2,100 paid, 174 hackers**. Repos cloned
~/Desktop/BUGS/citrea-2026 (clementine@vtmp.testing.5, citrea@v2.6.0-rc.1, token-bridge).

**SATURATION MISJUDGED (recurring lesson): I picked it as "thin-competition BitVM niche" — WRONG.** The repos' audits/
folder contains **Sigma Prime v2.0 (CMT-01..36) + a Cantina competition report**, covering exactly the crown-jewel seams
(deposit.rs/operator.rs/verifier.rs/aggregator.rs/musig2.rs/rpc/*). Their findings (CMT-01 OOB panics, is_profitable
underflow, is_deposit_valid extraneous-operators, premature-disprove theft) are Resolved = dup/ineligible. NOT under-reviewed.

**FIRST-PASS HUNT = EXECUTED NULL (rigorous, 5 thin-competition seams):**
- Deposit/withdraw verification: 2-audit fortress, all findings resolved/dup.
- Presigning/auth (MuSig2 + gRPC): auth interceptor = exact DER cert-pinning (interceptors.rs:36 only_aggregator_and_self), heavily audited, null.
- CLI/Bitcoin: deposit-address re-derived + checked against funded UTXO (aggregator.rs:2163/2261/2345); the hardcoded-placeholder
  recovery key is a Regtest dev-default that produces deposit REJECTION not silent-freeze. Negative space.
- bitcoin-da parsing (parsers.rs parse_relevant_transaction): no mis-acceptance survives.
- LCP determinism + batch-proof native-vs-circuit: no HashMap/float/time/rand; retarget/MTP math has EXISTING differential
  tests vs real Bitcoin-Core mainnet headers across retarget boundaries (verifier.rs:731-809) that pass. Non-determinism structurally impossible.
VERDICT: fortress, RE-SOURCE. The residual (ZK circuit internals) is specialized + "unusually disciplined". Don't re-hunt from scratch.
See [[feedback-check-prior-audits-and-competitions-at-intake]].
