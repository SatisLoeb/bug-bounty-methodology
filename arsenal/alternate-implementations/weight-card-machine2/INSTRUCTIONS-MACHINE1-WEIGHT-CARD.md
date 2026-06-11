# Instructions Machine 1 — Weight Card Encoding

## Contexte

Session du 2026-04-13 (machine 2). Après la mise en place du Chain Proof Gate (commit `24cd46d`), une seconde failure mode a été identifiée : **Phemex R2** (soumis 2026-04-10, marqué Informative 2026-04-13 par HackenProof) avait une chaîne technique prouvée mais un **impact narré au lieu d'être calculé**. Le draft disait *"I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital"* — le chain proof gate aurait passé, mais le poids n'était pas ancré numériquement.

Le Chain Proof Gate répond à *"does the exploit execute?"*. Le Weight Card répond à *"is the exploit profitable, for whom, irreversibly, and market-priced at what?"*. Les deux gates sont complémentaires et orthogonaux — une finding doit passer les deux.

**Direction de synchronisation inversée** par rapport au commit `24cd46d` : cette fois machine 2 est l'auteur, machine 1 est le consommateur.

## Les 5 couches à synchroniser

| # | Fichier | Rôle | Localisation arsenal |
|---|---|---|---|
| 1 | `WEIGHT-CARD.md` | Template gate complet (Stage 1 slot completion → Stage 2 hard gate → Stage 3 dashboard → Stage 4 authorization) | `arsenal/checklists/WEIGHT-CARD.md` (nouveau) |
| 2 | `PREFLIGHT-CHECK.md` | Criterion D8 ajouté, gating | `arsenal/checklists/PREFLIGHT-CHECK.md` (modifié) |
| 3 | `REPORT-STANDARD.md` | Section "Weight Accounting" ajoutée après "Chain Acceptance Verification" | `arsenal/methodology/REPORT-STANDARD.md` (modifié) |
| 4 | `CLAUDE.md` | Rule #37 ajoutée après rule #36 | `arsenal/CLAUDE.md` (modifié) |
| 5 | `feedback_weight_card.md` | Feedback memory avec trigger phrases pour auto-détection | **Pas dans le repo** — créer manuellement sur machine 1 (§5) |

**Bonus layer :** nouveau fichier `arsenal/tools/precedent-scan.sh` — shell script (grep + jq) qui émet un bloc W5 copy-paste-ready formaté directement pour REPORT-STANDARD.md. Critique pour éviter la friction de reformatage manuel qui fait que le slot se fait skip sous deadline.

**Skills layer :** `arsenal/skills/gravedigger/SKILL.md` et `arsenal/skills/mrrobbot/SKILL.md` ont reçu une ligne MANDATORY Weight Card à côté de la ligne MANDATORY Chain Proof Gate déjà présente. Sur machine 2 ces fichiers sont hardlinkés avec `~/.claude/skills/`, donc l'édition propage automatiquement. Sur machine 1 si la structure est similaire, un `git pull` suffit.

## 1. Pull arsenal repo

Sur machine 1 :

```bash
cd ~/arsenal
git pull origin main
```

Vérification rapide des 5 fichiers versionnés :

```bash
test -f ~/arsenal/checklists/WEIGHT-CARD.md && echo "WEIGHT-CARD: OK"
grep -q "^| D8 |" ~/arsenal/checklists/PREFLIGHT-CHECK.md && echo "PREFLIGHT D8: OK"
grep -q "### Weight Accounting" ~/arsenal/methodology/REPORT-STANDARD.md && echo "REPORT-STANDARD section: OK"
grep -q "^37\. \*\*MANDATORY — Weight Card" ~/arsenal/CLAUDE.md && echo "CLAUDE.md rule #37: OK"
test -x ~/arsenal/tools/precedent-scan.sh && echo "precedent-scan.sh: OK"
grep -q "Weight Card" ~/arsenal/skills/gravedigger/SKILL.md && echo "gravedigger skill: OK"
grep -q "Weight Card" ~/arsenal/skills/mrrobbot/SKILL.md && echo "mrrobbot skill: OK"
```

Les 7 lignes "OK" doivent apparaître.

## 2. Mirror vers working directory `~/Desktop/BUGS`

Sur machine 2, `CLAUDE.md` est hardlinké entre `~/arsenal/CLAUDE.md` et `~/Desktop/BUGS/CLAUDE.md`, donc une seule édition propage. Si machine 1 n'a pas ce hardlink, faire le cp manuellement.

