# Reference -- Upshift as the gold-standard instance of upshift2

upshift2 is an abstraction. This file grounds it in the one concrete engagement it abstracts from, so a future session can always recover *what the mentality looks like when it works*. Read this once before your first upshift2 engagement. The full instance lives in the `/upshift` skill (`~/.claude/skills/upshift/`) and the produced artifacts at `~/Desktop/BUGS/upshift-package/`.

## The instance in one paragraph

Upshift Finance / August Digital: $308M TVL, 68 vaults, 27 chains. Contracts audited by ChainSecurity. The off-chain layer (FastAPI backends, operator EOA, frontend bundle) audited by no one. The seam -- *the off-chain API that makes the operator wallet sign on-chain transactions* -- was owned by neither the SC auditor (scope stopped at the contract) nor a web pentester (none was engaged on the backend specifically). The engagement swept that seam with 10 vectors across a 4-pass discipline, produced 48 findings (7 Critical), constructed the F1+W34 = $308M chain, disclosed via a 4-stage protocol, got a 24h ack from the Co-CEO after 47 days of silence, watched patches land in 30h, and fired a fortress follow-up that opened a hardening engagement.

## The abstraction map (upshift specific → upshift2 universal)

| upshift (concrete) | upshift2 (abstract) | Where it lives now |
|---|---|---|
| "SC audited, backend treated as a normal web project" | seam thesis: two disciplines, the handoff owned by neither | SEAM-THESIS.md |
| 10 DeFi vectors (V1 bundle harvest … V10 proxy governance) | pluggable vector pack, one per surface, same 5-part structure | vectors/*.md |
| F1 (off-chain→on-chain unauth trigger) | the seam's mirror-invariant Critical (Pass 3) | HUNT-METHODOLOGY.md Pass 3 |
| W34 (executor credential in public bundle) | the secret that crossed build→run / internal→external | each pack's secret-hygiene vector + Pass 2B |
| F1+W34 = $308M chain | chain construction: credential-leak + unauth-trigger killshot | HUNT-METHODOLOGY.md Pass 4 |
| operator EOA signs across 14 chains | concentrated blast-radius / single trust anchor | TARGET-SELECTION.md D3 + Pass 2A authority chain |
| "TVL>$50M + executor pattern" triage | "seam strength + blast radius + disclosure path" triage | TARGET-SELECTION.md |
| 30h hunt, never stop at first Critical | immortal mode, 5 guards, solid=measured | IMMORTAL-MODE.md |
| forge lint / internal consistency / mirror coverage green | the 3 green signals, parameterized per surface | IMMORTAL-MODE.md Guard 4 |
| Stage 1-4 + kabayanerve + fortress | the 4-stage arc + per-surface channel calibration | DISCLOSURE-PROTOCOL.md |
| (implicit) the 3 self-corrections in the package | anti-inflation gate, promoted to first-class | ANTI-INFLATION.md |

## The three self-corrections (why anti-inflation is first-class)

The most transferable lesson from the upshift-package is not a finding -- it is the discipline of catching your own inflation before any external send. The package documents three, in an explicit "audit trail of corrections" table:

1. **EIP-1967 slot misread** -- a draft read the ProxyAdmin slot (`0xb53127684a…`) as the implementation slot (`0x360894a13b…`) and claimed upgrades that never happened. → the SCOPE/MECHANISM correction.
2. **"$308M" two distinct keys** -- a draft summed two independent single-points-of-failure (`operator 0xE0b7DEab` ≠ `ProxyAdmin owner 0x828F86BC`) into one $308M chain. Corrected: two separate findings, honest proven number $5.96M on coreUSDC. → the MAGNITUDE correction.
3. **"$74M missing" mislabeled field** -- a `$1.96B` vault showing `actual_tvl=$0.96` read as "undercollateralized". Corrected: `actual_tvl` is a derived/mislabeled internal field; the real finding is the unauth exposure, severity Medium. → the MAGNITUDE/derived-field trap.

Every one of these was caught BEFORE send. That is the bar. ANTI-INFLATION.md makes it a gate.

## The honest-chain discipline (the part most hunters skip)

The package's `chain-analysis/` and `CHAIN-REPORT` show Pass 4 done honestly: the naive "anon → master password → updateTotalAssets → drain" chain is marked **BROKEN** because `updateTotalAssets` was never an API call (it is `OperatorOnly()`, signed off-chain). The real chains are labelled per their honest trigger:
- F3 NAV-zero-bypass: Critical-if-triggered, trigger = operator EOA, anon = No.
- F3 × W19: the ONE anon link (W19 leaks per-vault operator addresses + idle balances) turns any key-compromise into turnkey targeting -- labelled "removes enumeration cost, does not add loss".
- F3 × W23/W34: trust-reduction, explicitly labelled **PARTIAL** (opsec amplification, not a mechanism bypass).

This is the model: a chain gets `standalone | chained(honest) | trigger | anon?` columns, and a chain that requires a trusted-key compromise says so. upshift2 carries this into ANTI-INFLATION.md's MECHANISM correction and HUNT-METHODOLOGY.md's Pass 4 output template.

## What the engagement is worth (the economics that justify immortal mode)

Realistic ex-gratia for an upshift-class engagement of this severity, engaged this thoroughly, fortress accepted: $50K-$250K. That range is what makes the "ignore token and time budget" instruction rational -- one extra Critical found by refusing to stop is worth orders of magnitude more than the tokens or hours saved. For non-DeFi surfaces the absolute numbers differ (a web2 bounty chain, a crypto-lib CVE-with-credit, an ML vendor disclosure) but the *structure* of the economics holds: the headline chain is what gets the engagement taken seriously, and the headline chain only exists if you ran all 4 passes.

## How to use this file

- Before your first upshift2 engagement: read end-to-end once.
- When a vector pack feels abstract: map it back to the corresponding upshift vector here.
- When tempted to stop early: re-read "what the engagement is worth" + IMMORTAL-MODE.md.
- When tempted to inflate: re-read "the three self-corrections".
- When constructing a chain: re-read "the honest-chain discipline".

The full source is `~/.claude/skills/upshift/` (the specialized DeFi instance) and `~/Desktop/BUGS/upshift-package/` (the produced artifacts). When in doubt about what the mentality produces, read the package -- it is the proof that the methodology works.
