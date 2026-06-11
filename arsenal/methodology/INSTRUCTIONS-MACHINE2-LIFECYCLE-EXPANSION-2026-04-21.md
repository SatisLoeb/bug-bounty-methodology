# Instructions Machine 2 — Lifecycle Expansion 2026-04-21

## Contexte

Session du 2026-04-21. Après le $10K Medium validé sur Polymarket #197 + le Critical passé en analyst review chez Circle Malachite #3681944, session dédiée à outiller la prochaine vague de targets. 8 livrables d'infrastructure ajoutés au `audit-lifecycle/` + 1 méthodologie nouvelle + split MEMORY.md par domaine + logging des lessons apprises.

Déclencheur immédiat : la session McGraw Hill VDP où j'ai brûlé 60 minutes à drafter F-002 (ghost-branch supply chain) avant de réaliser que le finding était OOS per H1 Core Ineligible Findings (unexploitable-today = theoretical). CLAUDE.md rule #27 existait mais n'a pas fire. Diagnostic : les règles textuelles en contexte fonctionnent mal quand CLAUDE.md dépasse 40 règles. Solution : **mechanical gates that refuse execution**, pas des rules textuelles à retenir.

## Les 8 livrables

| # | Livrable | Fichiers ajoutés | Fichiers modifiés |
|---|---|---|---|
| A | Scope gate pre-draft | `templates/SCOPE-CHECK.md`, `templates/SCOPE-workspace.md`, `lib/scope-validator.sh` | `bin/on-finding.sh` (two-stage), `bin/init-target.sh` (+SCOPE.md), `bin/preflight-mechanical.sh` (+D0-scope) |
| #1 | Kill-gate feedback loop | `lib/inject-kill-lessons.sh`, `bin/on-kill.sh`, `~/Desktop/BUGS/KILLED-FINDINGS-LESSONS.yaml` (8 règles initiales) | `bin/on-finding.sh` (auto-inject au stage 2) |
| #2 | Competition density | `bin/competition-density.sh`, `bin/competition-density.TODO.md` | — |
| #3 | State tracker | `bin/findings-state.sh` | — |
| #4 | Pattern lifting | `bin/pattern-lift.sh` (thin wrapper), `lib/pattern-lift.py` (parse + scan) | — |
| #5 | Surface layering | `methodology/SURFACE-LAYERING.md` | — |
| #6 | Schema OUTCOMES étendu | — | `templates/OUTCOMES-schema.json` (+4 champs : hours_invested, surface, platform, bounty_program), `bin/on-submit.sh` (prompts interactifs) |
| B | Scope parser URL | `bin/scope-parser.sh`, `lib/scope-parser.py` | `bin/init-target.sh` (`--scope-url` flag) |

Livrable **C** (split MEMORY.md par domaine) concerne `~/.claude/projects/-home-malix-Desktop-BUGS/memory/` — non versionné dans `~/arsenal`. Machine 2 doit faire manuellement (§ "MEMORY split" ci-dessous).

## Pull arsenal repo

```bash
cd ~/arsenal
git pull origin main
```

Vérification post-pull :

```bash
# Bin scripts (11 total)
for f in init-target on-finding on-submit on-hold on-kill preflight-mechanical findings-state competition-density scope-parser pattern-lift; do
  test -x ~/arsenal/audit-lifecycle/bin/${f}.sh && echo "bin/${f}.sh OK" || echo "bin/${f}.sh MISSING"
done

# Lib scripts (7 total)
for f in artifact-validator marker target-router scope-validator inject-kill-lessons; do
  test -x ~/arsenal/audit-lifecycle/lib/${f}.sh && echo "lib/${f}.sh OK" || echo "lib/${f}.sh MISSING"
done
for f in pattern-lift scope-parser; do
  test -x ~/arsenal/audit-lifecycle/lib/${f}.py && echo "lib/${f}.py OK" || echo "lib/${f}.py MISSING"
done

# Templates (5 total)
for f in OUTCOMES-schema.json PROGRESS.md SEVERITY-COMMIT.md SCOPE-CHECK.md SCOPE-workspace.md; do
  test -f ~/arsenal/audit-lifecycle/templates/${f} && echo "templates/${f} OK" || echo "templates/${f} MISSING"
done

# Methodology
test -f ~/arsenal/methodology/SURFACE-LAYERING.md && echo "methodology/SURFACE-LAYERING.md OK"
```

