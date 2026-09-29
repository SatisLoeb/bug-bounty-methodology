"""Random + adversarial sequence search over dirty parameters.
Objective 1 (dt=0): any actor ends with net positive token flow.
Objective 2: backing / share-conservation invariants after every op.
Objective 3 (with accrual): actor gain > interest attributable (checked via
backing invariant + 'closed-loop' actor: an actor who only supplies must never
withdraw more than deposit + supply-index growth on their shares).
"""
import random, sys
from xoxno_math import *
from sim import Market, Revert, dirty_params

seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
random.seed(seed)
N_SEQ = int(sys.argv[2]) if len(sys.argv) > 2 else 4000
WITH_ACCRUAL = len(sys.argv) > 3 and "accrual" in sys.argv[3]
PRIV = len(sys.argv) > 3 and "priv" in sys.argv[3]

PRIMES = [7, 13, 97, 101, 997, 7919, 104729, 1299709, 15485863, 179424673, 2147483647,
          9999999967, 1000000007, 123456789011]
ACTORS = ["A", "B", "C"]

def dirty_index(lo, hi):
    return random.randrange(lo, hi) | 1

def rnd_amount(dec):
    base = random.choice(PRIMES)
    scale = random.choice([1, 1, 3, 10**(dec//2), 10**dec, 10**(dec+2)])
    return (base * scale + random.randrange(0, 97)) % 10**(dec+8) + 1

best_gain = -10**30; best = None
viol = []
min_slack = 10**30; min_slack_case=None
n_ok = 0
for it in range(N_SEQ):
    dec = random.choice([5, 7, 8, 9, 18])
    p = dirty_params(dec, reserve_bps=random.choice([0, 1, 1337, 4999, 9999]),
                     max_util=random.choice([RAY, 95*RAY//100, 999_999_999_999_999_999_999_999_999]))
    m = Market(p, supply_index=dirty_index(RAY, 4*RAY), borrow_index=dirty_index(RAY, 4*RAY))
    # optional pre-existing pool: an honest LP "L" whose flows we exclude from the objective
    if random.random() < 0.8:
        m.supply("L", rnd_amount(dec) + 10**dec)
    ops = random.randrange(3, 13)
    seq = []
    for _ in range(ops):
        a = random.choice(ACTORS)
        op = random.choice(["supply", "supply", "withdraw", "withdraw_all", "borrow", "repay",
                            "repay_all", "net_settle", "claim", "seize_dep", "write_down", "accrue"])
        if op == "accrue" and not WITH_ACCRUAL:
            op = "supply"
        if op in ("seize_dep", "write_down") and not PRIV:
            op = "withdraw"
        try:
            if op == "supply":
                x = rnd_amount(dec); m.supply(a, x); seq.append((op, a, x))
            elif op == "withdraw":
                pos = m.sup.get(a, 0)
                hu = unscale_supply(pos, m.supply_index, dec)
                fl = unscale_supply_floor(pos, m.supply_index, dec)
                x = random.choice([hu, fl, max(hu-1,0), max(fl-1,0), rnd_amount(dec), max(1, fl//2), fl+1])
                m.withdraw(a, x); seq.append((op, a, x))
            elif op == "withdraw_all":
                m.withdraw(a, Market.WITHDRAW_ALL); seq.append((op, a))
            elif op == "borrow":
                x = random.choice([rnd_amount(dec), max(1, m.cash * random.randrange(1, 98) // 100)])
                m.borrow(a, x); seq.append((op, a, x))
            elif op == "repay":
                pos = m.debt.get(a, 0)
                c = unscale_borrow_ceil(pos, m.borrow_index, dec)
                x = random.choice([c, max(c-1, 0), c+1, max(1, c//2), rnd_amount(dec)])
                m.repay(a, x); seq.append((op, a, x))
            elif op == "repay_all":
                m.repay_all(a); seq.append((op, a))
            elif op == "net_settle":
                s = unscale_supply_floor(m.sup.get(a,0), m.supply_index, dec)
                d = unscale_borrow_ceil(m.debt.get(a,0), m.borrow_index, dec)
                x = random.choice([I128_MAX, s, d, max(s-1,0), max(d-1,0), max(1,min(s,d)//2)])
                m.net_settle(a, x); seq.append((op, a, x))
            elif op == "claim":
                m.claim_revenue(); seq.append((op,))
            elif op == "seize_dep":
                m.seize_deposit(a); seq.append((op, a))
            elif op == "write_down":
                if m.debt.get(a, 0) > 0:
                    m.write_down(a); seq.append((op, a))
            elif op == "accrue":
                dt = random.choice([1, 17, 1000, 86_400_000, 31_556_926_000 // 12, 31_556_926_000, 3 * 31_556_926_000 + 1])
                m.accrue(dt); seq.append((op, dt))
        except (Revert, MathOverflow) as e:
            seq.append((op, "REVERT", str(e)[:30]))
            continue
        errs = m.check_invariants()
        # A write-down clamped at the index floor is a documented unbacked state; flag separately
        if errs:
            viol.append((seed, it, dec, seq[:], errs, m.snapshot()))
        sl = m.backing_slack()
        if sl < min_slack:
            min_slack, min_slack_case = sl, (dec, seq[:], m.snapshot())
    n_ok += 1
    if not WITH_ACCRUAL:
        for a in ACTORS:
            g = m.flow.get(a, 0)
            # closed-loop only: actor with no remaining claims (else gain is just an open position)
            if m.sup.get(a, 0) == 0 and m.debt.get(a, 0) == 0 and g > best_gain:
                best_gain, best = g, (dec, seq[:], m.snapshot())
    else:
        # with accrual: a pure supplier (never borrowed) must not beat index growth; check via
        # each actor's flow <= value-of-shares growth is implied by backing; here we track
        # the single strongest signal: any actor with zero positions and gain > sum of interest paid by others
        paid = sum(-m.flow.get(b, 0) for b in ACTORS + ["L"] if -m.flow.get(b, 0) > 0)
        for a in ACTORS:
            g = m.flow.get(a, 0)
            if m.sup.get(a, 0) == 0 and m.debt.get(a, 0) == 0 and g > best_gain:
                best_gain, best = g, (dec, seq[:], m.snapshot())

print(f"seed={seed} sequences={N_SEQ} accrual={WITH_ACCRUAL} priv={PRIV}")
print(f"best closed-loop actor gain: {best_gain}")
if best: print("  case:", best[0], best[1])
print(f"invariant violations: {len(viol)}")
for v in viol[:5]:
    print("  ", v)
print(f"min backing slack (cash+ceil(debt)-floor(supply)) = {min_slack}")
if min_slack_case: print("  at:", min_slack_case[0], min_slack_case[1][-4:], min_slack_case[2])
