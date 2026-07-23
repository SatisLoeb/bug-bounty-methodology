---
name: feedback-authz-split-across-layers
description: "a privileged action's authorization is often SPLIT across layers (entrypoint/caller-check + msg ValidateBasic + the internal keeper dispatch); reading ONE layer and seeing 'no authority check' is NOT 'permissionless' — read EVERY layer before declaring a gate open; the unbiased PoC is the backstop that catches the over-claim"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 10b90010-ed37-424c-8329-685db3b11d96
---

2026-06-29, Injective native-EVM bank precompile. I read `erc20/keeper/msg_server.go CreateTokenPair`, saw it had NO `msg.Sender != authority` check (unlike its siblings `UpdateParams`/`DeleteTokenPair`), and declared a **Critical "permissionless drain"** (register attacker contract ↔ any valuable denom, then `bank.transfer(victim,attacker)`). I escalated it for ~10 turns — even computed the USDC/INJ blast radius from LCD — BEFORE reading the function the wrapper CALLS: the internal `keeper.go createTokenPair`, which type+authority-dispatches (`createTokenPairPeggy`/`IBC` forbid a custom erc20 → force the owner-less wrapper; `createTokenPairTokenFactory` requires denom admin). The whole drain was FALSE: an attacker can't install a malicious contract for USDC/IBC/native. **The unbiased simnet PoC killed it on first run** (`unsupported bank denom type` / registration rejected) — exactly the [[apparatus-is-packaging-not-discovery]] standing order: "a biased PASS → false-positive submitted → credibility burned."

**Why (root):** authorization for one privileged action is rarely in one place. For the bank-precompile drain it was split across THREE layers — (1) the precompile's `caller` binding, (2) the msg's `ValidateBasic` (subaccount/owner), (3) the keeper's internal dispatch (`createTokenPair` type+admin gate). Seeing "no check" in layer 1 (the entrypoint/wrapper) says NOTHING about layers 2-3. This is the FIRST MAXIM applied to my own analysis: "no authority check in the wrapper" names the wrapper's behavior, never that the action is permissionless — the gate may live one call deeper.

**How to apply (before claiming ANY gate is open / any drain reachable):**
- Trace the privileged action to the LEAF that mutates state; read the authorization at EVERY hop (entrypoint → msg ValidateBasic → keeper method → the internal fn it delegates to). The gate is the AND of all layers.
- Sibling-asymmetry ("Delete is authority-gated, Create isn't") is a STRONG lead worth chasing — but it's a hypothesis to execute, not a conclusion. The asymmetry was real here yet the missing check was compensated one layer deeper.
- Do NOT compute blast radius / escalate severity until the leaf authorization is read. I burned ~10 turns escalating before the PoC corrected me.
- The unbiased fork/simnet PoC is the non-negotiable backstop: build it BEFORE believing a Critical, run the disconfirmer (here: register the denom → it's rejected). Code-read of one layer is not even half-done. See [[doctrine-surgical-reports-fight-to-the-end]], [[feedback-verify-before-working-no-theater]].