```bash
cp ~/arsenal/checklists/WEIGHT-CARD.md ~/Desktop/BUGS/WEIGHT-CARD.md
cp ~/arsenal/checklists/PREFLIGHT-CHECK.md ~/Desktop/BUGS/PREFLIGHT-CHECK.md
cp ~/arsenal/methodology/REPORT-STANDARD.md ~/Desktop/BUGS/REPORT-STANDARD.md
# CLAUDE.md — skip si hardlink déjà en place
ls -li ~/arsenal/CLAUDE.md ~/Desktop/BUGS/CLAUDE.md 2>/dev/null | awk '{print $1}' | sort -u | wc -l
# Si la sortie est "1" → hardlink, pas de cp. Si "2" → deux fichiers distincts, faire le cp:
# cp ~/arsenal/CLAUDE.md ~/Desktop/BUGS/CLAUDE.md
```

Si machine 1 a sa propre version locale modifiée, faire un diff d'abord et garder `arsenal/` comme source de vérité.

## 3. Vérifier que CLAUDE.md contient bien rule #37

```bash
grep -A 3 "^37\. \*\*MANDATORY — Weight Card" ~/Desktop/BUGS/CLAUDE.md
```

Doit afficher le début de la rule #37. Si absent, revoir l'étape 2.

## 4. Test précédent scanner

Smoke test sur trois classes connues :

```bash
~/arsenal/tools/precedent-scan.sh "IDOR"         | grep -q "\$"
~/arsenal/tools/precedent-scan.sh "SSRF"         | grep -q "\$"
~/arsenal/tools/precedent-scan.sh "auth bypass"  | grep -q "\$"
~/arsenal/tools/precedent-scan.sh "IDOR"         | grep -q "W5 — Precedent"
~/arsenal/tools/precedent-scan.sh "IDOR"         | grep -q "| Report |"
```

Les 5 commandes doivent retourner 0 (match trouvé). Si l'une échoue, le grep ou le corpus H1-HUNTING-PATTERNS.md sur machine 1 peut être désynchronisé.

## 5. Créer la feedback memory (couche 5)

Le fichier feedback n'est pas dans le repo Arsenal parce qu'il vit dans `~/.claude/projects/` (spécifique au harnais Claude Code de chaque machine). À créer manuellement sur machine 1.

```bash
MEMORY_DIR="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory"
mkdir -p "$MEMORY_DIR"

cat > "$MEMORY_DIR/feedback_weight_card.md" <<'MEMORY_EOF'
---
name: Weight Card — Mandatory Before Non-Informational Submission
description: Every finding claiming severity ≥ Low MUST contain at least one numerical anchor — computed dollar loss (W1) or paid precedent with dollar figure (W5). Dashboard slots W2/W3/W4 surface argumentation weakness but don't block. Complementary to Chain Proof Gate — Chain Proof answers "does the exploit execute?", Weight Card answers "is it profitable, irreversibly, market-priced at what?".
type: feedback
---

**Rule:** Before submitting any finding claiming severity ≥ Low with a dollar impact, populate the Weight Card template in REPORT-STANDARD.md Weight Accounting section. The hard gate is at least one numerical anchor via W1 (computed dollar loss) OR W5 (paid precedent with dollar figure). Both slots cannot be qualitative. An unpaid "related H1 #xxx" does not satisfy W5.

**Anti-pattern phrase grep (mechanical trigger — case-insensitive):**
```bash
grep -niE "could drain|could extract|significant funds|substantial losses|large number of users|many users affected|potentially affects|widespread impact|catastrophic|devastating|severe financial damage|exposes users to|estimated to cost|impact is significant|attacker could (drain|extract|steal)" "$DRAFT_PATH"
```

**If ≥1 match AND no numerical anchor:**
- Option A: Compute W1 from real inputs. Inputs must be cited (on-chain reads with block numbers, API readbacks with response dates, documented protocol limits). Formula must be visible.
- Option B: Run `arsenal/tools/precedent-scan.sh "<class>"` to populate W5 with paid precedents. The script emits a copy-paste-ready table block formatted for REPORT-STANDARD Weight Accounting — no reformatting needed.
- Option C: **DoS exception** — if the finding is a DoS on a critical endpoint, use W1 form (b): `downtime × req/s × affected users`. Duration must be measured or extrapolated from a reproducible PoC, not asserted.
- Option D: Downgrade severity to Informational. Remove all phrases claiming higher impact. An acknowledged Low beats a dismissed High.

**Why:** Phemex R2 (submitted 2026-04-10, marked Informative 2026-04-13) had a proven chain (trading API key called /assets/transfer successfully) but the weight was narrated: *"I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital."* Informative, 2 rep, $0. One hour later WEEX-002 was saved by Chain Proof Gate via a user question, but Phemex R2 died on a different failure mode entirely — the chain was fine, the weight was absent.

Rule #15 existed before 2026-04-13 ("honest impact quantification") but fired reactively — it punished overselling after the fact. Weight Card encodes the computation requirement proactively, via a template that cannot be filled with adjectives.

The two failure modes are orthogonal:
- **Chain incomplete** (WEEX-002 pre-edit): chain proof absent → Chain Proof Gate catches it.
- **Weight uncomputed** (Phemex R2): chain proof present but no numerical anchor → Weight Card catches it.

Both gates are needed. Neither replaces the other.

**How to apply:**
- Fill W1 OR W5 with real numbers before the draft is considered submission-ready. The rest of the draft can be in any state; the numerical anchor must be concrete.
- If the finding is smart contract with a forge-test PoC that asserts state delta → W1 auto-passes (the asserted delta IS the computed loss). Still run precedent-scan.sh for W5 to market-price.
- If the finding is pure information disclosure already at Informational/Low → Weight Card is N/A.
- Dashboard slots W2/W3/W4 are visibility tools, not blockers. Fill them where possible because emptiness surfaces argumentation weakness pre-submission. The triager will challenge on W2/W3/W4 gaps even if W1/W5 are solid.
- The precedent-scan.sh output format is critical: it must emit a copy-paste-ready W5 table directly in REPORT-STANDARD syntax. If the output requires manual reformatting, the slot gets skipped under deadline pressure.

**The absurdity test:** replace any adjective in the draft with "$3.47". If the sentence becomes absurd ("$3.47 funds could drain"), the adjective is doing the work of the argument. Put a real number there or the claim is not defensible.

**Trigger keywords to self-detect during drafting:** if I catch myself writing any of the anti-pattern phrases (listed in the grep above) during the Impact section, stop immediately. The phrase is a signal that I'm narrating instead of computing. Either compute W1, populate W5 via precedent-scan, or downgrade severity before continuing to write the rest of the section.

**Reference files:**
- `~/Desktop/BUGS/WEIGHT-CARD.md` — full procedure, Stages 1-4
- `~/Desktop/BUGS/PREFLIGHT-CHECK.md` criterion D8 — gating in preflight
- `~/Desktop/BUGS/REPORT-STANDARD.md` Weight Accounting section — mandatory template slot
- `~/Desktop/BUGS/CLAUDE.md` rule #37 — top-level rule
- `~/arsenal/tools/precedent-scan.sh` — fast W5 population from H1-HUNTING-PATTERNS corpus

**Not applicable to:**
- Pure information disclosure findings already claimed at Informational/Low severity (the floor reflects absent weight).
- Smart contract findings with forge-test state delta assertions (the delta IS the anchor).
- Findings where the HTTP response IS the weight (e.g. /api/users returning 247 KYC records — count is impact).
MEMORY_EOF

echo "Memory file created at: $MEMORY_DIR/feedback_weight_card.md"
```

