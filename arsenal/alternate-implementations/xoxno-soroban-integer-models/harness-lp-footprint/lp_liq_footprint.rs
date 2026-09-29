//! MEASUREMENT: transaction footprint and budget of `liquidate` (Transfer and
//! Credit(0)), `clean_bad_debt`, `withdraw` and `get_health_factor` over
//! accounts whose collateral legs are Aquarius LP tokens priced through the
//! real price aggregator with nested dual-source underlyings, versus the same
//! account shapes with plain dual-source (Reflector Twap(3) + RedStone)
//! collateral legs.
//!
//! Scenario C (control): plain dual-source legs, ladder 1C+1D .. 5C+5D.
//! Scenario B: 3 LP collateral legs + 4 dual-source debts.
//! Scenario A: 5 LP collateral legs (mainnet-like set) + 4 debts.
//! Replay: the same accounts liquidated with the controller and aggregator
//! swapped to their release WASM so CPU/memory are metered like on-chain.
//!
//! Run:
//!   cargo test -p test-harness --features testing --test lp_liq_footprint -- --nocapture --test-threads=1
extern crate std;

use std::collections::BTreeMap;

use common::types::SeizeMode;
use controller::types::{
    AssetOracle, FeedNature, FeedSource, IndependencePolicy, MultiFeedRef, OracleAssetRef,
    OracleReadMode, PriceKey, PriceSource, ProviderRef, ReflectorFeedRef, ScaledSource,
};
use governance::op::{AdminOperation, ConfigureAssetOracleArgs};
use soroban_sdk::testutils::budget::ContractCostType;
use soroban_sdk::testutils::{Address as _, Ledger as _};
use soroban_sdk::{
    token, xdr, Address, Bytes, Env, String as SString, Symbol, TryIntoVal, Vec as SVec,
};
use test_harness::mock_aquarius::MockAquariusPool;
use test_harness::mock_redstone::MockRedStonePriceFeedClient;
use test_harness::mock_reflector::{MockReflector, MockReflectorClient};
use test_harness::oracle::redstone::{
    anchor_market_with_redstone, anchor_market_with_redstone_feed, register_redstone_adapter,
};
use test_harness::{
    hub_asset, redstone_single_config, tolerance_band, usd, AssetConfigPreset, LendingTest,
    MarketPreset, ALICE, BOB, CAROL, DEFAULT_ASSET_CONFIG, DEFAULT_MARKET_PARAMS,
    DEFAULT_MAX_SANITY_PRICE_WAD, DEFAULT_MIN_SANITY_PRICE_WAD, LIQUIDATOR,
};

// ---------------------------------------------------------------------------
// Limits
// ---------------------------------------------------------------------------

/// Limits the task statement and the repo's own `meta/footprint_test.rs` /
/// `meta/budget_breakdown.rs` assert against (pre protocol-23 mainnet).
const OLD_ENTRIES: u32 = 100;
const OLD_WRITES: u32 = 50;
const OLD_CPU: u64 = 100_000_000;
/// Limits `soroban_sdk::testutils::cost_estimate::InvocationResourceLimits::mainnet()`
/// ships for SDK 28 (mainnet snapshot 2026-07-10).
const CUR_ENTRIES: u32 = 400;
const CUR_WRITES: u32 = 200;
const CUR_CPU: u64 = 400_000_000;
const MEM_LIMIT: u64 = 41_943_040;
const READ_BYTES_LIMIT: u32 = 200_000;

// ---------------------------------------------------------------------------
// Measurement helpers
// ---------------------------------------------------------------------------

#[derive(Clone, Debug)]
struct Row {
    label: String,
    cpu: u64,
    mem: u64,
    disk_r: u32,
    mem_r: u32,
    writes: u32,
    read_bytes: u32,
    write_bytes: u32,
    events: u32,
    contracts: usize,
    calls: usize,
}

impl Row {
    fn entries(&self) -> u32 {
        self.disk_r + self.mem_r + self.writes
    }
}

fn capture(env: &Env, label: &str, labels: &Labels) -> Row {
    let r = env.cost_estimate().resources();
    let b = env.cost_estimate().budget();
    let (contracts, calls) = distinct_contracts(env, labels);
    Row {
        label: label.to_string(),
        cpu: b.cpu_instruction_cost(),
        mem: b.memory_bytes_cost(),
        disk_r: r.disk_read_entries,
        mem_r: r.memory_read_entries,
        writes: r.write_entries,
        read_bytes: r.disk_read_bytes,
        write_bytes: r.write_bytes,
        events: r.contract_events_size_bytes,
        contracts,
        calls,
    }
}

fn measured<T>(env: &Env, label: &str, labels: &Labels, f: impl FnOnce() -> T) -> (Row, T) {
    let mut b = env.cost_estimate().budget();
    b.reset_unlimited();
    b.reset_tracker();
    let out = f();
    (capture(env, label, labels), out)
}

fn header() {
    std::println!(
        "  {:<44} {:>7} {:>6} {:>6} {:>6} {:>8} {:>8} {:>6} {:>12} {:>11} {:>5} {:>5}",
        "call",
        "entries",
        "diskR",
        "memR",
        "writes",
        "readB",
        "writeB",
        "evB",
        "cpu",
        "mem",
        "ctr",
        "calls"
    );
}

fn print_row(r: &Row) {
    std::println!(
        "  {:<44} {:>7} {:>6} {:>6} {:>6} {:>8} {:>8} {:>6} {:>12} {:>11} {:>5} {:>5}",
        r.label,
        r.entries(),
        r.disk_r,
        r.mem_r,
        r.writes,
        r.read_bytes,
        r.write_bytes,
        r.events,
        r.cpu,
        r.mem,
        r.contracts,
        r.calls
    );
}

fn verdict(r: &Row) -> String {
    let e = r.entries();
    let old = e <= OLD_ENTRIES && r.writes <= OLD_WRITES && r.cpu <= OLD_CPU && r.mem <= MEM_LIMIT;
    let cur = e <= CUR_ENTRIES && r.writes <= CUR_WRITES && r.cpu <= CUR_CPU && r.mem <= MEM_LIMIT;
    let mut binding = std::vec::Vec::new();
    if e > OLD_ENTRIES {
        binding.push(std::format!("entries {e}>{OLD_ENTRIES}"));
    }
    if r.writes > OLD_WRITES {
        binding.push(std::format!("writes {}>{OLD_WRITES}", r.writes));
    }
    if r.cpu > OLD_CPU {
        binding.push(std::format!("cpu {}>{OLD_CPU}", r.cpu));
    }
    if r.mem > MEM_LIMIT {
        binding.push(std::format!("mem {}>{MEM_LIMIT}", r.mem));
    }
    if r.read_bytes > READ_BYTES_LIMIT {
        binding.push(std::format!("readB {}>{READ_BYTES_LIMIT}", r.read_bytes));
    }
    std::format!(
        "old(100e/50w/100M): {}  current(400e/200w/400M): {}  {}",
        if old { "FITS" } else { "EXCEEDS" },
        if cur { "FITS" } else { "EXCEEDS" },
        binding.join(", ")
    )
}

