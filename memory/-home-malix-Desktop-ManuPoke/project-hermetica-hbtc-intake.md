---
name: project-hermetica-hbtc-intake
description: "Hermetica hBTC (Immunefi, Stacks/Clarity BTC-yield vault, $100k, NO-KYC, hBTC launched Apr-2026) — ACTIVE intake, GO. Fresh ERC-4626 vault w/ DAILY NAV updates + strategy = deposits into Zest+Granite. Seam = stale-NAV / bounded-update (max-deviation) can't-track-crash → stale-high redeem drain, + deposit-front-run-the-reward theft-of-yield. Need scope addresses to pin deployed==HEAD."
metadata:
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
  modified: 2026-07-26T20:19:00.189Z
---

Re-source after Zest V2 (fortress) + Granite (over-saturated NO-GO). Found on Immunefi scan 2026-07-26.
Program `immunefi.com/bug-bounty/hermetica/information`: Stacks/Clarity BTC-yield, **$100k** Crit
(min $20k) / High $20k, **NO KYC**, PoC/local-fork, 13 assets, live 2026-02-12 upd 2026-07-11. Impacts:
theft/perm-freeze of unclaimed yield (High). OOS: no oracle-price testing; prior-audit issues at
docs.hermetica.fi ineligible. Pre-flagged Tier-1 in [[reference-landscape-scan-2026-07-21]].

**WHY THE PICK:** Clarity edge HOT (just did StackingDAO+Zest+Granite); hBTC = NOVEL delta-neutral BTC-yield
vault (swarm has no checklist); **hBTC only launched Apr-2026** (fresher than USDh core the audits mostly
covered: Strata 2024 + Clarity Alliance 2025 on USDh). Cross-protocol: hBTC strategy DEPOSITS INTO ZEST +
GRANITE (traits zest-market/zest-vault/granite-borrower) = the two protocols I just mapped.

