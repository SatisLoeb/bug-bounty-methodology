### Weight Accounting

<!--
MANDATORY for every finding claiming severity ≥ Low with a dollar impact.
Skipping this section = automatic D8 fail in preflight = submission blocked
at claimed severity. See WEIGHT-CARD.md for full procedure.

The hard gate: W1 (computed loss) OR W5 (paid precedent) must contain a
numerical anchor. Both cannot be qualitative. An unpaid "related H1 #xxx"
does NOT satisfy W5 — only paid references with dollar figures count.

Dashboard slots W2/W3/W4 are optional but their absence is a visible
argumentation weakness. Fill them where possible.

Exceptions (write "N/A — [reason]" if applicable):
- Pure information disclosure already at Informational/Low severity.
- Smart contract findings where the forge-test state delta is the anchor.
- Findings where the HTTP response IS the weight (e.g. 247 KYC records
  returned from /api/users — count is the impact).

For DoS findings, use W1 form (b): downtime × req/s × users from a
reproducible PoC. Counts as numerical anchor for D8.

Fast W5 population: arsenal/tools/precedent-scan.sh "<class>" emits a
copy-paste-ready W5 block formatted for this template.
-->

**Severity claimed:** [Low / Medium / High / Critical]

**Numerical anchor:** [W1 (a) computed / W1 (b) DoS metric / W5 precedents / both]

**W1 — Loss accounting:**

*Form (a) — computed dollar loss:*
```
Formula:        [$value × victims × frequency × time window]
Inputs:
  - [input 1]:  [value]  (source: on-chain block X / API readback / documented limit)
  - [input 2]:  [value]  (source)
  - [input 3]:  [value]  (source)
Computed loss:  $[amount]
```

*OR form (b) — DoS alternate anchor:*
```
Target endpoint:   [URL or contract function]
Downtime:          [X seconds/minutes/hours] (measured via reproducible PoC)
Request rate:      [Y req/s] (source)
Affected users:    [Z users] (source: disclosed MAU / on-chain active addrs)
Degradation:       [duration × rate × users] = [N failed sessions / blocked TXs]
```

*OR form (c) — non-quantifiable (only valid if W5 provides the anchor):*
```
Non-quantifiable because: [specific constraint — off-chain data / KYC only / etc.]
Conservative scenario:    [worst-case prose with concrete victims and outcomes]
```

**W5 — Precedent anchor:**

| Report | Class | Payout | Source |
| --- | --- | --- | --- |
| [ID or URL] | [vulnerability class] | $[paid amount] | [H1 / C4 / Cantina / Sherlock] |
| [ID or URL] | [vulnerability class] | $[paid amount] | [H1 / C4 / Cantina / Sherlock] |
| [ID or URL] | [vulnerability class] | $[paid amount] | [H1 / C4 / Cantina / Sherlock] |

**W2 — Stakeholder map:**
[LPs / treasury / retail / integrators / KYC victims — with addresses or counts where possible]

**W3 — Reversibility audit:**
[pause / governance override / timelock / circuit breaker — each noted present/absent with proof (cast call output, governance contract check, etc.)]

**W4 — Live conditions:**
[block/timestamp + readback proving profitability conditions are active NOW — pool liquidity, paused=false, active user interaction]

**Argumentation weakness noted:**
[List W2/W3/W4 slots left empty, or write "none" if all populated]

---

