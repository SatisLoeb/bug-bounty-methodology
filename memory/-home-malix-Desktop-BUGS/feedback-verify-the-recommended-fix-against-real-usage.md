---
name: feedback-verify-the-recommended-fix-against-real-usage
description: "The recommended fix/remediation is a load-bearing claim too — test it against the target's real call pattern before submitting, or you hand the maintainer a regression"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 80451fba-0d45-4f5b-9930-3e67b9befdae
---

The PoC is not the only claim in a report that must be executed — the **recommended fix is also a load-bearing claim**, and a fix that false-positives on the target's real code path is a regression you're handing the maintainer (worse than no fix: it burns trust on the spot when they paste it and CI breaks).

**Why:** On py_webauthn issue #265 (cbor2 boolean/int COSE key collision), I drafted a fix using canonical re-encode-and-compare (`cbor2.dumps(obj, canonical=True) != data`). It looked clean and rejected the attack payload. But py_webauthn parses the COSE key from a buffer that still has trailing WebAuthn extension bytes (`parse_authenticator_data.py:83`), so the canonical re-encode never equals the input and **every legitimate registration with extensions would be wrongly rejected**. The maintainer's own prior GHSA-f5qc thread had documented exactly this trailing-bytes pattern. I only caught it because I read the real call site and ran the honest+trailing case as a disconfirmer on the FIX (not just the bug). The correct fix was the upstream-blessed `allow_duplicate_keys=False` flag, which only rejects dup keys within the first map and ignores trailing bytes — verified safe with extensions present.

**How to apply:** Before any report leaves, run the disconfirmer on the remediation, not only the exploit: (1) find the target's REAL call sites for the function you're patching (grep the deployed source, don't assume the minimal-repro shape), (2) feed the fix the legitimate/edge inputs that path actually sees — trailing bytes, extensions, empty/max, optional fields — and confirm it does NOT false-positive, (3) prefer the mechanism the upstream maintainer already shipped (a flag, an option) over a clever local check, because the maintainer-blessed path is already tested against their ecosystem. A fix you didn't run against the target's real usage is the same un-executed hypothesis the standard bans for PoCs, just on the remediation side. Related: [[feedback-verify-before-working-no-theater]], [[doctrine-surgical-reports-fight-to-the-end]].
