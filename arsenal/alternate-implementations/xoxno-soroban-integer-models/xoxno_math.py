"""
Faithful integer transcription of the XOXNO lending (rs-lending-xlm) fixed-point
and share/index math. Python ints are unbounded, so the i128 fast path and the
I256 widened path collapse into one exact computation (the Rust code documents
both paths return the same value: common/src/math/fp_core.rs:5-8). We only
emulate i128 overflow as a panic where a result is converted back to i128.

Every function cites the Rust source it transcribes.
"""

I128_MAX = (1 << 127) - 1
I128_MIN = -(1 << 127)

# common/src/constants/shared.rs:5-34, common/src/constants/pool.rs:9-23
RAY = 10**27
WAD = 10**18
BPS = 10_000
RAY_DECIMALS = 27
WAD_DECIMALS = 18
MILLISECONDS_PER_YEAR = 31_556_926_000
SUPPLY_INDEX_FLOOR_RAW = RAY // 1_000
MAX_BORROW_RATE_RAY = 2 * RAY
MAX_BORROW_INDEX_RAY = 10**36
MAX_SUPPLY_INDEX_RAY = MAX_BORROW_INDEX_RAY
LIQUIDATION_BUFFER_BPS = 200


class MathOverflow(Exception):
    pass


class DivisionByZero(Exception):
    pass


def _to_i128(v):
    # fp_core.rs:300-303
    if v > I128_MAX or v < I128_MIN:
        raise MathOverflow(v)
    return v


