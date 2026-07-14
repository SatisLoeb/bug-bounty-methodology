---
name: extract
description: >-
  Détecte la veine MATH-EXTRACTIBLE. Activer AVANT audit profond d'une cible avec calculs de valeur (vault ERC-4626, AMM, lending, primitive crypto). Structure = CHAÎNE ordonnée par vitesse-de-mort : chaque gate tue. Mesure chaque gate au coût minimal (lecture+arithmétique) AVANT le fork. Le fork seulement si le gate qui tue le plus vite survit.
---

# extract — chaîne de la veine math-extractible

Veine = MATH-EXTRACTIBLE (une erreur de calcul transfère de la valeur).
Structure = chaîne. Chaque gate tue. Ordonnée par vitesse-de-mort.
Le Gate-2 par LECTURE est l'exercice de l'instrument — pas le fork.
Monter un fork ≠ exercer l'instrument. Trancher chaque gate au coût minimal = l'exercer.

## Gate 1 — DIRECTIONNALITÉ (tue le plus vite)

L'erreur penche-t-elle TOUJOURS vers l'extracteur ?
Bidirectionnelle/aléatoire = moyenne à zéro = MORTE.

Deux modes :
- ACCOUNTING : directionnel-signé. L'arrondi penche-t-il contre l'utilisateur ?
  (ERC-4626 : sharesDown au dépôt, sharesUp au retrait, debtUp. Si le sens
  correct Down/Up est appliqué selon le flux → gardé. Si un appelant choisit
  la mauvaise direction sur la valeur d'autrui → candidat.)
- CRYPTO : exploitable-vs-inerte. L'erreur produit-elle un état exploitable ou
  inerte ? (_invMod(0)=0 inert, isOnCurve rejette → Scribe meurt ici.)

[trou Scribe : le mode accounting seul ne couvre pas la crypto. Le Gate-1 a
deux modes selon la nature du calcul.]

## Gate 2 — ACCUMULATION (mesure par LECTURE)

Erreur bornée-par-op (1-wei) ou accumulable (boucle/répétition → matérielle) ?

Mesure par lecture+arithmétique, PAS par fork :
- magnitude : décimales des assets, ratio des opérandes. 1-wei sur un yield de
  millions = négligeable.
- répétabilité : l'op consomme-t-elle l'état ? (liquidation Euler : cool-off +
  état consommé + no-self-liq → non-répétable → MORTE. Accrual : par-bloc,
  toutes positions, illimité → accumulable SI un attaquant capte.)

[Euler : les deux candidats math meurent ici, par lecture, zéro fork.
L114 floor 1-wei non-répétable vers le protocole ; accrual toAssetsUp vers
le protocole, capture pro-rata infinitésimale.]

## Gate 3 — ABSORPTION (mesure en EXÉCUTION)

Un mécanisme mange-t-il l'erreur avant extraction ?
MESURE en exécution, pas en lecture (le piège GR-001 : l'absorption se lit
faussement présente, l'exécution montre qu'elle ne couvre pas le chemin).

## Gate 4 — TRIGGER + BORNE

L'état exploitable est-il atteignable organiquement (pas seulement en théorie) ?
Est-il cappé (limite par tx, par bloc, par position) ?
**Survit-il ?** Si l'exploit exige que l'état reste INTERMÉDIAIRE pendant une DURÉE (fenêtre de
saturation / liquidation / déblocage / oracle-stale / époque), la fenêtre meurt de trois façons :
(i-a) un acteur la RESET pour un payoff ; (i-b) reset INCIDENT — du trafic de routine la refresh
gratuitement (liquidation d'un voisin, rééquilibrage d'arb, tout dépôt/retrait qui touche l'accumulateur),
payoff propre ~0 mais te tue quand même ; (ii) front-run de ton extraction À maturité (fenêtre intacte,
tu n'es pas payé). MEV / arb / liquidateur / keeper = **présents à t=0**, jamais un risque futur. Le
payoff adverse se rechiffre POST-PoC (fenêtre + valeur = SORTIES du PoC, inconnues avant) : pré-fork tu
FLAG, après quantif tu tues. Voir KILL-GATE **Q5b** (gate universelle, deux points de contrôle).

## Gate 5 — IMPACT RÉALISÉ

Population/valeur réelle exposée ? Perte concrète chiffrable ?
(GR-001 : conditional-armed Medium — réel mais conditionné à un état non
organiquement présent.)

## Sortie
- meurt Gate-1 : directionnalité absente (math non-directionnelle, Scribe crypto)
- meurt Gate-2 : 1-wei non-accumulable (Euler les deux candidats)
- meurt Gate-3 : absorbée
- meurt Gate-4 : fenêtre intermédiaire tuée par un acteur t=0 — reset ciblé, reset INCIDENT (trafic de routine, payoff propre ~0), ou front-run à maturité (Ammalgam saturation 120j)
- passe les 5 : veine extractible (GR-001)

## DETTE DE VALIDATION (honnête)
Gates 3/4/5 jamais exercés au-delà du Gate-2 en RÉEL — validés sur le
contre-factuel GR-001 construit seulement. Crypto-mode validé Gate-1 seulement
(Scribe). En conditions réelles, seul le Gate-1 et le Gate-2 ont tué.
