import os
import sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xoxno_model import *
rng = random.Random(4243)
MS_YEAR = 31_556_926_000
MAX_IDX = 10**36

def compound(rate, dt):
    if dt == 0: return RAY
    x = rate * dt
    s = RAY + x; p = x
    for dv in [2, 6, 24, 120, 720, 5040, 40320]:
        p = ray_mul(p, x); s += div_by_int_half_up(p, dv)
    return s

def update_supply_index(supplied, old, rewards):
    if supplied == 0 or rewards == 0: return old
    total = ray_mul(supplied, old)
    if total == 0: return old
    grown = mul_div_floor(total + rewards, RAY, supplied)
    bounded_old = min(old, MAX_IDX)
    return max(min(grown, MAX_IDX), bounded_old)

def accrue_step(reserve_bps, borrowed, supplied, bidx, sidx, rate_ms, dt):
    factor = compound(rate_ms, dt)
    nb = min(ray_mul(bidx, factor), MAX_IDX)
    old_debt = ray_mul(borrowed, bidx); new_debt = ray_mul(borrowed, nb)
    accrued = new_debt - old_debt
    fee = mul_div_half_up(accrued, reserve_bps, BPS)
    rewards = accrued - fee
    ns = update_supply_index(supplied, sidx, rewards)
    distributed = ray_mul(supplied, ns) - ray_mul(supplied, sidx)
    assert distributed <= rewards and distributed >= 0
    shortfall = rewards - distributed
    reward = fee + shortfall
    rev_shares = 0 if reward == 0 else protocol_fee_shares(reward, ns, supplied)
    return nb, ns, rev_shares

# H7: after a step, growth of (supply claims incl. revenue) <= growth of debt (exact rational, RAY value)
viol = 0; ex = None; N = 0; worst = F(0)
for _ in range(40000):
    d = rng.choice([7, 9, 18])
    sidx = dirty_index(rng); bidx = dirty_index(rng)
    if bidx < RAY: bidx += RAY
    supplied = rng.randrange(1, 10**(d + 12)) * 10**(27 - d) + rng.choice(PRIMES)
    borrowed = rng.randrange(0, supplied + 1)
    rate_ms = rng.choice([1, 37, 1_000_003, RAY // MS_YEAR // 20, RAY // MS_YEAR, 2 * RAY // MS_YEAR])
    dt = rng.choice([1, 13, 5_000, 86_400_000, MS_YEAR])
    reserve = rng.choice([0, 1, 1000, 2500, 9999])
    nb, ns, rev = accrue_step(reserve, borrowed, supplied, bidx, sidx, rate_ms, dt)
    N += 1
    claims_before = F(supplied * sidx, RAY)
    claims_after = F((supplied + rev) * ns, RAY)
    debt_growth = F(borrowed * (nb - bidx), RAY)
    if claims_after - claims_before > debt_growth:
        viol += 1; ex = ex or (d, sidx, bidx, supplied, borrowed, rate_ms, dt, reserve, float(claims_after - claims_before - debt_growth))
    worst = max(worst, (claims_after - claims_before) - debt_growth)
print(f"H7 accrue_step: claims growth <= debt growth: {viol} violations / {N}; example {ex}; worst excess (RAY units) {float(worst)}")

# H7 cadence differential: one 30-day chunk vs 30 daily chunks at fixed util (rate held); who gains?
sidx = 1_003_718_291_300_000_000_000_000_000; bidx = 1_017_000_000_000_000_000_000_000_007
supplied = 5_000_003 * 10**20; borrowed = 4_000_001 * 10**20; rate = RAY // MS_YEAR  # 100% APR
one_nb, one_ns, one_rev = accrue_step(1000, borrowed, supplied, bidx, sidx, rate, 30 * 86_400_000)
nb, ns, s = bidx, sidx, supplied
for _ in range(30):
    nb, ns, rev = accrue_step(1000, borrowed, s, nb, ns, rate, 86_400_000); s += rev
print("cadence: single 30d chunk borrow idx", one_nb, " vs 30x1d", nb, " rel diff", (nb - one_nb) / one_nb)
print("cadence: single chunk supply idx", one_ns, " vs 30x1d", ns, " rel diff", (ns - one_ns) / one_ns)

# Whole-unit rule-1 dirty example: 0-decimal collateral, LT 8000, LTV 7000, bonus 500, price non-round
def wad_from_token(a, d): return rescale_half_up(a, d, 18)
price = 70_370_000_000_000_000_003   # $70.37 WAD-ish, dirty
D = 59_053_000_000_000_000_000        # debt $59.053 WAD
b_wad = mul_div_half_up(500, WAD, BPS); one_plus_b = WAD + b_wad
unit_usd = mul_div_half_up(wad_from_token(1, 0), price, WAD)
unit_at_bonus = mul_div_floor(unit_usd, WAD, one_plus_b)
R = unit_usd  # one debt leg priced same for simplicity would differ; take debt-token unit ~ $1 at 7 dec -> tiny
R = mul_div_half_up(wad_from_token(1, 7), 1_000_000_000_000_000_000, WAD)
print("whole-unit: unit_usd", unit_usd, "unit_at_bonus", unit_at_bonus, "D+R", D + R, "rule1 fires:", unit_at_bonus >= D + R)
print("  liquidator pays D=%s USD, receives 1 unit = %s USD, excess over 5%% bonus = %s USD" % (D / WAD, unit_usd / WAD, (unit_usd - mul_div_half_up(D, one_plus_b, WAD)) / WAD))