/// Maps contract addresses (as their `ScAddress` debug rendering, which is
/// what `MeteringInvocation` prints) to readable labels.
struct Labels(std::vec::Vec<(String, String)>);

impl Labels {
    fn new() -> Self {
        Labels(std::vec::Vec::new())
    }
    fn add(&mut self, addr: &Address, label: &str) {
        self.0.push((
            std::format!("{:?}", xdr::ScAddress::from(addr)),
            label.to_string(),
        ));
    }
    fn label(&self, invocation_dbg: &str) -> String {
        for (dbg, label) in &self.0 {
            if invocation_dbg.contains(dbg.as_str()) {
                return label.clone();
            }
        }
        "?unknown".to_string()
    }
}

fn fn_name(invocation_dbg: &str) -> String {
    // `InvokeContract(Contract(..), ScSymbol(StringM("prices")))`
    match invocation_dbg.rfind("StringM(") {
        Some(i) => {
            let rest = &invocation_dbg[i + 8..];
            rest.trim_matches(|c| c == '"' || c == ')' || c == ']')
                .to_string()
        }
        None => invocation_dbg.to_string(),
    }
}

#[derive(Default, Clone)]
struct Agg {
    calls: u32,
    entries_incl: i32,
    entries_excl: i32,
    writes_excl: i32,
    cpu_excl: i64,
    mem_excl: i64,
    fns: BTreeMap<String, u32>,
}

/// Per-contract breakdown of the last invocation: calls, footprint entries
/// first touched inside that contract's frames (exclusive of sub-calls), and
/// exclusive CPU / memory.
fn breakdown(env: &Env, labels: &Labels) -> BTreeMap<String, Agg> {
    let mut out: BTreeMap<String, Agg> = BTreeMap::new();
    let Some(d) = env.host().get_detailed_last_invocation_resources() else {
        return out;
    };
    let mut stack = std::vec![&d];
    while let Some(node) = stack.pop() {
        let dbg = std::format!("{:?}", node.invocation);
        let label = labels.label(&dbg);
        let child_entries: i32 = node
            .sub_call_resources
            .iter()
            .map(|c| c.resources.disk_read_entries + c.resources.memory_read_entries)
            .sum();
        let child_writes: i32 = node
            .sub_call_resources
            .iter()
            .map(|c| c.resources.write_entries)
            .sum();
        let child_cpu: i64 = node
            .sub_call_resources
            .iter()
            .map(|c| c.resources.instructions)
            .sum();
        let child_mem: i64 = node
            .sub_call_resources
            .iter()
            .map(|c| c.resources.mem_bytes)
            .sum();
        let incl = node.resources.disk_read_entries + node.resources.memory_read_entries;
        let agg = out.entry(label).or_default();
        agg.calls += 1;
        agg.entries_incl += incl;
        agg.entries_excl += incl - child_entries;
        agg.writes_excl += node.resources.write_entries - child_writes;
        agg.cpu_excl += node.resources.instructions - child_cpu;
        agg.mem_excl += node.resources.mem_bytes - child_mem;
        *agg.fns.entry(fn_name(&dbg)).or_default() += 1;
        for c in node.sub_call_resources.iter() {
            stack.push(c);
        }
    }
    out
}

fn distinct_contracts(env: &Env, labels: &Labels) -> (usize, usize) {
    let b = breakdown(env, labels);
    let calls: u32 = b.values().map(|a| a.calls).sum();
    (b.len(), calls as usize)
}

fn print_breakdown(env: &Env, labels: &Labels) {
    let b = breakdown(env, labels);
    std::println!("    per-contract (exclusive of sub-calls): calls | entries first-touched | writes | cpu | mem | fns");
    let mut rows: std::vec::Vec<(&String, &Agg)> = b.iter().collect();
    rows.sort_by_key(|(_, a)| std::cmp::Reverse(a.entries_excl));
    for (label, a) in rows {
        let fns: std::vec::Vec<String> =
            a.fns.iter().map(|(f, n)| std::format!("{f}x{n}")).collect();
        std::println!(
            "      {:<22} calls={:>3} entries={:>3} writes={:>3} cpu={:>10} mem={:>9}  {}",
            label,
            a.calls,
            a.entries_excl,
            a.writes_excl,
            a.cpu_excl,
            a.mem_excl,
            fns.join(" ")
        );
    }
}

fn dump_cost_types(env: &Env, top: usize) {
    let b = env.cost_estimate().budget();
    let mut rows: std::vec::Vec<(ContractCostType, u64, u64, u64)> = std::vec::Vec::new();
    for ct in ContractCostType::VARIANTS.iter().copied() {
        let tr = b.tracker(ct);
        if tr.cpu > 0 || tr.iterations > 0 {
            rows.push((ct, tr.cpu, tr.mem, tr.iterations));
        }
    }
    rows.sort_by_key(|r| std::cmp::Reverse(r.1 + r.2));
    let (mut icpu, mut imem, mut iiters) = (0u64, 0u64, 0u64);
    for (ct, cpu, mem, iters) in &rows {
        let name = std::format!("{ct:?}");
        if name.starts_with("InstantiateWasm")
            || name.starts_with("VmInstantiation")
            || name.starts_with("VmCachedInstantiation")
        {
            icpu += cpu;
            imem += mem;
            iiters = iiters.max(*iters);
        }
    }
    for (ct, cpu, mem, iters) in rows.into_iter().take(top) {
        std::println!(
            "      {:<34?} cpu={:>11} mem={:>10} iters={:>7}",
            ct,
            cpu,
            mem,
            iters
        );
    }
    std::println!(
        "    VM instantiation subtotal: cpu={icpu} mem={imem} over {iiters} instantiations => per call cpu={} mem={}",
        icpu / iiters.max(1),
        imem / iiters.max(1)
    );
}

