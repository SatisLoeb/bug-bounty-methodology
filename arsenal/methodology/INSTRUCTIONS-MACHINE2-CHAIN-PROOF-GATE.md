# Instructions Machine 2 — Chain Proof Gate Encoding

## Contexte

Session du 2026-04-13. Une question du hunter ("on a pas confirmé que le jwt est accepté") a sauvé le finding WEEX-002 d'une submission en Medium/Informative et l'a transformé en Critical après un test d'acceptance éthique contre Zendesk qui a retourné HTTP 200 + `authenticated:true` + création de compte permanent.

Le même jour, Phemex R2 avait été marqué Informative pour exactement la même raison — un `feedback_auth_bypass_needs_impact.md` existait déjà en mémoire mais n'avait pas fire parce que les mémoires sont lues passivement "quand pertinent" et la pertinence n'est pas mécanique.

Conclusion : il fallait encoder la leçon en **5 couches structurales** pour qu'elle refire mécaniquement sur toutes les futures findings auth-class. Les 5 couches sont déjà en place sur machine 1. Ce fichier décrit comment machine 2 les récupère et les applique.

## Les 5 couches à synchroniser

| # | Fichier | Rôle | Localisation arsenal |
|---|---|---|---|
| 1 | `CHAIN-PROOF-GATE.md` | Template gate complet (Stage 1 hedge scan → Stage 2 ethical variant → Stage 3 sanity → Stage 4 authorization) | `arsenal/checklists/CHAIN-PROOF-GATE.md` (nouveau) |
| 2 | `PREFLIGHT-CHECK.md` | Criterion D7 ajouté, gating | `arsenal/checklists/PREFLIGHT-CHECK.md` (modifié) |
| 3 | `REPORT-STANDARD.md` | Section "Chain Acceptance Verification" ajoutée après Proof of Concept | `arsenal/methodology/REPORT-STANDARD.md` (modifié) |
| 4 | `CLAUDE.md` | Rule #36 ajoutée à la fin de la liste des rules | `arsenal/CLAUDE.md` (modifié) |
| 5 | `feedback_chain_proof_gate.md` | Feedback memory avec trigger phrases pour auto-détection | **Pas dans le repo** — créer manuellement sur machine 2 (§5) |

## 1. Pull arsenal repo

Sur machine 2 :

```bash
cd ~/arsenal
git pull origin main
```

Les 4 fichiers versionnés (couches 1-4) seront synchronisés. Vérification rapide :

```bash
test -f ~/arsenal/checklists/CHAIN-PROOF-GATE.md && echo "CHAIN-PROOF-GATE: OK"
grep -q "^| D7 |" ~/arsenal/checklists/PREFLIGHT-CHECK.md && echo "PREFLIGHT D7: OK"
grep -q "Chain Acceptance Verification" ~/arsenal/methodology/REPORT-STANDARD.md && echo "REPORT-STANDARD section: OK"
grep -q "^36\. \*\*MANDATORY" ~/arsenal/CLAUDE.md && echo "CLAUDE.md rule #36: OK"
```

Les 4 lignes "OK" doivent apparaître.

## 2. Mirror vers working directory `~/Desktop/BUGS`

Sur machine 1, les fichiers canoniques sont dans `~/Desktop/BUGS/` (working directory), et les copies arsenal sont des mirrors. Machine 2 doit faire pareil :

```bash
cp ~/arsenal/checklists/CHAIN-PROOF-GATE.md ~/Desktop/BUGS/CHAIN-PROOF-GATE.md
cp ~/arsenal/checklists/PREFLIGHT-CHECK.md ~/Desktop/BUGS/PREFLIGHT-CHECK.md
cp ~/arsenal/methodology/REPORT-STANDARD.md ~/Desktop/BUGS/REPORT-STANDARD.md
cp ~/arsenal/CLAUDE.md ~/Desktop/BUGS/CLAUDE.md
```

Si machine 2 a sa propre version modifiée localement, faire un diff d'abord :

```bash
for f in CHAIN-PROOF-GATE.md PREFLIGHT-CHECK.md REPORT-STANDARD.md CLAUDE.md; do
  src_bugs="$HOME/Desktop/BUGS/$f"
  src_arsenal_methodology="$HOME/arsenal/methodology/$f"
  src_arsenal_checklists="$HOME/arsenal/checklists/$f"
  src_arsenal_root="$HOME/arsenal/$f"
  for arsenal in "$src_arsenal_checklists" "$src_arsenal_methodology" "$src_arsenal_root"; do
    if [ -f "$arsenal" ] && [ -f "$src_bugs" ]; then
      diff -q "$src_bugs" "$arsenal" 2>/dev/null
    fi
  done
done
```

