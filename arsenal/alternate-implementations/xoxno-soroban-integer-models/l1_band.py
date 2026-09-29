# Exact-integer replay of the band partial (curve.rs/math.rs) for mainnet spoke 1:
# USDC collateral (LT 8000, bonus 400, fee 1000, 7 dec), XLM debt (7 dec).
WAD=10**18; RAY=10**27; BPS=10000
def hu(x,y,d): return (x*y + d//2)//d          # mul_div_half_up
def fl(x,y,d): return (x*y)//d
def ce(x,y,d): return -((-x*y)//d)
def rescale_hu(v,f,t): return hu(v,10**t,10**f) if t<f else v*10**(t-f)
def rescale_fl(v,f,t): return fl(v,10**t,10**f) if t<f else v*10**(t-f)
def rescale_ce(v,f,t): return ce(v,10**t,10**f) if t<f else v*10**(t-f)
LT=8000; BONUS=400; FEE=1000; DEC=7
p_usdc=WAD; 
def book(col_units, debt_units, p_xlm):
    # supply index = borrow index = RAY (fresh markets)
    col_ray=col_units*10**(27-DEC); debt_ray=debt_units*10**(27-DEC)
    C=hu(rescale_hu(col_ray,27,18),p_usdc,WAD)                 # position_value (half-up)
    Cf=fl(rescale_fl(col_ray,27,18),p_usdc,WAD)                # floor for gates
    W=fl(Cf,LT,BPS)
    D=ce(rescale_ce(debt_ray,27,18),p_xlm,WAD)                 # ceil debt
    HF=fl(W,WAD,D)
    p=hu(W,WAD,C)
    cap=HF*BPS//p - BPS
    return C,W,D,HF,p,cap
def band_partial(col_units, debt_units, p_xlm, x_units):
    C,W,D,HF,p,cap=book(col_units,debt_units,p_xlm)
    assert HF<WAD and C>=D and cap<BONUS, (HF,C,D,cap)
    cap=max(cap,0)
    x_usd=hu(rescale_hu(x_units,DEC,18),p_xlm,WAD)             # usd_value_wad
    one_plus=WAD+hu(cap,WAD,BPS)
    seize_usd=hu(x_usd,one_plus,WAD)
    share=hu(C,WAD,C)                                          # single leg -> WAD
    leg_usd=hu(seize_usd,share,WAD)
    seize_wad=hu(leg_usd,WAD,p_usdc); seize_ray=rescale_hu(seize_wad,18,27)
    tok=rescale_fl(seize_ray,27,DEC)                           # partial: floor
    base_ray=fl(seize_ray,RAY,rescale_hu(one_plus,18,27))
    bonus_ray=max(seize_ray-base_ray,0)
    fee=rescale_fl(hu(bonus_ray,FEE,BPS),27,DEC); fee=max(fee,1) if bonus_ray>0 and fee==0 else fee
    realised=rescale_fl(tok*10**(27-DEC)-base_ray,27,DEC) if tok*10**(27-DEC)>base_ray else 0
    fee=min(fee,realised)
    # post state: debt burned = floor(x/borrow_index) shares -> x units exactly at index RAY
    C2,W2,D2,HF2,p2,cap2=book(col_units-tok, debt_units-x_units, p_xlm)
    return dict(C=C,D=D,HF=HF,p=p,cap=cap,x_usd=x_usd,seize_tok=tok,fee=fee,C2=C2,D2=D2,HF2=HF2,cap2=cap2,
                CD_before=C/D, CD_after=C2/D2 if D2 else None)
if __name__=="__main__":
    # 1000 USDC collateral; XLM debt of 3000 XLM priced so C/D = 1.002 (band: 1 <= C/D < 1.04)
    col=1000_0000000; debt=3000_0000000
    for ratio in (1.0020, 1.0001, 1.0000005):
        p_xlm=int(1000*WAD/ratio/3000)
        for x in (1_0000000, 100_0000000, 1000_0000000, 2999_0000000):
            r=band_partial(col,debt,p_xlm,x)
            print(f"C/D={ratio} x={x/1e7:.0f}XLM cap={r['cap']}bps seize={r['seize_tok']/1e7:.7f}USDC fee={r['fee']} "
                  f"C/D {r['CD_before']:.12f} -> {r['CD_after']:.12f} HF {r['HF']/1e18:.6f}->{r['HF2']/1e18:.6f} cap'={r['cap2']}  drop={r['CD_after']<r['CD_before']}")
