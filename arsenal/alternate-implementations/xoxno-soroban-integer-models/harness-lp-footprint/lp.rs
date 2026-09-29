//! Lists an Aquarius LP share token as a priced market: registers a
//! `MockAquariusPool` bound to the market's token as share token and to two
//! other listed markets as reserves, then configures the real price
//! aggregator with a single `AquariusLp` / `AquariusStableLp` source whose
//! `key_a` / `key_b` are the underlying markets' `PriceKey::Token`s, the
//! shape `configs/mainnet/markets.json` uses for every `*_LP` market.
use controller::types::{
    AquariusLpSource, AssetOracle, IndependencePolicy, OracleTolerance, PriceKey, PriceSource,
};
use soroban_sdk::{Address, Env, Symbol};

use crate::core::LendingTest;
use crate::mock_aquarius::{MockAquariusPool, MockAquariusPoolClient};

/// Mainnet `*_LP` oracles use this staleness ceiling (`XLMUSDC_LP`); an LP
/// whose leg allows a looser staleness must carry that leg's ceiling
/// (`XLMSolvBTC_LP`: 93_600).
pub const MAINNET_LP_MAX_PRICE_STALE_SECONDS: u64 = 57_600;
pub const MAINNET_SOLV_LP_MAX_PRICE_STALE_SECONDS: u64 = 93_600;

/// Registers a mock Aquarius pool answering for `share` with reserves
/// `token_a` / `token_b`.
pub fn register_aquarius_pool(
    env: &Env,
    share: &Address,
    token_a: &Address,
    token_b: &Address,
    stable: bool,
    reserve_a: u128,
    reserve_b: u128,
    total_shares: u128,
) -> Address {
    let pool = env.register(
        MockAquariusPool,
        (
            share.clone(),
            token_a.clone(),
            token_b.clone(),
            total_shares,
        ),
    );
    let client = MockAquariusPoolClient::new(env, &pool);
    let kind = if stable { "stable" } else { "constant_product" };
    client.set_pool_type(&Symbol::new(env, kind));
    client.set_reserves(&reserve_a, &reserve_b);
    pool
}

/// Single-source Aquarius LP oracle, mainnet shape: `tolerance` 0/0,
/// `RequireDisjoint`, and an explicit sanity band (sole-source LP oracles
/// must carry one no wider than `MAX_LP_SANITY_BAND_BPS`; mainnet uses
/// 0.45..2.5 around a ~$1 share). `min_pool_value_wad` is a
/// parameter because mainnet's $1M floor would make a crashed test pool
/// unpriceable.
#[allow(clippy::too_many_arguments)]
pub fn aquarius_lp_oracle(
    env: &Env,
    pool: &Address,
    token_a: &Address,
    token_b: &Address,
    reserve_a_decimals: u32,
    reserve_b_decimals: u32,
    stable: bool,
    min_pool_value_wad: i128,
    sanity_band_wad: (i128, i128),
    max_price_stale_seconds: u64,
) -> AssetOracle {
    let lp = AquariusLpSource {
        pool: pool.clone(),
        token_a: token_a.clone(),
        token_b: token_b.clone(),
        key_a: PriceKey::Token(token_a.clone()),
        key_b: PriceKey::Token(token_b.clone()),
        reserve_a_decimals,
        reserve_b_decimals,
        min_pool_value_wad,
    };
    let mut sources = soroban_sdk::Vec::new(env);
    sources.push_back(if stable {
        PriceSource::AquariusStableLp(lp)
    } else {
        PriceSource::AquariusLp(lp)
    });
    AssetOracle {
        asset_decimals: 7,
        max_price_stale_seconds,
        sources,
        tolerance: OracleTolerance {
            upper_ratio_bps: 0,
            lower_ratio_bps: 0,
        },
        independence: IndependencePolicy::RequireDisjoint,
        min_sanity_price_wad: sanity_band_wad.0,
        max_sanity_price_wad: sanity_band_wad.1,
    }
}

impl LendingTest {
    /// Binds a mock Aquarius pool to the listed market `lp_market` (its token
    /// is the share token) with reserves in the listed markets `token_a` /
    /// `token_b`, and replaces `lp_market`'s oracle with the LP source. Both
    /// underlying markets must already be priceable: `set_oracle` attests
    /// the pool and probes the LP price. Returns the pool address.
    #[allow(clippy::too_many_arguments)]
    pub fn list_lp_oracle(
        &self,
        lp_market: &str,
        token_a: &str,
        token_b: &str,
        stable: bool,
        reserve_a: u128,
        reserve_b: u128,
        total_shares: u128,
        min_pool_value_wad: i128,
        sanity_band_wad: (i128, i128),
        max_price_stale_seconds: u64,
    ) -> Address {
        let share = self.resolve_asset(lp_market);
        let a = self.resolve_market(token_a);
        let b = self.resolve_market(token_b);
        let pool = register_aquarius_pool(
            &self.env,
            &share,
            &a.asset,
            &b.asset,
            stable,
            reserve_a,
            reserve_b,
            total_shares,
        );
        let oracle = aquarius_lp_oracle(
            &self.env,
            &pool,
            &a.asset,
            &b.asset,
            a.decimals,
            b.decimals,
            stable,
            min_pool_value_wad,
            sanity_band_wad,
            max_price_stale_seconds,
        );
        self.configure_market_oracle(&share, &oracle);
        pool
    }

    pub fn set_lp_reserves(&self, pool: &Address, reserve_a: u128, reserve_b: u128) {
        MockAquariusPoolClient::new(&self.env, pool).set_reserves(&reserve_a, &reserve_b);
    }
}
