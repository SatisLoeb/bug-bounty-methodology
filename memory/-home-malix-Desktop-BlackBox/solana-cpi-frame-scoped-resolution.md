---
name: solana-cpi-frame-scoped-resolution
description: "Solana CPI program resolution is FRAME-scoped — kills the \"arbitrary CPI + PDA signer = drain\" false-positive class."
metadata: 
  node_type: memory
  type: reference
  originSessionId: b9d8aaf3-0cf4-4fb9-8c66-a824e509a28b
  modified: 2026-08-12T07:10:33.006Z
---

**Executed fact (Agave 4.0.1, local-validator PoC 2026-08-12):** Solana resolves a CPI's target program **from the invoking program's OWN forwarded frame**, NOT transaction-wide. A program B invoked by A can only `invoke` a program whose account A forwarded into B's `account_infos`. A program merely *loaded* elsewhere in the transaction (e.g. appended as a remaining account) but absent from B's frame is **unreachable** → runtime aborts with `Unknown program <id>` / `InstructionError [i,"MissingAccount"]` ("An account required by the instruction is missing").

Proof shape (3 tiny BPF programs): victim `invoke_signed`(prog=evil, [acct, pda(signer)]) — evil IS in victim's frame ⇒ **works**, and the PDA signer **propagates** (evil sees `pda.is_signer=true`). evil then `invoke`(prog=canary, [acct,pda]) with canary loaded in the tx but NOT forwarded into evil's frame ⇒ **MissingAccount**. (Note: the caller does NOT need to re-list the target program in the `invoke` sub-slice as long as it's in the caller's top-level frame — that's why the interceptor's `transfer_tokens_cpi` passes only 4 data accounts yet works.)

**Why it matters — kills a tempting false-positive class:** "handler CPIs an UNCHECKED user-supplied program while signing with its PDA authority" (Neodyme sealevel-attacks #5, arbitrary-cpi) is **NOT a drain** by itself. The malicious program receives only the data accounts the caller forwarded (token account, mint, dest, PDA-signer) — none executable — so it has **no program in its frame to wield the propagated signature against**, and it can't touch a token account directly (owned by SPL-Token). The only account-model-permitted abuse is **no-op-skipping** the CPI (fake program returns Ok without transferring) — which only profits the attacker when the skipped transfer would have moved value AWAY from them (e.g. a "repay"/"burn" the protocol credits anyway). If the transfers move value TO the attacker (claims/withdrawals), skipping yields nothing. So: arbitrary-CPI is payable ONLY when (a) the caller forwards the real target program (or any executable) into the malicious program's frame, OR (b) a skipped transfer benefits the attacker. Otherwise it's defense-in-depth/QA (add the program-id check), not a finding.

Applied in [[jito-sc-target-state]] to kill F1 (interceptor claim's unchecked `token_program`). Composes with [[measure-before-asserting-in-reports]]: this is exactly the runtime mechanic to EXECUTE rather than concede/over-claim.
