"""Targeted seams (a)-(g) from the task, with dirty numbers."""
import random
from xoxno_math import *
from sim import Market, Revert, dirty_params, default_params

random.seed(20260929)
PRIMES = [7, 13, 97, 101, 997, 7919, 104729, 1299709, 15485863, 179424673, 2147483647,
          9999999967, 1000000007, 123456789011, 98765432101, 1000000000039]

def dirty_index(lo=RAY, hi=3*RAY):
    # e.g. 1.0037182913... in RAY with all 27 digits populated
    return random.randrange(lo, hi) | 1

def fresh(dec, si=None, bi=None, reserve=1337):
    p = dirty_params(dec, reserve)
    m = Market(p, supply_index=si or RAY, borrow_index=bi or RAY)
    return m

def worst(results, key):
    return max(results, key=key) if results else None

# ---------------------------------------------------------------- (a) supply x then withdraw-all
def test_a():
    print("== (a) supply x, withdraw-all immediately (dt=0). gain = out - in, should be <= 0")
    worst_gain = -10**30; worst_case = None; count=0
    for dec in (5, 7, 8, 9, 18):
        for _ in range(4000):
            si = dirty_index(RAY, 5*RAY)
            x = (random.choice(PRIMES) * random.choice([1, 3, 7, 11, 10**dec, 10**(dec-1)+1]) + random.randrange(0, 1000)) % 10**(dec+9) + 1
            m = fresh(dec, si=si)
            # seed pool with another supplier so index matters
            m.supply("seed", 10**dec * 1000 + 17)
            try:
                m.supply("A", x)
                m.withdraw("A", Market.WITHDRAW_ALL)
            except (Revert, MathOverflow) as e:
                continue
            g = m.flow["A"]
            count += 1
            errs = m.check_invariants()
            assert not errs, errs
            if g > worst_gain:
                worst_gain, worst_case = g, (dec, si, x, m.log[-2:])
    print(f"  cases={count} max gain={worst_gain} (case={worst_case[:3]})")
    return worst_gain

