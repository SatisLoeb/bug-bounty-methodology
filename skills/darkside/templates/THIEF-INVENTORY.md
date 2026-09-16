# THIEF-INVENTORY + CHAIN-TRIAGE — <target>

> The admission gate + the pair-hunt. Copy this per engagement to `analysis/THIEF-INVENTORY-<target>.md`.
> Every candidate a door hands you (Door A N-cell, Door B invariant, Door C unwritten-invariant) enters
> here as a **primitive Pn** — a thing you can STORE toward a theft, not "a bug". A primitive earns a
> PoC ONLY if it passes the admission gate. See SKILL.md §2.

## Admission gate (run on EVERY primitive before spending a PoC)

> *"Does this dark place hand me a primitive I can STORE toward a concrete PAYABLE-IMPACT path —
> fund-movement OR a payable capability — even via chaining?"*
> - **Family A — fund-movement** (SC/DeFi-contest default): theft · drain · mint · freeze/halt-of-funds ·
>   stale-value arbitrage · bad-debt socialization · quantified griefing/DoS with a `$` figure.
> - **Family B — payable capability** (web/API / human-triager programs): ATO/session-takeover ·
>   BAC/BOLA/IDOR · auth bypass · priv-esc · PII/KYC exposure · infra/bridge halt. No `loss=$X` required.
> - Which family governs is set by the **program class** (SC-contest → A only; web/bounty → A+B).
> - Chains to NEITHER for this program → **note it, spend ZERO PoC.**

## 1. Primitive inventory

| Pn | door | primitive (what you can STORE) | reachable by | admission (A / B / none) | note |
|----|------|--------------------------------|--------------|--------------------------|------|
| P1 | A/B/C | e.g. "panic on 32-byte addr in GetAllVouchers" | untrusted msg | A (halt) | |
| P2 | | | | | |
| P3 | | | | | |

- **reachable by:** untrusted actor / role-gated (which role) / operator-only. Role-gated or operator-only
  ⇒ OOS unless a role boundary is exceeded (GATE #0 in the manual loop kills ~half the inventory here).

## 2. Pair-hunt (primitives chain; CVSS scores them alone)

For each pair, ask: does `Pa` supply the **trigger / reachability / window / amplification** that `Pb`
lacked alone? Critical-pair heuristics: auth-gap + value-move · oracle-blindness + liquidation path ·
dedup/replay + signed financial action · share-math edge (div-0, totalSupply==0) + vault withdraw ·
bad-debt-socialization + supplier-exit/dust · a fix that closed ONE path while a SIBLING reaches the
same impact un-mitigated.

| chain | path (every arrow = an EXECUTED A→B test) | standalone | chained | payable impact |
|-------|-------------------------------------------|------------|---------|----------------|
| C1 | P1 → [pivot] → P3 → concrete impact | Med | High | loss=$X / frozen-$·dur / gov-seized |

- **The prize is a shared ROOT, not a magic Critical:** many weak primitives feeding ONE root cause =
  one coherent higher-severity thesis. Report `STANDALONE: x / CHAINED: y` + the explicit path.

## 3. ANTI-INFLATION self-dismantle (mandatory, symmetric to the executed disconfirmer)

A chain is real ONLY if **every hop is executed/proven** AND it nets an in-scope payable impact:
- **Extraction class:** the attacker must net POSITIVE (creating `Pa` costs less than chaining to `Pb`
  yields). If not → it's a timing-aid, downgrade. (See `CASE-zest-v2`.)
- **Freeze/griefing/deanon/gov-takeover class:** attacker-nets-zero is its NATURE, not inflation — do
  NOT kill it for netting zero; the payable impact is the denial/seizure/exposure.
- Does any hop secretly need a crash / DAO / exogenous trigger? An OOS hop participates only if a later
  in-scope, untrusted-reachable hop carries the impact.
- **No arrow survives without code that walks it.** A path drawn as arrows with no tx/test traversing it
  = hypothesis, not finding.

## 4. Verdicts

- Admitted → manual loop (SKILL.md §4) → `templates/FINDING-CARD.md`.
- Noted-no-PoC → list here with the one-line reason it chains to no payable impact.