## Livrable A — Scope gate (le plus important)

**Ce que ça fait :** `on-finding.sh --stage 1` crée UNIQUEMENT `{id}-scope-check.md`. Le draft file, kill-gate, severity-commit, chain-proof, weight-card ne sont créés qu'au `--stage 2`, et le stage 2 refuse de s'exécuter tant que le scope-validator n'a pas retourné PASS avec signature `SCOPE_CHECK_SIGNED_PROCEED`.

**Nouveau flow utilisateur :**

```bash
# 1. Workspace avec scope auto-parse (si URL fournie)
TARGET_HINTS="web api" ~/arsenal/audit-lifecycle/bin/init-target.sh mytarget \
  --scope-url "https://hackerone.com/mytarget"

# 2. Fill SCOPE.md (auto-parsed + annotate manuellement si SPA)

# 3. Per finding — stage 1 SEULEMENT
~/arsenal/audit-lifecycle/bin/on-finding.sh MYTARGET-F001 --stage 1

# 4. Fill findings/MYTARGET-F001-scope-check.md :
#    - Step 1 scope (from SCOPE.md)
#    - Step 2 OOS (from SCOPE.md)
#    - Step 3 grid : pour chaque OOS token, cocher MATCH ou NOMATCH
#    - Step 4 asset match
#    - Step 5 verdict + signature exacte "[x] SCOPE_CHECK_SIGNED_PROCEED"

# 5. Validator (retourne exit 0 si PROCEED, 1 si BLOCKED, 2 si KILL/AMEND)
~/arsenal/audit-lifecycle/lib/scope-validator.sh \
  findings/MYTARGET-F001-scope-check.md

# 6. Stage 2 : crée les 4 autres gates avec auto-injection des kill-pattern rules
~/arsenal/audit-lifecycle/bin/on-finding.sh MYTARGET-F001 --stage 2
```

**E2E test local avant de trust le flow :**

```bash
rm -rf /tmp/m2-test
TARGET_HINTS="web api" ~/arsenal/audit-lifecycle/bin/init-target.sh testm2 /tmp/m2-test
~/arsenal/audit-lifecycle/bin/on-finding.sh TEST-F001 /tmp/m2-test --stage 1
# Observer : uniquement scope-check.md est créé
ls /tmp/m2-test/findings/
# Sans fill : stage 2 doit refuser
~/arsenal/audit-lifecycle/bin/on-finding.sh TEST-F001 /tmp/m2-test --stage 2
echo "exit: $?"  # doit être 1
rm -rf /tmp/m2-test
```

## Livrable #1 — Kill-gate feedback loop