## 6. Update MEMORY.md index sur machine 1

Le fichier `MEMORY.md` est spécifique au harnais local. Ajouter l'entrée après la ligne Chain Proof Gate :

```bash
MEMORY_INDEX="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md"

if ! grep -q "feedback_weight_card.md" "$MEMORY_INDEX"; then
  if grep -q "feedback_chain_proof_gate.md" "$MEMORY_INDEX"; then
    sed -i '/feedback_chain_proof_gate\.md/a - [Weight Card](feedback_weight_card.md) — MANDATORY numerical anchor before non-Informational submission. W1 (computed $) OR W5 (paid precedent with $). Phemex R2 lesson: chain proven but weight narrated → Informative. WEIGHT-CARD.md + PREFLIGHT D8 + CLAUDE.md #37.' "$MEMORY_INDEX"
  else
    echo "- [Weight Card](feedback_weight_card.md) — MANDATORY numerical anchor before non-Informational submission. W1 (computed \$) OR W5 (paid precedent with \$). Phemex R2 lesson: chain proven but weight narrated → Informative. WEIGHT-CARD.md + PREFLIGHT D8 + CLAUDE.md #37." >> "$MEMORY_INDEX"
  fi
  echo "MEMORY.md updated"
else
  echo "MEMORY.md already has the entry"
fi
```

## 7. Smoke test complet anti-pattern phrases

Test de bout en bout avec un faux draft qui narre l'impact :

```bash
cat > /tmp/fake-phemex-r2.md <<'EOF'
## Summary
The trading API key could drain users funds via margin manipulation.
Attacker could extract significant funds. I have not confirmed whether
this enables profitable extraction. Widespread impact on large number
of users.
EOF

grep -cE "could drain|could extract|significant funds|substantial losses|large number of users|many users affected|potentially affects|widespread impact|catastrophic|devastating|severe financial damage|exposes users to|estimated to cost|impact is significant|attacker could (drain|extract|steal)|not confirmed whether|I have not confirmed" /tmp/fake-phemex-r2.md
```

Doit retourner ≥4. Si 0 → le grep est cassé.

## 8. Validation finale

