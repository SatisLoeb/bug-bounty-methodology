// solfork CPI-forwarder template.
//
// Purpose: pierce an introspection gate that checks the TOP-LEVEL instruction (its program-id and/or
// its data prefix). Deploy this AT the address the gate expects (--bpf-program <AUTH_ADDR> fwd.so),
// then call it with data = [ GUARD_PREFIX (STRIP bytes) || real_cpi_data ]. It forwards accounts[1..]
// to accounts[0] (the real target program) with the prefix stripped, so:
//   - the gate reads the TOP-LEVEL instruction: program-id == <AUTH_ADDR>, data[0..STRIP] == your prefix.
//   - the target sees the real instruction data.
//
// STRIP must equal the number of prefix bytes the gate reads. On Jupiter RFQ v2 the gate checked
// data[0..8] against a Jupiter route discriminator -> STRIP = 8, prefix = the route disc.
// If the gate checks a different length (or only the program-id), adjust STRIP (0 = pure pass-through).
//
// This proves the gate is SATISFIABLE (any attacker wraps the call). It does NOT prove theft:
// re-check what SEPARATELY gates the money-move (token-owner constraint, a real signature) — SKILL step 7.
use solana_program::{account_info::AccountInfo, entrypoint, entrypoint::ProgramResult,
    instruction::{AccountMeta, Instruction}, program::invoke, pubkey::Pubkey};

const STRIP: usize = 8; // bytes of guard-satisfying prefix to drop before CPI

entrypoint!(process);
fn process(_pid: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    let target = *accounts[0].key;                      // accounts[0] = real target program
    let metas: Vec<AccountMeta> = accounts[1..].iter().map(|a| AccountMeta {
        pubkey: *a.key, is_signer: a.is_signer, is_writable: a.is_writable }).collect();
    let cpi_data = if data.len() >= STRIP { data[STRIP..].to_vec() } else { data.to_vec() };
    let ix = Instruction { program_id: target, accounts: metas, data: cpi_data };
    invoke(&ix, &accounts[1..])
}
