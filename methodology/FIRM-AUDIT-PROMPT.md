# FIRM-AUDIT-PROMPT.md — raw deploy prompt (manual paste mode)

> This is the verbatim operator prompt for a firm-grade deep audit. Paste it directly
> when you want manual control over the moment of deployment. The encoded equivalent is
> the `/firmaudit` skill — same procedure, invocable. Use whichever fits the moment.
>
> The universal firm-grade + anti-LLM-garbage floor (CLAUDE.md OPERATING STANDARD) applies
> regardless of whether you paste this or invoke the skill.

---

en mode immortel pas de limite de temps pas de limite de tokens on le fait d'une manière
professionnelle en deep sur chaque détail si il le faut on entre en mode plan et on fait un
plan en 8 semaines tu peux aussi utiliser exploit-primitive-mindset mais ne pas te limiter à
ça je veux un audit digne des grandes firms d'audit pas du garbage de llm et surtout anti-fast-pass / no-shallow-dismissal : le cœur du no-shallow-dismissal. Les audits ont des angles morts : pas seulement le code post-audit (le delta),
  mais le code qu'ils ont survolé à l'intérieur même de leur scope — les zones qu'ils ont traitées en surface, marquées "Acknowledged" sans re-dériver
  l'impact, ou regardées sous un seul angle. par exemple tout le monde audite le write-path des oracles (signature, replay), personne ne va au bout du read path dans le moteur de liquidation

Phase 0 maintenant (1-2h) — Target Intelligence avant tout plan:

1. Recon du repo — langages réels, taille LOC, modules, dépendances natives, surface cross-chain supportée
2. Audit history — qui a déjà audité (CertiK? SlowMist? Halborn? jamais?), public reports disponibles
3. Commit velocity post-audit — diff entre dernier audit et HEAD = code non-revu
4. AI-bot check — v12-auditor / Olympix sur le repo? (impact dup-risk)
5. Issue tracker / GHSA history — vulns publiques déjà disclosed
6. Crypto primitives présents — quelles courbes, quels schemas de signature, quels HD-wallet derivations, quel multi-sig si applicable
7. Threat model implicite — non-custodial pure? key derivation côté client? interaction RPC node?
8. Surface cross-chain réelle — EVM, Solana, Bitcoin, Cosmos, Aptos, Sui, Move, Cairo? Chaque chaîne = primitive crypto différente

Ensuite remonte avec un plan 8 semaines structuré par firm-grade audit methodology:

- Sem 1-2: Architecture deep-dive + threat model formel + scope freezing
- Sem 3-4: Per-chain crypto primitives audit (BIP-32/39/44, EIP-191/712, SLIP-0010, BIP-340 Schnorr, ed25519 malleability, multisig si présent)
- Sem 5-6: Cross-chain logic + serialization + transaction construction + RPC layer
- Sem 7: Adversarial review + differential fuzzing setup + property tests
- Sem 8: Report assembly firm-grade + disclosure coordination

Pas de skill auto-orchestré.

---

> **Sync notes (équivalence avec le skill `/firmaudit`, ajoutées sans toucher au prompt ci-dessus):**
> - **Phase 0 scriptée:** `~/arsenal/audit-lifecycle/bin/phase0-intel.sh <repo> [owner/repo] [audit-base] > PHASE0-INTEL.md` auto-remplit les points 1-5 + 8 (recon/audits/delta-post-audit/ai-bot/GHSA/cross-chain) + candidats crypto (point 6). Points 6/7 + le point **9 money-flow** restent humains.
> - **Point 9 (gate OKX F-007, à la Phase 0 pas en semaine 8):** pour chaque mover de fonds, peut-on écrire `loss=$X`? Sinon la surface est dépriorisée maintenant. + un finding dont le seul acteur est le owner/governance de confiance = OOS owner-rug, décidé ici.
> - **"8 semaines" = phases ordonnées par dépendance, pas un calendrier.** La profondeur (§ stop conditions: forge-lint green + internal-consistency 100% + mirror-coverage exhaustif loggés), pas une horloge, ferme une phase.
> - **Exécution = harnais de fan-out à la main:** par phase, un `Workflow` = DIG (1 agent/surface) → ADVERSARIAL-VERIFY (1 sceptique/candidat, défaut REFUTED, dedup vs audits cités) → **OPERATOR HAND-VERIFY de chaque REAL** (les agents sur-rapportent ~10:1 sur code durci; 6 "Critical/High" renversés à la main sur Reserve). Un agent ne peut pas auto-déclarer un finding prêt.
> - **Phase T — Triage top-down AVANT le plan deep (le gate ROI n°1):** après Phase 0, modéliser top-down avant de lire 35 contrats. T1 assets/valeur-terminale → T2 frontières/entrées → T3 acteurs → T4 graphe de chemins (arêtes = `~/arsenal/methodology/SC-PATH-PATTERNS.md` SC-P-01..16 + H1 M-H1-* pour web2) → T5 gate d'atteignabilité (KILL-GATE Q2, manuel) → T6 gate de recevabilité front-loaded (T6a scope-exclusion DURE incl. **admin-trust + `loss=$X`-or-DROP**, T6b dup, T6c edge-fit) → T7 scoring ORDINAL (P0/P1/P2/DROP) → `TRIAGE-CARD.md` avec verdict **GO / NO-GO / WATCH**. **NO-GO = stop, on n'entre pas en audit deep.** Critère de départage trusted-actor: si franchir la frontière exige de compromettre un rôle que le programme déclare de confiance → DROP (admin-trust, cf. Centrifuge #283 / Reserve F-SOL-001); si la frontière est franchie par un input non-fiable atteignable (peer cross-chain forgeable, param keeper contrôlé) → DIG (SC-P-03). Une fenêtre courte ne court-circuite jamais la recevabilité.
