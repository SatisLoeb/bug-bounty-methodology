import os
import sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from liq_model import *

# ---- dirty mainnet-like markets (spoke 1 "Blue Chip", plus 9/18-dec RWAs from spokes 8/4) ----
P = dict(USDC=usd(1.0003), XLM=usd(0.3137), SolvBTC=usd(113257.41), EURC=usd(1.1729), PYUSD=usd(0.9998),
         XAUM=usd(2617.33), DEJTRSY=usd(1.0741))
SIDX = dict(USDC=1_013_700_000_000_000_000_000_000_123, XLM=1_002_300_000_000_000_000_000_000_777,
            SolvBTC=1_000_100_000_000_000_000_000_000_001, XAUM=1_004_400_000_000_000_000_000_000_009,
            DEJTRSY=1_000_000_000_000_000_000_000_000_000)
BIDX = dict(EURC=1_042_100_000_000_000_000_000_000_331, PYUSD=1_031_000_000_000_000_000_000_000_017)
DEC = dict(USDC=7, XLM=7, SolvBTC=8, EURC=7, PYUSD=7, XAUM=9, DEJTRSY=18)

def leg(name, spoke, tokens):
    lt, b, f = listing(spoke, name)
    scaled = fl(rs_hu(int(tokens * 10**DEC[name]), DEC[name], 27), RAY, SIDX[name])  # shares held
    return Leg(name, DEC[name], P[name], SIDX[name], lt, b, f, scaled)
def debt_for_usd(name, usd_wad):
    tokens_ray = fl(hu(usd_wad, WAD, P[name]), 10**9, 1)  # WAD USD / price -> WAD tokens -> RAY
    return Debt(name, DEC[name], P[name], BIDX[name], fl(tokens_ray, RAY, BIDX[name]))
def book_at_hf(legs, hf_target_wad, split=(1.0,)):
    """debts sized so that HF == hf_target (approximately, within ceil rounding)."""
    C, W, _, _ = totals(legs, [])
    D_target = fl(W, WAD, hf_target_wad)
    names = ["EURC", "PYUSD"]
    return [debt_for_usd(names[i], int(D_target * s)) for i, s in enumerate(split)]
