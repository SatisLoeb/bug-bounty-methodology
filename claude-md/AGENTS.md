# Agent Operating Rules (Local)

Date: 2026-02-20

## Mandatory Validation Standard (All Future Targets)

1. Only count findings as valid if they show **non-admin fund theft executable now** on current on-chain state.
2. Final proof must be **fork-based** against currently deployed contracts (no mock-only conclusion).
3. Each target must include:
   - `LIVE_THEFT_CHECK.md` (on-chain preconditions and current-state feasibility)
   - `POC_FORK.md` (repro steps, tx path, measured extraction)
   - binary verdict: `EXPLOITABLE_NOW` or `NOT_EXECUTABLE_NOW`
4. If exploit exists only at design level but cannot be executed now, classify as `NOT_EXECUTABLE_NOW`.
5. Never rely on hypothetical/admin-only paths for this workflow.

