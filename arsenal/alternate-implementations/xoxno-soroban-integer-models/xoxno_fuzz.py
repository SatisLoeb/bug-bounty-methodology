import os
import sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xoxno_model import *

rng = random.Random(1793)
DECS = [0, 2, 3, 6, 7, 8, 9, 18]

def report(name, viol, total, ex):
    print(f"{name}: {viol} violations / {total} cases; example: {ex}")

# ---------------- H4: withdraw pays <= exact value of burned shares -------------
viol = 0; ex = None; N = 0
for _ in range(60000):
    d = rng.choice(DECS); sidx = dirty_index(rng)
    pos = rng.randrange(1, 10**(d + 8)) * rng.choice([1, 10**9, 10**(27 - d)]) + rng.choice(PRIMES) % 10**9
    actual = unscale_supply(pos, sidx, d)
    # request half-up value exactly, floor value, floor-1, MAX
    for amt in [actual, max(actual - 1, 0), unscale_supply_floor(pos, sidx, d), 2**127 - 1, 1]:
        burned, gross = resolve_withdrawal(amt, pos, sidx, d)
        N += 1
        if burned > pos:
            viol += 1; ex = ex or ("burn>pos", d, sidx, pos, amt, burned); continue
        if gross > exact_value(burned, sidx, d):
            viol += 1; ex = ex or ("paid>value", d, sidx, pos, amt, burned, gross, float(exact_value(burned, sidx, d)))
report("H4 withdraw paid<=value(burned)", viol, N, ex)

# ---------------- repay: tokens kept >= value of debt burned ----------------------
viol = 0; ex = None; N = 0
for _ in range(60000):
    d = rng.choice(DECS); bidx = dirty_index(rng)
    if bidx < RAY: bidx += RAY
    pos = rng.randrange(1, 10**(d + 8)) * rng.choice([1, 10**9, 10**(27 - d)]) + rng.choice(PRIMES) % 10**9
    ceil = unscale_borrow_ceil(pos, bidx, d)
    for amt in [ceil, ceil - 1, ceil + 5, 1, dirty_amount(rng, d)]:
        if amt <= 0: continue
        burned, over = resolve_repay(amt, pos, bidx, d)
        N += 1
        if burned > pos: viol += 1; ex = ex or ("burn>pos", d, bidx, pos, amt); continue
        net = amt - over
        if net < exact_value(burned, bidx, d):
            viol += 1; ex = ex or ("net<value", d, bidx, pos, amt, burned, net, float(exact_value(burned, bidx, d)))
report("repay net>=value(burned debt)", viol, N, ex)

# ---------------- H3: net settle: value(supply burned) >= settle >= value(debt burned)
viol = 0; ex = None; N = 0; worst_account_loss = F(0)
for _ in range(80000):
    d = rng.choice(DECS); sidx = dirty_index(rng); bidx = dirty_index(rng)
    if bidx < RAY: bidx += RAY
    sup = rng.randrange(1, 10**(d + 8)) * rng.choice([1, 10**9, 10**(27 - d)]) + rng.choice(PRIMES) % 10**9
    debt = rng.choice([sup, sup + 1, sup - 1 if sup > 1 else 1,
                       rng.randrange(1, 10**(d + 8)) * rng.choice([1, 10**9, 10**(27 - d)]) + rng.choice(PRIMES) % 10**9])
    sf = unscale_supply_floor(sup, sidx, d); dc = unscale_borrow_ceil(debt, bidx, d)
    for amt in [2**127 - 1, sf, dc, max(min(sf, dc) - 1, 1), 1, dirty_amount(rng, d)]:
        bs, bd, settle = resolve_net_settle(amt, sup, debt, sidx, bidx, d)
        N += 1
        if settle == 0:
            assert bs == 0 and bd == 0; continue
        if bs == 0 or bd == 0:
            continue  # pool panics NetSettleRoundsToZeroShares
        vs = exact_value(bs, sidx, d); vd = exact_value(bd, bidx, d)
        if vs < settle or vd > settle:
            viol += 1; ex = ex or (d, sidx, bidx, sup, debt, amt, bs, bd, settle, float(vs), float(vd))
        worst_account_loss = max(worst_account_loss, vs - vd)
report("H3 net settle value(sup burn)>=settle>=value(debt burn)", viol, N, ex)
print("   max account-side loss (value units) per net settle:", float(worst_account_loss))

