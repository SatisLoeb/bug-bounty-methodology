"""Accrual conservation & cadence analysis.
Per chunk: borrower interest (RAY, half-up) vs supplier reward + protocol fee booked
(supply index growth * supplied + revenue shares * new index).
Cadence: 1 x 100d vs 100 x 1d vs 1000 irregular, $1M market, 18 and 7 decimals.
Also: can a permissionless update_indexes caller (arbitrary cadence) make
floor(supply claims) exceed cash + ceil(debt)?  -> backing slack tracking.
"""
import random
from xoxno_math import *
from sim import Market, Revert, dirty_params

random.seed(7)
DAY = 86_400_000

def dirty_index(lo, hi):
    return random.randrange(lo, hi) | 1

def per_chunk_conservation(trials=3000):
    print("== per-chunk RAY conservation: (new supply value + new revenue value) - (old supply value) <= borrower interest")
    worst = -10**60; wc = None
    worst_tok = -10**30; wtc = None
    for _ in range(trials):
        dec = random.choice([5, 7, 18])
        p = dirty_params(dec, reserve_bps=random.choice([0, 1, 1337, 9999]))
        supplied = random.randrange(10**20, 10**40) | 1
        borrowed = random.randrange(1, supplied) | 1
        si = dirty_index(RAY, 10**30); bi = dirty_index(RAY, 10**30)
        dt = random.choice([1, 13, 1000, DAY, 30*DAY, MILLISECONDS_PER_YEAR])
        try:
            nbi, nsi, rev, info = accrue_step(p, borrowed, supplied, bi, si, dt)
        except MathOverflow:
            continue
        interest = ray_mul(borrowed, nbi) - ray_mul(borrowed, bi)          # what borrowers now owe (half-up)
        old_sv = ray_mul(supplied, si)
        new_sv = ray_mul(supplied + rev, nsi)                                # incl. revenue shares
        leak = (new_sv - old_sv) - interest                                  # >0 means supply claims grew more than debt
        if leak > worst: worst, wc = leak, (dec, supplied, borrowed, si, bi, dt, info)
        # token-level: floor(supply) growth vs ceil(debt) growth
        tl = (unscale_supply_floor(supplied + rev, nsi, dec) - unscale_supply_floor(supplied, si, dec)) \
             - (unscale_borrow_ceil(borrowed, nbi, dec) - unscale_borrow_ceil(borrowed, bi, dec))
        if tl > worst_tok: worst_tok, wtc = tl, (dec, supplied, borrowed, si, bi, dt)
    print(f"  max RAY leak (supply+revenue growth - borrower interest) = {worst}  (1 RAY unit = 1e-27 token)")
    print(f"  max token-level leak (dfloor(supply) - dceil(debt)) = {worst_tok} at {wtc[:2] if wtc else None}")

def cadence(dec, reserve=1500, util_target=0.61):
    print(f"== cadence, dec={dec}, $1M market (price $1), util≈{util_target}")
    p = dirty_params(dec, reserve_bps=reserve)
    S = 1_000_000 * 10**dec + 7_919
    B = int(S * util_target) + 104_729
    def run(schedule):
        m = Market(p, supply_index=1_003_718_291_300_000_000_000_000_001, borrow_index=1_001_234_567_891_234_567_891_234_567)
        m.supply("L", S)
        m.borrow("X", B)
        s0 = m.snapshot()
        slack0 = m.backing_slack()
        min_slack = slack0
        for dt in schedule:
            m.accrue(dt)
            min_slack = min(min_slack, m.backing_slack())
        debt_growth = unscale_borrow_ceil(m.borrowed, m.borrow_index, dec) - unscale_borrow_ceil(s0["borrowed"], s0["bi"], dec)
        sup_growth = unscale_supply_floor(m.supplied, m.supply_index, dec) - unscale_supply_floor(s0["supplied"], s0["si"], dec)
        lp_claim = unscale_supply_floor(m.sup["L"], m.supply_index, dec) - S
        rev_claim = unscale_supply_floor(m.revenue, m.supply_index, dec)
        return dict(bi=m.borrow_index, si=m.supply_index, debt_growth=debt_growth, sup_growth=sup_growth,
                    lp_gain=lp_claim, rev=rev_claim, slack_after=m.backing_slack(), slack0=slack0, min_slack=min_slack)
    total = 100 * DAY
    r1 = run([total])
    r2 = run([DAY] * 100)
    irregular = []
    rem = total
    while rem > 0:
        d = min(rem, random.choice([1, 999, 60_000, 3_600_000, 7 * 3_600_000, DAY // 3]))
        irregular.append(d); rem -= d
    r3 = run(irregular)
    r4 = run([1_000] * (total // 1_000) if dec == 7 else [60_000] * (total // 60_000))  # 1s cadence (dec 7) / 1 min
    for name, r in (("1x100d", r1), ("100x1d", r2), (f"{len(irregular)} irregular", r3), (f"{len([1]*(total//(1000 if dec==7 else 60_000)))}x fine", r4)):
        print(f"  {name:>16}: debt_growth={r['debt_growth']} supply_growth={r['sup_growth']} lp_gain={r['lp_gain']} rev={r['rev']} "
              f"unbacked(sup-debt growth)={r['sup_growth']-r['debt_growth']} slack0={r['slack0']} slack_after={r['slack_after']} min_slack={r['min_slack']}")
    print(f"  cadence spread of borrower cost (max-min) = {max(r['debt_growth'] for r in (r1,r2,r3,r4)) - min(r['debt_growth'] for r in (r1,r2,r3,r4))} token units")

def permissionless_pump(dec, calls=5000):
    """Adversarial: call update_indexes every 1 ms (finest) and track cumulative floor(supply) - ceil(debt) drift."""
    print(f"== permissionless update_indexes every 1ms x {calls}, dec={dec}")
    p = dirty_params(dec, reserve_bps=1337)
    m = Market(p, supply_index=dirty_index(RAY, 2*RAY), borrow_index=dirty_index(RAY, 2*RAY))
    S = 1_000_000 * 10**dec + 7919
    m.supply("L", S); m.borrow("X", int(S*0.83)+13)
    slack0 = m.backing_slack(); mn = slack0; mx = slack0
    for i in range(calls):
        m.accrue(1)
        s = m.backing_slack(); mn = min(mn, s); mx = max(mx, s)
    print(f"  slack0={slack0} min={mn} max={mx}  (slack = cash + ceil(debt) - floor(supply); negative would be unbacked)")
    print(f"  revenue shares={m.revenue} bi={m.borrow_index} si={m.supply_index} invariants={m.check_invariants()}")

if __name__ == "__main__":
    import sys
    if "pump" in sys.argv: permissionless_pump(7, 20000); permissionless_pump(18, 20000); sys.exit()
    per_chunk_conservation()
    permissionless_pump(7, 20000); permissionless_pump(18, 20000)
