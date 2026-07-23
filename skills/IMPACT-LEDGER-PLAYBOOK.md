# IMPACT-LEDGER PLAYBOOK — enumerate every PAYABLE impact class so no un-hunted class hides the finding the theft-lens skipped

**Shared mandatory gate. Invoked by `firmaudit` (Phase T, before any NO-GO/NULL-COÛTEUX verdict) and `intake` (at dossier build, to set the ROW set) and `darkside` (before any fortress close). One source of truth — the skills reference this file, none duplicates it.** The telos is NOT "prove the target has no theft"; it is **"don't MISS a payable finding by hunting only the theft ROW of a scope that pays for six other impact classes."** The completeness THIRD: `SURFACE-INVENTORY` enumerates WHERE (all surfaces, at start), `COVERAGE-LEDGER` enumerates WHICH FILES (in-scope files, before close) — both are **WHERE** axes. This ledger is the orthogonal **WHAT** axis: which payable impact *classes* were actually hunted, not just which files were opened.

## The defect this fixes (the operator's catch, 2026-07-19 — "le scope ne se limite pas au fund theft")

The entire discovery/triage arsenal gates acceptance on a dollar-denominated extraction line, so a candidate that produces any *other* payable impact is dropped **before the code is read**, always before its payability is scored against the program's real severity table. Measured on `~/Desktop/BUGS`: the `loss=$X` / present-loss prefilter appears in **63 folders**; of 71 classified verdicts, **38% never named any non-theft class at all**, 23% named one only inside a theft-lens dismissal ("DoS not loss", "griefing not extraction"). A fortress verdict answers exactly ONE question — *"can an unprivileged attacker walk away with funds?"* — and is silent on the orthogonal question every freeze/griefing/liveness/insolvency/deanon tier pays for:

> **"Can an unprivileged attacker, at self-loss or zero profit, FREEZE / BRICK / DoS / render-INSOLVENT / take-GOVERNANCE-of / DEANONYMIZE the protocol for everyone else?"**

The First Maxim is the diagnostic: `owner-recoverable`, `gated setter`, `attacker nets negative`, `rounds against the attacker`, `monotonic counter` each name the EXISTENCE of a control **against theft** — never its STRENGTH against a griefer who burns value to hurt others. **Mezo (2026-06-11) is the counter-proof:** the one engagement where the operator re-ran a freeze/insolvency/griefing pass flipped **NO-GO → payable Medium** (bridge-worker infinite re-enqueue DoS). `nearcore`/`noble` are the inverse proof — they hunted liveness/halt first-class *because the program history forced a non-theft class onto the asset map from day one.*

The asymmetry that makes this a methodology bug, not a target property: **the full non-theft taxonomy already lives in the arsenal — but only in the REPORTING skills** (`immunefi-submit`, `security-disclosure`, `report-nerve`), never the DISCOVERY/triage skills. You can *classify* a non-theft finding you already hold, but you have **no generator to find one**, and the first acceptance gate re-narrows to theft and kills the finding you were handed. This ledger moves the taxonomy UPSTREAM of the gate that was dropping the candidate.

## THE LEDGER — a class×surface MATRIX, not a column (why it is a new artifact)

Impact-class coverage is a **cross-product** — one class spans many files; one file hosts many classes — that a single column on a file-keyed ledger structurally cannot hold. `COVERAGE-LEDGER` is keyed on the in-scope FILE; `SURFACE-INVENTORY`'s column named "Class" holds surface-*type* (web-route/host/seam), not impact-class; darkside's Door-A matrix is money-path × **dev-test-covered** (what the devs tested, not what you hunted). None carries the WHAT axis. Build `recon/IMPACT-LEDGER.md`:

### Step 1 — instantiate the ROWS from the program's actual severity table
Pull the payable-impact set for THIS platform (§ THE PAYABLE-IMPACT MAP below), then filter to the program: **drop a row only for a CITED program carve-out** (README known-issues / accepted-risk / "cap = Critical-only" / scope exclusion — quote the line). Keep a row you're unsure about; an un-hunted class must not be silently absent. Group the rows:
- **Value-integrity** — perma-freeze · insolvency/bad-debt · temp-freeze · unclaimed-yield loss/freeze · protocol-fee loss · value-leak-no-beneficiary
- **Availability/liveness** — permanent core-fn DoS · time-sensitive-fn liveness DoS (liquidation/oracle/auction/settlement) · unbounded-gas/OOG · griefing (no attacker profit) · block-stuffing · (Blockchain/DLT scope only) chain-halt/split/node-exhaustion
- **Authorization/governance** — governance-result manipulation/takeover · upgrade/init-takeover · untrusted→privileged escalation
- **Confidentiality/privacy** — deanonymization / anonymity-set collapse / metadata & timing correlation · PII/sensitive-data disclosure · secret/key retrieval · read-path authz gap
- **Correctness/integrity** — unauthorized mint/supply-inflation · RNG predictability · replay/nonce/domain-separator reuse · oracle-manip-causing-loss · unintended-behavior-no-financial-risk