**Ce que ça fait :** `KILLED-FINDINGS-LESSONS.yaml` stocke des règles dérivées de findings morts (8 règles initiales extraites de SNOW-002, AQUA-001, S-102, Polymarket #107/#110/#197, CLEARMACRO, CIRCLE-MALACHITE dups, HRB-001, MHE-F002). À chaque `on-finding.sh --stage 2`, `inject-kill-lessons.sh` append les 8 règles dans le kill-gate.md du finding avec checkbox à cocher.

**Fichier canonique :** `~/Desktop/BUGS/KILLED-FINDINGS-LESSONS.yaml` (pas dans `~/arsenal` — fichier de working data, machine-specific).

Machine 2 doit créer sa copie :

```bash
# Copier depuis machine 1 via scp ou recréer localement
# Si recréation : voir structure YAML dans inject-kill-lessons.sh pour le schema
```

**Nouveau script `on-kill.sh`:** quand un finding est dismissed/killed, l'invoquer pour logger dans OUTCOMES + générer un stub de nouvelle règle à ajouter au YAML :

```bash
~/arsenal/audit-lifecycle/bin/on-kill.sh SNOW-002 "theoretical multi-party" /path/to/workspace
# Emits a YAML stub with derived_from, trigger_pattern, pre_submit_check fields
# Operator completes and appends to KILLED-FINDINGS-LESSONS.yaml
```

## Livrable #2 — Competition density

**Ce que ça fait :** heuristique saturation avant de committer 15-100h sur un target. `competition-density.sh <program-url>` auto-scrape pour H1 + C4, guided manual pour Cantina / Sherlock / Immunefi (SPA, pas scrapeable).

**Manual override pour SPA platforms :**

```bash
~/arsenal/audit-lifecycle/bin/competition-density.sh \
  --platform cantina --submissions 104 --researchers 28 \
  "https://cantina.xyz/competitions/xyz"
```

Heuristique verdicts : <30 submissions = GO, 30-100 = CAUTION, >100 = SATURATED (pivot off-path ou skip).

## Livrable #3 — State tracker

```bash
~/arsenal/audit-lifecycle/bin/findings-state.sh
```

Parse tous les `OUTCOMES.jsonl` globaux + per-workspace. 5 tables :
- OVERDUE RELANCE (>7d no result)
- NUDGE CANDIDATES (>14d in review)
- DISPUTE WINDOW (dup/info/dismissed ≤30d)
- PAYMENT WAIT (accepted reward=0 >14d)
- RECENT WINS (≤30d reward>0)

Utile en routine : run une fois par jour, identifie les escalations à faire.

## Livrable #4 — Pattern lifting

```bash
~/arsenal/audit-lifecycle/bin/pattern-lift.sh <target-dir>
# OR scoped:
~/arsenal/audit-lifecycle/bin/pattern-lift.sh --category auth <target-dir>
~/arsenal/audit-lifecycle/bin/pattern-lift.sh --pattern P-H1-023 <target-dir>
```

Extrait les 47 `Detection:` grep blocks de `~/arsenal/methodology/H1-HUNTING-PATTERNS.md`, scanne target, rank par payout. Output : `<target>/PATTERN-LIFT-REPORT.md`.

**HIT ≠ vulnerability.** Signature match = candidate à vérifier manuellement, pas une finding.

## Livrable #5 — Surface layering

`methodology/SURFACE-LAYERING.md` — méthodologie documentée. Source : Polymarket #197 ($10K). Principle : programs qui couvrent SC + Web + API, investir 20% de recon additionnel sur surfaces adjacentes = 3-5x ROI sur programmes saturés-SC.

**Pas de script associé** — c'est une discipline appliquée dans gravedigger / mrrobbot Phase 1-2.

## Livrable #6 — Schema OUTCOMES étendu

**4 nouveaux champs :**
- `hours_invested` (number) : recon + drafting + gates + response handling total
- `surface` (enum 27 options) : sc-solidity, web, api, bridge, relayer, supply-chain, etc.
- `platform` (enum) : hackerone, cantina, c4, sherlock, hackenproof, etc.
- `bounty_program` (string) : program name/URL

**`on-submit.sh` demande interactivement** ou skip-prompts via env vars :

```bash
HOURS_INVESTED=8 SURFACE=web PLATFORM=hackerone BOUNTY_PROGRAM=mytarget \
  ~/arsenal/audit-lifecycle/bin/on-submit.sh MYID submitted /path/to/workspace
```

Permet de calculer $/hour par surface après accumulation de ~3 mois de data.

## Livrable B — Scope parser URL

```bash
~/arsenal/audit-lifecycle/bin/scope-parser.sh \
  "https://hackerone.com/program" \
  /path/to/SCOPE.md \
  program-name
```

Parse best-effort H1 (__NEXT_DATA__) + Cantina + generic HTML (h2/h3 "Scope" / "Out of Scope" sections). Fallback graceful quand c'est une SPA : émet un SCOPE.md avec instruction "populate manually" + Core Ineligible Findings H1 pre-rempli.

Intégré à `init-target.sh --scope-url <url>`.

## MEMORY split (Livrable C — manuel, pas versionné)

Sur machine 1, `~/.claude/projects/-home-malix-Desktop-BUGS/memory/MEMORY.md` a été split :
- MEMORY.md 31KB → 7.9KB (master index only)
- 3 INDEX par domaine : `INDEX-web.md`, `INDEX-sc.md`, `INDEX-strategic.md`
- Backup préservé : `MEMORY-pre-split-2026-04-21.md.bak`

**Target-router a été modifié** pour émettre dans `ROUTING.md` : "Feedback memory indexes to load — Always: INDEX-strategic.md | Conditional: INDEX-web.md / INDEX-sc.md selon target class."

Machine 2 devra :
1. Soit répliquer le split localement (pas de sync entre machines pour memory/ selon ma lecture)
2. Soit adapter le target-router pour ses propres paths

Pour ma propre memory, j'ai préservé le backup ; machine 2 fait ce qu'elle veut.

## Feedback memories créées (machine 2 réplique si souhaité)

3 nouvelles mémoires feedback écrites cette session :
- `feedback_mitigation_speed_downgrade.md` — dismissal vector appris de Polymarket #197 (Critical → Medium via team-responsiveness argument)
- `feedback_platform_responsiveness_tiers.md` — classification C4/Cantina/H1/HackenProof par temps réponse, dispute ROI, strategic use
- Addendum au même fichier : règle "NO preemptive anti-downgrade comments" (signal d'insécurité, invite le downgrade)

Machine 2 peut les recréer localement en lisant machine 1 via le canal de sync habituel.

## Données live en cours (pour context)

Au moment du handover :

| Finding | État | Next action |
|---|---|---|
| Polymarket #197 | **Medium $10K accepted 2026-04-21** | Acceptance note rédigée, à poster (voir `~/Desktop/BUGS/polymarket-cantina-tracker/F-W003-197-ACCEPTANCE-NOTE.md`) |
| Polymarket #232 | High New since 2026-04-19, chain-of-custody posté | NO preemptive comment. Dispute reserve ready if downgrade. |
| Circle Malachite #3681944 | Critical passed analyst 2026-04-21 | Awaiting Circle team reproduction. $27K-$75K potential. |
| Request Finance RF2-C01 | Yoann routed vers RN 2026-04-21 | 7-day silent clock, deadline 2026-04-28. Level 1-4 escalation + RN contacts ready. |
| Upshift Finance SEAL email | SERVFAIL on a911@securityalliance.xyz | Pivot vers Telegram @seal_911_bot + Discord SEAL. |

## Post-handover sanity

Machine 2, après pull et vérification, lance cet E2E pour confirmer que tout tourne :

```bash
# 1. Workspace
rm -rf /tmp/m2-sanity
TARGET_HINTS="web api" ~/arsenal/audit-lifecycle/bin/init-target.sh sanitycheck /tmp/m2-sanity

# 2. Stage 1 scope-check
~/arsenal/audit-lifecycle/bin/on-finding.sh SANITY-F001 /tmp/m2-sanity --stage 1

# 3. Stage 2 refusé sans PROCEED
~/arsenal/audit-lifecycle/bin/on-finding.sh SANITY-F001 /tmp/m2-sanity --stage 2
# exit code attendu : 1

# 4. Pattern-lift sur le workspace (patterns chargent)
~/arsenal/audit-lifecycle/bin/pattern-lift.sh /tmp/m2-sanity
# Observer : "[pattern-lift] loaded 27 patterns" approximatif

# 5. Competition density
~/arsenal/audit-lifecycle/bin/competition-density.sh --platform cantina --submissions 50 --researchers 15 "https://example.com"
# Observer : "verdict: CAUTION"

# 6. State tracker
~/arsenal/audit-lifecycle/bin/findings-state.sh
# Observer : 5 tables émises, current state reflété

# 7. Cleanup
rm -rf /tmp/m2-sanity
```

Si les 7 étapes tournent sans erreur, machine 2 est synchronisée.

## Questions ouvertes pour discussion

1. **SPA parsing Cantina/Sherlock** — abandonné cette session après tentative d'accès à `api.cantina.xyz` (404 sur toutes les routes publiques). Options restantes : Playwright headless ou auth-session persistée. Décision reportée.
2. **Hours tracking backfill** — `on-submit.sh` prompte désormais `hours_invested` mais les 15 entrées OUTCOMES.jsonl existantes n'ont pas la donnée. Backfill manuel ou batch depuis memoire persona ?
3. **Cross-machine feedback sync** — memoire `feedback_*.md` vit dans `~/.claude/projects/.../memory/` sur chaque machine. Pas de canal de sync automatique. Option : push MEMORY index files dans arsenal sous un path `memory-indexes/` versionné, laisser les feedback files originaux sur chaque machine.

Machine 2 peut commenter ou répondre sur chacune de ces 3 questions via commit supplémentaire ou edit de ce fichier.