fn plain_market(
    name: &'static str,
    decimals: u32,
    price_wad: i128,
    borrowable: bool,
) -> MarketPreset {
    MarketPreset {
        name,
        decimals,
        price_wad,
        initial_liquidity: 10_000_000.0,
        config: AssetConfigPreset {
            is_borrowable: borrowable,
            ..DEFAULT_ASSET_CONFIG
        },
        params: DEFAULT_MARKET_PARAMS,
    }
}

fn scale(p: i128, num: i128, den: i128) -> i128 {
    p * num / den
}

fn base_labels(t: &LendingTest) -> Labels {
    let mut l = Labels::new();
    l.add(&t.controller, "controller");
    l.add(&t.price_aggregator, "price_aggregator");
    l.add(&t.governance, "governance");
    l.add(&t.position_nft, "position_nft");
    l.add(&t.mock_reflector, "reflector_cex");
    let mut names: std::vec::Vec<&String> = t.markets.keys().collect();
    names.sort();
    if let Some(n) = names.first() {
        l.add(&t.markets[*n].pool, "pool");
    }
    for n in names {
        l.add(&t.markets[n].asset, &std::format!("tok:{n}"));
    }
    l
}

/// Supplies `legs` into `user`'s default account (created on the first leg).
fn supply_legs(t: &mut LendingTest, user: &str, legs: &[(&str, f64)]) {
    let mut first = true;
    for (name, amount) in legs {
        if first {
            t.supply(user, name, *amount);
            first = false;
        } else {
            let id = t.resolve_account_id(user);
            t.supply_to(user, id, name, *amount);
        }
    }
}

fn liquidate_mode(
    t: &mut LendingTest,
    liquidator: &str,
    target: &str,
    debts: &[(&str, f64)],
    mode: SeizeMode,
) -> u64 {
    let liq = t.get_or_create_user(liquidator);
    let id = t.resolve_account_id(target);
    let mut payments = SVec::new(&t.env);
    for (name, amount) in debts {
        let m = t.resolve_market(name);
        let raw = test_harness::amount_raw(*amount, m.decimals);
        m.token_admin.mint(&liq, &raw);
        payments.push_back((hub_asset(m.asset.clone()), raw));
    }
    t.ctrl_client().liquidate(&liq, &id, &payments, &mode)
}

fn read_price(t: &LendingTest, name: &str) -> i128 {
    let key = PriceKey::Token(t.resolve_asset(name));
    let keys = SVec::from_array(&t.env, [key.clone()]);
    t.price_agg_client()
        .prices(&keys)
        .get(key)
        .unwrap()
        .price_wad
}

// ---------------------------------------------------------------------------
// Scenario C: plain dual-source legs (control)
// ---------------------------------------------------------------------------

const COLL: [&str; 5] = ["C0", "C1", "C2", "C3", "C4"];
const DEBT: [&str; 5] = ["D0", "D1", "D2", "D3", "D4"];

struct PlainCtx {
    t: LendingTest,
    adapter: Address,
    labels: Labels,
}

fn plain_ctx(nc: usize, nd: usize) -> PlainCtx {
    let mut b = LendingTest::new()
        .with_position_limits(5, 5)
        .with_min_borrow_collateral_disabled();
    for name in COLL.iter().take(nc).chain(DEBT.iter().take(nd)) {
        b = b.with_market(plain_market(name, 7, usd(1), true));
    }
    let t = b.build();
    t.env.cost_estimate().disable_resource_limits();
    t.env.cost_estimate().budget().reset_unlimited();
    let feeds: std::vec::Vec<(&str, i128)> = COLL
        .iter()
        .take(nc)
        .chain(DEBT.iter().take(nd))
        .map(|n| (*n, usd(1)))
        .collect();
    let adapter = register_redstone_adapter(&t, &feeds);
    for (name, _) in &feeds {
        anchor_market_with_redstone(&t, &adapter, name);
    }
    let mut labels = base_labels(&t);
    labels.add(&adapter, "redstone");
    PlainCtx { t, adapter, labels }
}

fn plain_set_price(c: &mut PlainCtx, name: &str, price_wad: i128) {
    c.t.set_price(name, price_wad);
    MockRedStonePriceFeedClient::new(&c.t.env, &c.adapter)
        .set_price(&SString::from_str(&c.t.env, name), &price_wad);
}

fn plain_scenario(nc: usize, nd: usize, verbose: bool) -> std::vec::Vec<Row> {
    let mut c = plain_ctx(nc, nd);
    let coll: std::vec::Vec<(&str, f64)> = COLL.iter().take(nc).map(|n| (*n, 1000.0)).collect();
    // 75% LTV: $1000 x nc collateral, $600 x nd debt fits for every ladder rung.
    let debt_each = 600.0 * nc as f64 / nd as f64 * 0.8;
    let debts: std::vec::Vec<(&str, f64)> = DEBT.iter().take(nd).map(|n| (*n, debt_each)).collect();
    for user in [ALICE, BOB, CAROL] {
        supply_legs(&mut c.t, user, &coll);
        for (name, amount) in &debts {
            c.t.borrow(user, name, *amount);
        }
    }
    c.t.advance_time_no_refresh(60);
    for name in COLL.iter().take(nc).chain(DEBT.iter().take(nd)) {
        plain_set_price(&mut c, name, usd(1));
    }
    let tag = std::format!("plain {nc}C+{nd}D");
    let env = c.t.env.clone();
    let mut rows = std::vec::Vec::new();
    let id = c.t.resolve_account_id(ALICE);
    let (r, _) = measured(
        &env,
        &std::format!("{tag} get_health_factor"),
        &c.labels,
        || c.t.ctrl_client().get_health_factor(&id),
    );
    rows.push(r);
    let (r, _) = measured(
        &env,
        &std::format!("{tag} withdraw 1 (healthy)"),
        &c.labels,
        || c.t.withdraw(ALICE, COLL[0], 1.0),
    );
    rows.push(r);
    // Crash every collateral to 50c: HF = 0.5 * 0.8 * 1000nc / (480nc) = 0.83.
    for name in COLL.iter().take(nc) {
        plain_set_price(&mut c, name, scale(usd(1), 50, 100));
    }
    assert!(
        c.t.can_be_liquidated(ALICE),
        "{tag}: account must be liquidatable"
    );
    let pay: std::vec::Vec<(&str, f64)> = debts.iter().map(|(n, a)| (*n, a / 6.0)).collect();
    let (r, _) = measured(
        &env,
        &std::format!("{tag} liquidate Transfer"),
        &c.labels,
        || liquidate_mode(&mut c.t, LIQUIDATOR, ALICE, &pay, SeizeMode::Transfer),
    );
    if verbose {
        print_breakdown(&env, &c.labels);
    }
    rows.push(r);
    let (r, _) = measured(
        &env,
        &std::format!("{tag} liquidate Credit(0)"),
        &c.labels,
        || liquidate_mode(&mut c.t, LIQUIDATOR, BOB, &pay, SeizeMode::Credit(0)),
    );
    rows.push(r);
    // Deep crash: collateral below the $5 dust cap, debt above it.
    for name in COLL.iter().take(nc) {
        plain_set_price(&mut c, name, scale(usd(1), 1, 10_000));
    }
    let cid = c.t.resolve_account_id(CAROL);
    let (r, res) = measured(
        &env,
        &std::format!("{tag} clean_bad_debt"),
        &c.labels,
        || c.t.try_clean_bad_debt_by_id(cid),
    );
    assert!(res.is_ok(), "{tag}: clean_bad_debt failed: {res:?}");
    rows.push(r);
    rows
}