**Repo:** github.com/hermetica-fi/hermetica-contracts (Clarity, actively developed — redeem-peg-out-many
#186 just added, "restructure for immunefi" #174, "post-audit fixes" #160). Cloned depth-60 to
~/Desktop/BUGS/hermetica-2026. hBTC contracts: `protocol/vault-v1-2` (ERC-4626 deposit/request-redeem/
redeem/redeem-peg-out[-many]/cancel/fund-claim), `protocol/state-v1` (NAV+params+update-state choke-point),
`protocol/controller-v1` (keeper: log-reward=daily NAV update, settle-pending), `protocol/trading-v1`
(strategy exec), reserve/reserve-fund/hq/fee-collector/blacklist, tokens/token-hbtc.

**⚠ DEPLOYER NOT FOUND via search/repo (relative refs; not under settings principals). MUST get the 13
scope addresses (Immunefi scope tab) to pin deployed==HEAD — repo HEAD is actively dev'd, may be ahead of
live (the Granite lesson: don't audit a non-live version).** Mechanism hunt is version-independent; started
on repo HEAD.

**SEAM (xseam, mechanism-down) — being developed:**
- INVARIANT: share-price = net-assets/supply reflects the FRESH value of the strategy; no money leaves
  (redeem) except against a NAV that tracks real strategy value.
- V (stored) = `total-assets` (state-v1:111), the NAV. Reader: get-share-price/convert-to-assets
  (:189/213) → deposit/redeem. Writer: controller `log-reward` → `update-state` reward path
  (state-v1:673) → `update-total-assets` (:606). LAZY (daily keeper), PRIVILEGED (check-is-protocol),
  BOUNDED (check-max-reward + **check-max-deviation** :711 caps per-update share-price move by max-deviation
  u7; check-update-window; staleness-window u50).
- COUTURE candidates: (1) **bounded-update can't track a fast strategy LOSS** → NAV stays stale-HIGH over
  multiple updates → redeemers exit over-valued → drain/insolvency (Critical direction). Trigger = strategy
  (Zest/Granite) value drop; express-redeem (4h cooldown, rate-limited express-limit u250) front-runs the
  loss-booking. (2) **deposit front-runs the daily reward tx** (separate tx, mempool-visible) → shares at
  stale-low price → capture pending yield = theft-of-yield (High), bounded by max-deviation/update but
  repeatable, must clear cooldown(3d)/express(4h)+fees(perf 10%/express 0.5%).
- OPEN: exact unit/magnitude of max-deviation u7 (bps? → 0.07%); does deposit/redeem gate on staleness-window
  (blocks stale-NAV ops?); redeem price locked at request or redeem (claim share-price=none at create,
  vault:105); is the loss-booking bounded such that a real crash strands stale-high NAV; PoC in Clarinet.

**DEPLOYED PINNED + ==HEAD CONFIRMED (2026-07-26).** Live deployer = **SP1S1HSFH0SQQGWKB69EYFNY0B1MHRMGXR3J1FH4D** (via Hiro FT registry token-hbtc; others test-tokens under SP6XGBD…). Deployed names = `{c}-hbtc-v1` (state-hbtc-v1, controller-hbtc-v1, trading-hbtc-v1, reserve/reserve-fund/fee-collector/zest-interface/hermetica-interface-hbtc-v1, token-hbtc, blacklist-v1, hq-v1) + **`vault-hbtc-v1-2` deployed 2026-04-01 = the scope "Vault" (freshest, Primacy-of-Impact)**. Prior vault-hbtc-v1/v1-1 superseded. **Deployed vault-hbtc-v1-2 == repo HEAD vault-v1-2 BYTE-IDENTICAL (name-normalized, only trailing newline).** Repo=live code, no forward-diff fix pending. Pulled all in-scope → ~/Desktop/BUGS/hermetica-2026/deployed/.

**BOUNDS QUANTIFIED (live state-hbtc-v1):** `check-max-reward` (:529) = reward ≤ max-reward(u5)/bps × total-assets = **0.05%/day**; `check-max-deviation` (:534) = share-price move ≤ max-deviation(u7) = **0.07%/update**; `check-update-window` (:525) = log-reward ≤ once per update-window(u86340≈24h); log-reward keeper-gated (`check-is-rewarder`). Reserve-fund buffers losses (controller handle-loss-covered vs handle-loss-exceeds). **exit-fee=u0 (standard redeem FREE); express-fee u50=0.5% but express rate-limited (express-limit u250, window 24h).** **NO staleness gate on vault deposit/redeem** (grep empty) → ops run against ≤24h-stale NAV.

**SHARPENED SEAM (payable direction = INSOLVENCY):** the max-reward 0.05%/day cap on NAV updates means a real strategy LOSS exceeding the reserve-fund is booked at ≤0.05%/day → a 5% loss strands the NAV stale-HIGH ~100 days. During that window any redeemer exits at the inflated NAV (exit-fee 0, or express 4h) → drains the vault, socializing an amplified loss onto remaining holders → **insolvency**. Class = "bounded update can't track a crash". Trigger = strategy (Zest/Granite/hedge) loss (organic in delta-neutral); attacker OBSERVES loss + front-runs the slow booking (no attacker-caused loss needed → not oracle/flashloan-OOS). Secondary: deposit-front-run-the-daily-reward = theft-of-yield but bounded 0.05%/cap → Medium-marginal.

**MECHANISM VERIFIED (controller handle-loss-exceeds :153):** excess loss (loss − reserve-fund) is subtracted from total-assets via `update-state` reward `is-add:false` → which ITSELF runs check-max-reward(:694)+check-max-deviation(:711). So a loss > 0.05%-of-NAV REVERTS at update-state → keeper CANNOT book a big loss at once → forced ≤0.05%/day. **Stale-high stranding CONFIRMED.** Redeem free (exit-fee 0) + no-staleness-gate + express 4h (rate-limited). ⟹ once a loss starts booking (visible on-chain), any informed holder knows the full loss books over days/months and express/standard-redeems at the still-inflated NAV → drains → amplified deficit socialized to passive holders = run/first-mover insolvency.

**THE PAYABILITY GATE (unresolved — determines GO):** finding is LATENT — needs a loss EXCEEDING the reserve-fund (organic delta-neutral: funding spike / hedge slippage / Zest-Granite bad debt; NOT attacker-caused → not oracle/flashloan-OOS, but also not attacker-triggered). Per [[feedback-trigger-reachability-is-payability-gate]] + [[feedback-window-finding-measure-both-bounds]]: MEASURE both bounds — (a) reserve-fund LIVE size vs (b) realistic loss magnitude/rate. If reserve-fund covers realistic losses → trigger unreachable → HARDENING not payable (Berachain shape). If a plausible loss exceeds it → payable insolvency. NOT YET MEASURED.

**REACHABILITY GATE = PASSES → GO (measured live 2026-07-26, notes/reachability.py):** NAV(total-assets)=**52.65 BTC** (5,265,260,723 sats); **reserve-fund loss buffer = 0.125 BTC = 0.2375% of NAV** (tiny — young vault, buffer=5%-of-profits). reserve(liquid sBTC)=52.65 BTC (=full NAV, redemptions fundable), trading=0 (positions off-chain/in-Zest; yield real: share-price 1.018 = +1.8% since Apr-01). Booking cap 0.05%/day. ⟹ **any loss >0.24% of NAV strands NAV stale-high** (0.5%→~5d, 1%→~15d, 5%→~95d), realistic for delta-neutral (few days negative funding / one bad hedge-rebalance / Zest-Granite bad-debt on lent sBTC). BOTH window bounds measured (rate 0.05%/day + buffer 0.24%); realistic loss exceeds buffer → NOT an impossible-deficit. Standard redeem = no rate-limit + exit-fee 0 + 3d-cooldown ≪ weeks-stranding.

**PRICE-LOCK / SINK CONFIRMED (vault redeem path):** request-redeem→create-claim locks shares, assets=none, ts=now+cooldown (3d std / 4h express). `fund-claim` (:237) **has NO caller assert** — reads `get-share-price` at fund-time + calls `process-claim`. `process-claim` (:301) gate (:314): with `(some is-manager)`, funds if `(or is-manager is-cooled-down)` → **a NON-manager funds their OWN claim once cooled-down**, locking assets = shares×share-price(fund-time)/share-base, then subtracts from NAV + burns shares; `redeem` (:147) pays the locked assets from reserve after ts. exit-fee 0.

**COMPLETE UNPRIVILEGED ATTACK:** (1) hold hBTC, request-redeem → 3d cooldown; (2) wait cooldown → claim now fundable by attacker ANYTIME, indefinitely; (3) when organic loss strands NAV stale-high (weeks ≫ 3d cooldown), fund-claim(self,cooled-down) locks payout at INFLATED share-price → redeem pulls inflated sBTC from the full-liquid reserve (52.65 BTC); (4) passive holders under-backed → insolvency. Cooldown is NOT a defense (pre-position the claim). Source(stale-high NAV: 0.05%/day cap + 0.24% buffer) + sink(fund-at-stale-price, permissionless-after-cooldown) both on live code. Unprivileged, reachable (organic loss >0.24%).

**CLARINET PoC PASSES (2026-07-26)** — `poc/poc-stale-nav-drain.test.ts` on the repo harness (repo==deployed byte-identical). Ran on the ACTUAL hBTC contracts: 2 equal holders deposit 100 BTC each (NAV 200, reserve 200); 20 BTC strategy loss modeled as protocol-authorized reserve outflow (Zest not simnet-loadable) → reserve 180, **NAV stays STALE-HIGH at 200** (0.05%/day cap can't book it); attacker funds OWN claim (non-manager, cooled-down) at share-price 1.0 → redeems **full 100 BTC** → reserve drained to 80; passive holder's fund-claim **REVERTS ERR_INSUFFICIENT_BALANCE (u105001)** — the 20 BTC loss fell entirely on the passive holder, attacker escaped their 10 BTC share. evidence/poc-output.txt. Setup gotcha (for re-run): needs `npx clarigen` to generate tests/clarigen-types.ts + `npm i @stacks/clarinet-sdk@3.13.1` first.

**RE-HUNT AFTER OPERATOR PUSH ("on laisse tomber si facilement?") → EXHAUSTED NULL (2026-07-26, defensible now w/ artifacts).** I'd conceded on ONE seam; re-hunted the 11 skipped contracts. REGISTRE: (1) trading-hbtc-v1 zest-open/close/swap-and-reward + zest/hermetica-interface = ALL check-is-trader/rewarder → not attacker-reachable; (2) HQ role-grant = check-is-owner + timelock (initProtocol confirms) → NO become-the-actor (attacker can't get trader/rewarder); (3) swap (state check-swap-auth:576) = trading-enabled-gated strategy op, not user-facing; (4) deposit (vault:73) = proportional + DONATION-RESISTANT (total-assets is booked var not balanceOf → NO first-depositor inflation attack) + transfers sBTC straight to reserve; (5) **deposit-front-run-the-daily-reward** — the one ATTACKER-CREATED angle (attacker deposits pre-reward → captures existing holders' pending yield → passes the actor triangle, PoC reaches-not-builds, trigger=guaranteed daily) — **KILLED by live deposit-cap: cap=50 BTC < NAV=52.65 BTC → net-assets+assets>cap → ALL deposits revert ERR_DEPOSIT_CAP_EXCEEDED → attacker can't enter, f=0** (notes/frontrun.py). Only conditionally reachable if DAO raises cap or a redemption frees small room = marginal. Un-checked low-EV residue: blacklist bypass, cancel-redeem (express-cancel #162/163), redeem-peg-out sBTC-source, interface cross-protocol accounting (trader-gated).

**STATUS: NEAR-MISS → DO NOT SUBMIT (operator caught it 2026-07-26). = PERENA #83 REDUX.** The PoC passes but the finding DIES ON THE ACTOR, not the mechanism — exactly Perena (junior exits at stale share_price BEFORE trusted booking = rejected 2×) and Berachain (latent, slashing-triggered). Hermetica = holder redeems at stale NAV BEFORE keeper books the organic loss. NOT attacker-caused. **TELL I ignored: my PoC BUILT the state** (granted wallet1 protocol role + transferred sBTC out to fake the loss) = the "PoC builds the state" signal for a non-reachable finding [[feedback-findings-die-on-the-actor-not-the-mechanism]]. **Confirmed no attacker-CREATED version:** every user fn (deposit / redeem-via-fund-claim) moves real sBTC + booked NAV PROPORTIONALLY → attacker can't manufacture a real-vs-booked divergence; the divergence only comes from the strategy (organic loss, oracle/cross-protocol-OOS to induce) or the keeper (reward). Only attacker-reachable variant = deposit-front-run-the-daily-reward → bounded 0.05%/day + 3-day cooldown = marginal Medium, and Hermetica has NO Medium tier → unpaid. **METHODOLOGY MISS: I ran the REACHABILITY gate (is a loss realistic? yes) and mistook it for the ACTOR gate (does the attacker cause/CREATE the adverse state? no). Run the actor gate FIRST, before reachability + PoC.** PoC artifacts retained (poc/, evidence/) as the mechanism-proof, but NOT submittable. → RE-SOURCE. ~/Desktop/BUGS/hermetica-2026. [[feedback-window-finding-measure-both-bounds]] [[feedback-trigger-reachability-is-payability-gate]] [[project-zest-v2-intake]] [[feedback-trigger-reachability-is-payability-gate]] [[feedback-window-finding-measure-both-bounds]]
