"""
Market simulator mirroring contracts/pool/src/ops/*.rs on top of xoxno_math.
State: cash, supplied (total supply shares incl. revenue), borrowed (debt shares),
revenue (shares), supply_index, borrow_index, last_ts.  Accounts hold shares.
Actor token flows are tracked as (received_from_pool - paid_to_pool).
"""
from xoxno_math import *


class Revert(Exception):
    pass


import functools, copy

def transactional(fn):
    """A Soroban panic reverts the whole invocation; mirror that here."""
    @functools.wraps(fn)
    def wrapper(self, *a, **k):
        saved = (self.cash, self.supplied, self.borrowed, self.revenue, self.supply_index,
                 self.borrow_index, self.last_ts, self.now, dict(self.sup), dict(self.debt),
                 dict(self.flow), self.owner_flow, len(self.log))
        try:
            return fn(self, *a, **k)
        except (Revert, MathOverflow):
            (self.cash, self.supplied, self.borrowed, self.revenue, self.supply_index,
             self.borrow_index, self.last_ts, self.now, self.sup, self.debt, self.flow,
             self.owner_flow, n) = saved
            del self.log[n:]
            raise
    return wrapper


class Market:
    def __init__(self, params: Params, supply_index=RAY, borrow_index=RAY, ts=0):
        self.p = params
        self.dec = params.dec
        self.cash = 0
        self.supplied = 0
        self.borrowed = 0
        self.revenue = 0
        self.supply_index = supply_index
        self.borrow_index = borrow_index
        self.last_ts = ts
        self.now = ts
        self.sup = {}   # actor -> supply shares
        self.debt = {}  # actor -> debt shares
        self.flow = {}  # actor -> net tokens received from pool
        self.owner_flow = 0  # revenue claimed by owner
        self.log = []

    # ------------------------------------------------ helpers
    def _flow(self, a, d):
        self.flow[a] = self.flow.get(a, 0) + d

    def snapshot(self):
        return dict(cash=self.cash, supplied=self.supplied, borrowed=self.borrowed,
                    revenue=self.revenue, si=self.supply_index, bi=self.borrow_index)

    # ------------------------------------------------ guards.rs
    def require_utilization_below_max(self):
        # guards.rs:19-34
        if self.supplied == 0 or self.p.max_utilization >= RAY:
            return
        borrowed = ray_mul_ceil(self.borrowed, self.borrow_index)
        if borrowed == 0:
            return
        supplied = ray_mul_floor(self.supplied, self.supply_index)
        if not (supplied > 0 and ray_div_ceil(borrowed, supplied) <= self.p.max_utilization):
            raise Revert("UtilizationAboveMax")

    def require_liquidation_buffer(self, draw):
        # guards.rs:39-47
        supplied = unscale_supply_floor(self.supplied, self.supply_index, self.dec)
        reserved = mul_div_ceil(supplied, LIQUIDATION_BUFFER_BPS, BPS)
        if self.cash - draw < reserved:
            raise Revert("InsufficientLiquidity(buffer)")

    def backing_shortfall(self):
        # guards.rs:61-66
        claim = unscale_supply_floor(self.supplied, self.supply_index, self.dec)
        debt = unscale_borrow_ceil(self.borrowed, self.borrow_index, self.dec)
        return max(claim - (self.cash + debt), 0)

    def require_backed_market(self):
        if self.backing_shortfall() != 0:
            raise Revert("PoolInsolvent(backing)")

    def require_supply_for_debt(self):
        if self.supplied == 0 and self.borrowed != 0:
            raise Revert("PoolInsolvent(no supply for debt)")

    def require_reserves(self, amt):
        if self.cash < amt:
            raise Revert("InsufficientLiquidity(reserves)")

    def require_revenue_backed(self):
        if self.revenue > self.supplied:
            raise Revert("InternalError(revenue>supplied)")

    # ------------------------------------------------ interest.rs
    @transactional
    def accrue(self, dt_ms):
        """global_sync (interest.rs:226-239) after advancing time by dt_ms."""
        self.now += dt_ms
        remaining = self.now - self.last_ts
        while remaining > 0:
            chunk = min(remaining, MAX_COMPOUND_DELTA_MS)
            nbi, nsi, rev, _ = accrue_step(self.p, self.borrowed, self.supplied,
                                           self.borrow_index, self.supply_index, chunk)
            self.borrow_index = nbi
            self.supply_index = nsi
            # cache.accrue_revenue (shares.rs:36-39)
            self.revenue += rev
            self.supplied += rev
            remaining -= chunk
        self.last_ts = self.now

    def _sync(self):
        self.accrue(0)

    # ------------------------------------------------ ops/supply.rs:19-42
    @transactional
    def supply(self, a, amount):
        assert amount >= 0
        self._sync()
        self.require_backed_market()
        minted = calculate_scaled_supply(amount, self.dec, self.supply_index)
        if not (amount == 0 or minted > 0):
            raise Revert("SupplyRoundsToZeroShares")
        self.sup[a] = self.sup.get(a, 0) + minted
        self.supplied += minted
        self.cash += amount
        self._flow(a, -amount)
        self.log.append(("supply", a, amount, minted))
        return minted

    # ------------------------------------------------ ops/withdraw.rs:99-161
    WITHDRAW_ALL = I128_MAX

    @transactional
    def withdraw(self, a, amount, is_liquidation=False):
        assert amount >= 0
        self._sync()
        pos = self.sup.get(a, 0)
        burned, gross = resolve_withdrawal(amount, pos, self.supply_index, self.dec)
        if not (gross == 0 or burned > 0):
            raise Revert("WithdrawRoundsToZeroShares")
        # burn_position
        self.supplied = checked_sub_nonneg(self.supplied, burned)
        self.require_revenue_backed()
        remaining = checked_sub_nonneg(pos, burned)
        net = gross
        empty_close = pos == 0 and amount == I128_MAX
        # gate_and_debit
        self.require_reserves(net)
        if not (is_liquidation or empty_close):
            self.require_utilization_below_max()
        self.require_supply_for_debt()
        self.cash -= net
        self.sup[a] = remaining
        self._flow(a, net)
        self.log.append(("withdraw", a, amount, burned, gross))
        return burned, gross

    # ------------------------------------------------ ops/borrow.rs:42-79
    @transactional
    def borrow(self, a, amount):
        if amount <= 0:
            raise Revert("require_positive_amount")
        self._sync()
        self.require_reserves(amount)
        self.require_liquidation_buffer(amount)
        minted = calculate_scaled_borrow(amount, self.dec, self.borrow_index)
        if minted <= 0:
            raise Revert("BorrowRoundsToZeroShares")
        self.debt[a] = self.debt.get(a, 0) + minted
        self.borrowed += minted
        self.require_utilization_below_max()
        self.cash -= amount   # debit_cash (reserves already checked)
        self._flow(a, amount)
        self.log.append(("borrow", a, amount, minted))
        return minted

    # ------------------------------------------------ ops/repay.rs:119-146
    @transactional
    def repay(self, a, amount):
        assert amount >= 0
        self._sync()
        pos = self.debt.get(a, 0)
        burned, over = resolve_repay(amount, pos, self.borrow_index, self.dec)
        net = amount - over
        if not (net == 0 or burned > 0):
            raise Revert("RepayRoundsToZeroShares")
        self.debt[a] = checked_sub_nonneg(pos, burned)
        self.borrowed = checked_sub_nonneg(self.borrowed, burned)
        self.cash += net
        self._flow(a, -net)   # overpayment is refunded, so actor only loses net
        self.log.append(("repay", a, amount, burned, net))
        return burned, net

    def repay_all(self, a):
        self._sync()
        d = unscale_borrow_ceil(self.debt.get(a, 0), self.borrow_index, self.dec)
        return self.repay(a, d)

    # ------------------------------------------------ ops/net_settle.rs:169-207
    @transactional
    def net_settle(self, a, amount):
        assert amount >= 0
        self._sync()
        s = self.sup.get(a, 0)
        d = self.debt.get(a, 0)
        bs, bd, gross = resolve_net_settle(amount, s, d, self.supply_index, self.borrow_index, self.dec)
        if not (gross == 0 or (bs > 0 and bd > 0)):
            raise Revert("NetSettleRoundsToZeroShares")
        self.supplied = checked_sub_nonneg(self.supplied, bs)
        self.require_revenue_backed()
        self.borrowed = checked_sub_nonneg(self.borrowed, bd)
        self.require_supply_for_debt()
        self.sup[a] = s - bs
        self.debt[a] = d - bd
        self.log.append(("net_settle", a, amount, bs, bd, gross))
        return bs, bd, gross

    # ------------------------------------------------ ops/revenue.rs + cache/shares.rs:54-75
    @transactional
    def claim_revenue(self):
        self._sync()
        treasury_actual = unscale_supply_floor(self.revenue, self.supply_index, self.dec)
        amount = min(self.cash, treasury_actual)
        if amount <= 0:
            burned = 0
            amount = 0
        else:
            if amount >= treasury_actual:
                burned = self.revenue
            else:
                burned = ray_mul_ratio_ceil(self.revenue, amount, treasury_actual)
            if burned == 0:
                raise Revert("InternalError(zero revenue burn)")
            self.revenue -= burned
            self.supplied -= burned
        self.require_utilization_below_max()
        self.require_supply_for_debt()
        self.require_reserves(amount)
        self.cash -= amount
        self.owner_flow += amount
        self.log.append(("claim_revenue", amount, burned))
        return amount

    # ------------------------------------------------ ops/seize.rs:18-35 (Borrow side)
    @transactional
    def write_down(self, a):
        """Bad-debt cleanup of actor a's whole debt position."""
        self._sync()
        pos = self.debt.get(a, 0)
        bad_debt = ray_mul_ceil(pos, self.borrow_index)   # unscale_borrow_ceil_ray
        self.supply_index = apply_bad_debt_to_supply_index(self.supplied, self.supply_index, bad_debt)
        self.borrowed = checked_sub_nonneg(self.borrowed, pos)
        self.debt[a] = 0
        self.log.append(("write_down", a, pos, bad_debt))

    @transactional
    def seize_deposit(self, a):
        """Deposit-side seize: reclassify actor's supply shares as revenue."""
        self._sync()
        pos = self.sup.get(a, 0)
        self.revenue += pos
        self.require_revenue_backed()
        self.sup[a] = 0
        self.log.append(("seize_deposit", a, pos))

    # ------------------------------------------------ invariants
    def supply_value_floor(self):
        return unscale_supply_floor(self.supplied, self.supply_index, self.dec)

    def debt_value_ceil(self):
        return unscale_borrow_ceil(self.borrowed, self.borrow_index, self.dec)

    def check_invariants(self):
        errs = []
        # backing: floor(supply value) <= cash + ceil(debt)
        sf = self.supply_value_floor()
        dc = self.debt_value_ceil()
        if sf > self.cash + dc:
            errs.append(("BACKING", sf - (self.cash + dc)))
        # share conservation
        if sum(self.sup.values()) + self.revenue != self.supplied:
            errs.append(("SUPPLY_SHARES", sum(self.sup.values()) + self.revenue - self.supplied))
        if sum(self.debt.values()) != self.borrowed:
            errs.append(("DEBT_SHARES", sum(self.debt.values()) - self.borrowed))
        # token conservation: cash == -(sum of actor flows) - owner_flow
        if self.cash != -sum(self.flow.values()) - self.owner_flow:
            errs.append(("CASH", self.cash + sum(self.flow.values()) + self.owner_flow))
        if self.cash < 0:
            errs.append(("NEG_CASH", self.cash))
        if self.revenue > self.supplied:
            errs.append(("REV>SUP", self.revenue - self.supplied))
        return errs

    def backing_slack(self):
        return self.cash + self.debt_value_ceil() - self.supply_value_floor()


def default_params(dec=7, reserve_bps=1500, max_util=RAY):
    # A realistic-looking curve: base 1%, s1 4%, s2 10%, s3 60%, mid 45%, opt 80%
    return Params(dec,
                  base=RAY // 100,
                  s1=4 * RAY // 100,
                  s2=10 * RAY // 100,
                  s3=60 * RAY // 100,
                  mid=45 * RAY // 100,
                  opt=80 * RAY // 100,
                  max_util=max_util,
                  max_rate=2 * RAY,
                  reserve_bps=reserve_bps)


def dirty_params(dec=7, reserve_bps=1337, max_util=RAY):
    p = Params(dec,
               base=10_371_829_130_000_000_000_000_000,        # 1.037...%
               s1=37_182_913_000_000_000_000_000_001,           # 3.718...%
               s2=97_182_913_000_000_000_000_000_003,
               s3=612_345_678_912_345_678_912_345_679,
               mid=437_182_913_000_000_000_000_000_007,
               opt=811_111_111_111_111_111_111_111_113,
               max_util=max_util,
               max_rate=1_999_999_999_999_999_999_999_999_999,
               reserve_bps=reserve_bps)
    p.verify()
    return p
