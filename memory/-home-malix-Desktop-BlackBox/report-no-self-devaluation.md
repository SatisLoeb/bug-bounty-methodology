---
name: report-no-self-devaluation
description: "Discipline de rédaction imposée par l'opérateur — un rapport ne concède jamais son propre tier, n'invoque jamais la clause d'exclusion du programme contre lui-même, et distingue existence d'exposition."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: aa9d7761-12d6-49d5-87db-4c024f1206b8
  modified: 2026-08-06T22:24:35.666Z
---

Trois motifs à ne jamais écrire dans un rapport, corrigés un par un par l'opérateur sur la
soumission Decentraland #87537. Les trois sont des formes d'auto-sabotage qui *ressemblent* à de
l'honnêteté.

**1. Ne jamais pré-concéder le tier.** J'avais écrit « I would not argue against a Medium if triage
weighs the precondition more heavily ». Personne ne l'avait demandé. La règle : les caveats
dimensionnent la **vraisemblance**, ils ne fixent pas le tier. Énoncer les faits, laisser le
programme placer. Corollaire mesuré : ne pas coller d'étiquette de sévérité sur du matériel posté
**dans** un fil déjà déposé en Critical — ça donne un point d'ancrage pour raisonner vers le bas.

**2. Ne jamais invoquer la clause d'exclusion du programme contre son propre finding.** J'avais
écrit « the programme excludes impacts that require access to leaked credentials » à propos de ma
propre trouvaille. C'était faux en plus d'être suicidaire : aucune clé privée n'intervenait. Une
signature sur une chaîne fixe n'est pas un identifiant fuité, c'est un **artefact de requête traité
comme un porteur**. La classe correcte était « durée de vie d'un bearer token », qui est payable.
Vérifier à quelle classe appartient vraiment le matériel avant de s'auto-exclure.

**3. Séparer existence et exposition.** « Requires a leaked signature » (précondition
hypothétique) contre « le format est produit en production aujourd'hui, leur propre commentaire
`@deprecated` le dit, et sa durée de vie est le défaut ; l'exposition est la question ouverte ».
Même matériel, la seconde formulation est bien plus forte et strictement aussi honnête. Dire
explicitement ce qu'on ne démontre pas, sans en faire une concession sur l'impact.

**Cohérence en-tête/Impact.** Un rapport qui revendique une ligne d'impact en en-tête et concède
son chemin en section Impact se fait fermer sur la seconde. Le triageur lit les deux.

**Et le pendant symétrique — ne pas sur-revendiquer.** Même session : j'ai écrit « signatures over
the legacy payload do not expire » sans mesurer. L'opérateur a demandé la vérification ;
`ECDSA_EPHEMERAL` **est** validé sur la voie de repli, donc la borne réelle était la durée de
session (31 j côté Builder) et non l'infini. Un chiffre pris d'une seule observation — un snapshot
de `localStorage` — au lieu de la source : c'était le vrai trou, pas celui que je croyais défendre.
Voir [[measure-before-asserting-in-reports]].

**Comment appliquer.** Avant d'envoyer, deux greps sur le fichier : les formes d'auto-dévaluation
(`would not argue`, `arguably`, `might not qualify`, `feel free to downgrade`) et les clauses
d'exclusion citées contre soi (`programme excludes`, `out of scope`, `leaked credential`). Un hit
sur la seconde n'est légitime que s'il borne ce qu'on **ne** revendique pas — par exemple déclarer
qu'on ne rapporte pas la verbosité d'une erreur comme finding — jamais s'il concède la trouvaille
principale. Le gate de recevabilité reste [[recevability-gate-before-poc]].
