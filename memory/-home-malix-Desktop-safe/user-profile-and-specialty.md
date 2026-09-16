---
name: user-profile-and-specialty
description: Who the user is as a security researcher — top-tier standing and a demonstrated edge in the split-normalization / case-sensitivity / auth-bypass class; use this to calibrate targeting and the submit bar.
metadata: 
  node_type: memory
  type: user
  originSessionId: 4a3f4193-6fbd-420c-a4af-5e9e6b7f522d
  modified: 2026-08-25T21:45:32.060Z
---

Independent security researcher (authorized channels only: public bug bounties + coordinated OSS disclosure). Handles: malix / SatisLoeb / MalikX31 / malikb31s / Xvush. Reviews Go, Rust, Solidity, Clarity, Python, JS; root-cause of protocol/parser logic; local fork/testnet PoCs.

**Standing (verifiable):** currently #1 on a program leaderboard as `malikb31s` (reputation 38). Track record includes CVE-2026-44288/GHSA-q6x5-8v7m-xcrf (protobufjs), GHSA-g3qj-j598-cxmq (fido2-lib), Cantina @SatisLoeb (1 critical, $10k), Immunefi MalikX31 (1 critical + 1 high, $5k), and two Transak Criticals: #3579821 (Case-Sensitivity Bypass on api.transak.com) and #3619539 (google_oauth grant-type → partner account takeover).

**Demonstrated edge (his paying class):** the split-normalization / case-sensitivity / signature-scope-mismatch class — a control that verifies over one normalization of a value while an authorization/resolution decision reads a different one. Proven across THREE distinct targets: Decentraland #87537 (case-sensitive scene-signer guard vs lowercased signed payload), Transak #3579821 (case-sensitivity bypass on the API surface), and the ENS normalization vein. When targeting for him, lean into this class first (auth/resolution seams where two normalizers disagree).

**How to apply:** his reputation is an asset a weak submission damages — the submit bar is "a clean Critical of a class that fits this profile", not "a valid finding". See [[submit-bar-reputation-over-fee]]. Non-refundable Immunefi fees make a dup/known-issue close a straight reputation+fee loss; hold weak/fold-in-risk findings on the merits.
