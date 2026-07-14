---
name: screenshot
description: Generate a step-by-step screenshot capture guide that the researcher can execute manually in their terminal to produce visual evidence artifacts for a bug bounty submission. Output is a workspace-local Markdown file with numbered screenshots, each containing a suggested filename, what the screenshot proves, the exact command to copy-paste, and the expected output. Use after a PoC is finalized and the report is drafted, BEFORE submitting to the bounty platform. Triggers: "prepare screenshots for [target]", "generate screenshot guide", "give me commands to screenshot", "I want to attach proof images". Composes with report-nerve (adds the visual evidence layer) and chill (the screenshots themselves are a strong human-authenticity signal against anti-AI screening).
---

# screenshot

A skill for generating reproducible terminal-screenshot guides that the operator runs manually to produce visual evidence for a bug bounty submission.

## Why this skill exists

Screenshots from a real terminal serve three distinct purposes that no other artifact does:

1. **Independent verification** — triagers can re-run the same commands and see the same output. Cast call returns and tx hashes are bound to mainnet state the researcher does not control.
2. **Anti-AI signal** — a real terminal screenshot (with prompt, syntax highlighting, line wrap, occasional typo) is one of the strongest human-authenticity signals available. Anti-AI classifiers on HackerOne, Cantina, and HackenProof have no way to flag a `.png` of a working terminal.
3. **Effort signal** — the visible footprint of "this person actually ran the commands" raises perceived diligence. Triagers reward demonstrable effort with faster engagement and more generous severity calibration.

The skill itself does not take screenshots. It produces the **guide** the operator follows to take them, with the discipline necessary to make each screenshot load-bearing rather than decorative.

## Composition with other skills

- **report-nerve** provides the structural skeleton of the report. This skill provides the visual evidence layer that supports specific claims in that report.
- **chill** is the voice layer for the report. Screenshots are an even stronger human-authenticity signal than chill prose; the two compose multiplicatively. A chill-styled report with a 7-screenshot evidence pack is the strongest form factor against anti-AI screening currently known.

Run this skill **after** report-nerve has produced the draft and **before** the operator clicks submit. The screenshots become a separate attachment to the submission.

## When to invoke

- Operator says "prepare screenshots for [target]" / "generate screenshot guide" / "give me commands to screenshot"
- Operator says "I want to attach proof images" / "I'll capture this manually"
- Any bug bounty submission destined for an anti-AI-screening platform (HackerOne, public Cantina, HackenProof, Code4rena) where the PoC produces verifiable on-chain or HTTP-level artifacts
- Critical/High findings where the bounty floor justifies the time investment (≥ $1K)

## When NOT to invoke