### Step 2 — the COLUMNS are the surfaces (reuse, don't re-enumerate)
Columns = the surfaces from `SURFACE-INVENTORY.md`, but ensure the set includes the surfaces a theft pass never enumerates: **availability surfaces** (queues, keepers, cron/settlement, async-message handlers), **authority/governance transitions** (valset/role/upgrade paths), and **privacy/data-exposure surfaces** (any path that can emit another party's state/identity/secret). Wire to darkside Door A: the N-column (money-paths the devs left untested) becomes high-priority columns.

### Step 3 — fill each CELL
`cell = hunted? → { EXECUTED artifact (PoC / live read + pasted output / named-and-run disconfirmer) | N-A + CITED program-reason }`. **The exclusion of a class must be a cited program ruling, never a `loss=$X` reflex.** "No extraction" is NOT a valid reason to leave a freeze/griefing cell un-hunted — those classes net the attacker zero by definition.

### Step 4 — the CLOSE GATE (mirrors the coverage-ledger's)
**No NO-GO / NULL-COÛTEUX / fortress verdict while any `(payable-row × reachable-surface)` cell is un-hunted.** A theft-row-only sweep can no longer produce a fortress verdict. The close sentence must read: "the program pays N impact classes; I probed each reachable class×surface cell with an executed artifact or a cited exclusion; the theft row is one of N, not the whole board." Then RE-SOURCE.

### Step 5 — RANK surviving cells by THIS platform's payout, not a fixed DeFi hierarchy
Cantina points **Crit=20 / High=10 / Med=3** · C4 **High=10-share / Med=3-share** · Sherlock pool×tier. A Cosmos chain-halt (Blockchain/DLT-scope Critical) can outrank a theft; a permanent-freeze (Immunefi Crit) can too.

## THE PAYABLE-IMPACT MAP (verified tiers — the ROW menu)

| Impact class | Immunefi | Cantina | Code4rena | Sherlock | HackenProof |
|---|---|---|---|---|---|
| Permanent freezing of principal | **Crit** | Crit(managed)/High(comp) | **High** | High if >1%&>$10 | **Crit** |
| Protocol insolvency / bad-debt | **Crit** | Crit/High | High | High/Med per bars | **Crit** |
| Temporary freezing (recoverable) | **High** | High | **Medium** | Med/High by duration | High |
| Loss/freeze of *unclaimed* yield | High (NOT Crit) | High | Med/High | High/Med | High |
| Value-leak, no beneficiary (dust drift) | →insolvency | Medium | **Medium** | replay-rule: unbounded=100% | — |
| Permanent DoS / broken core fn | **Med-capped (SC)** →Crit iff freeze | Med→High if locks | Med→High if freeze | Medium | Medium |
| Liveness DoS of time-sensitive fn | Med | Medium | Medium | Med(one)/High(also locks) | Medium |
| Unbounded-gas / OOG | Med | Med | Med | Med/High | Med |
| Griefing (no attacker profit) | **Med — paid** | **Med — paid** | Med (QA if trivial) | Med iff clears a bucket | **Med — paid** |
| Chain halt/split (Blockchain/DLT scope) | **Crit** halt / High split | Crit/High | Med | **EXCLUDED** | per-program |
| Governance takeover / vote manipulation | **Crit** | **Crit** | **QA/Low — THE TRAP** | High/Med iff untrusted | **Crit** |
| Upgrade / init takeover | →Crit | →Crit | High iff untrusted | High/Med iff untrusted | High |
| Unauthorized mint / supply inflation | **Crit** | High | High iff untrusted | High/Med | **Crit** |
| RNG predictable/manipulable | Crit iff abuse | — | Med/High | — | — |
| Replay / domain-separator reuse | →impact | — | Med/High | Med/High (replay-rule) | — |
| Oracle-manip causing loss (no clean theft) | →impact | — | Med/High | High/Med iff $ + rational | High |
| Deanon / anonymity-set collapse / timing | (no SC row) | — | (OOS) | — | tiered >15%=High/3–15%=Med |
| PII / sensitive-data disclosure | **High (W&A)** | — | (OOS SC) | — | High tiered |
| Secret / key / sensitive-file retrieval | **Crit (W&A)** | — | — | — | Crit |

**Highest-value single lever:** perma-vs-temp freeze — on C4 that one word of reachability is High(10-share) vs Med(3-share), a ~3.3x swing; on Immunefi it is Crit vs High. **Model permanence explicitly.**

## NEGATIVE SPACE — do NOT spend a report on these standalone
- **Pure MEV / front-running / sandwich** — unpayable standalone (Immunefi not-classified); chain it into a listed Crit/High.
- **Admin / trusted-role MISUSE** — C4 QA/Low, Sherlock invalid, Immunefi downgrade. The finding must show **authn ≠ authz** (an *untrusted* actor reaching the power), not that a trusted admin *could* rug. This is the First Maxim in payout form, and the lever that flips a held finding to payable (a permissionless path to a power currently admin-gated).
- **Kill the "liveness = jackpot" reflex:** a pure DoS/liveness on an app-layer **Smart-Contract** scope caps at **Medium** everywhere — it reaches High/Crit only by *becoming* a permanent freeze (funds locked) or on a **Blockchain/DLT-scope** L1/consensus target (where a halt genuinely is Critical).
- **Chain reorg / network-liveness** — Sherlock EXCLUDES explicitly. **Missing events / gas-opt** — separate track, not main severity.

## THE PRIVACY SPECIAL CASE (Monero / Tor / any anonymity-scope target)
For a dedicated privacy protocol the **maximum-severity impact is breaking the anonymity/confidentiality guarantee — with ZERO theft**: deanon, anonymity-set collapse, metadata/timing correlation, `.onion`↔IP linkage, view/spend-key exposure, cross-service identifier joins. **The arsenal currently cannot GENERATE one** (`expand-surface` covers only ZK-mixer soundness; `power` discards the read-authz gap that *is* the deanon, pre-test). On any privacy target: (1) deanon rows are MANDATORY and ranked at the TOP; (2) seed the privacy-surface column from the target's own OPSEC-prohibition list (any path that could emit `.onion`/key/IP/circuit/session data is a deanon surface — the project's "never log X" list is a ready-made attack-surface checklist); (3) never write NO-GO until the deanon row has an executed probe.

## The standing PRE-NO-GO ritual (encode wherever a fortress verdict can be written)
Before any NO-GO on a target with a queue / bridge / liquidation / aggregation / validator-set / async-settlement mechanism, run one **adversary-maximizes-OTHERS'-loss** pass: *"can an unprivileged actor, at self-loss, FREEZE / BRICK / DoS / render-INSOLVENT / take-GOVERNANCE-of / DEANONYMIZE for everyone else?"* This is the pass that flipped Mezo. A summary is not the code: every gate you cite (`owner-recoverable`, `gated setter`, `valset power-validation`) is an un-executed hypothesis until pierced on the real artifact — the ledger tells you WHICH cells to probe, it does not pre-decide the verdict.

## The one-line rule
**NO-GO means "no THEFT path", never "no payable bug." Surface-inventory says where to look; coverage-ledger says which files were opened; the impact-ledger says which of the program's payable impact CLASSES were actually hunted — and a fortress verdict is illegal while any payable-class × reachable-surface cell is un-probed.** Run this before every NO-GO/NULL-COÛTEUX close, on every target, and instantiate the ROWS from the program's real severity table — not from the theft reflex.
