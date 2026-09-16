---
name: feedback-corpus-not-trusted-100-poke-first
description: "The corpus is a bounded expectation-set (the extractor's story of where THEY think bugs live) — completeness backstop inside known classes only; the poke finds the surface no class names; order is poke FIRST, apparatus AFTER"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e0ebe540-de2b-4fe6-8682-3b50e56433a0
  modified: 2026-09-08T12:05:00.739Z
---

Ne pas se fier à 100 % au corpus (ni à `/intake`). Le corpus est une **expectation-set bornée** = la story de celui qui l'a extrait, là où EUX croyaient que les bugs vivent. Le bug est toujours une **indirection EN DEHORS** de là où tu as atteint la compréhension propre — la Seconde Maxime appliquée au TOOLING, pas juste au code.

Répartition des rôles, non négociable :
- **corpus = completeness backstop À L'INTÉRIEUR des classes connues** (packaging, ne-rien-rater dans le nommé).
- **poke = la passe de DÉCOUVERTE** qui trouve la surface qu'aucune classe ne nomme (ex : `admin-api` n'appartient à aucune classe du corpus).

Tension explicite et ASSUMÉE avec la règle "corpus-coverage-gate : lead-dont-improvise" — **les deux sont vrais**. Le gate/corpus rattrape les classes que le poke rate ; le poke trouve le bug pour lequel le corpus n'a pas de classe. **L'ORDRE EST TOUT : poke D'ABORD, apparatus ENSUITE.**

**Why:** un corpus lu comme complet reproduit l'angle mort de son extracteur ; traité comme backstop-après-poke il ne fait que compléter, il ne cadre plus la chasse.

**How to apply:** ne jamais OUVRIR une cible par corpus-query. Poke à la main → puis corpus pour packager/backstop. Si le dossier est corpus-first, l'ordre est faux — le corriger. Voir [[feedback-manual-poke-bracket-mandatory]].
