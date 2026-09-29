"""
Generate-first extraction hypotheses. Each is written as if it were a real finding,
executed in the model with dirty integers, then a one-variable differential flips
the suspected trigger, and a repetition run says whether any leak compounds.
Leak sign convention: + = actor extracted from pool (BAD), - = pool gained (safe).
"""
from xoxno_math import *
from sim import Market, Revert, dirty_params

SI = 1_003_718_291_300_000_000_000_000_001     # 1.0037182913... (odd, all digits)
BI = 1_017_182_913_579_246_801_357_924_681     # 1.0171829135...
K = []

def kill(h, seq, leak, bounded, path, note=""):
    K.append((h, seq, leak, bounded, path, note))
    print(f"[{h}] leak={leak} {bounded} :: {note}")

def mk(dec, si=SI, bi=BI, reserve=1337, seed=True):
    m = Market(dirty_params(dec, reserve), supply_index=si, borrow_index=bi)
    if seed:
        m.supply("L", 1_000_003 * 10**dec + 7919)
    return m

# ---------------------------------------------------------------- H1
def H1():
    """Supply x at dirty index, withdraw-all in same ledger. Rounding table: mint floor,
    claim floor at both steps. Author-unconsidered input: x_ray not divisible by si.
    If the two floors were applied in the wrong order (floor to token before floor to RAY)
    a +1 would appear. Expect: -1 or 0."""
    for dec, x in ((7, 179_424_673), (18, 15_485_863_000_000_000_101), (5, 97)):
        m = mk(dec); m.supply("A", x); m.withdraw("A", Market.WITHDRAW_ALL)
        leak = m.flow["A"]
        # repetition: 50 cycles
        m2 = mk(dec)
        for _ in range(50):
            m2.supply("A", x); m2.withdraw("A", Market.WITHDRAW_ALL)
        # differential: exact index
        m3 = mk(dec, si=RAY); m3.supply("A", x); m3.withdraw("A", Market.WITHDRAW_ALL)
        kill("H1", f"supply {x} @dec{dec} si={SI}; withdraw_all", leak,
             f"compounds AGAINST actor: 50 cycles={m2.flow['A']}", "hypotheses.py:H1",
             f"differential si=RAY: {m3.flow['A']}")

# ---------------------------------------------------------------- H2
def H2():
    """Half-up display seam: request == display (=floor+1) triggers full close paying floor;
    request == display-1 (=floor) is partial with ceil burn, leaves dust; then withdraw-all
    the dust. Unconsidered input: frac(value) >= 0.5 so display == ceil. Expect partial+dust <= floor."""
    dec = 7
    # find shares whose token value has frac >= 0.5
    shares = None
    for cand in range(1_299_709 * 10**20 + 1, 1_299_709 * 10**20 + 10**21, 10**19 + 7):
        hu = unscale_supply(cand, SI, dec); fl = unscale_supply_floor(cand, SI, dec)
        if hu == fl + 1:
            shares = cand; break
    assert shares is not None
    m = mk(dec); m.sup["A"] = shares; m.supplied += shares; m.cash += hu  # inject position
    m.withdraw("A", hu - 1)                # partial, burns ceil((hu-1)_ray/si)
    dust = m.sup["A"]
    m.withdraw("A", Market.WITHDRAW_ALL)   # dust: display 1, floor 0
    got = m.flow["A"]
    # differential: request == hu -> full close
    m2 = mk(dec); m2.sup["A"] = shares; m2.supplied += shares; m2.cash += hu
    m2.withdraw("A", hu)
    kill("H2", f"shares={shares} si={SI} dec7 hu={hu} fl={fl}; withdraw {hu-1}; withdraw_all(dust={dust})",
         got - fl, "bounded: partial+dust == floor, dust paid 0", "hypotheses.py:H2",
         f"differential request==hu(full close) paid {m2.flow['A']} (== floor {fl}); dust value floor = {unscale_supply_floor(dust, SI, dec)}")