Les couches sont en place sur machine 1 quand :

- [ ] `~/arsenal/checklists/WEIGHT-CARD.md` existe et contient "Stage 4: Submission Authorization"
- [ ] `~/arsenal/checklists/PREFLIGHT-CHECK.md` contient `| D8 |` et la mention "gating"
- [ ] `~/arsenal/methodology/REPORT-STANDARD.md` contient `### Weight Accounting`
- [ ] `~/arsenal/CLAUDE.md` contient `37. **MANDATORY — Weight Card`
- [ ] `~/arsenal/tools/precedent-scan.sh` existe, exécutable, passe les 3 smoke tests (IDOR / SSRF / auth bypass)
- [ ] `~/arsenal/skills/gravedigger/SKILL.md` contient "Weight Card"
- [ ] `~/arsenal/skills/mrrobbot/SKILL.md` contient "Weight Card"
- [ ] `~/Desktop/BUGS/WEIGHT-CARD.md` mirror de `~/arsenal/checklists/WEIGHT-CARD.md`
- [ ] `~/Desktop/BUGS/PREFLIGHT-CHECK.md` mirror de `~/arsenal/checklists/PREFLIGHT-CHECK.md`
- [ ] `~/Desktop/BUGS/REPORT-STANDARD.md` mirror de `~/arsenal/methodology/REPORT-STANDARD.md`
- [ ] `~/Desktop/BUGS/CLAUDE.md` mirror de `~/arsenal/CLAUDE.md`
- [ ] `~/.claude/projects/-home-malix-Desktop-BUGS/memory/feedback_weight_card.md` existe
- [ ] `~/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md` contient une ligne pointant vers `feedback_weight_card.md`
- [ ] Smoke test anti-pattern grep retourne ≥4 matches sur le fake draft

## Ce que la gate fait en pratique

Quand machine 1 tombe sur un finding non-Informational claiming severity ≥ Low :

1. **Pendant la rédaction** : `feedback_weight_card.md` fournit les trigger phrases à éviter. Si Claude écrit un adjectif du type "significant funds", il doit s'arrêter et soit compute W1, soit lancer precedent-scan.sh pour W5.
2. **Avant preflight** : Claude lance `~/arsenal/tools/precedent-scan.sh "<class>"` et colle le bloc W5 dans REPORT-STANDARD.md Weight Accounting section. Si le bloc retourne "W5 EMPTY", Claude doit soit strengthen W1, soit downgrade.
3. **Pendant preflight** : D8 est un critère gating dans PREFLIGHT-CHECK.md. D8 fail = submission bloquée at claimed severity.
4. **Dans le template REPORT-STANDARD.md** : la section "Weight Accounting" est obligatoire. Un rapport sans cette section sur un finding non-Informational = rapport incomplet.
5. **Au démarrage de chaque session** : CLAUDE.md rule #37 rappelle la procédure et l'absurdity test ("replace adjective with $3.47").

## Différences architecturales avec le Chain Proof Gate

| | Chain Proof Gate (#36) | Weight Card (#37) |
|---|---|---|
| **Failure mode** | Chain incomplete (exploit pas prouvé) | Weight uncomputed (impact narré) |
| **Scope** | Auth/credential/signature classes only | Toute finding ≥ Low avec $ claim |
| **Gate type** | Hard gate binaire (accept/reject) | Dashboard + 1 hard gate (W1 OR W5 numérique) |
| **Nombre de slots** | 1 (chain proven) | 5 (W1 loss, W2 stakeholder, W3 reversibility, W4 live, W5 precedent) |
| **Exception classes** | Smart contracts, pure info disclosure, response-is-impact | Pure info Low/Informational, SC state delta auto-pass, DoS alternate anchor |
| **Trigger mechanism** | Hedge phrase grep on draft | Anti-pattern adjective grep on draft + precedent-scan.sh tool |
| **Exemple de save** | WEEX-002 (Medium → Critical) | Phemex R2 (retroactif : Informative → avec ancrage W5 Medium defensible) |

## Référence

- Session d'origine : 2026-04-13 (machine 2)
- Commit référence (Chain Proof Gate, pre-requisite) : `24cd46d`
- Finding de référence : Phemex R2 (chain OK, weight absent → Informative)
- Finding symétrique : WEEX-002 (chain absent initialement → saved by Chain Proof Gate)
- Hunter's reflex question qui a déclenché l'encodage : *"ce qui manque pour que l'agent n'imagine pas seulement l'impact d'un finding mais qu'il comprenne vraiment le poids ?"*
- Feedback connexe : `feedback_chain_proof_gate.md` (complément symétrique sur le chain), `feedback_auth_bypass_needs_impact.md` (réactif, ne firing pas — c'est pourquoi encoding mécanique obligatoire)