Résoudre les divergences (garder toujours la version `arsenal/` comme source de vérité pour les fichiers de méthodologie).

## 3. Vérifier que CLAUDE.md contient bien rule #36

Sur machine 2, après le pull :

```bash
grep -A 3 "^36\. \*\*MANDATORY" ~/Desktop/BUGS/CLAUDE.md
```

Doit afficher le début de la rule #36. Si absent, c'est que le pull n'a pas été appliqué correctement au fichier `~/Desktop/BUGS/CLAUDE.md` — revoir l'étape 2.

## 4. Test du grep Stage 1

Test de fumée : vérifier que le grep fonctionne comme prévu sur un faux draft.

```bash
cat > /tmp/fake-auth-draft.md <<'EOF'
## Summary
The JWT signing key is exposed in the bundle. I have confirmed the key is present
and the signing function is reachable. I deliberately did not present the forged
JWT to the backend because doing so would access a real user.
EOF

grep -nE "I did not test|I deliberately did not|inferred from|would access|would authenticate|would receive|deliberately not executed|not executed because|strongly indicates|architectural analysis suggests|documented .* protocol, not from testing|not confirmed whether|I stopped at|I did not attempt|the final link .* is inferred|not tested against|could not verify|assumed to be accepted" /tmp/fake-auth-draft.md
```

Doit retourner au moins 2 matches (`I deliberately did not`, `would access`). Si ça retourne 0 match, le grep ne fonctionne pas — problème de shell escape.

## 5. Créer la feedback memory (couche 5)

Le fichier feedback n'est pas dans le repo Arsenal parce qu'il vit dans `~/.claude/projects/` (specific au harnais Claude Code de chaque machine). Il faut le créer manuellement sur machine 2.

```bash
MEMORY_DIR="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory"
mkdir -p "$MEMORY_DIR"

cat > "$MEMORY_DIR/feedback_chain_proof_gate.md" <<'MEMORY_EOF'
---
name: Chain Proof Gate — Mandatory Before Auth-Class Submission
description: Every auth/credential/signature/JWT/session/IDOR-write/password-reset finding MUST have HTTP-level chain proof via ethical variant before submission. Grep the draft for hedge phrases — any match = chain incomplete.
type: feedback
---

**Rule:** Before submitting any finding in the class auth-bypass / hardcoded-credential / signature-forge / JWT-token / session-hijack / IDOR-write / password-reset / account-binding, run the hedge phrase grep on the draft. Any match = chain incomplete, not submission-ready.

**Hedge phrase grep (mechanical trigger):**
```bash
grep -nE "I did not test|I deliberately did not|inferred from|would access|would authenticate|would receive|deliberately not executed|not executed because|strongly indicates|architectural analysis suggests|documented .* protocol, not from testing|not confirmed whether|I stopped at|I did not attempt|the final link .* is inferred|not tested against|could not verify|assumed to be accepted" "$DRAFT_PATH"
```

**If ≥1 match:**
- Option A: Find an ethical variant of the test and complete the chain. Catalog:
  - JWT/token forge → forge with fictitious external_id (Zendesk Messenger lesson — creates permanent appUser without touching real user)
  - Password reset → reset our own account's password
  - IDOR write/delete → use two accounts we control (A exploits B, both ours)
  - Session hijack → both sessions in our control
  - Hardcoded credential → hit metadata/enumeration endpoint (/me, /users?limit=1, pagination total only)
  - File read/path traversal → upload a marker file we created, exploit traversal to read it back
  - IDOR read on private data → query our own ID, prove enumeration works without reading anyone else's
- Option B: Downgrade severity to reflect missing impact, remove all hedge phrases claiming higher impact. An acknowledged Medium beats a dismissed High.

**Why:** The memory feedback_auth_bypass_needs_impact.md existed before 2026-04-13 and did not fire because memories are read passively "when relevant" — and the brain's relevance check fails when the architectural analysis feels strong enough to stand alone. On 2026-04-13, two findings the same day proved the pattern:

- Phemex R2 (POST /assets/transfer via trading key): submitted with "I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital." Marked Informative, 2 rep, $0.
- WEEX-002 (Zendesk HS256 signing key in JS bundle): draft contained "I deliberately did not present the forged JWT to Zendesk Messenger — doing so would authenticate as a real WEEX user and access their support conversation history." The hunter asked "on a pas confirmé que le jwt est accepté" seven seconds before submission. Ethical acceptance test with fictitious external_id test-research-2026-04-13-malik returned HTTP 200 + authenticated:true + permanent appUser _id: 69dcb782cf5d0f6880946178 + full realtime Faye baseUrl grant. Severity jumped Medium/Informative → Critical. Bounty range $2,500-$10,000.

Identical pattern, one hour apart, one caught and one missed. The difference was a mechanical check running against the draft before submission.

**How to apply:**
- Run the grep on every auth-class submission draft, not conditionally. "This architectural analysis is so strong it doesn't need acceptance proof" is exactly the reasoning that fails.
- The ethical variant almost always exists. For JWT/token in particular: almost every auth system creates a new user record if the subject is unknown, so forging with a fictitious subject produces a clean, reproducible acceptance proof without touching anyone real.
- If no ethical variant exists for the specific class: downgrade severity and remove the hedge. Never submit an auth finding with an unproven acceptance step at High or Critical — the triager will always find the gap and mark Informational.
- Reference files: CHAIN-PROOF-GATE.md (full procedure), PREFLIGHT-CHECK.md criterion D7 (gating in preflight), REPORT-STANDARD.md Chain Acceptance Verification section (mandatory template slot), CLAUDE.md rule #36 (top-level rule).
- This rule does NOT apply to smart-contract findings with forge-test PoCs. Those already prove the chain via state delta assertion on mainnet fork. It applies to web/API findings where a "server accepts the forged thing" step exists.

**Trigger keywords to self-detect during drafting:** if I catch myself writing any of the hedge phrases during rapport rédaction, stop immediately. The phrase is honest but it is also a signal that I'm about to ship an incomplete chain. Find the ethical variant before continuing to write the rest of the report.
MEMORY_EOF

echo "Memory file created at: $MEMORY_DIR/feedback_chain_proof_gate.md"
```