# ---------------------------------------------------------------- H3
def H3():
    """Dust left by H2 keeps earning index growth. Does dust + accrual ever pay more than the
    fair growth on those shares? Unconsidered: withdrawal of dust after index growth crosses 1 unit."""
    dec = 7
    shares = 7 * 10**19 + 8   # value ~0.70 tokens: display 1, floor 0
    m = mk(dec); m.sup["A"] = shares; m.supplied += shares
    m.borrow("L", 600_000 * 10**dec)  # utilization so supply index grows
    m.accrue(365 * 86_400_000 * 3)
    fair = unscale_supply_floor(shares, m.supply_index, dec)
    m.withdraw("A", Market.WITHDRAW_ALL)
    kill("H3", f"dust shares={shares}; accrue 3y at ~60% util; withdraw_all", m.flow["A"] - fair,
         "bounded: pays floor of grown value", "hypotheses.py:H3", f"paid {m.flow['A']} fair_floor {fair}")

# ---------------------------------------------------------------- H4
def H4():
    """Repay ceil(debt)-1 (partial, floor burn) then repay-all remainder vs one repay of ceil.
    Unconsidered: floor burn leaves residual shares worth < 1 unit which then ceil to 1 -> cost ceil+0.
    A leak would be total < ceil."""
    for dec in (7, 18, 5):
        m = mk(dec); y = 1_299_709 * (10**dec // 10**5 or 1) + 13
        m.borrow("A", y)
        c = unscale_borrow_ceil(m.debt["A"], m.borrow_index, dec)
        m.repay("A", c - 1); m.repay_all("A")
        m2 = mk(dec); m2.borrow("A", y); m2.repay("A", c)
        kill("H4", f"borrow {y} dec{dec} bi={BI}; repay ceil-1={c-1}; repay_all", m.flow["A"] - m2.flow["A"],
             "bounded: split path costs same or +1 vs single ceil", "hypotheses.py:H4",
             f"split total repaid {y - m.flow['A']}, single {y - m2.flow['A']}, ceil={c}")

# ---------------------------------------------------------------- H5
def H5():
    """Borrow x then repay exactly x (not the ceil). Unconsidered: ceil(x_ray/bi)*bi > x_ray so
    ceil(debt)=x+1 immediately; repaying x is partial and leaves 1-unit residual."""
    dec = 7; x = 104_729
    m = mk(dec); m.borrow("A", x); m.repay("A", x)
    resid = unscale_borrow_ceil(m.debt["A"], m.borrow_index, dec)
    m.repay_all("A")
    m2 = mk(dec, bi=RAY); m2.borrow("A", x); m2.repay("A", x)
    kill("H5", f"borrow {x} dec7 bi={BI}; repay {x}; repay_all", m.flow["A"],
         "bounded: -1 per round trip (pool gains)", "hypotheses.py:H5",
         f"residual after repay x = {resid}; differential bi=RAY residual debt shares = {m2.debt['A']}, flow {m2.flow['A']}")

# ---------------------------------------------------------------- H6
def H6():
    """Net settle with floor(supply) == ceil(debt) exactly, and ±1. Unconsidered: equality closes
    both sides (supply loses its frac, debt pays its ceil); ±1 leaves a 1-unit residual on one side.
    Leak would be actor flow > 0 after closing everything."""
    dec = 7
    for delta in (-1, 0, 1):
        m = mk(dec)
        s_amt = 7_919_017
        m.supply("A", s_amt)
        fl = unscale_supply_floor(m.sup["A"], m.supply_index, dec)
        # choose borrow so that ceil(debt) == fl + delta
        target = fl + delta
        # search y near target
        y = target
        m.borrow("A", y)
        c = unscale_borrow_ceil(m.debt["A"], m.borrow_index, dec)
        m.net_settle("A", I128_MAX)
        left_s = m.sup["A"]; left_d = m.debt["A"]
        if left_d: m.repay_all("A")
        if left_s: m.withdraw("A", Market.WITHDRAW_ALL)
        kill("H6", f"supply {s_amt}; borrow {y} (floor(S)={fl}, ceil(D)={c}, delta={delta}); net_settle MAX; close rest",
             m.flow["A"], "bounded: <= 0 per cycle", "hypotheses.py:H6",
             f"after settle residual shares S={left_s} D={left_d}; invariants={m.check_invariants()}")

# ---------------------------------------------------------------- H7
def H7():
    """Revenue payout when cash == floor(revenue_value) - 1 -> partial branch burns
    ceil(rev*cash/floor). Unconsidered: is the burned share value >= paid cash, and can the
    remaining revenue later claim more than the leftover value? (owner-side leak)"""
    dec = 7
    m = mk(dec); m.borrow("B", 700_000 * 10**dec + 17); m.accrue(200 * 86_400_000)
    fv = unscale_supply_floor(m.revenue, m.supply_index, dec)
    # drain cash so cash == fv - 1 : withdraw from L
    m.p.max_utilization = RAY  # keep gate open
    m.withdraw("L", m.cash - (fv - 1))
    rev0 = m.revenue
    paid1 = m.claim_revenue()
    burned = rev0 - m.revenue
    burned_val = unscale_supply_floor(burned, m.supply_index, dec)
    # now repay B to refill cash then claim the rest
    m.repay_all("B")
    paid2 = m.claim_revenue()
    kill("H7", f"accrue -> revenue floor value {fv}; set cash={fv-1}; claim; repay_all B; claim", (paid1 + paid2) - fv,
         "bounded: total owner payout <= floor(revenue value) at claim time (+ index growth)", "hypotheses.py:H7",
         f"paid1={paid1} burned_val={burned_val} (>= paid1: {burned_val >= paid1}) paid2={paid2}; diff cash==fv would burn all")

# ---------------------------------------------------------------- H8
def H8():
    """Write-down where bad_debt_ray >= total_supply_ray: reduction floor -> 0, index clamps at 1e24.
    Unconsidered: residual claims with no backing. Then: can any user extract? Supply is gated;
    withdraw pays floor of inflated claim from whatever cash remains (first come)."""
    dec = 7
    m = Market(dirty_params(dec, 1337), supply_index=SI, borrow_index=BI)
    m.supply("V", 1_000_000 * 10**dec + 7919)
    m.supply("B", 100 * 10**dec)
    y = m.cash - mul_div_ceil(m.supply_value_floor(), 200, BPS)   # max borrow under buffer
    m.borrow("B", y)
    # round 1 write-down (index x ~0.02)
    m.write_down("B")
    r1_idx = m.supply_index; r1_short = m.backing_shortfall()
    # round 2: borrow max again and default again
    y2 = m.cash - mul_div_ceil(m.supply_value_floor(), 200, BPS)
    m.borrow("B", y2); m.write_down("B")
    at_floor = m.supply_index == SUPPLY_INDEX_FLOOR_RAW
    short = m.backing_shortfall()
    claims = m.supply_value_floor()
    try:
        m.supply("N", 10**dec); n_entered = True
    except Revert as e:
        n_entered = False; err = str(e)
    # V withdraws all: gets min(claim, cash)? -> require_reserves blocks if claim > cash
    try:
        m.withdraw("V", Market.WITHDRAW_ALL); v_flow = m.flow["V"]
    except Revert as e:
        v_flow = f"REVERT {e}"
    kill("H8", f"2 rounds of max-borrow+write_down; index r1={r1_idx} r2={m.supply_index} at_floor={at_floor}",
         short, "bounded by the documented clamp; NO user extraction (supply gated, withdraw needs reserves)",
         "hypotheses.py:H8", f"claims={claims} cash={m.cash} shortfall={short}; new supplier entered={n_entered}; V withdraw_all -> {v_flow}")

# ---------------------------------------------------------------- H9
def H9():
    """Supply index exactly at 1e24 floor: mint = x_ray*1000 exactly (no rounding). Unconsidered:
    does a new supplier at the floor own more of remaining cash than paid (dilution)?"""
    dec = 7
    m = Market(dirty_params(dec, 1337), supply_index=SUPPLY_INDEX_FLOOR_RAW, borrow_index=BI)
    m.supply("V", 999_983); x = 7_919
    m.supply("N", x)
    own = m.cash * m.sup["N"] // m.supplied
    m.withdraw("N", Market.WITHDRAW_ALL)
    m2 = Market(dirty_params(dec, 1337), supply_index=SUPPLY_INDEX_FLOOR_RAW + 1, borrow_index=BI)
    m2.supply("V", 999_983); m2.supply("N", x); m2.withdraw("N", Market.WITHDRAW_ALL)
    kill("H9", f"si=1e24 exactly; V supplies 999983, N supplies {x}, N withdraw_all", m.flow["N"],
         "bounded: exact at floor (0), -1 at floor+1", "hypotheses.py:H9",
         f"N ownership of cash={own} vs paid {x}; differential si=1e24+1 -> flow {m2.flow['N']}")

# ---------------------------------------------------------------- H10
def H10():
    """Borrow index at 1e36 - 7919 and at exactly 1e36: borrow, accrue 1y, repay. Unconsidered:
    cap makes interest 0 (borrowers free) - do supplier claims grow anyway (unbacked)?"""
    dec = 7
    for bi in (MAX_BORROW_INDEX_RAY - 7919, MAX_BORROW_INDEX_RAY):
        m = Market(dirty_params(dec, 1337), supply_index=SI, borrow_index=bi)
        m.supply("V", 1_000_003 * 10**dec); y = 600_000 * 10**dec + 97
        m.borrow("A", y)
        s0 = m.supply_value_floor(); slack0 = m.backing_slack()
        m.accrue(MILLISECONDS_PER_YEAR)
        s1 = m.supply_value_floor(); slack1 = m.backing_slack()
        m.repay_all("A")
        kill("H10", f"bi={bi}; borrow {y}; accrue 1y; repay_all", m.flow["A"],
             "bounded: at cap no interest, supply claims do not grow", "hypotheses.py:H10",
             f"supply value {s0}->{s1}, slack {slack0}->{slack1}, bi after={m.borrow_index}, inv={m.check_invariants()}")

# ---------------------------------------------------------------- H11
def H11():
    """Chunking at MAX_COMPOUND_DELTA_MS ± 1 ms: 1y-1 (single chunk), 1y, 1y+1 (chunks 1y + 1ms).
    Unconsidered: the 1ms tail chunk recomputes utilization with revenue shares added. Leak would be
    supply claim growth > debt growth."""
    dec = 7
    out = []
    for dt in (MILLISECONDS_PER_YEAR - 1, MILLISECONDS_PER_YEAR, MILLISECONDS_PER_YEAR + 1, 2 * MILLISECONDS_PER_YEAR + 1):
        m = mk(dec); m.borrow("B", 610_000 * 10**dec + 104_729)
        d0 = m.debt_value_ceil(); s0 = m.supply_value_floor(); sl0 = m.backing_slack()
        m.accrue(dt)
        out.append((dt, m.debt_value_ceil() - d0, m.supply_value_floor() - s0, m.backing_slack()))
    worst = max(o[2] - o[1] for o in out)
    kill("H11", "borrow 61%; accrue 1y-1 / 1y / 1y+1 / 2y+1", worst, "bounded: token-level (dfloor(S)-dceil(D)) <= 1, slack never < 0",
         "hypotheses.py:H11", "; ".join(f"dt={o[0]} dD={o[1]} dS={o[2]} slack={o[3]}" for o in out))

# ---------------------------------------------------------------- H12
def H12():
    """reserve_factor = 1 bps, tiny market, update_indexes every 1ms: fee = half_up(accrued/10000)
    rounds to 0 when accrued < 5000 RAY units. Unconsidered: repeated zero fees starve protocol revenue;
    conversely does the supply index floor drop supplier value into revenue? Redistribution only."""
    dec = 7
    p = dirty_params(dec, reserve_bps=1)
    def run(n, dt):
        m = Market(p, supply_index=SI, borrow_index=BI)
        m.supply("V", 10**dec); m.borrow("B", 6 * 10**(dec - 1))  # 1 token market, 60% util
        for _ in range(n): m.accrue(dt)
        return m
    a = run(1000, 1); b = run(1, 1000)
    def rev_ray(m): return ray_mul(m.revenue, m.supply_index)
    def sup_ray(m): return ray_mul(m.supplied - m.revenue, m.supply_index)
    kill("H12", "1-token market, rf=1bps: 1000 x accrue(1ms) vs 1 x accrue(1000ms)",
         (sup_ray(a) - sup_ray(b)), "bounded: RAY-unit redistribution (1e-27 tok); token-level 0",
         "hypotheses.py:H12", f"revenue RAY fine={rev_ray(a)} coarse={rev_ray(b)}; supplier RAY fine={sup_ray(a)} coarse={sup_ray(b)}; debt RAY fine={ray_mul(a.borrowed,a.borrow_index)} coarse={ray_mul(b.borrowed,b.borrow_index)}")

# ---------------------------------------------------------------- H13
def H13():
    """Supply-index stall: supplied huge vs per-call rewards so grown == old index -> all rewards
    to shortfall -> revenue shares floor(reward/si) may be 0 -> reward dropped entirely.
    Unconsidered: value vanishes (pool keeps it as surplus). Per-call dropped bound = 1 share = si/RAY tokens."""
    dec = 18
    p = dirty_params(dec, reserve_bps=0)
    m = Market(p, supply_index=SI, borrow_index=BI)
    m.supply("V", 10**11 * 10**dec)         # 1e11 tokens -> supplied ~1e38 shares
    m.borrow("B", 10**dec)                  # 1 token borrowed: interest per ms ~ 1e-27 tokens
    dropped = 0; stalled = 0
    for _ in range(200):
        s0 = ray_mul(m.supplied, m.supply_index); d0 = ray_mul(m.borrowed, m.borrow_index)
        si0 = m.supply_index
        m.accrue(1)
        s1 = ray_mul(m.supplied, m.supply_index); d1 = ray_mul(m.borrowed, m.borrow_index)
        dropped += (d1 - d0) - (s1 - s0)
        stalled += (m.supply_index == si0)
    kill("H13", "1e11-token supply, 1-token debt, 200 x accrue(1ms)", -dropped,
         "bounded: dropped <= 1 RAY unit/call; direction pool-favoured", "hypotheses.py:H13",
         f"stalled supply index in {stalled}/200 calls; total interest dropped = {dropped} RAY units")

# ---------------------------------------------------------------- H14 / H15
def H14():
    """Many 1-unit partial repays (floor burn each) vs one full repay. Unconsidered: each floor
    burns < 1 unit of shares -> borrower over-pays cumulatively; a leak would be under-pay."""
    dec = 5; m = mk(dec); y = 997; m.borrow("A", y)
    for _ in range(y - 1): m.repay("A", 1)
    m.repay_all("A")
    m2 = mk(dec); m2.borrow("A", y); m2.repay_all("A")
    kill("H14", f"borrow {y} dec5; 996 x repay(1); repay_all", m.flow["A"] - m2.flow["A"],
         "bounded: split costs >= single", "hypotheses.py:H14", f"split total repaid {y - m.flow['A']}, single {y - m2.flow['A']}")

def H15():
    """Many 1-unit partial withdrawals (ceil burn each) vs one withdraw-all."""
    dec = 5; m = mk(dec); x = 7919; m.supply("A", x)
    n = 0
    try:
        for _ in range(x): m.withdraw("A", 1); n += 1
    except Revert: pass
    m.withdraw("A", Market.WITHDRAW_ALL)
    m2 = mk(dec); m2.supply("A", x); m2.withdraw("A", Market.WITHDRAW_ALL)
    kill("H15", f"supply {x} dec5; {n} x withdraw(1); withdraw_all", m.flow["A"] - m2.flow["A"],
         "bounded: split pays <= single", "hypotheses.py:H15", f"split total received {x + m.flow['A']}, single {x + m2.flow['A']} (deposit {x})")

# ---------------------------------------------------------------- H16
def H16():
    """Accrual sandwich: supply 1 ms before a big update_indexes, withdraw-all right after.
    Attributable interest = shares * (si_new - si_old) floor. Leak = paid - deposit - attributable."""
    dec = 7; m = mk(dec); m.borrow("B", 650_000 * 10**dec + 3)
    m.accrue(30 * 86_400_000)   # let it run 30 days first
    x = 179_424_673 * 10**2 + 17
    m.supply("A", x); si0 = m.supply_index
    m.accrue(1)                 # 1 ms chunk
    attributable = unscale_supply_floor(m.sup["A"], m.supply_index, dec) - unscale_supply_floor(m.sup["A"], si0, dec)
    m.withdraw("A", Market.WITHDRAW_ALL)
    kill("H16", f"supply {x}; accrue(1ms); withdraw_all", m.flow["A"] - attributable,
         "bounded: <= 0 beyond index growth", "hypotheses.py:H16", f"flow={m.flow['A']} attributable={attributable}")

# ---------------------------------------------------------------- H17
def H17():
    """Two suppliers + borrower, long accrual with mixed cadence, then everyone exits. Is the last
    exiting supplier short (claims > cash+debt)? Leak sign = final backing slack < 0."""
    dec = 7; m = mk(dec)
    m.supply("A", 333_333_337_1); m.borrow("B", 600_000 * 10**dec + 1)
    for dt in (1, 86_400_000, 7, 31_556_926_000 // 2, 999, 3):
        m.accrue(dt)
    m.repay_all("B"); m.withdraw("A", Market.WITHDRAW_ALL); m.withdraw("L", Market.WITHDRAW_ALL); m.claim_revenue()
    kill("H17", "L,A supply; B borrows; 6 irregular accruals; all exit", -m.backing_slack() if m.backing_slack() < 0 else 0,
         "bounded: residual cash >= 0 after all exits", "hypotheses.py:H17",
         f"residual cash={m.cash} supplied={m.supplied} borrowed={m.borrowed} revenue={m.revenue}; inv={m.check_invariants()}")

# ---------------------------------------------------------------- H18
def H18():
    """Repay overpayment refund path: amount = ceil + K -> refund K, cash credited net only.
    Unconsidered: refund computed from ceil, so is net == ceil exactly (no double count)?"""
    dec = 7; m = mk(dec); m.borrow("A", 1_299_709)
    c = unscale_borrow_ceil(m.debt["A"], m.borrow_index, dec)
    cash0 = m.cash
    m.repay("A", c + 104_729)
    kill("H18", f"borrow 1299709; repay ceil+104729", (m.cash - cash0) - c, "bounded: net == ceil exactly", "hypotheses.py:H18",
         f"cash delta {m.cash-cash0} vs ceil {c}; actor flow {m.flow['A']}")

# ---------------------------------------------------------------- H19
def H19():
    """Write-down where bad_debt_ray == total_supply_ray EXACTLY (not just >=): remaining=0,
    reduction=0, index clamps. Differential: bad_debt = total - 1 RAY unit -> reduction = floor((1)*RAY/total) = 0 as well!
    Unconsidered: any bad debt within total/RAY of total also zeroes the index (double floor)."""
    dec = 7
    supplied = 10**20 * 7 + 3; si = SI
    total = ray_mul(supplied, si)
    res = []
    for bd in (total, total - 1, total - total // RAY, total - total // RAY - 1, total // 2):
        res.append((bd - total, apply_bad_debt_to_supply_index(supplied, si, bd)))
    kill("H19", f"supplied={supplied} si={SI}: write-down bad_debt = total + {[r[0] for r in res]}", 0,
         "bounded: index -> 1e24 clamp for bad_debt within total/RAY of total; suppliers lose (pool-favoured)", "hypotheses.py:H19",
         "new index per case: " + ", ".join(str(r[1]) for r in res))

# ---------------------------------------------------------------- H20
def H20():
    """Utilization gate seam: withdraw that leaves floor(supply value) == 0 with debt > 0 reverts
    (div by zero guarded). Not a leak; DoS-only. Record."""
    dec = 7; m = Market(dirty_params(dec, 1337, max_util=95 * RAY // 100), supply_index=SI, borrow_index=BI)
    m.supply("A", 10**dec); m.borrow("A", 5 * 10**(dec - 1))
    try:
        m.withdraw("A", 4 * 10**(dec - 1)); r = "ok"
    except Revert as e:
        r = str(e)
    kill("H20", "supply 1 tok, borrow 0.5, withdraw 0.4 with max_util 95%", 0, "n/a (gate, not value)", "hypotheses.py:H20", r)

if __name__ == "__main__":
    for h in (H1, H2, H3, H4, H5, H6, H7, H8, H9, H10, H11, H12, H13, H14, H15, H16, H17, H18, H19, H20):
        try:
            h()
        except Exception as e:
            print(f"[{h.__name__}] EXC {type(e).__name__}: {e}")
    print("\n=== KILL-LIST ===")
    for h, seq, leak, bounded, path, note in K:
        print(f"{h} | {seq} | leak={leak} | {bounded} | {path}\n    {note}")
