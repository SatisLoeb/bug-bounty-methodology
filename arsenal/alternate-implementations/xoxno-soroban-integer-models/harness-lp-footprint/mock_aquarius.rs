//! Test double for an Aquarius AMM pool, mirroring the mock the price
//! aggregator's own provider tests use
//! (`contracts/price-aggregator/tests/oracle/support.rs`). It answers every
//! entry point `common::oracle::providers::aquarius::AquariusPoolClient`
//! calls, from instance storage.
//!
//! Simplification versus a live Aquarius pool: a real pool is a WASM
//! contract (instance + code entries, one VM instantiation per call) and a
//! real share token is a WASM token contract; this mock is a native test
//! contract and the harness binds it to a SAC share token.
use soroban_sdk::{contract, contractimpl, contracttype, Address, Env, Symbol, Vec};

#[contracttype]
pub enum AquaKey {
    Share,
    TokenA,
    TokenB,
    Shares,
    Kind,
    ReserveA,
    ReserveB,
    Amp,
}

#[contract]
pub struct MockAquariusPool;

#[contractimpl]
impl MockAquariusPool {
    pub fn __constructor(
        env: Env,
        share: Address,
        token_a: Address,
        token_b: Address,
        total_shares: u128,
    ) {
        let store = env.storage().instance();
        store.set(&AquaKey::Share, &share);
        store.set(&AquaKey::TokenA, &token_a);
        store.set(&AquaKey::TokenB, &token_b);
        store.set(&AquaKey::Shares, &total_shares);
        store.set(&AquaKey::Amp, &1500u128);
    }

    pub fn get_total_shares(env: Env) -> u128 {
        env.storage().instance().get(&AquaKey::Shares).unwrap()
    }

    pub fn get_reserves(env: Env) -> Vec<u128> {
        let store = env.storage().instance();
        Vec::from_array(
            &env,
            [
                store.get(&AquaKey::ReserveA).unwrap(),
                store.get(&AquaKey::ReserveB).unwrap(),
            ],
        )
    }

    pub fn pool_type(env: Env) -> Symbol {
        env.storage().instance().get(&AquaKey::Kind).unwrap()
    }

    pub fn share_id(env: Env) -> Address {
        env.storage().instance().get(&AquaKey::Share).unwrap()
    }

    pub fn get_tokens(env: Env) -> Vec<Address> {
        let store = env.storage().instance();
        let a: Address = store.get(&AquaKey::TokenA).unwrap();
        let b: Address = store.get(&AquaKey::TokenB).unwrap();
        Vec::from_array(&env, [a, b])
    }

    pub fn set_reserves(env: Env, reserve_a: u128, reserve_b: u128) {
        let store = env.storage().instance();
        store.set(&AquaKey::ReserveA, &reserve_a);
        store.set(&AquaKey::ReserveB, &reserve_b);
    }

    pub fn set_total_shares(env: Env, total_shares: u128) {
        env.storage()
            .instance()
            .set(&AquaKey::Shares, &total_shares);
    }

    pub fn set_pool_type(env: Env, pool_type: Symbol) {
        env.storage().instance().set(&AquaKey::Kind, &pool_type);
    }

    pub fn a(env: Env) -> u128 {
        env.storage().instance().get(&AquaKey::Amp).unwrap()
    }

    pub fn set_amp(env: Env, amp: u128) {
        env.storage().instance().set(&AquaKey::Amp, &amp);
    }
}