# ---------------- H6: write-down never leaves claims above (old claims - bad_debt) unless clamp
viol = 0; ex = None; N = 0; clamp_cases = 0
for _ in range(60000):
    d = rng.choice(DECS); sidx = dirty_index(rng)
    supplied = rng.randrange(1, 10**(d + 12)) * 10**(27 - d) + rng.choice(PRIMES)
    total = ray_mul(supplied, sidx)
    bad = rng.choice([1, total // 2 + 1, total - 1, total, total + 1, rng.randrange(1, total + 1)])
    new = apply_bad_debt(supplied, sidx, bad)
    N += 1
    if new == SUPPLY_INDEX_FLOOR and ray_mul_floor(sidx, ray_div_floor(total - min(bad, total), total)) < SUPPLY_INDEX_FLOOR:
        clamp_cases += 1; continue
    after = F(supplied * new, RAY); before = F(supplied * sidx, RAY)
    if after > before - min(bad, total):
        viol += 1; ex = ex or (d, sidx, supplied, bad, new, float(after), float(before - bad))
report("H6 write-down: after <= before - bad_debt (non-clamped)", viol, N, ex)
print("   clamp cases (residual unbacked claims, documented):", clamp_cases)

# ---------------- H5: revenue claim burns shares worth >= amount paid -------------
viol = 0; ex = None; N = 0
for _ in range(60000):
    d = rng.choice(DECS); sidx = dirty_index(rng)
    revenue = rng.randrange(1, 10**(d + 10)) + rng.choice(PRIMES) % 10**9
    supplied = revenue + rng.randrange(0, 10**(d + 10))
    ta = unscale_supply_floor(revenue, sidx, d)
    for cash in [0, 1, ta - 1, ta, ta + 7, rng.randrange(0, ta + 2)]:
        if cash < 0: continue
        amt, burn = burn_claimable_revenue(revenue, supplied, cash, sidx, d)
        N += 1
        if amt == 0: continue
        if burn > revenue or amt > exact_value(burn, sidx, d):
            viol += 1; ex = ex or (d, sidx, revenue, cash, amt, burn, float(exact_value(burn, sidx, d)))
report("H5 claim_revenue paid<=value(burned revenue)", viol, N, ex)

# ---------------- liquidation fee withhold: backing non-decreasing --------------
viol = 0; ex = None; N = 0
for _ in range(60000):
    d = rng.choice(DECS); sidx = dirty_index(rng)
    pos = rng.randrange(1, 10**(d + 8)) * rng.choice([1, 10**9, 10**(27 - d)]) + rng.choice(PRIMES) % 10**9
    supplied = pos + rng.randrange(0, 10**(d + 9)); cash = rng.randrange(0, 10**(d + 9))
    amt = rng.choice([unscale_supply(pos, sidx, d), unscale_supply_floor(pos, sidx, d), dirty_amount(rng, d)])
    burned, gross = resolve_withdrawal(amt, pos, sidx, d)
    if gross == 0 or burned == 0 or gross > cash: continue
    fee = rng.choice([0, 1, gross // 20, gross])
    if fee > gross: continue
    fee_shares = protocol_fee_shares(from_asset(fee, d), sidx, supplied - burned) if fee else 0
    net = gross - fee
    N += 1
    before = F(cash) - exact_value(supplied, sidx, d)                    # cash - supply claims (debt const)
    after = F(cash - net) - exact_value(supplied - burned + fee_shares, sidx, d)
    if after < before:
        viol += 1; ex = ex or (d, sidx, pos, amt, fee, burned, fee_shares, float(after - before))
report("liq-fee withhold: backing(cash-claims) non-decreasing", viol, N, ex)

# ---------------- credit-mode split conserves shares ------------------------------
viol = 0; N = 0
for _ in range(20000):
    seized = rng.randrange(1, 10**30); bonus = rng.randrange(0, seized + 1); fees = rng.randrange(0, BPS)
    fee, liq = split_seized_shares(seized, bonus, fees); N += 1
    if fee + liq != seized or fee < 0 or liq < 0: viol += 1
report("credit split fee+liq==seized", viol, N, None)

# ---------------- supply mint then withdraw-all round trip (attacker gain?) --------
viol = 0; ex = None; N = 0; best = 0
for _ in range(60000):
    d = rng.choice(DECS); sidx = dirty_index(rng)
    amt = dirty_amount(rng, d)
    minted = calculate_scaled_supply(amt, d, sidx)
    if minted == 0: continue   # SupplyRoundsToZeroShares
    burned, gross = resolve_withdrawal(2**127 - 1, minted, sidx, d)
    N += 1
    if gross > amt: viol += 1; ex = ex or (d, sidx, amt, minted, gross)
    best = max(best, gross - amt)
report("supply->withdraw-all round trip gross<=deposit", viol, N, ex)

# ---------------- borrow then repay-all round trip: attacker pays >= borrowed? -------
viol = 0; ex = None; N = 0
for _ in range(60000):
    d = rng.choice(DECS); bidx = dirty_index(rng)
    if bidx < RAY: bidx += RAY
    amt = dirty_amount(rng, d)
    minted = calculate_scaled_borrow(amt, d, bidx)
    if minted == 0: continue
    ceil = unscale_borrow_ceil(minted, bidx, d); N += 1
    if ceil < amt: viol += 1; ex = ex or (d, bidx, amt, minted, ceil)
report("borrow->repay-all: repay ceil >= borrowed", viol, N, ex)
