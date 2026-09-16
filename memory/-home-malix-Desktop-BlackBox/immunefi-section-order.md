---
name: immunefi-section-order
description: Ordre canonique des sections d'un rapport Immunefi + le skill immuformat qui l'encode ; charger immuformat sur toute cible Immunefi.
metadata:
  type: reference
---

**Champs formulaire :** Target · Category (Websites&Apps / Blockchain-DLT) · Impact(s) [copié VERBATIM de la liste
in-scope] · PoC Link (gist secret).

**Description, ordre FIXE :** Brief/Intro → Vulnerability Details → Impact Details → Recommended Fix → References →
Proof of Concept. (Différent de l'ordre report-nerve HackerOne/Cantina qu'ont C-2/V-1 : Summary→Steps→Distinction→
Impact→Fix→Supporting. Pour Immunefi, utiliser l'ordre ci-dessus.)

**PoC toujours :** baseline d'abord (le guard marche) PUIS le bypass (guard défait), et finir sur l'artefact PERSISTÉ
+ attribué (la row/tx acceptée AS l'adresse victime). + Chain-acceptance (what-it-proves / what-it-does-NOT) + Testing
conduct (identité throwaway, routes destructrices NON exercées, divulguer tout artefact laissé, adresser la clause
live-testing).

Le skill **immuformat** (`~/.claude/skills/immuformat/SKILL.md`) encode tout ça + les conventions par section
(table de breadth measured/source, "What this is not" par exclusion nommée, Duplicate-check public-channel, Provenance
= commit d'intro prouve le threat model). Composer : immuformat (ordre/container) + [[recevability-gate-before-poc]] +
report-nerve (rigueur) + chill (voix). Calibré sur le rapport-or Decentraland builder-api (split-normalisation auth
bypass, 5 services, écriture state-modifying mesurée). Charger immuformat sur TOUTE cible Immunefi.
