---
name: feedback-execute-the-central-link
description: Two PoCs proving the two ENDS of a mechanism is not proof of the mechanism — run the real MIDDLE component on the attack-shaped input and observe it produce the linking artifact.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 23c2ad63-ea6a-4ea6-bb7a-7c534409af1f
---

Proving the two ENDS of an exploit chain (input decodes to attacker values / final state changes when fed attacker values) is NOT proof of the mechanism — it is an assembly YOU did by hand at the seam. The reviewer's strongest reject is "you stitched the ends together; you never executed the joint." (Same failure family as [[feedback-invariant-that-passes-is-not-a-finding]] and [[feedback-separate-and-attribute-not-amalgamate]]: an un-executed hypothesis dressed as a conclusion.)

**Why:** the joint is exactly where the author's mental model lives, so it is where a hidden guard you code-read past would sit. If the real middle component actually refuses the attack-shaped input, both end-PoCs still pass and the finding is false — you only find out by running the middle.

**How to apply:** build the PoC that drives the REAL middle component (not a reimplementation, not the two ends) on the attacker's input and asserts it emits the artifact that links the ends. On Push Chain F-A01 this was running the real `event_listener.go` via `processSlotRange` over a mocked RPC returning the attacker sig + forged non-gateway log, asserting the listener STORED the attacker `Inbound{recipient,amount,token}` — the exact object the mint-leg then consumes. The off-chain (parser emitter-blind) and on-chain (forged Inbound mints 0→1e12) PoCs are the ends; the listener e2e is the middle. Add the middle before submitting: it converts the strongest reject class into a one-command replay. Cross-ref [[project-push-chain-dualdefense]].
