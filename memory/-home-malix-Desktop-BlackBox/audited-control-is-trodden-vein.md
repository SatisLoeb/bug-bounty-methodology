---
name: audited-control-is-trodden-vein
description: Sur un canal privé (bounty), un contrôle récemment audité = veine labourée ; pondère le dup-risk à la hausse avant de payer un fee, même sur un fix-bypass valide.
metadata:
  type: feedback
---

Un contrôle récemment audité (le HMAC covenant-signer de Coinspect BP2-024) attire les chercheurs sur EXACTEMENT
cette primitive. Un fix incomplet est une classe payable, mais c'est aussi une zone déjà fréquentée — donc le dup-risk
y est SUPÉRIEUR à la moyenne, pas inférieur. Sur un canal privé (Immunefi), les reports des autres sont INVISIBLES
(pas dans le repo, ni audit publié, ni GHSA) — aucune vérif source-primaire ne les fait remonter.

**Preuve :** C-2 (covenant-signer HMAC cross-endpoint replay -> /v1/lock) soumis #89885, blindé sur tous les axes
vérifiables, fermé DUP de #62507 (soumission privée antérieure, même sink, même exploit). $50 fee perdu. Invisible
avant soumission par construction. + signal sévérité : #62507 = Medium sur le même angle persistance => mon High était
optimiste (le programme calibre ce griefing en Medium).

**How to apply :** quand le pivot d'un finding est « incomplétude d'un fix récemment audité » (le cadrage BP2-024 /
OZ-checkpoint), traite l'acknowledgment d'audit comme un DOUBLE signal : (1) atout de recevabilité (in-scope, in-threat-
model) MAIS (2) marqueur de veine labourée => dup-risk privé élevé. Avant de payer un fee dessus : pondère le dup à la
hausse, et anticipe que le tier réel peut être un cran sous ton cadrage (le mainteneur a déjà vu la classe). Ne change
pas de cap (le fix-bypass reste bon), mais entre avec les yeux ouverts sur le coût structurel du pay-to-submit privé.
Raffinement du [[recevability-gate-before-poc]] et de [[by-design-gate-not-just-git-dup]] ; cousin de [[report-no-self-devaluation]]
(ne pas sur-vendre le tier). Voir aussi la leçon severité StackingDAO/wsts.
