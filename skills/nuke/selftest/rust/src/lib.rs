// NUKE non-EVM self-test fixture. DO NOT DEPLOY. Deliberate mechanical-substrate smells.
pub fn withdraw(balance: u128, amount: u128) -> u128 {
    balance - amount            // clippy::arithmetic_side_effects — silent underflow in release wasm
}
pub fn parse(x: Option<u64>) -> u64 {
    x.unwrap()                   // clippy::unwrap_used — panic path
}
pub unsafe fn danger(p: *const u8) -> u8 {
    *p                           // unsafe deref — cargo-geiger heat
}
