# Instructions Machine 1 — Weight Card Encoding

## Contexte

Session du 2026-04-13 (suite). Chain Proof Gate (commit 24cd46d) a fermé une failure mode — submission de findings auth-class sans preuve d'exécution. Phemex R2 (submitted 2026-04-10, marqué Informative 2026-04-13) a démontré qu'une deuxième failure mode restait ouverte : un finding peut passer ce qui serait un D7 chain proof check (l'endpoint retourne 200) et quand même être rejeté parce que l'impact est **narré au lieu d'être calculé**.

Weight Card (commit [this one]) est l'encodage structural de cette leçon : une couche dashboard à 5 slots avec un hard gate (D8) sur la présence d'un anchor numérique, soit via W1 (computed dollar loss) soit via W5 (paid precedent avec dollar figure).

**Direction inversée par rapport au commit précédent** : cette fois c'est machine 2 qui a authored (design + implementation via Plan mode), et machine 1 doit appliquer. Les steps ci-dessous sont le sync protocol pour machine 1.

## Les 5 (+2) couches à synchroniser

| # | Fichier | Rôle | Localisation arsenal |
|---|---|---|---|
| 1 | `WEIGHT-CARD.md` | Template gate complet (Stages 1-4, 5 slots, dashboard, war log) | `arsenal/checklists/WEIGHT-CARD.md` (nouveau) |
| 2 | `PREFLIGHT-CHECK.md` | Criterion D8 ajouté, gating parallel à D7 | `arsenal/checklists/PREFLIGHT-CHECK.md` (modifié) |
| 3 | `REPORT-STANDARD.md` | Section "Weight Accounting" ajoutée après "Chain Acceptance Verification" | `arsenal/methodology/REPORT-STANDARD.md` (modifié) |
| 4 | `CLAUDE.md` | Rule #37 ajoutée après rule #36 | `arsenal/CLAUDE.md` (modifié) |
| 5 | `feedback_weight_card.md` | Feedback memory avec trigger phrases pour auto-détection | **Pas dans le repo** — créer manuellement sur machine 1 (§5) |
| 6 | `precedent-scan.sh` | Shell MVP qui émet un W5 block copy-paste-ready depuis H1-HUNTING-PATTERNS + H1-STATISTICS + OUTCOMES.jsonl | `arsenal/tools/precedent-scan.sh` (nouveau) |
| 7 | `gravedigger/SKILL.md` + `mrrobbot/SKILL.md` | Ligne Weight Card ajoutée next to Chain Proof Gate dans Phase 6 (gravedigger) et Phase 4 (mrrobbot) | `arsenal/skills/gravedigger/SKILL.md` + `arsenal/skills/mrrobbot/SKILL.md` (modifiés) |

## 1. Pull arsenal repo sur machine 1

```bash
cd ~/arsenal
git pull origin main
```

Les 6 fichiers versionnés (couches 1-4, 6, 7) seront synchronisés. Vérification rapide :

```bash
test -f ~/arsenal/checklists/WEIGHT-CARD.md && echo "WEIGHT-CARD: OK"
grep -q "^| D8 |" ~/arsenal/checklists/PREFLIGHT-CHECK.md && echo "PREFLIGHT D8: OK"
grep -q "### Weight Accounting" ~/arsenal/methodology/REPORT-STANDARD.md && echo "REPORT-STANDARD section: OK"
grep -q "^37\. \*\*MANDATORY — Weight Card" ~/arsenal/CLAUDE.md && echo "CLAUDE.md rule #37: OK"
test -x ~/arsenal/tools/precedent-scan.sh && echo "precedent-scan.sh: OK"
grep -q "WEIGHT-CARD\|Weight Card" ~/arsenal/skills/gravedigger/SKILL.md && echo "gravedigger SKILL: OK"
grep -q "WEIGHT-CARD\|Weight Card" ~/arsenal/skills/mrrobbot/SKILL.md && echo "mrrobbot SKILL: OK"
```

Les 7 lignes "OK" doivent apparaître.

## 2. Mirror vers working directory `~/Desktop/BUGS`

```bash
cp ~/arsenal/checklists/WEIGHT-CARD.md ~/Desktop/BUGS/WEIGHT-CARD.md
cp ~/arsenal/checklists/PREFLIGHT-CHECK.md ~/Desktop/BUGS/PREFLIGHT-CHECK.md
cp ~/arsenal/methodology/REPORT-STANDARD.md ~/Desktop/BUGS/REPORT-STANDARD.md
cp ~/arsenal/CLAUDE.md ~/Desktop/BUGS/CLAUDE.md
```

Le precedent-scan.sh reste dans `~/arsenal/tools/` (ne nécessite pas de mirror dans BUGS — il est invoqué via chemin absolu).

Les skills (`gravedigger/SKILL.md` et `mrrobbot/SKILL.md`) doivent aussi être sync vers `~/.claude/skills/` :

```bash
cp ~/arsenal/skills/gravedigger/SKILL.md ~/.claude/skills/gravedigger/SKILL.md
cp ~/arsenal/skills/mrrobbot/SKILL.md ~/.claude/skills/mrrobbot/SKILL.md
```

Si des modifications locales existent sur machine 1, faire un diff d'abord :

```bash
for pair in \
  "~/Desktop/BUGS/WEIGHT-CARD.md:~/arsenal/checklists/WEIGHT-CARD.md" \
  "~/Desktop/BUGS/PREFLIGHT-CHECK.md:~/arsenal/checklists/PREFLIGHT-CHECK.md" \
  "~/Desktop/BUGS/REPORT-STANDARD.md:~/arsenal/methodology/REPORT-STANDARD.md" \
  "~/Desktop/BUGS/CLAUDE.md:~/arsenal/CLAUDE.md" \
  "~/.claude/skills/gravedigger/SKILL.md:~/arsenal/skills/gravedigger/SKILL.md" \
  "~/.claude/skills/mrrobbot/SKILL.md:~/arsenal/skills/mrrobbot/SKILL.md"; do
  LOCAL="${pair%%:*}"
  CANONICAL="${pair##*:}"
  LOCAL=$(eval echo "$LOCAL")
  CANONICAL=$(eval echo "$CANONICAL")
  if [ -f "$LOCAL" ] && [ -f "$CANONICAL" ]; then
    diff -q "$LOCAL" "$CANONICAL" 2>/dev/null || true
  fi
done
```

Résoudre les divergences (garder la version `arsenal/` comme source de vérité pour les fichiers de méthodologie).

## 3. Créer la feedback memory (couche 5)

Le fichier feedback n'est pas dans le repo Arsenal parce qu'il vit dans `~/.claude/projects/` (spécifique au harnais Claude Code de chaque machine). Il faut le créer manuellement sur machine 1.

```bash
MEMORY_DIR="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory"
mkdir -p "$MEMORY_DIR"

cat > "$MEMORY_DIR/feedback_weight_card.md" <<'MEMORY_EOF'
---
name: Weight Card — Mandatory Before Non-Informational Submission
description: Every finding claiming severity ≥ Low with dollar impact MUST contain at least one numerical anchor — W1 (computed dollar loss via formula and cited inputs) or W5 (paid precedent with dollar figure from H1/C4/Cantina/Sherlock). Dashboard slots W2/W3/W4 surface argumentation weakness but do not block. Complementary to Chain Proof Gate (D7) — answers "is the impact priced?" rather than "does the exploit execute?".
type: feedback
---

**Rule:** Before submitting any finding claiming severity ≥ Low with a dollar impact, populate the Weight Card template in REPORT-STANDARD.md "Weight Accounting" section. The hard gate (D8) requires at least one numerical anchor — both W1 and W5 cannot be qualitative.

**Narrative-weight grep (mechanical trigger — catches the opposite of what D8 requires):**

```bash
grep -nE "could drain|could extract|could potentially|significant funds|substantial losses|large number of users|many users|many accounts|estimated to|potentially affects|at risk|exposes users to|attacker could extract|could lead to|may result in|would enable loss of|all users|all deposits|all funds" "$DRAFT_PATH"
```

For each match: verify a specific number (dollar amount, user count, TVL percentage) appears in the same section. If the phrase stands alone without accompanying numerical data, the finding fails D8. Three options:

- **Option A: populate W1.** Compute dollar loss with formula and inputs cited from on-chain reads, API counts, documented protocol limits. Variables must have sources.
- **Option B: DoS alternative W1.** For DoS findings, substitute downtime × req/s × affected users. Downtime must be measured from a reproducible PoC, not asserted.
- **Option C: populate W5.** Run ~/arsenal/tools/precedent-scan.sh <class> to get a copy-paste-ready W5 precedent anchor block with ≥1 paid reference from H1/C4/Cantina/Sherlock. Each row must have a dollar amount — unpaid "related H1 #xxx" references do NOT count.
- **Option D: downgrade severity to Informational.** An acknowledged Informational beats a dismissed Medium.

Both W1 and W5 cannot be qualitative. If W1 is escape-hatch "Non-quantifiable — conservative scenario", W5 MUST be populated with ≥1 paid precedent.

**Dashboard slots (non-gating but noted):**
- W2 — Stakeholder map: who loses, with on-chain addresses or documented identifiers
- W3 — Reversibility audit: pause / governance override / timelock / circuit breaker with proof of absence or weakness
- W4 — Live conditions proof: block/timestamp + readback proving profitability conditions active NOW

Empty dashboard slots = argumentation weakness noted in the report, but do not block.

**Why:** Phemex R2 (POST /assets/transfer via trading key, submitted 2026-04-10, marked Informative 2026-04-13) passed what would have been a D7 chain proof check — the server accepted the primitive and returned code=0, status=10. It failed because the weight was narrated, not computed. The draft said "I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital." Result: 2 rep, $0, marked Informative.

Rule #15 (honest impact quantification) existed before this incident but fired reactively — it punished oversell after triage. Weight Card forces computation proactively, before the draft leaves the workspace.

Chain Proof Gate (D7) and Weight Card (D8) are independent gates catching distinct failure modes:
- D7 = "does the exploit execute?" — grep for hedge phrases. Fix: ethical variant test or severity downgrade.
- D8 = "given it executes, is the impact priced?" — grep for narrative phrases. Fix: compute W1 or scan W5 or severity downgrade.

A finding must pass both where applicable. Phemex R2 would have passed D7 and failed D8.

**How to apply:**
- Run the narrative-weight grep on every submission draft claiming ≥ Low with dollar impact, not conditionally.
- Use precedent-scan.sh to populate W5 fast. The script emits a copy-paste-ready markdown block matching REPORT-STANDARD Weight Accounting template exactly — no reformatting required.
- For smart contract findings with forge-test PoCs asserting state deltas, W1 is implicit. Still populate W5 where precedent exists.
- For pure information disclosure findings claimed at Informational/Low, this gate does not apply.
- For DoS findings, use W1 alternate form: measured downtime × req/s × affected users.
- Reference files: WEIGHT-CARD.md (full procedure), PREFLIGHT-CHECK.md D8 (gating), REPORT-STANDARD.md Weight Accounting section, CLAUDE.md rule #37, ~/arsenal/tools/precedent-scan.sh.

**Trigger keywords to self-detect during drafting:** if I catch myself writing any of the narrative-weight phrases without a specific number in the same section, stop immediately. Populate W1 or W5 before continuing.
MEMORY_EOF

echo "Memory file created at: $MEMORY_DIR/feedback_weight_card.md"
```

## 4. Update MEMORY.md index sur machine 1

```bash
MEMORY_INDEX="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md"

if ! grep -q "feedback_weight_card.md" "$MEMORY_INDEX"; then
  # Insérer juste après la ligne feedback_chain_proof_gate.md si elle existe
  if grep -q "feedback_chain_proof_gate.md" "$MEMORY_INDEX"; then
    sed -i '/feedback_chain_proof_gate\.md/a - [Weight Card](feedback_weight_card.md) — MANDATORY numerical anchor (W1 computed loss or W5 paid precedent) before submitting any finding ≥ Low with dollar impact. Complementary to Chain Proof Gate. Phemex R2 2026-04-10/13: chain was proven but weight was narrated ("I have not confirmed whether profitable extraction") → Informative. See WEIGHT-CARD.md + PREFLIGHT D8 + CLAUDE.md rule #37 + `arsenal/tools/precedent-scan.sh`.' "$MEMORY_INDEX"
  else
    echo "- [Weight Card](feedback_weight_card.md) — MANDATORY numerical anchor (W1 computed loss or W5 paid precedent) before submitting any finding ≥ Low with dollar impact. Complementary to Chain Proof Gate. Phemex R2 2026-04-10/13: chain was proven but weight was narrated → Informative. See WEIGHT-CARD.md + PREFLIGHT D8 + CLAUDE.md rule #37 + arsenal/tools/precedent-scan.sh." >> "$MEMORY_INDEX"
  fi
  echo "MEMORY.md updated"
else
  echo "MEMORY.md already has the entry"
fi
```

## 5. Smoke test complet du precedent-scan

```bash
# 1. Smoke test on IDOR class
~/arsenal/tools/precedent-scan.sh "IDOR" | grep -q "W5 — copy-paste" && echo "precedent-scan IDOR: OK"

# 2. Verify emitted block matches REPORT-STANDARD table format
~/arsenal/tools/precedent-scan.sh "SSRF" | grep -q "| Report | Class | Payout | Source |" && echo "precedent-scan format: OK"

# 3. Verify handling of 0-match classes
~/arsenal/tools/precedent-scan.sh "nonexistent-vuln-xyz" 2>&1 | grep -q "no paid precedents found" && echo "precedent-scan empty handling: OK"

# 4. Narrative-weight grep smoke test
cat > /tmp/fake-phemex-r2.md <<'EOF'
## Summary
The trading API key could drain users funds via margin manipulation.
An attacker could extract significant funds. Potentially affects large number of
users. I have not confirmed whether this enables profitable extraction.
All users of the trading bot ecosystem are at risk.
EOF

grep -cE "could drain|could extract|significant funds|potentially affects|large number of users|all users|at risk|could lead to|not confirmed whether|I have not confirmed|exposes users|many users" /tmp/fake-phemex-r2.md
# Expected: ≥4 matches
```

## 6. Retroactive tests — validate gate on known cases

### Test 1: Phemex R2 (should FAIL D8)

Simulate applying Weight Card to Phemex R2:
- W1: "I have not confirmed whether this enables profitable extraction" → non-quantifiable escape hatch
- W5: run `~/arsenal/tools/precedent-scan.sh "API key privilege escalation"` or `"trading key authorization bypass"` → likely 0 paid precedents
- Expected D8 verdict: **FAIL** (both W1 and W5 qualitative/empty)
- Correct outcome: downgrade to Informational before submission

### Test 2: WEEX-002 (should PASS D8)

Simulate applying Weight Card to WEEX-002:
- W1: 6.2M users × support conversation history (KYC docs, withdrawals, 2FA) — qualitative conservative scenario
- W5: run `~/arsenal/tools/precedent-scan.sh "JWT"` or `"hardcoded signing key"` or `"signature forgery"` — should find paid precedents for JWT/secret exposure class
- Expected D8 verdict: **PASS** (W5 has ≥1 paid precedent with dollar figure)
- Correct outcome: gate authorizes the finding it should authorize (Critical submission)

## 7. Validation finale

Les 7 couches sont en place sur machine 1 quand :

- [ ] `~/arsenal/checklists/WEIGHT-CARD.md` existe et contient "Stage 4: Submission Authorization"
- [ ] `~/arsenal/checklists/PREFLIGHT-CHECK.md` contient `| D8 |` et la mention "gating"
- [ ] `~/arsenal/methodology/REPORT-STANDARD.md` contient `### Weight Accounting`
- [ ] `~/arsenal/CLAUDE.md` contient `37. **MANDATORY — Weight Card`
- [ ] `~/arsenal/tools/precedent-scan.sh` est exécutable et émet le W5 block copy-paste-ready
- [ ] `~/arsenal/skills/gravedigger/SKILL.md` contient la section Weight Card dans Phase 6
- [ ] `~/arsenal/skills/mrrobbot/SKILL.md` contient la section Weight Card dans Phase 4
- [ ] `~/Desktop/BUGS/WEIGHT-CARD.md` est un mirror de `~/arsenal/checklists/WEIGHT-CARD.md`
- [ ] `~/Desktop/BUGS/PREFLIGHT-CHECK.md` est un mirror de `~/arsenal/checklists/PREFLIGHT-CHECK.md`
- [ ] `~/Desktop/BUGS/REPORT-STANDARD.md` est un mirror de `~/arsenal/methodology/REPORT-STANDARD.md`
- [ ] `~/Desktop/BUGS/CLAUDE.md` est un mirror de `~/arsenal/CLAUDE.md`
- [ ] `~/.claude/skills/gravedigger/SKILL.md` est sync avec arsenal
- [ ] `~/.claude/skills/mrrobbot/SKILL.md` est sync avec arsenal
- [ ] `~/.claude/projects/-home-malix-Desktop-BUGS/memory/feedback_weight_card.md` existe
- [ ] `~/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md` contient une ligne pointant vers `feedback_weight_card.md`
- [ ] Le smoke test narrative-weight grep retourne ≥4 matches sur le fake Phemex R2 draft
- [ ] `precedent-scan.sh "IDOR"` émet un W5 block avec au moins 1 row

## Ce que la gate fait en pratique

Quand machine 1 tombe sur un finding claiming severity ≥ Low avec dollar impact :

1. **Pendant la rédaction** : la memory `feedback_weight_card.md` fournit les narrative-weight trigger phrases à éviter. Si Claude écrit "could drain" sans un nombre spécifique dans la même section, il doit s'arrêter et populer W1 ou W5.
2. **Avant report writing** : Claude lance le grep narrative-weight contre le draft OR populate W1 (computed loss) OR run `precedent-scan.sh` to populate W5.
3. **Pendant preflight** : D8 est un critère gating dans PREFLIGHT-CHECK.md. D8 fail = submission bloquée at claimed severity, regardless of total score.
4. **Dans le template REPORT-STANDARD.md** : la section "Weight Accounting" est obligatoire (template incomplet sans elle).
5. **Au démarrage de chaque session** : CLAUDE.md rule #37 rappelle la procédure.
6. **Dans les skills gravedigger et mrrobbot** : Phase 6 (gravedigger) et Phase 4 (mrrobbot) contiennent directement la procédure Weight Card inline, évitant le jump vers CLAUDE.md.
7. **Le tool precedent-scan.sh** émet un W5 block copy-paste-ready qui matche le REPORT-STANDARD template exactement — pas de friction de reformattage.

**Meta-rule** : Stage 4 du WEIGHT-CARD.md exige que le contenu littéral des slots soit collé dans le record, pas décrit de mémoire. Empêche l'hallucination "j'ai computed W1" sans avoir un vrai nombre.

## Les classes de finding où la gate s'applique

- Critical / High / Medium / Low claims avec dollar impact
- Fund theft (direct ou indirect)
- Permissionless profit extraction
- Information disclosure CLAIMED at ≥ Low (si claim à Informational, skip)
- DoS avec impact claim (utiliser W1 alternate form downtime × req/s × users)
- Bridge manipulation
- Oracle manipulation
- Access control bypass avec impact
- Governance attack
- Rate limit bypass avec impact monétaire

## Les classes où la gate ne s'applique PAS

- Pure information disclosure claimed at Informational/Low (severity floor déjà reflète absent weight)
- Smart contract findings avec forge-test PoCs assertant state deltas sur mainnet fork (state delta = W1 implicit)
- Findings où la réponse HTTP est la mesure directe (ex: /api/users retournant N users — le count est l'anchor)
- Theoretical / educational findings explicitement claimed at Informational

## Référence

- Session d'origine : 2026-04-13 (suite de Chain Proof Gate commit 24cd46d)
- Finding de référence négatif : Phemex R2 (Informative après chain proven, weight narrated)
- Finding de référence positif : WEEX-002 (Critical, chain proven + weight anchored via W5 if applied retroactively)
- Design tension résolue par user critique : Gate vs Dashboard (single hard gate on W1 OR W5), W6 fusion into PoC, W4 distinct from D7, DoS alternative anchor, copy-paste-ready W5 output
- Feedback connexe : `feedback_chain_proof_gate.md` (D7 pour "does exploit execute"), `feedback_auth_bypass_needs_impact.md` (pre-gate reactive rule)
