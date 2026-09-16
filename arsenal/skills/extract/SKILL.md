---
name: extract
description: >-
  Détecte la veine MATH-EXTRACTIBLE. Activer AVANT audit profond d'une cible avec calculs de valeur (vault ERC-4626, AMM, lending, primitive crypto). Structure = CHAÎNE ordonnée par vitesse-de-mort : chaque gate tue. Mesure chaque gate au coût minimal (lecture+arithmétique) AVANT le fork. Le fork seulement si le gate qui tue le plus vite survit.
---

# extract — chaîne de la veine math-extractible

Veine = MATH-EXTRACTIBLE (une erreur de calcul transfère de la valeur — ou, si
elle ne la transfère pas, la DÉTRUIT / bloque / brise la solvabilité : ces sorties
non-vol sont ré-orientées au Gate-1, PAS enterrées).
Structure = chaîne. Chaque gate tue. Ordonnée par vitesse-de-mort.
Le Gate-2 par LECTURE est l'exercice de l'instrument — pas le fork.
Monter un fork ≠ exercer l'instrument. Trancher chaque gate au coût minimal = l'exercer.

## Gate 1 — DIRECTIONNALITÉ (tue le plus vite)

L'erreur penche-t-elle TOUJOURS vers l'extracteur ?
Bidirectionnelle/aléatoire = moyenne à zéro POUR LE VOL — mais "moyenne à zéro"
≠ MORTE. Ré-oriente avant d'enterrer (une erreur de calcul produit d'AUTRES
impacts payants que le transfert de valeur) :
- directionnelle vers l'extracteur → veine EXTRACTION (continue la chaîne).
- casse la solvabilité / crée de la bad-debt (même sans bénéficiaire) → INSOLVENCY (High/Crit).
- revert/lock sur une branche ATTEIGNABLE (div-by-0, underflow, overflow-cap) → DoS/FREEZE (fonds bloqués = perma/temp-freeze payant).
- force une perte à la victime, gain-attaquant ≈ 0 → GRIEFING (Medium payant).
MORTE UNIQUEMENT si : moyenne à zéro pour le vol ET préserve TOUTE invariante de
solvabilité ET ne revert/lock sur AUCUN input atteignable. Sinon la veine CHANGE
DE NOM, elle ne meurt pas (→ `~/.claude/skills/IMPACT-LEDGER-PLAYBOOK.md`).

Deux modes (pour la branche EXTRACTION) :
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

## Gate 0 — ORACLE FREE-READ (avant tout, court-circuite la fenêtre)

Un finding oracle N'ENTRE PAS dans Gate-4 tant que ce pré-check déterministe n'a pas tourné. Un
wrong-read déterministe (staleness / decimals / clamp / negative / sequencer / read-only-reentrancy)
n'a AUCUNE fenêtre — il est faux à chaque bloc, toujours, gratuitement — donc il ne se re-chiffre PAS
contre un resetter t=0 et il ne passe JAMAIS par le gate coût-de-manip (qui ne s'applique QU'AUX findings
exigeant de POUSSER un prix). Six checks, chacun un seul `cast_call`, zéro fork, zéro P&L :
1. le **CONSUMER** vérifie `updatedAt` / `publish_time` vs un heartbeat serré (PAS le wrapper — le consumer)
2. decimals/exponent du feed = l'échelle assumée par le consumer
3. `answer > 0` ET pas collé au plancher/plafond `minAnswer` / `maxAnswer` (classe LUNA / Venus)
4. `sequencerUptimeFeed` interrogé sur L2 (Arbitrum/Optimism grace-period)
5. le getter de prix n'est pas read-only-reentrable mid-callback (`get_virtual_price` / spot getter)
6. le consumer **REVERT** (ne swallow pas) sur un tuple pourri

Propres tous les six ⇒ le finding tombe dans la machinerie manip/fenêtre (Gate-4). Un seul KO ⇒ c'est un
bug cost-free déterministe : saute Gate-4, va direct Gate-5. Sévérité = MEDIUM en général (le VOLUME paie),
HIGH/Crit seulement s'il est posé sur un mint/borrow/liquidation/quorum. Voir
[[feedback-oracle-replay-refute-first-reflex-fix]].

## Gate 4 — TRIGGER + BORNE

L'état exploitable est-il atteignable organiquement (pas seulement en théorie) ?
Est-il cappé (limite par tx, par bloc, par position) ?
**Survit-il ?** Si l'exploit exige que l'état reste INTERMÉDIAIRE pendant une DURÉE (fenêtre de
saturation / liquidation / déblocage / oracle-stale [manip-window UNIQUEMENT — un wrong-read déterministe a court-circuité via Gate-0] / époque), la fenêtre meurt de trois façons :
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