#[test]
fn scenario_c_plain_dual_source_ladder() {
    std::println!("\n=== SCENARIO C: plain dual-source (Reflector Twap(3) + RedStone) legs, native harness ===");
    std::println!("    entries = diskR + memR + writes (the network footprint counts every key, read or written)");
    header();
    let mut all = std::vec::Vec::new();
    for (nc, nd) in [(1, 1), (2, 2), (3, 3), (4, 4), (5, 4), (5, 5)] {
        let rows = plain_scenario(nc, nd, nc == 5 && nd == 4);
        for r in &rows {
            print_row(r);
        }
        all.extend(rows);
    }
    std::println!("\n  verdicts (liquidate Transfer):");
    for r in all
        .iter()
        .filter(|r| r.label.ends_with("liquidate Transfer"))
    {
        std::println!("    {:<28} {}", r.label, verdict(r));
    }
}

// ---------------------------------------------------------------------------
// LP scenarios (A: 5 LP legs, B: 3 LP legs)
// ---------------------------------------------------------------------------

struct LpCtx {
    t: LendingTest,
    adapter: Address,
    reflector_dex: Address,
    btc_ref_asset: Address,
    pools: std::vec::Vec<(&'static str, Address, bool)>,
    labels: Labels,
}

const LP_NAMES: [&str; 5] = [
    "XLMUSDC_LP",
    "XSOLVSOLV_LP",
    "XAUMUSDC_LP",
    "USTRYUSDC_LP",
    "XLMAQUA_LP",
];
const LP_DEBTS: [&str; 4] = ["USDC", "EURC", "XLM", "PYUSD"];

fn p_xlm() -> i128 {
    scale(usd(1), 30, 100)
}
fn p_btc() -> i128 {
    usd(100_000)
}
fn p_xaum() -> i128 {
    usd(3_000)
}
fn p_ustry() -> i128 {
    scale(usd(1), 105, 100)
}
fn p_aqua() -> i128 {
    scale(usd(1), 2, 1000)
}
fn p_eurc() -> i128 {
    scale(usd(1), 110, 100)
}

fn feed(contract: &Address, asset: &Address, max_stale: u64) -> FeedSource {
    FeedSource {
        provider: ProviderRef::Reflector(ReflectorFeedRef {
            contract: contract.clone(),
            asset: OracleAssetRef::Stellar(asset.clone()),
            read_mode: OracleReadMode::Twap(3),
        }),
        decimals: 14,
        max_stale_seconds: max_stale,
    }
}

fn rs_feed(env: &Env, adapter: &Address, id: &str, max_stale: u64) -> FeedSource {
    FeedSource {
        provider: ProviderRef::RedStone(MultiFeedRef {
            contract: adapter.clone(),
            feed_id: SString::from_str(env, id),
            nature: FeedNature::Fundamental,
        }),
        decimals: 8,
        max_stale_seconds: max_stale,
    }
}

fn oracle(
    env: &Env,
    sources: &[PriceSource],
    tol_bps: u32,
    independence: IndependencePolicy,
) -> AssetOracle {
    let mut v = SVec::new(env);
    let mut ceiling = 57_600u64;
    for s in sources {
        let loosest = match s {
            PriceSource::Feed(f) => f.max_stale_seconds,
            PriceSource::Scaled(sc) => sc.factor.max_stale_seconds,
            _ => 0,
        };
        ceiling = ceiling.max(loosest);
        v.push_back(s.clone());
    }
    AssetOracle {
        asset_decimals: 7,
        max_price_stale_seconds: ceiling,
        sources: v,
        tolerance: tolerance_band(env, tol_bps),
        independence,
        min_sanity_price_wad: DEFAULT_MIN_SANITY_PRICE_WAD,
        max_sanity_price_wad: DEFAULT_MAX_SANITY_PRICE_WAD,
    }
}

fn lp_ctx(n_lp: usize) -> LpCtx {
    // Underlyings mirror configs/mainnet/markets.json decimals.
    let mut b = LendingTest::new()
        .with_position_limits(5, 5)
        .with_min_borrow_collateral_disabled()
        .with_market(plain_market("XLM", 7, p_xlm(), true))
        .with_market(plain_market("USDC", 7, usd(1), true))
        .with_market(plain_market("EURC", 7, p_eurc(), true))
        .with_market(plain_market("PYUSD", 7, usd(1), true))
        .with_market(plain_market("SolvBTC", 8, p_btc(), false))
        .with_market(plain_market("xSolvBTC", 8, p_btc(), false))
        .with_market(plain_market("XAUM", 9, p_xaum(), false))
        .with_market(plain_market("USTRY", 7, p_ustry(), false))
        .with_market(plain_market("AQUA", 7, p_aqua(), false));
    for name in LP_NAMES.iter().take(n_lp) {
        b = b.with_market(plain_market(name, 7, usd(1), false));
    }
    let t = b.build();
    t.env.cost_estimate().disable_resource_limits();
    t.env.cost_estimate().budget().reset_unlimited();
    let env = t.env.clone();

    // One RedStone adapter for every feed, as mainnet (CA526Y2N...).
    let adapter = register_redstone_adapter(
        &t,
        &[
            ("XLM", p_xlm()),
            ("USDC", usd(1)),
            ("EUROC", p_eurc()),
            ("PYUSD", usd(1)),
            ("BTC", p_btc()),
            ("SolvBTC_FUNDAMENTAL", usd(1)),
            ("SolvBTC_FUNDAMENTAL/USD", p_btc()),
            ("xSolvBTC_FUNDAMENTAL", usd(1)),
            ("xSolvBTC_FUNDAMENTAL/USD", p_btc()),
            ("XAUm_FUNDAMENTAL/USD", p_xaum()),
            ("USTRY", p_ustry()),
            ("AQUA", p_aqua()),
        ],
    );
    // Second Reflector quoting in USDC: the DEX oracle the USTRY / AQUA
    // factor legs read on mainnet.
    let usdc = t.resolve_asset("USDC");
    let reflector_dex = env.register(MockReflector, ());
    let dex = MockReflectorClient::new(&env, &reflector_dex);
    dex.set_base_stellar(&usdc);
    let cex = MockReflectorClient::new(&env, &t.mock_reflector);
    // Mainnet's BTC reference is a Reflector `Symbol("BTC")`; the harness
    // mock keys prices by Stellar address, so a placeholder address stands in.
    let btc_ref_asset = Address::generate(&env);

    // Direct dual-source markets: Reflector CEX Twap(3) + RedStone.
    for (name, feed_id) in [
        ("XLM", "XLM"),
        ("USDC", "USDC"),
        ("EURC", "EUROC"),
        ("XAUM", "XAUm_FUNDAMENTAL/USD"),
    ] {
        anchor_market_with_redstone_feed(&t, &adapter, name, feed_id);
    }
    // PYUSD: RedStone single source (mainnet).
    {
        let asset = t.resolve_asset("PYUSD");
        let cfg = redstone_single_config(
            &env,
            &adapter,
            &SString::from_str(&env, "PYUSD"),
            usd(1),
            500,
        );
        t.configure_market_oracle(&asset, &cfg);
    }
    // Ref BTC: Reflector CEX Twap(3) + RedStone BTC.
    {
        cex.set_price(&btc_ref_asset, &p_btc());
        cex.set_twap_price(&btc_ref_asset, &p_btc());
        let cfg = oracle(
            &env,
            &[
                PriceSource::Feed(feed(&t.mock_reflector, &btc_ref_asset, 3600)),
                PriceSource::Feed(rs_feed(&env, &adapter, "BTC", 46_800)),
            ],
            1000,
            IndependencePolicy::RequireDisjoint,
        );
        t.gov_client().execute_immediate(
            &t.admin,
            &AdminOperation::ConfigureAssetOracle(ConfigureAssetOracleArgs {
                key: PriceKey::Ref(Symbol::new(&env, "BTC")),
                oracle: cfg,
            }),
        );
    }
    // SolvBTC / xSolvBTC: Scaled(RedStone factor, quote Ref BTC) + RedStone USD anchor.
    for (name, factor_id, anchor_id) in [
        ("SolvBTC", "SolvBTC_FUNDAMENTAL", "SolvBTC_FUNDAMENTAL/USD"),
        (
            "xSolvBTC",
            "xSolvBTC_FUNDAMENTAL",
            "xSolvBTC_FUNDAMENTAL/USD",
        ),
    ] {
        let asset = t.resolve_asset(name);
        let mut shared = SVec::new(&env);
        shared.push_back(adapter.clone());
        let cfg = oracle(
            &env,
            &[
                PriceSource::Scaled(ScaledSource {
                    factor: rs_feed(&env, &adapter, factor_id, 93_600),
                    quote: PriceKey::Ref(Symbol::new(&env, "BTC")),
                    min_factor_wad: 1,
                    max_factor_wad: DEFAULT_MAX_SANITY_PRICE_WAD,
                }),
                PriceSource::Feed(rs_feed(&env, &adapter, anchor_id, 57_600)),
            ],
            500,
            IndependencePolicy::AllowShared(shared),
        );
        t.configure_market_oracle(&asset, &cfg);
    }
    // USTRY: Scaled(Reflector DEX Twap(3) in USDC, quote USDC) + RedStone (AllowShared on mainnet).
    // AQUA: same factor shape + multi-feed anchor (mainnet: Xoxno; here RedStone, same call shape).
    for (name, anchor_id, price, shared_rs) in [
        ("USTRY", "USTRY", p_ustry(), true),
        ("AQUA", "AQUA", p_aqua(), true),
    ] {
        let asset = t.resolve_asset(name);
        dex.set_price(&asset, &price);
        dex.set_twap_price(&asset, &price);
        let independence = if shared_rs {
            let mut shared = SVec::new(&env);
            shared.push_back(adapter.clone());
            IndependencePolicy::AllowShared(shared)
        } else {
            IndependencePolicy::RequireDisjoint
        };
        let cfg = oracle(
            &env,
            &[
                PriceSource::Scaled(ScaledSource {
                    factor: feed(&reflector_dex, &asset, 7_200),
                    quote: PriceKey::Token(usdc.clone()),
                    min_factor_wad: 1,
                    max_factor_wad: DEFAULT_MAX_SANITY_PRICE_WAD,
                }),
                PriceSource::Feed(rs_feed(&env, &adapter, anchor_id, 57_600)),
            ],
            500,
            independence,
        );
        t.configure_market_oracle(&asset, &cfg);
    }

    // LP pools: each side ~$2M of reserves, 1,000,000 shares => ~$4/share.
    const SHARES: u128 = 1_000_000 * 10_000_000;
    let specs: [(&str, &str, &str, bool, u128, u128, u64); 5] = [
        (
            "XLMUSDC_LP",
            "XLM",
            "USDC",
            false,
            6_666_667 * 10_000_000,
            2_000_000 * 10_000_000,
            57_600,
        ),
        (
            "XSOLVSOLV_LP",
            "xSolvBTC",
            "SolvBTC",
            true,
            20 * 100_000_000,
            20 * 100_000_000,
            93_600,
        ),
        (
            "XAUMUSDC_LP",
            "USDC",
            "XAUM",
            false,
            2_000_000 * 10_000_000,
            666_667 * 1_000_000,
            57_600,
        ), // 666.667 XAUM at 9 decimals
        (
            "USTRYUSDC_LP",
            "USTRY",
            "USDC",
            false,
            1_904_762 * 10_000_000,
            2_000_000 * 10_000_000,
            57_600,
        ),
        (
            "XLMAQUA_LP",
            "XLM",
            "AQUA",
            false,
            6_666_667 * 10_000_000,
            1_000_000_000 * 10_000_000,
            57_600,
        ),
    ];
    // Every pool above prices at $4.00/share (2*sqrt($2M*$2M)/1M shares; the
    // balanced stable pool's D equals the same sum). Mainnet's LP band is
    // 0.45..2.5 around a ~$1.05 share; the same ratio is applied here.
    let band = (usd(4) * 45 / 105, usd(4) * 250 / 105);
    let mut pools = std::vec::Vec::new();
    for (lp, a, bb, stable, ra, rb, stale) in specs.iter().take(n_lp) {
        let pool = t.list_lp_oracle(lp, a, bb, *stable, *ra, *rb, SHARES, 1, band, *stale);
        std::println!(
            "    listed {lp:<13} ({a}/{bb}, {}) share price = {:.4} USD",
            if *stable {
                "stable"
            } else {
                "constant_product"
            },
            read_price(&t, lp) as f64 / 1e18
        );
        pools.push((*lp, pool, *stable));
    }
    let mut labels = base_labels(&t);
    labels.add(&adapter, "redstone");
    labels.add(&reflector_dex, "reflector_dex");
    for (lp, pool, _) in &pools {
        labels.add(pool, &std::format!("aqua:{lp}"));
    }
    LpCtx {
        t,
        adapter,
        reflector_dex,
        btc_ref_asset,
        pools,
        labels,
    }
}

/// Moves every crashable underlying feed to `num/den` of its base price
/// (XLM, BTC via the Ref and both Solv anchors, XAUM, USTRY, AQUA). USDC,
/// EURC, PYUSD stay at par.
fn lp_crash(c: &mut LpCtx, num: i128, den: i128) {
    let env = c.t.env.clone();
    let rs = MockRedStonePriceFeedClient::new(&env, &c.adapter);
    let cex = MockReflectorClient::new(&env, &c.t.mock_reflector);
    let dex = MockReflectorClient::new(&env, &c.reflector_dex);
    let set_rs = |id: &str, p: i128| rs.set_price(&SString::from_str(&env, id), &p);
    c.t.set_price("XLM", scale(p_xlm(), num, den));
    set_rs("XLM", scale(p_xlm(), num, den));
    c.t.set_price("XAUM", scale(p_xaum(), num, den));
    set_rs("XAUm_FUNDAMENTAL/USD", scale(p_xaum(), num, den));
    cex.set_price(&c.btc_ref_asset, &scale(p_btc(), num, den));
    cex.set_twap_price(&c.btc_ref_asset, &scale(p_btc(), num, den));
    set_rs("BTC", scale(p_btc(), num, den));
    set_rs("SolvBTC_FUNDAMENTAL/USD", scale(p_btc(), num, den));
    set_rs("xSolvBTC_FUNDAMENTAL/USD", scale(p_btc(), num, den));
    for (name, base) in [("USTRY", p_ustry()), ("AQUA", p_aqua())] {
        let asset = c.t.resolve_asset(name);
        dex.set_price(&asset, &scale(base, num, den));
        dex.set_twap_price(&asset, &scale(base, num, den));
        set_rs(name, scale(base, num, den));
    }
}

fn lp_refresh_par(c: &mut LpCtx) {
    let env = c.t.env.clone();
    let rs = MockRedStonePriceFeedClient::new(&env, &c.adapter);
    for (name, p) in [("USDC", usd(1)), ("EURC", p_eurc())] {
        c.t.set_price(name, p);
    }
    rs.set_price(&SString::from_str(&env, "USDC"), &usd(1));
    rs.set_price(&SString::from_str(&env, "EUROC"), &p_eurc());
    rs.set_price(&SString::from_str(&env, "PYUSD"), &usd(1));
    rs.set_price(&SString::from_str(&env, "SolvBTC_FUNDAMENTAL"), &usd(1));
    rs.set_price(&SString::from_str(&env, "xSolvBTC_FUNDAMENTAL"), &usd(1));
    lp_crash(c, 1, 1);
}

struct LpBook {
    /// Per LP: shares supplied by ALICE/BOB (about $1000 each) and by CAROL (about $0.10 each).
    supplies: std::vec::Vec<(&'static str, f64, f64)>,
    debts: std::vec::Vec<(&'static str, f64)>,
    dust_debts: std::vec::Vec<(&'static str, f64)>,
}

fn lp_book(c: &LpCtx, n_lp: usize) -> LpBook {
    let mut supplies = std::vec::Vec::new();
    for (lp, _, _) in &c.pools {
        let price = read_price(&c.t, lp);
        let shares_for = |usd_wad: i128| (usd_wad as f64) / (price as f64);
        supplies.push((*lp, shares_for(usd(1000)), shares_for(usd(1) / 10)));
    }
    // 4 debts totalling 70% of collateral value (LTV 75%). XLM is both a debt
    // leg and a crashed underlying, so the crash also shrinks that debt.
    let debt_usd_each = 700.0 * n_lp as f64 / 4.0;
    let debt_amount = |name: &str, usd_v: f64| {
        let p = match name {
            "XLM" => p_xlm(),
            "EURC" => p_eurc(),
            _ => usd(1),
        } as f64
            / 1e18;
        usd_v / p
    };
    let debts: std::vec::Vec<(&'static str, f64)> = LP_DEBTS
        .iter()
        .map(|n| (*n, debt_amount(n, debt_usd_each)))
        .collect();
    let dust_debts: std::vec::Vec<(&'static str, f64)> = LP_DEBTS
        .iter()
        .map(|n| (*n, debt_amount(n, 0.0185 * n_lp as f64)))
        .collect();
    LpBook {
        supplies,
        debts,
        dust_debts,
    }
}

fn lp_open_accounts(c: &mut LpCtx, book: &LpBook) {
    for user in [ALICE, BOB] {
        let legs: std::vec::Vec<(&str, f64)> =
            book.supplies.iter().map(|(n, big, _)| (*n, *big)).collect();
        supply_legs(&mut c.t, user, &legs);
        for (name, amount) in &book.debts {
            c.t.borrow(user, name, *amount);
        }
    }
    let legs: std::vec::Vec<(&str, f64)> = book
        .supplies
        .iter()
        .map(|(n, _, dust)| (*n, *dust))
        .collect();
    supply_legs(&mut c.t, CAROL, &legs);
    for (name, amount) in &book.dust_debts {
        c.t.borrow(CAROL, name, *amount);
    }
}

fn lp_scenario(n_lp: usize, verbose: bool) -> std::vec::Vec<Row> {
    let mut c = lp_ctx(n_lp);
    let book = lp_book(&c, n_lp);
    lp_open_accounts(&mut c, &book);
    c.t.advance_time_no_refresh(60);
    lp_refresh_par(&mut c);
    let tag = std::format!("LP {n_lp}C+4D");
    let env = c.t.env.clone();
    let mut rows = std::vec::Vec::new();
    let id = c.t.resolve_account_id(ALICE);
    let (r, _) = measured(
        &env,
        &std::format!("{tag} get_health_factor"),
        &c.labels,
        || c.t.ctrl_client().get_health_factor(&id),
    );
    rows.push(r);
    let (r, _) = measured(
        &env,
        &std::format!("{tag} withdraw (healthy)"),
        &c.labels,
        || c.t.withdraw(ALICE, LP_NAMES[0], 0.01),
    );
    rows.push(r);
    // 46% of base on every crashable feed: sqrt(.46)=0.68 on one-leg LPs, 0.46 on
    // both-leg LPs (the stable LP lands at $1.84, just above its $1.71 sanity floor,
    // which is the mainnet-shaped band's limit; a deeper crash makes the LP
    // unpriceable and the liquidation fail closed).
    lp_crash(&mut c, 46, 100);
    for (lp, _, _) in &c.pools {
        std::println!(
            "    after crash {lp:<13} share price = {:.4} USD",
            read_price(&c.t, lp) as f64 / 1e18
        );
    }
    for name in [
        "XLM", "USDC", "EURC", "PYUSD", "SolvBTC", "xSolvBTC", "XAUM", "USTRY", "AQUA",
    ] {
        if c.t.markets.contains_key(name) {
            std::println!(
                "    after crash {name:<13} price = {:.6} USD",
                read_price(&c.t, name) as f64 / 1e18
            );
        }
    }
    std::println!(
        "    after crash ALICE hf = {:.4}, collateral = {:.2}, debt = {:.2}",
        c.t.health_factor(ALICE),
        c.t.total_collateral(ALICE),
        c.t.total_debt(ALICE)
    );
    assert!(
        c.t.can_be_liquidated(ALICE),
        "{tag}: account must be liquidatable"
    );
    let pay: std::vec::Vec<(&str, f64)> = book.debts.iter().map(|(n, a)| (*n, a / 6.0)).collect();
    let (r, _) = measured(
        &env,
        &std::format!("{tag} liquidate Transfer"),
        &c.labels,
        || liquidate_mode(&mut c.t, LIQUIDATOR, ALICE, &pay, SeizeMode::Transfer),
    );
    if verbose {
        print_breakdown(&env, &c.labels);
    }
    rows.push(r);
    let (r, _) = measured(
        &env,
        &std::format!("{tag} liquidate Credit(0)"),
        &c.labels,
        || liquidate_mode(&mut c.t, LIQUIDATOR, BOB, &pay, SeizeMode::Credit(0)),
    );
    rows.push(r);
    let cid = c.t.resolve_account_id(CAROL);
    let (r, res) = measured(
        &env,
        &std::format!("{tag} clean_bad_debt"),
        &c.labels,
        || c.t.try_clean_bad_debt_by_id(cid),
    );
    assert!(res.is_ok(), "{tag}: clean_bad_debt failed: {res:?}");
    rows.push(r);
    rows
}

#[test]
fn scenario_b_three_lp_legs() {
    std::println!("\n=== SCENARIO B: 3 LP collateral legs (XLM/USDC cp, xSolvBTC/SolvBTC stable, USDC/XAUM cp) + 4 dual-source debts, native harness ===");
    header();
    let rows = lp_scenario(3, true);
    for r in &rows {
        print_row(r);
    }
    for r in rows.iter().filter(|r| r.label.contains("liquidate")) {
        std::println!("    {:<28} {}", r.label, verdict(r));
    }
}

#[test]
fn scenario_a_five_lp_legs() {
    std::println!("\n=== SCENARIO A: 5 LP collateral legs (+ USTRY/USDC cp with Scaled leg, XLM/AQUA cp with Scaled leg) + 4 dual-source debts, native harness ===");
    header();
    let rows = lp_scenario(5, true);
    for r in &rows {
        print_row(r);
    }
    for r in rows.iter().filter(|r| r.label.contains("liquidate")) {
        std::println!("    {:<28} {}", r.label, verdict(r));
    }
}

// ---------------------------------------------------------------------------
// WASM replay: controller + price aggregator + pool + nft metered as WASM
// ---------------------------------------------------------------------------

enum Native {
    Reflector,
    Redstone,
    Aquarius {
        share: Address,
        a: Address,
        b: Address,
        shares: u128,
    },
    Freezable,
}

fn wasm_dir() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../target/wasm32v1-none/release")
}

/// Snapshots `t`, swaps the native protocol contracts for their release
/// WASM, re-registers the native mocks at their addresses, and replays one
/// `liquidate` under real WASM metering (mock auths, so the auth recorder's
/// own work is included: an over-count).
fn wasm_replay(
    t: &LendingTest,
    natives: &[(Address, Native)],
    target: u64,
    payments: &[(Address, i128)],
    mode: SeizeMode,
    labels: &Labels,
    label: &str,
    verbose: bool,
) -> Row {
    let dir = wasm_dir();
    // A liquidator minted in the source env: `Address::generate` restarts its
    // counter in a snapshot-derived env and would collide with an address
    // that already holds an auth nonce.
    let liquidator_src = Address::generate(&t.env);
    // Fund it here too: a SAC `mint` needs the admin's auth, and the admin
    // already holds an auth nonce in the snapshot, which the mock-auth
    // recorder of the replay env cannot re-create.
    for (asset, amount) in payments {
        token::StellarAssetClient::new(&t.env, asset).mint(&liquidator_src, amount);
    }
    let pool = t.markets.values().next().unwrap().pool.clone();
    for (address, filename) in [
        (&t.controller, "controller.wasm"),
        (&t.price_aggregator, "price_aggregator.wasm"),
        (&pool, "pool.wasm"),
        (&t.position_nft, "position_nft.wasm"),
    ] {
        let wasm = std::fs::read(dir.join(filename)).unwrap_or_else(|e| panic!("{filename}: {e}"));
        let hash = t
            .env
            .deployer()
            .upload_contract_wasm(Bytes::from_slice(&t.env, &wasm));
        t.env.as_contract(address, || {
            t.env
                .deployer()
                .update_current_contract(soroban_sdk::ContractExecutable::Wasm(hash))
        });
    }
    let snapshot = t.env.to_ledger_snapshot();
    t.env
        .host()
        .ensure_module_cache_contains_host_storage_contracts()
        .unwrap();
    let module_cache = t.env.host().take_module_cache().unwrap();

    let env = Env::from_ledger_snapshot(snapshot);
    env.host().set_module_cache(module_cache).unwrap();
    env.cost_estimate().budget().reset_unlimited();
    env.cost_estimate().disable_resource_limits();
    env.mock_all_auths_allowing_non_root_auth();
    let rebind = |address: &Address| -> Address {
        xdr::ScAddress::from(address).try_into_val(&env).unwrap()
    };
    for (addr, kind) in natives {
        let at = rebind(addr);
        match kind {
            Native::Reflector => {
                env.register_at(&at, MockReflector, ());
            }
            Native::Redstone => {
                env.register_at(&at, test_harness::mock_redstone::MockRedStonePriceFeed, ());
            }
            Native::Aquarius {
                share,
                a,
                b,
                shares,
            } => {
                env.register_at(
                    &at,
                    MockAquariusPool,
                    (rebind(share), rebind(a), rebind(b), *shares),
                );
            }
            Native::Freezable => {
                env.register_at(&at, test_harness::freezable_token::FreezableToken, ());
            }
        }
    }
    let liquidator = rebind(&liquidator_src);
    let mut offered = SVec::new(&env);
    for (asset, amount) in payments {
        offered.push_back((hub_asset(rebind(asset)), *amount));
    }
    // Next ledger: accrual runs for every market touched.
    env.ledger().with_mut(|info| {
        info.timestamp += 5;
        info.sequence_number += 1;
    });
    let controller = rebind(&t.controller);
    let client = controller::ControllerClient::new(&env, &controller);
    let mut b = env.cost_estimate().budget();
    b.reset_unlimited();
    b.reset_tracker();
    client.liquidate(&liquidator, &target, &offered, &mode);
    let row = capture(&env, label, labels);
    if verbose {
        print_breakdown(&env, labels);
        std::println!("    top cost types:");
        dump_cost_types(&env, 60);
    }
    row
}

fn plain_natives(c: &PlainCtx) -> std::vec::Vec<(Address, Native)> {
    std::vec![
        (c.t.mock_reflector.clone(), Native::Reflector),
        (c.adapter.clone(), Native::Redstone),
    ]
}

fn lp_natives(c: &LpCtx) -> std::vec::Vec<(Address, Native)> {
    let mut v = std::vec![
        (c.t.mock_reflector.clone(), Native::Reflector),
        (c.reflector_dex.clone(), Native::Reflector),
        (c.adapter.clone(), Native::Redstone),
    ];
    for name in ["SolvBTC", "xSolvBTC", "XAUM"] {
        if c.t.markets.contains_key(name) {
            v.push((c.t.resolve_asset(name), Native::Freezable));
        }
    }
    const SHARES: u128 = 1_000_000 * 10_000_000;
    let specs = [
        ("XLMUSDC_LP", "XLM", "USDC"),
        ("XSOLVSOLV_LP", "xSolvBTC", "SolvBTC"),
        ("XAUMUSDC_LP", "USDC", "XAUM"),
        ("USTRYUSDC_LP", "USTRY", "USDC"),
        ("XLMAQUA_LP", "XLM", "AQUA"),
    ];
    for (lp, pool, _) in &c.pools {
        let (_, a, b) = specs.iter().find(|s| s.0 == *lp).unwrap();
        v.push((
            pool.clone(),
            Native::Aquarius {
                share: c.t.resolve_asset(lp),
                a: c.t.resolve_asset(a),
                b: c.t.resolve_asset(b),
                shares: SHARES,
            },
        ));
    }
    v
}

#[test]
fn wasm_replay_plain_and_lp() {
    std::println!("\n=== WASM REPLAY: controller + price_aggregator + pool + position_nft as release WASM; mocks (Reflector x2, RedStone, Aquarius pools, 8/9-dec tokens) stay native ===");
    header();
    let mut rows = std::vec::Vec::new();
    for (nc, nd) in [(5usize, 4usize), (5, 5)] {
        let mut c = plain_ctx(nc, nd);
        let coll: std::vec::Vec<(&str, f64)> = COLL.iter().take(nc).map(|n| (*n, 1000.0)).collect();
        let debt_each = 600.0 * nc as f64 / nd as f64 * 0.8;
        let debts: std::vec::Vec<(&str, f64)> =
            DEBT.iter().take(nd).map(|n| (*n, debt_each)).collect();
        supply_legs(&mut c.t, ALICE, &coll);
        for (name, amount) in &debts {
            c.t.borrow(ALICE, name, *amount);
        }
        for name in COLL.iter().take(nc) {
            plain_set_price(&mut c, name, scale(usd(1), 50, 100));
        }
        assert!(c.t.can_be_liquidated(ALICE));
        let payments: std::vec::Vec<(Address, i128)> = debts
            .iter()
            .map(|(n, a)| (c.t.resolve_asset(n), test_harness::amount_raw(a / 6.0, 7)))
            .collect();
        let id = c.t.resolve_account_id(ALICE);
        let natives = plain_natives(&c);
        let r = wasm_replay(
            &c.t,
            &natives,
            id,
            &payments,
            SeizeMode::Transfer,
            &c.labels,
            &std::format!("WASM plain {nc}C+{nd}D liquidate Transfer"),
            nc == 5 && nd == 4,
        );
        print_row(&r);
        rows.push(r);
    }
    for n_lp in [3usize, 5] {
        let mut c = lp_ctx(n_lp);
        let book = lp_book(&c, n_lp);
        lp_open_accounts(&mut c, &book);
        lp_crash(&mut c, 46, 100);
        assert!(c.t.can_be_liquidated(ALICE));
        let payments: std::vec::Vec<(Address, i128)> = book
            .debts
            .iter()
            .map(|(n, a)| (c.t.resolve_asset(n), test_harness::amount_raw(a / 6.0, 7)))
            .collect();
        let id = c.t.resolve_account_id(ALICE);
        let bid = c.t.resolve_account_id(BOB);
        let natives = lp_natives(&c);
        let r = wasm_replay(
            &c.t,
            &natives,
            id,
            &payments,
            SeizeMode::Transfer,
            &c.labels,
            &std::format!("WASM LP {n_lp}C+4D liquidate Transfer"),
            n_lp == 5,
        );
        print_row(&r);
        rows.push(r);
        let r = wasm_replay(
            &c.t,
            &natives,
            bid,
            &payments,
            SeizeMode::Credit(0),
            &c.labels,
            &std::format!("WASM LP {n_lp}C+4D liquidate Credit(0)"),
            false,
        );
        print_row(&r);
        rows.push(r);
    }
    std::println!("\n  verdicts:");
    for r in &rows {
        std::println!("    {:<40} {}", r.label, verdict(r));
    }
}
