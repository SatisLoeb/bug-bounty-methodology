---
name: project-treehouse-teth-intake
description: "Treehouse tETH (HackenProof) — proven 2x native-ETH NAV double-count, but PUBLISHED PRIOR ART in team's own audit repo; NO-GO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 62c85e20-9f15-48ab-b362-993acbeeabdd
  modified: 2026-07-25T22:29:59.568Z
---

**Treehouse tETH / HackenProof — NO-GO, prior-art-killed. Don't re-audit.**
Workspace `~/Desktop/ManuPoke/treehouse-fresh` (62 verified sources + 13 audit PDFs + VERDICT.md).

Leveraged wstETH looper. tETH = ERC4626 over a synthetic **IAU** (not over wstETH);
share price = `IAU.balanceOf(tETH)/tETH.totalSupply()`, moved only by
`MS_Accounting → PnlAccounting.doAccounting → NavLens.currentProtocolNav → TreehouseAccounting.mark`.

**F-01 PROVEN then KILLED:** `NavErc20` and `NavErc20WithDebt` both open with
`_nav += _target.balance`, and NavRegistry attaches BOTH to the same strategy with the same
target ⇒ native ETH counted **2.000000×** in protocol NAV. Executed A/B on anvil fork through
the real `currentProtocolNav`; Gearbox strategy (single module) = 1.000000× **control twin**.
Trigger permissionless (`Strategy.receive()` no-op payable), sticky (no action sweeps native
ETH — VaultSend is ERC20-only, LidoWithdrawClaim wraps only the delta), and the bogus mark
passes `maxPnl`. **Killed by `WatchPug tETH EtherFi Audit Report` (2026-03-27) [WP-I4]** in the
team's OWN public repo `treehouse-gaia/audit-report` — quotes the exact line, recommends
"Remove `_target.balance` from this module", status **Acknowledged/unfixed**. Residual (their
stated impact is only the loose intra-module `debt<=_nav` invariant, rated Informational; they
never saw the cross-module composition) = same root line + same fix ⇒ known-issue close.
Same shape as [[project-circle-xreserve-f01-drain]] and [[project-doppler-rehype-intake]].

**F-02 same fate:** `PnlAccounting.PRECISION=1e4` while all comments say 1e6 ⇒ live
`maxPnl()`=517 wstETH = **2.5%**/hour, not the documented 0.025%. Published verbatim as [WP-N5].

**Lesson that generalizes:** the audit-corpus check must include the target's OWN public
`audit-report` repo, and must be run **before** the fork PoC, not after — I had a clean
executed 2× artifact with a control twin before discovering it was published prior art.
Reinforces [[feedback-check-prior-audits-and-competitions-at-intake]]; the new edge is
*grep the vendor's own audit repo by module name*, since 7 of the 13 reports were WatchPug
increments that no search engine surfaces.

**F-03 NavUnStEth — pulled to exhaustion, NULL.** Proven on fork: Lido
`requestWithdrawals(amounts, _owner)` lets the CALLER pick the owner, so an outsider injected
105 requests owned by Strategy0 (118k gas each + 100 wei stETH); they price fine under
`NavUnStEth.nav` and `nav()` costs ~8,467 gas/id (N=5→126k, N=105→973k) ⇒ ~3,500 ids would
gas-DoS `doAccounting`. **Killed on the OFF-CHAIN bound:** injected requests are fully BACKED
(gift, no inflation), so the only impact is DoS — and DoS needs the off-chain list-builder to
ENUMERATE owned NFTs rather than track self-created ids. Decoded a real production
`doAccounting` (block 23568817, Safe 0x7a6f9a6a…): submitted ids for Strategy1 ==
mint/burn-reconstructed owned set EXACTLY (incl. the 101266 gap, another user's request) —
which is consistent with BOTH hypotheses and discriminates NEITHER, since historically every
owned NFT was also self-created. Unmeasured bound ⇒ don't build on it
([[feedback-window-finding-measure-both-bounds]]). Even granting it, ops just filter the list
⇒ recoverable liveness, no fund loss.

Negative space (named in NO report of 13): `NavUnStEth` (now NULL, above),
`LockReleaseTokenPool` (CCIP = imported-contract exclusion), `SimpleStakingERC20`
(read in full, clean), `NavHelper` (parallel READ-ONLY reimpl, not in the accounting path).
Dead ends recorded in VERDICT.md — IAU donation closed by `_update` minter gate, NavAaveV3
registered-but-UNATTACHED dead code, redemption `min(b0,bn)·minC/maxC` deliberate.
