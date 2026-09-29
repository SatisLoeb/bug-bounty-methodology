import os
"""Exact-integer replica of the XOXNO liquidation pipeline (controller + pool rounding).
Mirrors: risk/totals.rs, liquidation/curve.rs, liquidation/math.rs, liquidation/apply.rs,
pool ops/withdraw.rs + ops/repay.rs, common/rates/scaling.rs, common/math/fp.rs.
Whole-unit rules (asset_decimals < 3) are NOT modelled: no mainnet market has < 5 decimals."""
import json, random, sys
WAD = 10**18; RAY = 10**27; BPS = 10000
BAD_DEBT_USD_THRESHOLD = 5 * WAD

def hu(x, y, d): return (x * y + d // 2) // d
def fl(x, y, d): return (x * y) // d
def ce(x, y, d): return -((-x * y) // d)
def rs_hu(v, f, t): return v * 10**(t - f) if t >= f else hu(v, 1, 10**(f - t))
def rs_fl(v, f, t): return v * 10**(t - f) if t >= f else fl(v, 1, 10**(f - t))
def rs_ce(v, f, t): return v * 10**(t - f) if t >= f else ce(v, 1, 10**(f - t))
def bps_to_wad(b): return hu(b, WAD, BPS)

def pos_value(scaled, idx, price):      return hu(rs_hu(hu(scaled, idx, RAY), 27, 18), price, WAD)
def pos_value_floor(scaled, idx, price): return fl(rs_fl(fl(scaled, idx, RAY), 27, 18), price, WAD)
def pos_value_ceil(scaled, idx, price):  return ce(rs_ce(ce(scaled, idx, RAY), 27, 18), price, WAD)
def usd_of_tokens(tok, dec, price):      return hu(rs_hu(tok, dec, 18), price, WAD)

class Leg:  # supply leg: stored tuple + market
    def __init__(s, name, dec, price, sidx, lt, bonus, fee, scaled):
        s.name, s.dec, s.price, s.sidx, s.lt, s.bonus, s.fee, s.scaled = name, dec, price, sidx, lt, bonus, fee, scaled
    def clone(s): return Leg(s.name, s.dec, s.price, s.sidx, s.lt, s.bonus, s.fee, s.scaled)
class Debt:
    def __init__(s, name, dec, price, bidx, scaled):
        s.name, s.dec, s.price, s.bidx, s.scaled = name, dec, price, bidx, scaled
    def clone(s): return Debt(s.name, s.dec, s.price, s.bidx, s.scaled)
    def ceil_units(s): return rs_ce(ce(s.scaled, s.bidx, RAY), 27, s.dec)

# ---------------- risk/totals.rs ----------------
def totals(legs, debts):
    C = W = 0
    for l in legs:
        C += pos_value(l.scaled, l.sidx, l.price)
        gate = pos_value_floor(l.scaled, l.sidx, l.price)
        W += fl(gate, bps_to_wad(l.lt), WAD)
    D = sum(pos_value_ceil(d.scaled, d.bidx, d.price) for d in debts)
    HF = 2**127 - 1 if D == 0 else fl(W, WAD, D)
    return C, W, D, HF

# ---------------- math.rs get_account_bonus_params / curve.rs ----------------
def max_bonus_for_threshold(p):
    if p <= 0: return 0
    t = min(max(ce(p, BPS, WAD), 1), BPS)
    return BPS * (BPS - t) // t
def bonus_params(legs, C, p):
    mx = max_bonus_for_threshold(p)
    if C == 0: return 0, mx
    s = 0
    for l in legs:
        w = hu(pos_value(l.scaled, l.sidx, l.price), WAD, C)
        s += hu(w, l.bonus, WAD)
    return min(s, mx), mx
def curve_bonus(hf, base, mx, H, K, f):
    if hf >= H: return base
    scale = WAD if H <= K else min(WAD, hu(H - hf, WAD, H - K))
    inc = hu(mx - base, scale, WAD)
    return base + hu(inc, f, BPS)
def liquidation_at_target(C, W, D, p, bonus, H):
    one_plus = WAD + bps_to_wad(bonus)
    d_max = hu(C, WAD, one_plus)
    denom_term = hu(p, one_plus, WAD)
    target_debt = hu(H, D, WAD)
    if H <= denom_term or target_debt <= W: return min(d_max, D)
    return min(hu(target_debt - W, WAD, H - denom_term), d_max, D)
def estimate(C, W, D, HF, p, base, mx, H, K, f):
    """returns (ideal_usd, bonus_bps, arm)"""
    scaled = curve_bonus(HF, base, mx, H, K, f)
    cap = None if (p <= 0 or HF >= WAD) else HF * BPS // p - BPS
    if cap is None:
        bonus, arm = scaled, "zero-threshold"
    elif C < D:
        backed = fl(C, WAD, WAD + bps_to_wad(base))
        return min(backed, D), base, "insolvent"
    elif cap < base:
        return D, max(cap, 0), "band"
    else:
        bonus, arm = min(scaled, cap), "target"
    ideal = liquidation_at_target(C, W, D, p, bonus, H)
    rem = D - ideal
    if 0 < rem < BAD_DEBT_USD_THRESHOLD: return D, bonus, arm + "+dust-promoted"
    return ideal, bonus, arm

# ---------------- math.rs normalize_repayment_plan ----------------
def process_excess(entries, refunds, excess, keep_within_quote):
    rem = excess; i = len(entries)
    while rem > 0 and i > 0:
        i -= 1; e = entries[i]
        if e["amount"] <= 0 or e["usd"] == 0: continue
        if e["usd"] > rem:
            d = e["debt"]
            if keep_within_quote:
                new_amount = min(rs_fl(fl(e["usd"] - rem, WAD, d.price), 18, d.dec), e["amount"])
            else:
                ratio = fl(rem, WAD, e["usd"])
                new_amount = e["amount"] - rs_fl(fl(rs_hu(e["amount"], d.dec, 18), ratio, WAD), 18, d.dec)
            new_usd = usd_of_tokens(new_amount, d.dec, d.price)
            refunds.append((d.name, e["amount"] - new_amount))
            if new_amount == 0: entries.pop(i)
            else: e["amount"], e["usd"] = new_amount, new_usd
            if keep_within_quote:
                removed = e["usd_before"] - new_usd if new_amount else e["usd_before"]
                rem = 0 if removed >= rem else rem - removed
            else: rem = 0
        else:
            refunds.append((e["debt"].name, e["amount"])); entries.pop(i); rem -= e["usd"]

def build_plan(legs, debts, offers, curve):
    """offers: list of (debt_name, amount). Returns plan dict or raises."""
    H, K, f = curve
    C, W, D, HF = totals(legs, debts)
    if D == 0 or HF >= WAD: raise Exception("HealthFactorTooHigh")
    p = hu(W, WAD, C) if C > 0 else 0
    base, mx = bonus_params(legs, C, p)
    # aggregate offers (order of first appearance)
    merged = {}
    for n, a in offers:
        if a <= 0: raise Exception("InvalidPayments")
        merged[n] = merged.get(n, 0) + a
    refunds = []; entries = []; total = 0
    for n, a in merged.items():
        d = next((x for x in debts if x.name == n), None)
        if d is None: raise Exception("DebtPositionNotFound")
        cap_units = d.ceil_units()
        pay = a
        if pay > cap_units: refunds.append((n, pay - cap_units)); pay = cap_units
        usd = usd_of_tokens(pay, d.dec, d.price)
        total += usd
        entries.append({"debt": d, "amount": pay, "usd": usd, "usd_before": usd})
    ideal, bonus, arm = estimate(C, W, D, HF, p, base, mx, H, K, f)
    insolvent = C < D
    full_close = ideal >= D
    if not full_close and total > ideal:
        process_excess(entries, refunds, total - ideal, insolvent)
    repay = sum(e["usd"] for e in entries)
    one_unit = sum(usd_of_tokens(1, e["debt"].dec, e["debt"].price) for e in entries)
    seize_all = insolvent and repay > 0 and repay + one_unit >= ideal
    repays_all = full_close and len(entries) == len(debts) and all(e["amount"] >= e["debt"].ceil_units() for e in entries)
    if not entries: raise Exception("InvalidPayments(empty after trim)")
    seized = seize(legs, C, repay, bonus, seize_all)
    return dict(C=C, W=W, D=D, HF=HF, p=p, base=base, max=mx, ideal=ideal, bonus=bonus, arm=arm,
                entries=entries, refunds=refunds, repay=repay, full_close=full_close, offers=merged,
                seize_all=seize_all, repays_all=repays_all, seized=seized)

def resolve_withdrawal(amount, scaled, sidx, dec):
    cur_actual = rs_hu(hu(scaled, sidx, RAY), 27, dec)
    cur_floor = rs_fl(fl(scaled, sidx, RAY), 27, dec)
    if amount >= cur_actual: return scaled, cur_floor
    return ce(rs_hu(amount, dec, 27), RAY, sidx), amount
def resolve_repay(amount, scaled, bidx, dec):
    cur_ceil = rs_ce(ce(scaled, bidx, RAY), 27, dec)
    if amount >= cur_ceil: return scaled, amount - cur_ceil
    return fl(rs_hu(amount, dec, 27), RAY, bidx), 0

# ---------------- math.rs calculate_seized_collateral ----------------
def seize(legs, C, repay, bonus, seize_all):
    out = []
    if C <= 0: return out
    one_plus = WAD + bps_to_wad(bonus); one_plus_ray = rs_hu(one_plus, 18, 27)
    total_seizure = hu(repay, one_plus, WAD)
    for l in legs:
        actual_ray = hu(l.scaled, l.sidx, RAY)
        value = pos_value(l.scaled, l.sidx, l.price)
        share = hu(value, WAD, C)
        leg_usd = hu(total_seizure, share, WAD)
        seize_ray = rs_hu(hu(leg_usd, WAD, l.price), 18, 27)
        if seize_ray <= 0: continue
        capped = actual_ray if seize_all else min(seize_ray, actual_ray)
        if capped <= 0: continue
        is_full = capped == actual_ray
        base_ray = fl(seize_ray, RAY, one_plus_ray)
        bonus_ray = capped - base_ray if capped > base_ray else 0
        fee_ray = hu(bonus_ray, l.fee, BPS)
        seized_scaled = l.scaled if is_full else fl(capped, RAY, l.sidx)
        bonus_scaled = min(fl(bonus_ray, RAY, l.sidx), seized_scaled)
        if seized_scaled <= 0: continue
        amount = rs_hu(capped, 27, l.dec) if is_full else rs_fl(capped, 27, l.dec)
        if amount <= 0: continue
        _, pool_gross = resolve_withdrawal(amount, l.scaled, l.sidx, l.dec)
        fee_asset = rs_fl(fee_ray, 27, l.dec)
        bumped = 1 if (fee_ray > 0 and fee_asset == 0) else fee_asset
        paid_ray = rs_hu(pool_gross, l.dec, 27)
        realised = rs_fl(paid_ray - base_ray, 27, l.dec) if paid_ray > base_ray else 0
        out.append(dict(leg=l, amount=amount, fee=min(bumped, realised), scaled=seized_scaled,
                        bonus_scaled=bonus_scaled, fee_bps=l.fee, is_full=is_full,
                        base_ray=base_ray, seize_ray=seize_ray))
        assert 0 <= out[-1]["fee"] <= amount and 0 <= bonus_scaled <= seized_scaled
    return out

def scale_to_received(seized, received, planned):
    if planned <= 0 or received >= planned: return seized
    r = []
    for s in seized:
        t = dict(s); t["amount"] = fl(s["amount"], received, planned); t["fee"] = fl(s["fee"], received, planned)
        t["scaled"] = fl(s["scaled"], received, planned); t["bonus_scaled"] = fl(s["bonus_scaled"], received, planned)
        r.append(t)
    return r

# ---------------- execution: apply.rs + pool ----------------
def execute(legs, debts, offers, curve, mode="transfer", deliver=lambda name, pull: pull):
    """Returns result dict: liquidator paid/received (USD), borrower loss, post book, cleanup."""
    legs = [l.clone() for l in legs]; debts = [d.clone() for d in debts]
    plan = build_plan(legs, debts, offers, curve)
    # repayments
    received_usd = 0; paid_usd = 0; paid_tokens = {}
    for e in plan["entries"]:
        d = e["debt"]
        pull = plan["offers"][d.name] if plan["full_close"] else e["amount"]
        recv = deliver(d.name, pull)
        assert recv > 0
        leg_usd = e["usd"] if recv >= e["amount"] else fl(e["usd"], recv, e["amount"])
        received_usd += leg_usd
        burned, over = resolve_repay(recv, d.scaled, d.bidx, d.dec)
        net = recv - over
        assert net == 0 or burned > 0
        d.scaled -= burned
        paid_tokens[d.name] = paid_tokens.get(d.name, 0) + net   # pool refunds `over` to the liquidator
        paid_usd += usd_of_tokens(net, d.dec, d.price)
    seized = scale_to_received(plan["seized"], received_usd, plan["repay"])
    got_usd = 0; fee_usd = 0; borrower_col_lost_usd = 0
    for s in seized:
        l = s["leg"]
        if s["amount"] <= 0: continue
        if mode == "transfer":
            burned, gross = resolve_withdrawal(s["amount"], l.scaled, l.sidx, l.dec)
            assert gross == 0 or burned > 0, "WithdrawRoundsToZeroShares"
            assert gross >= s["fee"], "WithdrawLessThanFee"
            net = gross - s["fee"]
            got_usd += usd_of_tokens(net, l.dec, l.price); fee_usd += usd_of_tokens(s["fee"], l.dec, l.price)
            borrower_col_lost_usd += pos_value(burned, l.sidx, l.price)
            l.scaled -= burned
        else:
            fee_scaled = ce(s["bonus_scaled"], s["fee_bps"], BPS)
            assert fee_scaled <= s["scaled"]
            liq_scaled = s["scaled"] - fee_scaled
            assert l.scaled >= s["scaled"], "checked_sub over-seizure"
            l.scaled -= s["scaled"]
            got_usd += pos_value(liq_scaled, l.sidx, l.price); fee_usd += pos_value(fee_scaled, l.sidx, l.price)
            borrower_col_lost_usd += pos_value(s["scaled"], l.sidx, l.price)
    legs2 = [l for l in legs if l.scaled > 0]; debts2 = [d for d in debts if d.scaled > 0]
    C2, W2, D2, HF2 = totals(legs2, debts2)
    cleanup = None
    if debts2 and D2 > C2 and C2 <= BAD_DEBT_USD_THRESHOLD:
        cleanup = dict(socialized=D2, revenue_from_collateral=C2); legs2 = []; debts2 = []
    return dict(plan=plan, received_usd=received_usd, paid_usd=paid_usd, got_usd=got_usd, fee_usd=fee_usd,
                profit=got_usd - paid_usd, borrower_loss=borrower_col_lost_usd - (plan["D"] - D2),
                C2=C2, D2=D2, HF2=HF2, legs2=legs2, debts2=debts2, cleanup=cleanup)

# ---------------- mainnet parameters ----------------
SPOKES = json.load(open(os.environ.get("XOXNO_REPO", ".") + "/configs/mainnet/spokes.json"))
def listing(spoke, asset):
    a = SPOKES[str(spoke)]["assets"][asset]
    return a["liquidation_threshold"], a["liquidation_bonus"], a["liquidation_fees"]
def curve_of(spoke):
    c = SPOKES[str(spoke)]["liquidation_curve"]
    return int(c["target_hf_wad"]), int(c["hf_for_max_bonus_wad"]), int(c["liquidation_bonus_factor_bps"])

def usd(x): return int(round(x * WAD))
def fmt(w): return f"{w / WAD:,.6f}"