def book_at_cover(legs, ratio_ppm):
    C, _, _, _ = totals(legs, [])
    return [debt_for_usd("EURC", C * 1_000_000 // ratio_ppm)]
def tok(name, x): return int(x * 10**DEC[name])
def show(tag, r):
    p = r["plan"]
    print(f"{tag:58s} arm={p['arm']:22s} bonus={p['bonus']:5d}bps base={p['base']} max={p['max']} "
          f"C={fmt(p['C'])} D={fmt(p['D'])} HF={p['HF']/WAD:.6f} ideal={fmt(p['ideal'])} repay={fmt(p['repay'])} "
          f"paid={fmt(r['paid_usd'])} got={fmt(r['got_usd'])} fee={fmt(r['fee_usd'])} PROFIT={fmt(r['profit'])} "
          f"BORROWER_LOSS={fmt(r['borrower_loss'])} C'/D'={(r['C2']/r['D2'] if r['D2'] else float('inf')):.9f} "
          f"HF'={r['HF2']/WAD if r['D2'] else float('inf'):.6f} cleanup={r['cleanup']} refunds={p['refunds']}")
    return r

CURVE1 = curve_of(1)
three = [leg("USDC", 1, 400_001.37), leg("XLM", 1, 1_234_567.891), leg("SolvBTC", 1, 1.83000001)]
two = three[:2]
print("== book values ==", [ (l.name, fmt(pos_value(l.scaled, l.sidx, l.price))) for l in three])

print("\n### ARM: target formula (HF just below 1), 3 legs blended base, 2 debt legs, offer = 2x quote")
debts = book_at_hf(three, usd(0.9999), split=(0.7, 0.3))
C, W, D, HF = totals(three, debts)
r = show("target/3leg/offer 2x", execute(three, debts, [("EURC", tok("EURC", 10**9)), ("PYUSD", tok("PYUSD", 10**9))], CURVE1))
q = r["plan"]["ideal"]
print("  expected real-valued profit = repay*bonus - fee:", fmt(r["plan"]["repay"] * r["plan"]["bonus"] // BPS), "(pre-fee)")
r_c = execute(three, debts, [("EURC", tok("EURC", 10**9)), ("PYUSD", tok("PYUSD", 10**9))], CURVE1, mode="credit")
print("  credit-mode: got", fmt(r_c["got_usd"]), "fee", fmt(r_c["fee_usd"]), "profit", fmt(r_c["profit"]), "delta vs transfer", fmt(r_c["profit"] - r["profit"]))

print("\n### DIFFERENTIAL: offer = quote vs quote + 1 unit (single EURC leg)")
debts1 = book_at_hf(three, usd(0.9999))
r0 = execute(three, debts1, [("EURC", tok("EURC", 10**9))], CURVE1)
ideal_units = rs_fl(fl(r0["plan"]["ideal"], WAD, P["EURC"]), 18, 7)
for k, off in (("quote-1u", ideal_units - 1), ("quote", ideal_units), ("quote+1u", ideal_units + 1), ("quote+1000u", ideal_units + 1000)):
    show(f"  offer={k}", execute(three, debts1, [("EURC", off)], CURVE1))

print("\n### DIFFERENTIAL: HF 0.9999 vs 1.0001")
try: execute(three, book_at_hf(three, usd(1.0001)), [("EURC", 10**7)], CURVE1)
except Exception as e: print("  HF 1.0001 ->", e)

print("\n### DIFFERENTIAL: one more leg (2 vs 3 legs), same HF, same offer")
d2 = book_at_hf(two, usd(0.9999)); d3 = book_at_hf(three, usd(0.9999))
a = show("  2 legs", execute(two, d2, [("EURC", tok("EURC", 10**9))], CURVE1))
b = show("  3 legs", execute(three, d3, [("EURC", tok("EURC", 10**9))], CURVE1))
print("  profit/repay: 2 legs", a["profit"] / a["plan"]["repay"], " 3 legs", b["profit"] / b["plan"]["repay"])

print("\n### DIFFERENTIAL: bonus 400 vs 900 on the USDC leg (stored tuple), same book")
alt = [l.clone() for l in two]; alt[0].bonus = 900
show("  USDC bonus 400", execute(two, d2, [("EURC", tok("EURC", 10**9))], CURVE1))
show("  USDC bonus 900", execute(alt, book_at_hf(alt, usd(0.9999)), [("EURC", tok("EURC", 10**9))], CURVE1))

print("\n### ARM: band (1 <= C/D < 1+base): full close, partials, split vs close, C/D monotone")
for ppm in (1_030_000, 1_005_000, 1_000_100, 1_000_000):
    dbs = book_at_cover(three, ppm)
    full = show(f"  C/D={ppm/1e6} full close offer 2D", execute(three, dbs, [("EURC", tok("EURC", 10**9))], CURVE1))
    C, W, D, HF = totals(three, dbs)
    x = rs_fl(fl(D // 3, WAD, P["EURC"]), 18, 7)
    p1 = execute(three, dbs, [("EURC", x)], CURVE1)
    show(f"  C/D={ppm/1e6} partial x=D/3", p1)
    p2 = execute(p1["legs2"], p1["debts2"], [("EURC", tok("EURC", 10**9))], CURVE1)
    show(f"  C/D={ppm/1e6} then close remainder", p2)
    print(f"    split profit {fmt(p1['profit'] + p2['profit'])} vs one close {fmt(full['profit'])}  diff {fmt(p1['profit'] + p2['profit'] - full['profit'])}")

print("\n### ARM: insolvent (C < D): quote floor(C/(1+base)); offer above/at/below; seize_all threshold")
for ppm in (999_900, 995_000, 900_000):
    dbs = book_at_cover(three, ppm)
    r = show(f"  C/D={ppm/1e6} offer 2D", execute(three, dbs, [("EURC", tok("EURC", 10**9))], CURVE1))
    q_units = rs_fl(fl(r["plan"]["ideal"], WAD, P["EURC"]), 18, 7)
    show(f"  C/D={ppm/1e6} offer quote-1u", execute(three, dbs, [("EURC", q_units - 1)], CURVE1))
    show(f"  C/D={ppm/1e6} offer quote-3u (below seize_all)", execute(three, dbs, [("EURC", q_units - 3)], CURVE1))
    half = execute(three, dbs, [("EURC", q_units // 2)], CURVE1)
    show(f"  C/D={ppm/1e6} half quote", half)
    rest = execute(half["legs2"], half["debts2"], [("EURC", tok("EURC", 10**9))], CURVE1)
    show(f"  C/D={ppm/1e6} then rest", rest)
    print(f"    insolvent split profit {fmt(half['profit'] + rest['profit'])} vs one {fmt(r['profit'])}; lender loss one={fmt(r['cleanup']['socialized']) if r['cleanup'] else None} split={fmt(rest['cleanup']['socialized']) if rest['cleanup'] else None}")

print("\n### R-23 jump: C/D 1.005 vs 0.995 (3-leg blended base)")
a = execute(three, book_at_cover(three, 1_005_000), [("EURC", tok("EURC", 10**9))], CURVE1)
b = execute(three, book_at_cover(three, 995_000), [("EURC", tok("EURC", 10**9))], CURVE1)
print(f"  profit above {fmt(a['profit'])} ({a['profit']/a['plan']['D']*100:.4f}% of D)  below {fmt(b['profit'])} ({b['profit']/b['plan']['D']*100:.4f}% of D)  lender loss below {fmt(b['cleanup']['socialized']) if b['cleanup'] else 0}")

print("\n### ARM: dust promotion (residual < $5): tiny book")
tiny = [leg("USDC", 1, 12.37), leg("XLM", 1, 9.5)]
tdebts = book_at_hf(tiny, usd(0.999))
show("  tiny book offer 2x", execute(tiny, tdebts, [("EURC", tok("EURC", 100))], CURVE1))
show("  tiny book offer $3", execute(tiny, tdebts, [("EURC", tok("EURC", 2.55))], CURVE1))

print("\n### under-delivery (fee-on-transfer sibling; not on mainnet): 1% short on EURC")
r = show("  target, 1% short", execute(three, book_at_hf(three, usd(0.9999)), [("EURC", tok("EURC", 10**9))], CURVE1, deliver=lambda n, p: p - p // 100))
rc = show("  target, 1% short, credit", execute(three, book_at_hf(three, usd(0.9999)), [("EURC", tok("EURC", 10**9))], CURVE1, mode="credit", deliver=lambda n, p: p - p // 100))

print("\n### 9-dec and 18-dec legs (spoke 8 XAUM, spoke 4 DEJTRSY)")
x9 = [leg("XAUM", 8, 3.000000001)]; d9 = book_at_hf(x9, usd(0.9999)); CUR8 = curve_of(8)
show("  XAUM 9-dec target", execute(x9, d9, [("EURC", tok("EURC", 10**6))], CUR8))
show("  XAUM 9-dec credit", execute(x9, d9, [("EURC", tok("EURC", 10**6))], CUR8, mode="credit"))
x18 = [leg("DEJTRSY", 4, 1_000_003.7)]; d18 = book_at_hf(x18, usd(0.9999)); CUR4 = curve_of(4)
show("  DEJTRSY 18-dec target", execute(x18, d18, [("EURC", tok("EURC", 10**8))], CUR4))
show("  DEJTRSY 18-dec insolvent", execute(x18, book_at_cover(x18, 990_000), [("EURC", tok("EURC", 10**8))], CUR4))

print("\n### RANDOM SWEEP: invariants over dirty books (all arms, both modes)")
random.seed(7)
viol = 0; n = 0
names = ["USDC", "XLM", "SolvBTC", "XAUM", "DEJTRSY"]; spk = dict(USDC=1, XLM=1, SolvBTC=1, XAUM=8, DEJTRSY=4)
for it in range(4000):
    k = random.randint(1, 3)
    ls = []
    for nm in random.sample(names, k):
        ls.append(leg(nm, spk[nm], random.uniform(0.001, 5000) * (1 if nm != "SolvBTC" else 0.001)))
    for l in ls:
        l.price = int(l.price * random.uniform(0.7, 1.3)); l.sidx = int(l.sidx * random.uniform(1.0, 1.2))
        if random.random() < 0.3: l.bonus = random.choice([100, 400, 600, 900])
    cover = random.choice([0.5, 0.9, 0.99, 0.999, 1.0, 1.0001, 1.005, 1.02, 1.04, 1.08, 1.2, 1.3])
    C0, W0, _, _ = totals(ls, [])
    if C0 == 0: continue
    if cover < 1.4:
        dbs = [debt_for_usd("EURC", int(C0 / cover * random.uniform(0.6, 1.0))), debt_for_usd("PYUSD", int(C0 / cover * random.uniform(0.0, 0.4)))]
    dbs = [d for d in dbs if d.scaled > 0]
    C, W, D, HF = totals(ls, dbs)
    if D == 0 or HF >= WAD: continue
    mode = random.choice(["transfer", "credit"])
    frac = random.choice([0.001, 0.1, 0.5, 0.999, 1.0, 1.5, 3.0])
    offers = [(d.name, max(1, int(d.ceil_units() * frac))) for d in dbs]
    try:
        r = execute(ls, dbs, offers, curve_of(spk[ls[0].name]), mode=mode)
    except Exception as e:
        if "InvalidPayments" in str(e) or "HealthFactorTooHigh" in str(e): continue
        print("  EXC", e); viol += 1; continue
    n += 1
    p = r["plan"]
    one_plus = WAD + bps_to_wad(p["bonus"])
    slack = sum(usd_of_tokens(2, l.dec, l.price) for l in ls) + sum(usd_of_tokens(2, d.dec, d.price) for d in dbs) + 10**12
    entitled = hu(p["repay"], one_plus, WAD)
    # I1: liquidator never receives more collateral value than repay*(1+bonus) (+fee retained by protocol) beyond rounding slack
    if r["got_usd"] + r["fee_usd"] > entitled + slack and not p["seize_all"]:
        viol += 1; print("  I1 over-seizure", p["arm"], mode, fmt(r["got_usd"] + r["fee_usd"]), fmt(entitled))
    # I2: seize_all takes all collateral only when repay reaches the backed quote within one unit per leg
    if p["seize_all"] and p["repay"] + sum(usd_of_tokens(1, d.dec, d.price) for d in dbs) < p["ideal"]:
        viol += 1; print("  I2 seize_all early")
    # I3: solvent book -> C'/D' >= C/D (within slack) when debt remains
    if p["C"] >= p["D"] and r["D2"] > 0 and r["C2"] * p["D"] + slack * p["D"] < p["C"] * r["D2"]:
        viol += 1; print("  I3 coverage drop", p["arm"], mode, p["C"] / p["D"], r["C2"] / r["D2"])
    # I4: borrower loss <= repay*bonus + slack (solvent)  [insolvent: loss bounded by C - repay]
    if p["C"] >= p["D"] and r["borrower_loss"] > hu(p["repay"], bps_to_wad(p["bonus"]), WAD) + slack:
        viol += 1; print("  I4 borrower over-loss", p["arm"], mode, fmt(r["borrower_loss"]), fmt(hu(p["repay"], bps_to_wad(p["bonus"]), WAD)))
    # I5: paid never exceeds repay (+ per-leg ceiling unit on full close)
    if r["paid_usd"] > p["repay"] + slack:
        viol += 1; print("  I5 overpaid", fmt(r["paid_usd"]), fmt(p["repay"]))
print(f"  sweep: {n} executions, {viol} violations")
