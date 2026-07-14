# L'échelle de garantie : fuzz → Halmos → Certora

Halmos n'est pas un nouvel outil à part : c'est **le barreau du milieu**, dans ton format Foundry.

```
Foundry fuzzing         sonder LARGE          "pas de contre-exemple en 10M runs"  = pas trouvé
        │                                                                            (échantillon)
        ▼
Halmos (check_)         durcir un invariant   "pas de contre-exemple SOUS la borne" = prouvé borné
        │               PRÉCIS en preuve                                            (tous les chemins ≤ k)
        ▼
Certora (CVL)           invariant SYSTÈME      "prouvé" avec ghosts/hooks/summaries = preuve lourde
                        lourd, cross-contract                                        (courbe + rouille)
```

## Quand monter d'un barreau

- **Fuzz → Halmos** : dès qu'un invariant Foundry sort « pas de contre-exemple en N runs ». Le fuzz
  a échantillonné ; Halmos explore *tous* les chemins jusqu'à la borne. Tu passes de « pas trouvé » à
  « n'existe pas, sous ces bornes ». Même syntaxe, mêmes helpers, mêmes mocks — tu changes `test_` en
  `check_` et tu remplaces les inputs concrets par des symboliques.
- **Halmos → Certora** : seulement quand la propriété dépasse ce que Halmos exprime — invariant
  système lourd, cross-contract profond, base déjà spec-ée en CVL, et la profondeur justifie la
  courbe. Le jour venu tu penses déjà en propriétés ; il ne reste que la syntaxe.

## Le geste qui maintient la lame

La prochaine fois qu'un invariant Foundry tient « en 10M runs », **réécris-le en `check_` symbolique
et lance Halmos**. Tu apprends l'outil sur un cas que tu maîtrises déjà, et tu sens immédiatement la
différence entre « pas trouvé » et « prouvé borné ». Sur du vrai boulot, pas un tutoriel.

## Pourquoi Halmos plutôt que Certora par défaut

Halmos ne rouille pas : c'est tes tests Foundry avec un mot-clé. Certora demande CVL (ghost
variables, hooks, summaries) — une vraie compétence, qui rouille si tu la ressors deux fois par an.
La compétence transférable — **penser en propriétés** — se construit sans quitter l'environnement où
tu es fluide.

## Maturité réelle (corrige le préjugé « faible sur le lourd »)

Halmos est éprouvé sur : Morpho Blue (prêt multi-contrats réel), registres Farcaster, tokens Vyper
Snekmate, **la lib fixed-point de Solady** et **l'arithmétique 1024-bit de Cicada**. Donc la réserve
« faible sur le non-linéaire / le cross-contract » est trop dure : c'est **borné** et ça peut
**timeout**, mais l'outil tient sur des libs arithmétiques lourdes et des protocoles multi-contrats.
La limite est réelle (voir pitfalls.md), juste moins basse qu'on le peint.

## Place dans l'arsenal

Halmos est le barreau « preuve bornée » de la promotion NUKE (`nuke → signals → veine → PoC exécuté →
**Halmos** → report`). Il vient APRÈS le fuzz (`/invfuzz`, `/fizz`) : le fuzz trouve/rassure, Halmos
durcit. Un CONTRE-EXEMPLE Halmos est un candidat finding (rejoue-le en forge concret → `/report-nerve`).