- Pure Informational findings (the time investment is disproportionate to the payout)
- Pure code-only findings where the only evidence is a code quote (screenshots add nothing)
- Internal disclosure to a vendor security@ where format doesn't matter
- When the operator has explicitly said they will not take screenshots (respect the decision, don't generate the guide unprompted)

## Core principles

### Principle 1: Each screenshot must be load-bearing

Every screenshot in the guide must prove a specific claim in the report. If you cannot articulate "this screenshot proves that the report claim on line X is empirically correct," cut the screenshot. Decorative screenshots dilute the evidence pack and look like padding.

### Principle 2: Commands must be copy-paste-runnable

The operator should not have to think. Each command in the guide is one block, properly quoted, with environment variables exported once at the top. No mental substitution required.

### Principle 3: Expected output must be specified

For each screenshot, the guide shows what the operator should see. This serves two functions: (a) the operator knows immediately if the command worked, (b) the screenshot caption in the submission can quote the expected value as confirmation.

### Principle 4: Independent verification paths preferred

Where possible, generate at least one screenshot from a source independent of the researcher's tooling: Etherscan, public RPC, OSV.dev, npm registry, the target's own GitHub. This neutralizes the "researcher fabricated the output" dismissal.

### Principle 5: Hierarchy of importance

Order screenshots from most critical to least critical. The operator may not take all of them; the first 3-5 should be sufficient to prove the finding alone. Optional screenshots strengthen but are not required.

### Principle 6: Filename = sortable + descriptive

Each screenshot gets a suggested filename starting with a zero-padded number (`01-`, `02-`, etc.) so the triager opens them in the intended order, followed by a kebab-case description (`live-wbrl-cap-readback.png`). Never use spaces in suggested filenames.

## Standard screenshot categories

Use these as a checklist when generating the guide. Not all apply to every finding; pick the ones that match the finding type.

### A. Live on-chain state readbacks (smart contract findings)

For each load-bearing on-chain value cited in the report, generate one screenshot:

- Live value read via `cast call` against the deployed contract
- Suggested filename: `XX-live-<token>-<field>-readback.png`
- Proves: the number in the report is the live mainnet value, not a stale snapshot or a fabrication

Example commands:
```bash
cast call <contract> "<signature>" <args> --rpc-url $RPC_URL
cast call <contract> "<signature>" <args> --rpc-url $RPC_URL | cast --from-wei
```

### B. Function selector / error selector confirmation

When the report cites a specific selector (function selector, custom error selector), generate one screenshot showing forward + reverse confirmation:

- Suggested filename: `XX-<name>-selector.png`
- Proves: the name claimed in the report corresponds bidirectionally to the selector

Example commands:
```bash
cast sig "<FunctionOrErrorName>()"          # name → selector
cast 4byte 0x<selector>                      # selector → name (via 4byte directory)
```

### C. Historical event / production transaction proof

For each historical event cited in the report (e.g. "block X shows production usage at Y% of cap"), generate one screenshot. Two options:

- **Method 1** (cast): `cast tx <txhash> --rpc-url $RPC_URL | head -20`
- **Method 2** (etherscan, preferred for visual punch): screenshot the Etherscan tx page with key fields highlighted

Suggested filename: `XX-historical-<event-shortname>-<source>.png` where source is `cast` or `etherscan`.

If both methods are used: split as `XXa-...-cast.png` and `XXb-...-etherscan.png`.

Proves: the historical claim is not invented; tx receipt is on mainnet, verifiable by anyone.

### D. Build / compilation success

One screenshot per PoC project showing the build succeeds:

- Suggested filename: `XX-<project>-build-success.png`
- Proves: the environment is reproducible; triager can compile the PoC

Example command:
```bash
cd <pocs-dir> && forge build       # Foundry
cd <pocs-dir> && npm install && npx hardhat compile   # Hardhat
```

### E. Full test suite PASS — the keystone screenshot

The single most important screenshot. Shows all tests in the PoC pass against the live mainnet fork:

- Suggested filename: `XX-poc-N-of-N-pass.png` (e.g. `08-poc-7-of-7-pass.png`)
- Proves: the entire finding chain is empirically reproducible

Example command:
```bash
forge test                                   # Foundry
npx hardhat test                             # Hardhat
```

This screenshot is CRITICAL — never skip it.

### F. Headline test with logs (the killshot test)

The single test that demonstrates the headline scenario, with `-vv` for log visibility:

- Suggested filename: `XX-<headline-test-name>.png`
- Proves: the specific scenario the report leads with is empirically real

Example command:
```bash
forge test --match-test <headline_test> -vv
```

### G. Trace screenshot for mechanism verification (optional but strong)

For findings where the mechanism is non-obvious (revert selectors, custom errors, multi-call chains), one trace screenshot showing the relevant section:

- Suggested filename: `XX-<test>-trace-<what-it-shows>.png`
- Proves: the mechanical chain in the report matches what the EVM actually does

Example command:
```bash
forge test --match-test <test> -vvvv 2>&1 | grep -A 2 -B 1 "<keyword>"
```

The `grep -A 2 -B 1 "<keyword>"` trick keeps the screenshot focused on the relevant trace section rather than dumping 200 lines of noise.

### H. Source code on block explorer (optional, strong visual)

For findings where the bug is visible directly in the deployed source, screenshot the verified source on Etherscan / Polygonscan / BscScan with the relevant lines highlighted:

- Suggested filename: `XX-source-code-<what-it-shows>.png`
- Proves: the bug is in the deployed code, not just in a fork or test environment
- The operator highlights the specific lines that are load-bearing for the finding

### I. Web/API findings — replayable curl + decoded response

For web/API findings (auth bypass, IDOR, signature forge):

- Suggested filename: `XX-curl-<endpoint>-bypass.png`
- Proves: the bypass replays against the production endpoint
- Use `-w "HTTP_STATUS=%{http_code}\n"` to make the status code visible in the screenshot

Example command:
```bash
curl -s -X POST https://api.target.com/endpoint \
  -H "Authorization: Bearer <token>" \
  -d '{"payload":"value"}' \
  -w "\nHTTP_STATUS=%{http_code}\n"
```

### J. Off-chain artifact persistence (auth findings)

For findings where the bypass creates a persistent artifact (account row, MFA deletion, token issuance), one follow-up screenshot showing the artifact persists across a fresh session:

- Suggested filename: `XX-artifact-persists-<what>.png`
- Proves: the bypass is not ephemeral; the server accepted and stored the result

## Output structure

The skill produces a single file at:

```
<workspace>/submissions/SCREENSHOTS-GUIDE.md
```

The file structure:

1. **Top-level instructions** — terminal setup, RPC env var export, naming convention
2. **Numbered screenshot sections** in order of importance, each containing:
   - **Titre suggéré:** `XX-descriptive-name.png`
   - **Ce que ça prouve:** one-sentence claim from the report this screenshot supports
   - **Commande:** copy-paste-ready bash block
   - **Sortie attendue:** expected output, verbatim where possible
3. **Récap table** — all screenshots with importance tier (Critical / Important / Optional)
4. **Tier guidance** — which screenshots to take if the operator is short on time (4 minimum vital, 8 recommended, 12 complete)
5. **Packaging instructions** — `mkdir`/`zip` commands to bundle the .png files for submission

## Tiering discipline

Every screenshot in the guide MUST be tagged in the Récap table with one of:

- **Critique** — the report is materially weakened without this screenshot
- **Important** — strengthens the evidence pack, recommended if time permits
- **Optionnel** — adds polish, can be skipped under time pressure

Always provide the "minimum vital" subset (4 screenshots) for operators who are time-constrained. This subset must cover: (1) the headline test PASS, (2) the full suite PASS, (3) at least one independent verification (cast call or etherscan), (4) the historical anchor if applicable.

## Anti-patterns

### Anti-pattern 1: Generating screenshots for every cast call ever run

Pick the ones that prove load-bearing claims. A guide with 30 screenshots is worse than one with 8.

### Anti-pattern 2: Asking for screenshots of internal notes / workspace files

These have zero evidence value. Screenshots are for verifiable external artifacts only.

### Anti-pattern 3: Commands with placeholders the operator must fill in

`<your-rpc-url>`, `<your-address>`, etc. The skill knows the addresses (they're in the report). Use them literally.

### Anti-pattern 4: Forgetting the env var setup at the top

Operators get bitten by missing exports. Always include the setup block.

### Anti-pattern 5: Screenshot of a screenshot tool / IDE / editor

The skill produces a guide for terminal + browser screenshots. Never suggest screenshotting Cursor, VS Code, Slack, or any tooling that signals "AI workflow."

## Composition rules with chill skill

When the report is being styled by chill (HackerOne, public Cantina, HackenProof, Code4rena targets):

- Screenshot file names CAN be informal but should not be cringe. `08-poc-7-of-7-pass.png` is fine; `08-bro-it-works.png` is not.
- The guide itself stays technical (it's an internal operator document, not an external deliverable).
- The screenshots themselves are visual artifacts and not subject to chill voice rules.

## Composition rules with report-nerve skill

- The screenshot guide references which report sections each screenshot supports. Cross-link explicitly where possible.
- If report-nerve includes a Chain-of-custody comment, mention in the guide that screenshots #08, #09 and any historical-tx screenshots should also be referenced in the comment.
- Numerical anchors that emerge from screenshot readbacks can be cited in the report's Impact / Steps to Reproduce sections.

## Pre-handoff checklist

Before presenting the guide to the operator:

1. Every screenshot section has a `Titre suggéré`, `Ce que ça prouve`, `Commande`, `Sortie attendue` — none missing
2. All commands have been mentally walked through to confirm they will run (no typos in addresses, signatures, selectors)
3. RPC URL is a public no-auth-required endpoint where possible (`https://ethereum-rpc.publicnode.com`, `https://polygon-rpc.com`, etc.)
4. The Récap table covers every screenshot with importance tier
5. The minimum-vital subset is identified explicitly
6. Packaging instructions (`mkdir`, `zip`) are included
7. File written to `<workspace>/submissions/SCREENSHOTS-GUIDE.md` (or equivalent submissions directory)

## Reference implementation

The Ripio F-001 SCREENSHOTS-GUIDE.md (2026-05-21) is the reference implementation. It covers:
- 12 screenshots across categories A, B, C, D, E, F, G, H
- Critical/Important/Optional tiering
- Minimum vital subset (4 screenshots)
- Packaging instructions
- All commands tested live against `https://ethereum-rpc.publicnode.com`

Location: `~/Desktop/BUGS/ripio-audit/submissions/SCREENSHOTS-GUIDE.md`

## Companion skills

- **report-nerve**: produces the report draft this guide supports
- **chill**: voice layer for the report; this skill provides the visual layer
- **immunefi-submit**: if the target is Immunefi (rare per user's boycott rule), the screenshot guide format adapts to Immunefi's submission UI
- **security-disclosure**: for direct vendor disclosure, screenshots become inline `cid:` attachments rather than zip files

## Skill metadata

- **Version**: 1.0
- **Last updated**: 2026-05-21
- **Maintainer**: user (malix / SatisLoeb contexts)
- **Reference implementation**: Ripio F-001 (`~/Desktop/BUGS/ripio-audit/submissions/SCREENSHOTS-GUIDE.md`)
- **Composes with**: report-nerve, chill