# ---------------------------------------------------------------- (b) supply, borrow, repay-all, withdraw-all
def test_b():
    print("== (b) supply, borrow, repay-all, withdraw-all round trip (dt=0)")
    worst_gain = -10**30; worst_case=None; count=0
    for dec in (5, 7, 8, 9, 18):
        for _ in range(3000):
            si = dirty_index(RAY, 5*RAY); bi = dirty_index(RAY, 5*RAY)
            m = fresh(dec, si=si, bi=bi)
            m.supply("seed", 10**dec * 1000 + 17)
            x = random.choice(PRIMES) % (10**(dec+3)) + 1
            y = max(1, x * random.randrange(1, 70) // 100)
            try:
                m.supply("A", x)
                m.borrow("A", y)
                m.repay_all("A")
                m.withdraw("A", Market.WITHDRAW_ALL)
            except (Revert, MathOverflow):
                continue
            count += 1
            errs = m.check_invariants(); assert not errs, errs
            g = m.flow["A"]
            if g > worst_gain:
                worst_gain, worst_case = g, (dec, si, bi, x, y)
    print(f"  cases={count} max gain={worst_gain} case={worst_case}")
    return worst_gain

# ---------------------------------------------------------------- (c) many tiny supplies vs one big
def test_c():
    print("== (c) N tiny supplies vs one big supply of the same total: shares minted")
    worst = 0; wc=None
    for dec in (5, 7, 18):
        for _ in range(500):
            si = dirty_index(RAY, 3*RAY)
            n = random.randrange(2, 200)
            unit = random.choice(PRIMES) % 10**6 + 1
            one = calculate_scaled_supply(unit * n, dec, si)
            many = n * calculate_scaled_supply(unit, dec, si)
            d = many - one   # >0 would mean splitting mints more shares
            if d > worst: worst, wc = d, (dec, si, n, unit)
    print(f"  max(many - one) shares = {worst} (never positive => splitting never mints more)")
    # And withdraw side: N partial withdrawals vs one
    worst = -10**30; wc=None
    for dec in (5, 7, 18):
        for _ in range(500):
            si = dirty_index(RAY, 3*RAY)
            m = fresh(dec, si=si); m.supply("seed", 10**dec*100+3)
            x = random.choice(PRIMES) % 10**7 + 50
            m.supply("A", x)
            m2 = fresh(dec, si=si); m2.supply("seed", 10**dec*100+3); m2.supply("A", x)
            n = random.randrange(2, 30)
            try:
                for i in range(n):
                    m.withdraw("A", max(1, x // (2*n)))
                m.withdraw("A", Market.WITHDRAW_ALL)
                m2.withdraw("A", Market.WITHDRAW_ALL)
            except (Revert, MathOverflow):
                continue
            d = m.flow["A"] - m2.flow["A"]
            if m.flow["A"] > worst: worst = m.flow["A"]; wc=(dec,si,x,n,m.flow["A"], m2.flow["A"])
    print(f"  max net gain via split withdrawals = {worst} case={wc}")

# ---------------------------------------------------------------- (d) half-up seam in resolve_withdrawal
def test_d():
    print("== (d) withdraw request == half-up display vs floor; partial(half_up-1) vs full")
    n_hu_gt_floor = 0; worst_partial_gain=-10**30; wc=None; worst_seam=-10**30; sc=None
    for dec in (5, 7, 8, 9, 18):
        for _ in range(4000):
            si = dirty_index(RAY, 5*RAY)
            shares = random.choice(PRIMES) * random.randrange(1, 10**9) + random.randrange(0, 10**12)
            hu = unscale_supply(shares, si, dec)
            fl = unscale_supply_floor(shares, si, dec)
            assert hu in (fl, fl+1)
            # request == hu -> full close, pays fl
            b1, g1 = resolve_withdrawal(hu, shares, si, dec)
            assert b1 == shares and g1 == fl, "full-close branch must pay FLOOR"
            if hu == fl + 1:
                n_hu_gt_floor += 1
                # request hu-1 == fl -> partial, burns ceil(fl_ray/si)
                b2, g2 = resolve_withdrawal(hu - 1, shares, si, dec)
                assert g2 == fl and b2 == calculate_scaled_supply_ceil(fl, dec, si)
                assert b2 <= shares
                left = shares - b2
                # what can the leftover dust still fetch? (withdraw-all of leftover)
                b3, g3 = resolve_withdrawal(I128_MAX, left, si, dec)
                total_partial_then_all = g2 + g3
                seam = total_partial_then_all - fl   # >0 would beat the full path
                if seam > worst_seam: worst_seam, sc = seam, (dec, si, shares, fl, hu, b2, left, g3)
            # generic: partial path pays `amount`, burns ceil shares: value of burned shares (floor) >= amount?
            amt = max(0, fl - random.randrange(0, 5))
            if amt < hu and amt > 0:
                b, g = resolve_withdrawal(amt, shares, si, dec)
                v = unscale_supply_floor(b, si, dec)
                gain = g - v
                if gain > worst_partial_gain: worst_partial_gain, wc = gain, (dec, si, shares, amt, b, v)
    print(f"  half-up > floor in {n_hu_gt_floor} cases; full-close branch always paid FLOOR (asserted)")
    print(f"  max( partial(hu-1) + withdraw_all(dust) - floor ) = {worst_seam}  case={sc}")
    print(f"  max( amount_paid - floor_value(shares burned) ) for partial = {worst_partial_gain} case={wc}")

# ---------------------------------------------------------------- (e) repay ceil vs ceil-1
def test_e():
    print("== (e) repay exactly ceil(debt) vs ceil-1 then rest")
    worst = -10**30; wc=None
    for dec in (5, 7, 8, 9, 18):
        for _ in range(4000):
            bi = dirty_index(RAY, 5*RAY)
            shares = random.choice(PRIMES) * random.randrange(1, 10**9) + random.randrange(0, 10**12)
            c = unscale_borrow_ceil(shares, bi, dec)
            b1, over1 = resolve_repay(c, shares, bi, dec)
            assert b1 == shares and over1 == 0
            if c >= 2:
                b2, over2 = resolve_repay(c - 1, shares, bi, dec)
                assert over2 == 0 and b2 < shares
                left = shares - b2
                c2 = unscale_borrow_ceil(left, bi, dec)
                total = (c - 1) + c2
                saving = c - total   # >0 would mean the split path is cheaper than the full path
                if saving > worst: worst, wc = saving, (dec, bi, shares, c, b2, left, c2)
    print(f"  max saving (ceil - [ceil-1 + ceil(rest)]) = {worst} case={wc}")

# ---------------------------------------------------------------- (f) net settle same market
def test_f():
    print("== (f) net settle with supply == debt (same market), plus random overlaps")
    worst = -10**30; wc=None; count=0; viol=0
    for dec in (5, 7, 8, 9, 18):
        for _ in range(3000):
            si = dirty_index(RAY, 5*RAY); bi = dirty_index(RAY, 5*RAY)
            m = fresh(dec, si=si, bi=bi)
            m.supply("seed", 10**dec * 1000 + 17)
            x = random.choice(PRIMES) % 10**(dec+2) + 10
            try:
                m.supply("A", x)
                # borrow as close as possible to supply value (buffer permitting: seed large)
                y = x if random.random() < 0.5 else max(1, x - random.randrange(0, 3))
                m.borrow("A", y)
                req = random.choice([I128_MAX, x, y, x - 1, y - 1, max(1, x // 3)])
                m.net_settle("A", req)
                # close out whatever is left
                if m.debt["A"] > 0:
                    m.repay_all("A")
                if m.sup["A"] > 0:
                    m.withdraw("A", Market.WITHDRAW_ALL)
            except (Revert, MathOverflow):
                continue
            count += 1
            errs = m.check_invariants()
            if errs: viol += 1; print("   VIOLATION", errs, m.log)
            g = m.flow["A"]
            if g > worst: worst, wc = g, (dec, si, bi, x, y, req)
    print(f"  cases={count} violations={viol} max actor gain={worst} case={wc}")

# ---------------------------------------------------------------- (g) extremes: index floor after write-down, borrow index near ceiling
def test_g():
    print("== (g) write-down to supply-index floor; new supplier ownership vs payment")
    worst = -10**30; wc=None
    for dec in (5, 7, 18):
        for _ in range(300):
            m = fresh(dec, si=dirty_index(RAY, 2*RAY), bi=dirty_index(RAY, 2*RAY))
            S = 10**dec * 1000 + random.choice(PRIMES) % 10**dec
            m.supply("V", S)
            # borrower B takes a large fraction, then all of B's debt is written down
            m.supply("B", S // 10)
            frac = random.choice([9995, 9999, 9990, 5000, 9000]) 
            y = min(m.cash - mul_div_ceil(m.supply_value_floor(), 200, BPS), S * frac // 10000)
            try:
                m.borrow("B", y)
            except (Revert, MathOverflow):
                continue
            m.write_down("B")
            sf = m.supply_value_floor()
            short = m.backing_shortfall()
            at_floor = m.supply_index == SUPPLY_INDEX_FLOOR_RAW
            # can a new supplier enter?
            x = random.choice(PRIMES) % 10**(dec+2) + 1
            try:
                m.supply("N", x)
                entered = True
            except (Revert, MathOverflow) as e:
                entered = False
            if entered:
                # N's claim vs what they paid, and V's remaining claim
                nv = unscale_supply_floor(m.sup["N"], m.supply_index, dec)
                # proportional ownership of cash
                own = m.cash * m.sup["N"] // m.supplied
                gain = own - x
                m.withdraw("N", Market.WITHDRAW_ALL)
                g2 = m.flow["N"]
                if max(gain, g2) > worst: worst, wc = max(gain, g2), (dec, at_floor, short, x, nv, own, g2, m.supply_index)
            errs = [e for e in m.check_invariants() if e[0] != "BACKING"]
            assert not errs, errs
    print(f"  max new-supplier gain (ownership - paid, or withdraw-all - paid) = {worst} case={wc}")
    # borrow index near ceiling
    print("   borrow index near 1e36 ceiling: borrow 1 unit then repay-all")
    for dec in (5, 7, 18):
        bi = MAX_BORROW_INDEX_RAY - random.choice(PRIMES)
        m = fresh(dec, si=dirty_index(RAY, 2*RAY), bi=bi)
        m.supply("V", 10**dec * 10**6 + 7)
        y = random.choice(PRIMES) % 10**dec + 1
        m.borrow("A", y)
        m.repay_all("A")
        print(f"    dec={dec} bi={bi} borrow {y}: shares={m.log[-2][3]} flow={m.flow['A']} inv={m.check_invariants()}")

if __name__ == "__main__":
    test_a(); test_b(); test_c(); test_d(); test_e(); test_f(); test_g()
