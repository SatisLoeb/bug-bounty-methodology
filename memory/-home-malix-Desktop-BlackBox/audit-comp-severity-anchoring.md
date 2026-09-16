---
name: audit-comp-severity-anchoring
description: "En compétition d'audit, ne jamais punter la sévérité ni défaut-bas — l'ancrer sur le barème du programme lui-même (le voisin listé le plus proche)."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: adf81446-2497-4039-afd2-3faf96a7eb02
  modified: 2026-08-18T16:48:19.535Z
---

**CORRECTION 2026-08-18 (fermeture #89327 ENS) — LIRE EN PREMIER, corrige le corps ci-dessous.**
Un finding VRAI et PROUVÉ (mécanisme confirmé par le triageur Immunefi) a été FERMÉ car aucune **row d'impact
in-scope** ne collait *clause comprise*, et parce que j'ai calé la sévérité "par analogie à des known-issues (R3)".
Trois leçons dures :
1. **La row d'impact in-scope EST le gate**, avant la sévérité. Pas de row qui colle (sa clause incluse) =>
   quasi-infermable-autrement, quelle que soit la qualité du PoC. À trancher AU go/no-go : "aucune row propre" =>
   NO-GO ou attente Insight-seulement, PAS "je soumets et j'argumente par analogie".
2. **Les KNOWN ISSUES ne sont PAS une track de sévérité revendicable** (ils sont inéligibles). Citer une classe
   connue (ex. R3 High-availability) pour caler SA sévérité ne remplace pas la démonstration d'un impact in-scope ;
   Immunefi l'a rejeté verbatim ("unrelated known-issue entries").
3. **NE JAMAIS concéder dans le rapport la clause disqualifiante de la row choisie.** J'ai écrit "that part doesn't
   happen here" -> phrase de clôture offerte au triageur. Argumenter l'impact POSITIVEMENT, ou ne pas prendre la row.
Le corps ci-dessous ("ancre sur le voisin listé le plus proche") ne vaut que si le voisin est une IMPACT-ROW in-scope,
JAMAIS un known-issue.

En **compétition d'audit** (≠ bounty), la sévérité **détermine la part du pool** — la punter ("je vous
laisse le chiffre") ou défaut-Medium, c'est s'auto-inviter au tier le plus bas. Contexte ENS 2026-08-18.

**Why :** le juge alloue par tier ; un finding non-défendu sur sa sévérité prend le plancher. Et le
programme fournit souvent son PROPRE barème calibré : ses known-issues portent les sévérités que SES
auditeurs ont assignées, parfois une TRACK entière (ex. ENS : "High (availability)" pour des problèmes
de liveness/data-integrity **sans attaquant externe**, R3-01..R3-04).

**How to apply :**
1. Trouver le **voisin listé le plus proche** du finding et le **nommer**. Citer sa sévérité + son
   wording verbatim (ex. R3-03 = High, "permanent spinner for a name they may already own").
2. Argumenter que ton cas est **d'un cran PIRE sur le même axe** (ex. faux succès + commitment payé
   abandonné + record 'success' persisté > un simple spinner). C'est LEUR barème appliqué, pas de
   l'inflation.
3. **Ne PAS étirer vers un row Critical** qui ne colle pas (pas d'attaquant → les rows theft/hijack/
   wrong-recipient ne s'appliquent pas). Vérifier les 28 impacts : s'il n'existe **aucun row verbatim**
   pour ton comportement exact, l'ancrage honnête = la track de sévérité du programme, pas un Critical
   forcé. Le dire explicitement ("I'm deliberately not reaching for a Critical row") RENFORCE la crédibilité.
4. **Dedup agressif** ("same root cause = dup even by a different path") : séparer par **location de code
   + direction de l'échec**. Nommer le voisin, montrer l'opposé (R3-03 = hang / actor stoppé rien ne
   settle ; le mien = settle AVEC un mauvais receipt → faux succès). Bonus : si ta repro a une branche
   qui EST le known-issue (ici la race instantanée = hang = R3-02/R3-03), l'admettre et isoler la
   branche neuve — ça blinde le dedup au lieu de l'affaiblir.

**Logistique comp (≠ bounty) :** KYC souvent requis ; jugé à la FIN, dups partagent l'allocation (pas
premier-arrivé). Donc **qualité > vitesse**, pas d'urgence à dégainer.

Vérifier CHAQUE citation verbatim avant de l'écrire (le rapport ne vaut que par l'exactitude des refs).
Voir [[report-no-self-devaluation]], [[measure-before-asserting-in-reports]], [[ens-target-state]],
[[recevability-gate-before-poc]].
