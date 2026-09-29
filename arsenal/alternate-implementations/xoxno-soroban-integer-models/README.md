# XOXNO Lending (rs-lending-xlm v1.0.1) — exact-integer reference models

Python transcriptions of the protocol's fixed-point / share / index / liquidation arithmetic (each function cites
the Rust file:line it mirrors). Used to run dirty-number searches for rounding leaks, accrual conservation, net
settlement, revenue payout, write-down, liquidation quotes (target/band/insolvent arms, Credit vs Transfer,
under-delivery, split chains). All results: pool-favoured or zero; no extraction. Run with `python3 <file>`; `liq_model.py`/`scenarios.py` read `$XOXNO_REPO/configs/mainnet/spokes.json` (set `XOXNO_REPO` to a clone of rs-lending-xlm).
Not a PoC and not an exploit; a verification aid for re-opening the target on a new deployed commit.
- `xoxno_math.py`, `sim.py`, `hypotheses.py`, `targeted.py`, `search.py`, `accrual.py` — pool/share/index math.
- `xoxno_model.py`, `xoxno_fuzz.py`, `xoxno_fuzz2.py` — pool ops model + fuzz (~1.6M cases).
- `liq_model.py`, `scenarios.py`, `l1_band.py` — liquidation engine replica against mainnet spoke params.
- `harness-lp-footprint/` — test-harness additions (drop into `tests/test-harness/tests/` and `src/`, register the
  modules) that measure liquidation footprint/CPU/memory for accounts holding Aquarius-LP collateral legs; run
  `cargo test -p test-harness --features testing --test lp_liq_footprint -- --nocapture --test-threads=1`.
