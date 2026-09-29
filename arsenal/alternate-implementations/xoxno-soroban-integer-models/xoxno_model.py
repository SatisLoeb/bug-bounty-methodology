"""Exact-integer model of rs-lending-xlm rounding kernels.
Mirrors common/src/math/fp_core.rs, common/src/rates/scaling.rs,
contracts/pool/src/interest.rs, cache/shares.rs, ops/withdraw.rs.
All values are Python ints; Fraction is used for the *exact* rational value
so we can detect protocol loss (tokens paid > exact value burned).
"""
from fractions import Fraction as F
import random

RAY = 10**27
WAD = 10**18
BPS = 10_000
SUPPLY_INDEX_FLOOR = RAY // 1000

def div_floor(p, d):
    q, r = divmod(p, d)  # python divmod floors toward -inf
    return q

def div_ceil(p, d):
    return -((-p) // d)

def mul_div_half_up(x, y, d):
    assert x >= 0 and y >= 0 and d > 0
    return (x * y + d // 2) // d

def mul_div_floor(x, y, d):
    return div_floor(x * y, d)

def mul_div_ceil(x, y, d):
    return div_ceil(x * y, d)

def div_by_int_half_up(a, b):
    q = a // b if a >= 0 else -((-a) // b)   # trunc toward zero
    r = a - q * b
    half = b // 2 + b % 2
    if r >= half:
        return q + 1
    if r <= -half:
        return q - 1
    return q

def rescale_half_up(a, frm, to):
    if frm == to:
        return a
    if to > frm:
        return a * 10 ** (to - frm)
    return div_by_int_half_up(a, 10 ** (frm - to))

def rescale_floor(a, frm, to):
    if frm == to:
        return a
    if to > frm:
        return a * 10 ** (to - frm)
    f = 10 ** (frm - to)
    return a // f if a >= 0 else -((-a) // f)

def rescale_ceil(a, frm, to):
    if frm == to:
        return a
    if to > frm:
        return a * 10 ** (to - frm)
    f = 10 ** (frm - to)
    q = a // f if a >= 0 else -((-a) // f)
    if a >= 0 and a % f != 0:
        return q + 1
    return q

# Ray ops
def ray_mul(a, b):        return mul_div_half_up(a, b, RAY)
def ray_mul_floor(a, b):  return mul_div_floor(a, b, RAY)
def ray_mul_ceil(a, b):   return mul_div_ceil(a, b, RAY)
def ray_div_floor(a, b):  return mul_div_floor(a, RAY, b)
def ray_div_ceil(a, b):   return mul_div_ceil(a, RAY, b)
def from_asset(amount, d): return rescale_half_up(amount, d, 27)
def to_asset(v, d):        return rescale_half_up(v, 27, d)
def to_asset_floor(v, d):  return rescale_floor(v, 27, d)
def to_asset_ceil(v, d):   return rescale_ceil(v, 27, d)

# scaling.rs
def calculate_scaled_supply(amount, d, sidx):       return ray_div_floor(from_asset(amount, d), sidx)
def calculate_scaled_supply_ceil(amount, d, sidx):  return ray_div_ceil(from_asset(amount, d), sidx)
def calculate_scaled_borrow(amount, d, bidx):       return ray_div_ceil(from_asset(amount, d), bidx)
def calculate_scaled_borrow_floor(amount, d, bidx): return ray_div_floor(from_asset(amount, d), bidx)
def unscale_supply(s, idx, d):        return to_asset(ray_mul(s, idx), d)
def unscale_supply_floor(s, idx, d):  return to_asset_floor(ray_mul_floor(s, idx), d)
def unscale_borrow_ceil(s, idx, d):   return to_asset_ceil(ray_mul_ceil(s, idx), d)

def resolve_withdrawal(amount, pos, sidx, d):
    actual = unscale_supply(pos, sidx, d)
    floor = unscale_supply_floor(pos, sidx, d)
    if amount >= actual:
        return pos, floor
    return calculate_scaled_supply_ceil(amount, d, sidx), amount

def resolve_repay(amount, pos, bidx, d):
    ceil = unscale_borrow_ceil(pos, bidx, d)
    if amount >= ceil:
        return pos, amount - ceil
    return calculate_scaled_borrow_floor(amount, d, bidx), 0

def resolve_net_settle(amount, sup, debt, sidx, bidx, d):
    sf = unscale_supply_floor(sup, sidx, d)
    dc = unscale_borrow_ceil(debt, bidx, d)
    settle = min(amount, sf, dc)
    if settle <= 0:
        return 0, 0, 0
    bs = sup if settle == sf else min(calculate_scaled_supply_ceil(settle, d, sidx), sup)
    bd = debt if settle == dc else min(calculate_scaled_borrow_floor(settle, d, bidx), debt)
    return bs, bd, settle

def protocol_fee_shares(fee_ray, sidx, supplied):
    raw = mul_div_floor(fee_ray, RAY, sidx)
    return min(raw, (2**127 - 1) - supplied)

def apply_bad_debt(supplied, sidx, bad_debt_ray):
    total = ray_mul(supplied, sidx)
    if total == 0:
        return sidx
    capped = min(bad_debt_ray, total)
    remaining = total - capped
    red = ray_div_floor(remaining, total)
    new = ray_mul_floor(sidx, red)
    return max(new, SUPPLY_INDEX_FLOOR)

def exact_value(shares, idx, d):
    """exact token value of shares at idx as a Fraction"""
    return F(shares * idx, RAY * 10 ** (27 - d))

def burn_claimable_revenue(revenue, supplied, cash, sidx, d):
    ta = unscale_supply_floor(revenue, sidx, d)
    amount = min(cash, ta)
    if amount <= 0:
        return 0, 0
    if amount >= ta:
        burn = revenue
    else:
        burn = mul_div_ceil(revenue, amount, ta)
    assert burn != 0
    return amount, burn

def split_seized_shares(seized, bonus, fees_bps):
    fee = mul_div_ceil(bonus, fees_bps, BPS)
    assert fee <= seized
    return fee, seized - fee

# --- dirty generators -------------------------------------------------------
PRIMES = [7, 13, 97, 101, 1_000_003, 998_244_353, 2_147_483_647, 9_007_199_254_740_881]
def dirty_index(rng, lo=1.0, hi=3.0):
    # non-round indexes like 1.0037182913 RAY, sometimes below RAY (post write-down)
    base = rng.choice([RAY, RAY + 37_182_913_000_000_000_000_000, 1_003_718_291_300_000_000_000_000_000,
                       RAY * 2 + 1, RAY + rng.randrange(1, RAY), rng.randrange(SUPPLY_INDEX_FLOOR, 3 * RAY)])
    return base + rng.choice(PRIMES) % 1000

def dirty_amount(rng, d):
    return rng.choice([1, 2, 3, 7, 13, 97, 101, 10**d - 1, 10**d + 1, 3 * 10**d + 7,
                       rng.randrange(1, 10**(d + 6)), rng.choice(PRIMES) % 10**(d + 4) + 1])
