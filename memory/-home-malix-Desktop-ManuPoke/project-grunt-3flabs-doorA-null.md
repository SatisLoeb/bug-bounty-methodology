---
name: project-grunt-3flabs-doora-null
description: "grunt (3F Labs, Cantina) Door-A non-theft hunt = dedup-proven NULL; RWA-orchestration, 2xChainSecurity+2xCantina audited, huge OOS list pre-empts every non-theft class"
metadata: 
  node_type: memory
  type: project
  originSessionId: 399efac4-1073-4669-9c21-60111c4ae1a6
---

grunt by 3F Labs — Cantina bug bounty. Scope = all Solidity in /src on main (HEAD 96a18e3), EXCLUDING facility/IntentDescriptor.sol. Repo: github.com/3FLabs/grunt, cloned /home/malix/Desktop/BUGS/grunt-2026 (Foundry, builds `forge build`; deps forge-std/solady/morpho-blue[3FLabs fork, lib/=OOS]). Severity (operator-supplied verbatim): Crit=severe-fund-loss/permanent-system-disruption/widespread-compromise; High=notable-loss/significant-user-trust-harm; Med=limited-damage/moderate-impact. Operator mandate: **NON-THEFT only (fund-theft exhausted)**.

Architecture: RWA-leverage orchestration — Facility (intent hub, ERC-6909 LP shares) + Request/PT-YT bridge-loans + Funds (Centrifuge/Pareto/USCC adapters) + Morpho PositionManagers + MorphoFlashLoanRequest + TransferGuard compliance. ~11k impl LOC.

**4 audit reports IN-REPO (audits/): 2x ChainSecurity (2026-04, V1→V6 iteration, 66 findings mostly Code-Corrected) + Cantina 2026-05 (48 issues: 17 fixed/31 ack) + Cantina FeeReview (4 info, all fixed PR193).** The dominant found class IS permanent-DoS/brick/reentrancy/state-corruption (exactly the non-theft target) — audits mined it hard. The huge OOS list = the acknowledged/won't-fix subset. Extract audits at INTAKE via pdftotext to dedup (the Reserve lesson — applied here day-one).

**Door-A darkside hunt (incomplete-fix siblings + reentrancy-sibling + cross-intent isolation + non-recoverable-freeze) = HONEST NULL, hand-verified 2026-07-20.** Every untrusted-reachable non-theft candidate resolves to OOS / dup / operator-recoverable / deadline-bounded:
- **setRepaid-delay (3.1.1 mint(0,0), fixed 69a9a3) + siblings (consume)** = DEADLINE-BOUNDED not permanent: `_canWithdraw = repaid || block.timestamp>=repaymentDeadline` (Request.sol:188), `_syncWithdrawalStatus` auto-flips after deadline (:199), no-revert-branch. Deadline auto-unlock is explicit OOS. Caps at Med/OOS.
- **preLiquidate/onMorphoRepay reentrancy (3.4.8, by-design)** = MorphoBorrowPosition.sol:266-282 devs INTENTIONALLY not-nonReentrant, safety rests on unenforced "no callback-capable address holds MINTER/FACILITATOR" invariant — attacking it = OOS trusted-role. state-changers all role-gated+nonReentrant.
- **NEW candidate found+killed: permissionless repay() donates asset above setRepaid's maxBalance → ExcessiveBalance revert (Request.sol:266)** — REFUTED: maxBalance is owner-supplied (owner passes type(uint256).max to escape, :254), deadline auto-flips, attacker LOSES donated assets to YT. operator-recoverable+bounded+self-harming = below Med.
- FacilityLP cap tracks CURRENT totalSupply (restored on withdraw), claim iterates own-intent keys only (no cross-intent). VaultController redemption CEI + live-balanceOf mispricing = OOS 3.2.4 view-drift. OfferReceiver nonce advances before callback (no replay).

The 2 conceded open bricks (3.2.6 zero-clipped-NAV, 3.3.13 oracle-revert-DoS) require a TRUSTED oracle/NAV/compliance surface, not untrusted — ACK not new. **FINAL: grunt non-theft Door-A = dedup-proven NO-GO for untrusted-reachable findings.** Residual only via a pure Door-C composition (low-EV given OOS exhaustiveness) or the deployment role-census (off-scope/OOS). RE-SOURCE. See [[feedback-payable-impact-not-just-theft]] (impact-ledger applied correctly — hunted all non-theft rows, honestly null) · [[project-reserve-dtf-filler-seam-null]] (same pattern: mega-audited Cantina target, dedup kills residuals).