# ---------------------------------------------------------------- fp_core.rs
def mul_div_half_up(x, y, d):
    # fp_core.rs:108-143. Requires x>=0, y>=0, d>0. half = d/2 (floor).
    if d == 0:
        raise DivisionByZero
    if x < 0 or y < 0 or d <= 0:
        raise MathOverflow("half_up precondition")
    half = d // 2
    return _to_i128((x * y + half) // d)


def mul_div_floor(x, y, d):
    # fp_core.rs:148-159 (true floor toward -inf; Python // is floor)
    if d == 0:
        raise DivisionByZero
    return _to_i128((x * y) // d)


def mul_div_ceil(x, y, d):
    # fp_core.rs:164-175 (true ceil)
    if d == 0:
        raise DivisionByZero
    p = x * y
    return _to_i128(-((-p) // d))


def mul_div_floor_saturating(x, y, d):
    # fp_core.rs:180-201
    if d == 0:
        raise DivisionByZero
    q = (x * y) // d
    if q > I128_MAX:
        return I128_MAX
    if q < I128_MIN:
        return I128_MIN
    return q


def div_by_int_half_up(a, b):
    # fp_core.rs:279-296: half = ceil(b/2); remainder uses Rust (truncating) semantics
    if b == 0:
        raise DivisionByZero
    if b < 0:
        raise MathOverflow
    # Rust: quotient = a / b (trunc toward 0), remainder = a % b (sign of a)
    q = abs(a) // b
    r = abs(a) % b
    if a < 0:
        q, r = -q, -r
    half = b // 2 + b % 2
    if r >= half:
        return q + 1
    if r <= -half:
        return q - 1
    return q


def _rescale(a, from_d, to_d, round_down):
    # fp_core.rs:208-227
    if from_d == to_d:
        return a
    factor = 10 ** abs(to_d - from_d)
    if to_d > from_d:
        return _to_i128(a * factor)
    return round_down(a, factor)


def rescale_half_up(a, from_d, to_d):
    # fp_core.rs:234-240
    return _rescale(a, from_d, to_d, lambda a, f: div_by_int_half_up(a, f))


def rescale_floor(a, from_d, to_d):
    # fp_core.rs:246-252 : Rust `a / factor` truncates toward zero
    def trunc(a, f):
        q = abs(a) // f
        return -q if a < 0 else q
    return _rescale(a, from_d, to_d, trunc)


def rescale_ceil(a, from_d, to_d):
    # fp_core.rs:259-273
    def up(a, f):
        q = abs(a) // f
        if a < 0:
            return -q
        return q + (1 if a % f != 0 else 0)
    return _rescale(a, from_d, to_d, up)


# ---------------------------------------------------------------- fp.rs (Ray)
def ray_mul(a, b):        # fp.rs:50-52 half-up
    return mul_div_half_up(a, b, RAY)

def ray_div(a, b):        # fp.rs:55-57 half-up
    return mul_div_half_up(a, RAY, b)

def ray_div_floor(a, b):  # fp.rs:60-62
    return mul_div_floor(a, RAY, b)

def ray_div_ceil(a, b):   # fp.rs:65-67
    return mul_div_ceil(a, RAY, b)

def ray_div_by_int(a, n): # fp.rs:70-72
    return div_by_int_half_up(a, n)

def ray_mul_floor(a, b):  # fp.rs:75-77
    return mul_div_floor(a, b, RAY)

def ray_mul_ceil(a, b):   # fp.rs:80-82
    return mul_div_ceil(a, b, RAY)

def ray_mul_ratio_ceil(a, num, den):  # fp.rs:85-87
    return mul_div_ceil(a, num, den)

def ray_to_asset(a, dec):        # fp.rs:120-122 half-up
    return rescale_half_up(a, RAY_DECIMALS, dec)

def ray_to_asset_floor(a, dec):  # fp.rs:125-127
    return rescale_floor(a, RAY_DECIMALS, dec)

def ray_to_asset_ceil(a, dec):   # fp.rs:130-132
    return rescale_ceil(a, RAY_DECIMALS, dec)

def ray_from_asset(amount, dec): # fp.rs:140-147 (upscale is exact, checked)
    return rescale_half_up(amount, dec, RAY_DECIMALS)

def bps_apply_to_ray(bps, value):  # fp.rs:320-322 half-up
    return mul_div_half_up(value, bps, BPS)

def checked_sub_nonneg(a, b):  # fp.rs:20-25
    if a < 0 or b < 0 or b > a:
        raise MathOverflow("checked_sub_nonneg")
    return a - b


# ---------------------------------------------------------------- rates/scaling.rs
def scaled_to_original(scaled, index):   # scaling.rs:14-16 half-up
    return ray_mul(scaled, index)

def calculate_scaled_supply(amount, dec, supply_index):       # scaling.rs:37-39 floor
    return ray_div_floor(ray_from_asset(amount, dec), supply_index)

def calculate_scaled_supply_ceil(amount, dec, supply_index):  # scaling.rs:43-50
    return ray_div_ceil(ray_from_asset(amount, dec), supply_index)

def calculate_scaled_borrow(amount, dec, borrow_index):       # scaling.rs:54-56 ceil
    return ray_div_ceil(ray_from_asset(amount, dec), borrow_index)

def calculate_scaled_borrow_floor(amount, dec, borrow_index): # scaling.rs:60-67
    return ray_div_floor(ray_from_asset(amount, dec), borrow_index)

def unscale_supply(scaled, idx, dec):         # scaling.rs:71-73 half-up both steps
    return ray_to_asset(scaled_to_original(scaled, idx), dec)

def unscale_supply_floor(scaled, idx, dec):   # scaling.rs:77-81 floor both steps
    return ray_to_asset_floor(ray_mul_floor(scaled, idx), dec)

def unscale_borrow(scaled, idx, dec):         # scaling.rs:85-87 half-up
    return ray_to_asset(scaled_to_original(scaled, idx), dec)

def unscale_borrow_ceil(scaled, idx, dec):    # scaling.rs:91-95 ceil both steps
    return ray_to_asset_ceil(ray_mul_ceil(scaled, idx), dec)

def resolve_withdrawal(amount, pos_scaled, supply_index, dec):
    # scaling.rs:105-121
    current_supply_actual = unscale_supply(pos_scaled, supply_index, dec)   # half-up
    current_supply_floor = unscale_supply_floor(pos_scaled, supply_index, dec)
    if amount >= current_supply_actual:
        return pos_scaled, current_supply_floor
    return calculate_scaled_supply_ceil(amount, dec, supply_index), amount

def resolve_net_settle(amount, supply_scaled, debt_scaled, supply_index, borrow_index, dec):
    # scaling.rs:133-161
    supply_floor = unscale_supply_floor(supply_scaled, supply_index, dec)
    debt_ceil = unscale_borrow_ceil(debt_scaled, borrow_index, dec)
    settle = min(amount, supply_floor, debt_ceil)
    if settle <= 0:
        return 0, 0, 0
    if settle == supply_floor:
        burned_supply = supply_scaled
    else:
        burned_supply = min(calculate_scaled_supply_ceil(settle, dec, supply_index), supply_scaled)
    if settle == debt_ceil:
        burned_debt = debt_scaled
    else:
        burned_debt = min(calculate_scaled_borrow_floor(settle, dec, borrow_index), debt_scaled)
    return burned_supply, burned_debt, settle

def resolve_repay(amount, pos_scaled, borrow_index, dec):
    # scaling.rs:171-192
    current_debt_ceil = unscale_borrow_ceil(pos_scaled, borrow_index, dec)
    if amount >= current_debt_ceil:
        return pos_scaled, amount - current_debt_ceil
    return calculate_scaled_borrow_floor(amount, dec, borrow_index), 0


# ---------------------------------------------------------------- rates/curve.rs
class Params:
    def __init__(self, dec, base, s1, s2, s3, mid, opt, max_util, max_rate, reserve_bps):
        self.dec = dec
        self.base_borrow_rate = base
        self.slope1 = s1
        self.slope2 = s2
        self.slope3 = s3
        self.mid_utilization = mid
        self.optimal_utilization = opt
        self.max_utilization = max_util
        self.max_borrow_rate = max_rate
        self.reserve_factor = reserve_bps

    def verify(self):
        # common/src/types/pool.rs:174-222
        assert self.base_borrow_rate >= 0
        assert not (self.slope1 < self.base_borrow_rate or self.slope2 < self.slope1
                    or self.slope3 < self.slope2 or self.max_borrow_rate < self.slope3)
        assert self.max_borrow_rate > self.base_borrow_rate
        assert self.max_borrow_rate <= MAX_BORROW_RATE_RAY
        assert self.mid_utilization > 0
        assert self.optimal_utilization > self.mid_utilization
        assert self.optimal_utilization < RAY
        assert self.optimal_utilization <= self.max_utilization <= RAY
        assert 0 <= self.reserve_factor < BPS


def calculate_annual_borrow_rate(utilization, p):
    # curve.rs:76-114
    u = min(utilization, RAY)
    if u < p.mid_utilization:
        contribution = ray_div(ray_mul(u, p.slope1), p.mid_utilization)
        annual = p.base_borrow_rate + contribution
    elif u < p.optimal_utilization:
        excess = checked_sub_nonneg(u, p.mid_utilization)
        rng = checked_sub_nonneg(p.optimal_utilization, p.mid_utilization)
        contribution = ray_div(ray_mul(excess, p.slope2), rng)
        annual = p.base_borrow_rate + p.slope1 + contribution
    else:
        base_rate = p.base_borrow_rate + p.slope1 + p.slope2
        excess = checked_sub_nonneg(u, p.optimal_utilization)
        rng = checked_sub_nonneg(RAY, p.optimal_utilization)
        contribution = ray_div(ray_mul(excess, p.slope3), rng)
        annual = base_rate + contribution
    return min(annual, p.max_borrow_rate)

def calculate_borrow_rate(utilization, p):
    # curve.rs:120-123 half-up per-ms
    return ray_div_by_int(calculate_annual_borrow_rate(utilization, p), MILLISECONDS_PER_YEAR)

def utilization(borrowed, supplied):
    # curve.rs:155-160 half-up
    if supplied == 0:
        return 0
    return ray_div(borrowed, supplied)


# ---------------------------------------------------------------- rates/compound.rs
def compound_interest(rate, delta_ms):
    # compound.rs:31-51
    if delta_ms == 0:
        return RAY
    x = _to_i128(rate * delta_ms)
    s = RAY + x
    pw = x
    for divisor in (2, 6, 24, 120, 720, 5_040, 40_320):
        pw = ray_mul(pw, x)                # half-up
        s = s + ray_div_by_int(pw, divisor)  # half-up
    return s


# ---------------------------------------------------------------- rates/index.rs
def update_borrow_index(old_index, interest_factor):
    # index.rs:13-19
    new_index = ray_mul(old_index, interest_factor)
    if new_index > MAX_BORROW_INDEX_RAY:
        return MAX_BORROW_INDEX_RAY
    return new_index

def update_supply_index(supplied, old_index, rewards_increase):
    # index.rs:29-45
    if supplied == 0 or rewards_increase == 0:
        return old_index
    total_supplied_value = ray_mul(supplied, old_index)   # half-up
    if total_supplied_value == 0:
        return old_index
    new_value = total_supplied_value + rewards_increase
    grown = mul_div_floor_saturating(new_value, RAY, supplied)
    bounded_old = min(old_index, MAX_SUPPLY_INDEX_RAY)
    return max(min(grown, MAX_SUPPLY_INDEX_RAY), bounded_old)

def supply_index_reward_shortfall(supplied, old_index, new_index, rewards_increase):
    # index.rs:53-64
    distributed = checked_sub_nonneg(ray_mul(supplied, new_index), ray_mul(supplied, old_index))
    return checked_sub_nonneg(rewards_increase, distributed)

def calculate_supplier_rewards(p, borrowed, new_bi, old_bi):
    # index.rs:73-89
    old_total_debt = ray_mul(borrowed, old_bi)
    new_total_debt = ray_mul(borrowed, new_bi)
    accrued = checked_sub_nonneg(new_total_debt, old_total_debt)
    fee = bps_apply_to_ray(p.reserve_factor, accrued)
    rewards = checked_sub_nonneg(accrued, fee)
    return rewards, fee

def protocol_fee_shares(fee, supply_index, supplied):
    # index.rs:94-99
    raw = mul_div_floor_saturating(fee, RAY, supply_index)
    headroom = max(I128_MAX - supplied, 0)
    return min(raw, headroom)


# ---------------------------------------------------------------- rates/simulate.rs
def accrue_step(p, borrowed, supplied, borrow_index, supply_index, delta_ms):
    # simulate.rs:94-137 (accrue_step)
    borrowed_original = scaled_to_original(borrowed, borrow_index)
    supplied_original = scaled_to_original(supplied, supply_index)
    util = utilization(borrowed_original, supplied_original)
    rate = calculate_borrow_rate(util, p)
    factor = compound_interest(rate, delta_ms)
    new_bi = update_borrow_index(borrow_index, factor)
    rewards, fee = calculate_supplier_rewards(p, borrowed, new_bi, borrow_index)
    new_si = update_supply_index(supplied, supply_index, rewards)
    shortfall = supply_index_reward_shortfall(supplied, supply_index, new_si, rewards)
    protocol_reward = fee + shortfall
    rev_shares = 0 if protocol_reward == 0 else protocol_fee_shares(protocol_reward, new_si, supplied)
    return new_bi, new_si, rev_shares, dict(util=util, rate=rate, factor=factor,
                                            rewards=rewards, fee=fee, shortfall=shortfall)


# ---------------------------------------------------------------- pool/src/interest.rs
MAX_COMPOUND_DELTA_MS = MILLISECONDS_PER_YEAR  # compound.rs:13

def apply_bad_debt_to_supply_index(supplied, supply_index, bad_debt_ray):
    # interest.rs:279-295
    total = ray_mul(supplied, supply_index)       # half-up
    if total == 0:
        return supply_index
    capped = min(bad_debt_ray, total)
    remaining = checked_sub_nonneg(total, capped)
    reduction = ray_div_floor(remaining, total)
    new_idx = ray_mul_floor(supply_index, reduction)
    return max(new_idx, SUPPLY_INDEX_FLOOR_RAW)