## 6. Update MEMORY.md index sur machine 2

Le fichier `MEMORY.md` est aussi spécifique au harnais local. Ajouter l'entrée :

```bash
MEMORY_INDEX="$HOME/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md"

# Vérifier si l'entrée existe déjà
if ! grep -q "feedback_chain_proof_gate.md" "$MEMORY_INDEX"; then
  # Ajouter après la ligne feedback_agent_generated_findings_validation.md si elle existe,
  # sinon à la fin de la section "Feedback & Lessons"
  if grep -q "feedback_agent_generated_findings_validation.md" "$MEMORY_INDEX"; then
    # Insérer juste après la ligne de l'agent-generated findings feedback
    sed -i '/feedback_agent_generated_findings_validation\.md/a - [Chain Proof Gate](feedback_chain_proof_gate.md) — MANDATORY grep scan for hedge phrases before submitting any auth/credential/signature/JWT/session finding. Ethical variants exist for almost every class. WEEX-002 2026-04-13: draft bound for Medium/Informative → Critical after one user question caught the missing Zendesk acceptance test. See CHAIN-PROOF-GATE.md + PREFLIGHT D7 + CLAUDE.md rule #36.' "$MEMORY_INDEX"
  else
    echo "- [Chain Proof Gate](feedback_chain_proof_gate.md) — MANDATORY grep scan for hedge phrases before submitting any auth/credential/signature/JWT/session finding. Ethical variants exist for almost every class. WEEX-002 2026-04-13: draft bound for Medium/Informative → Critical after one user question caught the missing Zendesk acceptance test. See CHAIN-PROOF-GATE.md + PREFLIGHT D7 + CLAUDE.md rule #36." >> "$MEMORY_INDEX"
  fi
  echo "MEMORY.md updated"
else
  echo "MEMORY.md already has the entry"
fi
```

## 7. Smoke test complet

Avant de considérer machine 2 comme synchronisée, faire un test de bout en bout avec un faux draft :

```bash
# 1. Créer un draft auth-class avec un hedge
cat > /tmp/fake-weex002.md <<'EOF'
## Summary
The production bundle at example.com embeds the HS256 signing key...
I have confirmed the key is present in the bundle and the signing code uses it.
I deliberately did not present the forged JWT to the backend because doing so
would access a real user.

## Vulnerability Details
The forged JWT is structurally valid but the final link (Zendesk acceptance) is
inferred from the documented authentication protocol, not from testing.
EOF

# 2. Run the Stage 1 grep
grep -nE "I did not test|I deliberately did not|inferred from|would access|would authenticate|would receive|deliberately not executed|not executed because|strongly indicates|architectural analysis suggests|documented .* protocol, not from testing|not confirmed whether|I stopped at|I did not attempt|the final link .* is inferred|not tested against|could not verify|assumed to be accepted" /tmp/fake-weex002.md

# Expected output: 3 lines matching (I deliberately did not, would access, inferred from, the final link ... is inferred, documented protocol not from testing)
# If 0 matches → grep is broken, investigate
# If ≥3 matches → Stage 1 works correctly
```

