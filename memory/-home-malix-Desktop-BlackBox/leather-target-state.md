---
name: leather-target-state
description: Leather wallet (Immunefi) — BTC-01 finalized High Web/App ready-to-submit; Primacy-of-Impact escalation proven dead; RE-SOURCE
metadata: 
  node_type: memory
  type: project
  originSessionId: fcc7d312-e6c4-471a-a52c-b9b70879eda2
  modified: 2026-08-22T11:20:55.564Z
---

Leather self-custodial wallet (BTC + Stacks), Immunefi `leather`. Monorepo `leather-io/mono`, in-scope pin `e8699889377ee98080e67ac381b25156aadb8ac3` (= current `dev` HEAD = extension **v6.110.0**). Web/App only, KYC, arbitration enabled, step-by-step PoC required, local-only PoC (no mainnet). Workspace: `~/Desktop/BlackBox/leather-wallet-audit/` (in repo SatisLoeb/blackbox master).

**Reward grid (CORRECTED 2026-08-22):** Medium **$1-2k**, High **$2-3k**, Critical **$3-5k**, Web/App max $5k. (Earlier "Medium ~$500" was a generic-grid miscalibration; economy is real, not crumbs.)

**LEAD = BTC-01 (FINALIZED, ready to submit, High Web/App / Critical arguable).** `signPsbt` approval screen drops the row for any output whose scriptPubKey has no encodable address: `getAddressFromOutScript` (packages/bitcoin/src/utils/bitcoin.utils.ts:99-134) returns null for `unknown`/`tr_ms`/`tr_ns`/`p2a` → `use-parsed-outputs.tsx` keeps it with `address:null` + real value → `psbt-output-item.tsx:12` `if(address===null) return null` (no row, even when the collapsed output list is expanded). Same null → `''` blinds sanctions screening (psbt-signer.tsx:88-91). Signer signs the full PSBT regardless (display/sign decoupled). Screen DOES show correct "You'll transfer" net-outflow total + fee → finding is **destination-opacity, not amount-opacity** (this keeps it defensibly High vs Medium: diligent-user-who-expands still sees no row). Siblings warn (mobile unrecognized-outputs-card, extension descriptor "Unknown recipient") = internal-consistency. Re-verified all lines at pin; dup-clear (issues/PRs #2633=sighash-only #2171=diff-file; Least Authority 2021 PDF read = Stacks-key era, zero PSBT content). Report `submissions/BTC-01-immunefi.md` (immuformat+report-nerve+chill, all closing-greps clean). PoC secret gist https://gist.github.com/SatisLoeb/e691ffff10d51056d33c29e021a55566 (README+partA+control+partB+classify). **Human steps left: KYC + fill fields + submit.**

**Primacy-of-Impact escalation to Stacks Blockchain tier = PROVEN DEAD (executed trifecta).** The clause pays Stacks-tier *via Leather* IF a complete chain proves fund-loss WITH the attacker GAINING. Test (evidence/BTC01-escalation-trifecta-test.mjs, @scure 1.6.0): the trifecta **hidden ∧ default-relayable ∧ attacker-exclusive-custody = empty set** across unknown/tr_ms/tr_ns/p2a. Structural: "hidden" needs getAddressFromOutScript==null; "exclusive custody" needs an attacker-owned script; every owned form is either a standard witness output that ENCODES to an address (row renders, not hidden) or a raw tapscript (hidden but TX_NONSTANDARD → no default relay → victim tx never confirms). p2a=race, witness-v2=burn/miner-only. So it's victim-LOSS not attacker-GAIN → escalation condition unmeetable → do NOT claim it (= ENS-style self-close). LESSON: don't fabricate a Blockchain tier by invoking Primacy-of-Impact; and don't submit to the separate Stacks program (wrong code — bug is Leather's renderer, they'd close "not our code"). See [[by-design-gate-not-just-git-dup]], [[measure-before-asserting-in-reports]].

**Other leads (not drafted):** W-1 High web multisig-vault (decode-proposal-payload.ts:50 single-recipient collapse, malicious proposer drains vault, C8; 90% code / 55% e2e). STX-C1 Low (sign-in no nonce/origin, blocked on live api.leather.io). F4-02 (mobile biometric-ACL read/write mismatch, blocked on physical device). Killed/clean: provider/RPC/origin, key-mgmt (Argon2id), web XSS, Stacks WYSIWYS/multisig.

**Status: CLOSED clean 2026-08-22. RE-SOURCE after submitting BTC-01** (or draft W-1 if pursuing). Reopen if: a future extension build fixes the sink (re-pin, re-check), or a droppable output type gains default-relay + exclusive-custody (re-run trifecta).