## 8. Validation finale

Les 5 couches sont en place sur machine 2 quand :

- [ ] `~/arsenal/checklists/CHAIN-PROOF-GATE.md` existe et contient "Stage 4: Submission Authorization"
- [ ] `~/arsenal/checklists/PREFLIGHT-CHECK.md` contient `| D7 |` et la mention "gating"
- [ ] `~/arsenal/methodology/REPORT-STANDARD.md` contient `### Chain Acceptance Verification`
- [ ] `~/arsenal/CLAUDE.md` contient `36. **MANDATORY — Chain Proof Gate`
- [ ] `~/Desktop/BUGS/CHAIN-PROOF-GATE.md` est un mirror de `~/arsenal/checklists/CHAIN-PROOF-GATE.md`
- [ ] `~/Desktop/BUGS/PREFLIGHT-CHECK.md` est un mirror de `~/arsenal/checklists/PREFLIGHT-CHECK.md`
- [ ] `~/Desktop/BUGS/REPORT-STANDARD.md` est un mirror de `~/arsenal/methodology/REPORT-STANDARD.md`
- [ ] `~/Desktop/BUGS/CLAUDE.md` est un mirror de `~/arsenal/CLAUDE.md`
- [ ] `~/.claude/projects/-home-malix-Desktop-BUGS/memory/feedback_chain_proof_gate.md` existe
- [ ] `~/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md` contient une ligne pointant vers `feedback_chain_proof_gate.md`
- [ ] Le smoke test grep retourne ≥3 matches sur le fake draft

## Ce que la gate fait en pratique

Quand machine 2 tombe sur un finding auth-class (JWT forge, hardcoded credential, session hijack, IDOR write, password reset, signature forge) :

1. **Pendant la rédaction** : la memory `feedback_chain_proof_gate.md` fournit les trigger phrases à éviter. Si Claude écrit un hedge, il doit s'arrêter et chercher l'ethical variant.
2. **Avant preflight** : Claude lance le `grep -nE` de CHAIN-PROOF-GATE.md Stage 1 contre le draft. Si ≥1 match, Stage 2 obligatoire (ethical variant ou downgrade).
3. **Pendant preflight** : D7 est un critère gating dans PREFLIGHT-CHECK.md. D7 fail = submission bloquée regardless of total score.
4. **Dans le template REPORT-STANDARD.md** : la section "Chain Acceptance Verification" est obligatoire. Un rapport sans cette section sur un finding auth-class = rapport incomplet.
5. **Au démarrage de chaque session** : CLAUDE.md rule #36 rappelle la procédure.

La meta-rule : **Stage 4 exige que l'output littéral du grep soit collé dans le record, pas décrit de mémoire.** Ça empêche l'hallucination "j'ai grep'é, 0 matches" qui serait le dernier trou dans le filet.

## Les classes de finding où la gate s'applique

- Auth bypass (login, session, MFA skip)
- Hardcoded credentials (API keys, signing keys, service tokens)
- Signature forgery (JWT HS256, HMAC, custom signatures)
- JWT token issues (kid confusion, alg none, key confusion)
- Session hijacking (CSRF, session fixation, cookie theft)
- IDOR write/delete (state-changing endpoints)
- Password reset / account recovery flows
- Account binding / email change / SSO link

## Les classes où la gate ne s'applique PAS

- Smart contract findings avec forge test PoCs (state delta = chain proof déjà)
- On-chain state reads prouvant une bug condition live
- Pure information disclosure avec severity Low/Informational assumée
- Findings où la réponse HTTP **est** l'impact (ex: `/api/users` retournant 247 users — pas besoin d'un test "does the server accept this query", la query est la preuve)

## Référence

- Session d'origine : 2026-04-13
- Finding de référence : WEEX-002 (Zendesk HS256 forge → HTTP 200 authenticated:true après test avec fictitious external_id)
- Finding négatif de référence : Phemex R2 (Informative faute de proof d'extraction)
- Hunter's reflex question qui a déclenché l'encodage : "on a pas confirmé que le jwt est accepté"
- Feedback connexe : `feedback_auth_bypass_needs_impact.md` (existait avant, ne fired pas — c'est pourquoi encoding mécanique obligatoire)
