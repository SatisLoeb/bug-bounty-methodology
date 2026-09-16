---
name: measure-before-asserting-in-reports
description: "Règle de l'opérateur — tout mécanisme nommé dans un rapport doit être mesuré ou déclaré non mesuré ; et chaque affirmation mesurée doit être reproductible par le PoC publié, pas par la prose."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: aa9d7761-12d6-49d5-87db-4c024f1206b8
  modified: 2026-08-06T22:25:02.875Z
---

**La règle, énoncée par l'opérateur :** « Ne le laisse pas à mi-chemin. » Un mécanisme décrit dans
un rapport sans mesure met le lecteur dans le doute — *a-t-il trouvé quelque chose qu'il ne dit
pas ?* Deux sorties propres, jamais l'entre-deux :

1. Si c'est peut-être exploitable, **le mesurer maintenant**, avant le patch, parce que la fenêtre
   se ferme avec le correctif.
2. Si c'est déjà conclu non exploitable, le dire : « je n'ai pas trouvé de construction exploitable
   ici, je le signale comme durcissement de classe ».

**Instance.** J'avais glissé en section Fix que le payload signé est construit par `join(':')` sur
des composants non échappés, « donc ambigu ». En le mesurant : la frontière intéressante n'était pas
`path|ts` mais `ts|metadata` (si `md = A:B`, alors `ts=T, md=A:B` et `ts=T:A, md=B` joignent vers les
mêmes octets). Résultat exécuté : rejeté, parce que `verifyTimestamp` fait `Number(value)` +
`Number.isFinite`. Et l'autre frontière est fermée par `JSON.parse` sur la metadata. Donc sortie 2 —
mais la conclusion produite par la mesure était **meilleure** que la remarque initiale : *aucune des
deux gardes n'échappe le délimiteur, ce sont des validateurs de type qui excluent les deux-points par
effet de bord*, donc un parse plus laxiste rouvre la classe sans que personne ne touche au code du
payload. La sécurité est accidentelle, pas conçue. C'est ça qui justifie le durcissement.

Sous-produit typique de ce genre de mesure : elle révèle autre chose. Ici, le `RequestError` du garde
d'horodatage tombe lui aussi dans le `catch`, donc le repli déprécié reçoit **deux** classes
indépendantes de rejet du chemin moderne — ce qui prouve qu'il n'est pas un shim étroit mais le
réceptacle de tout ce que le chemin moderne refuse.

## Le corollaire artefact : la sortie brute, jamais le résumé

Une mesure citée dans un rapport doit être **reproductible par le PoC publié**, sinon c'est une
affirmation. Trois exigences, toutes issues de corrections de l'opérateur :

- **Le script doit produire la section.** Si le rapport montre un bloc `[N]`, le script publié doit
  l'imprimer. Sinon retirer la revendication ou étendre le script.
- **Coller la sortie brute, pas une version reformatée.** J'avais résumé un bloc à la main et perdu
  le drapeau que le script calcule lui-même (`joins-to-signed=True`) — précisément la donnée qui
  prouvait le propos, et une ligne sur quatre au passage. La sortie brute est plus forte que le
  résumé.
- **Déclarer toute troncature.** Si le script coupe les corps de réponse pour la largeur du
  terminal, le dire et donner la chaîne complète, ou faire imprimer le corps entier là où le corps
  **est** la preuve. Ne jamais éditer une sortie à la main pour la rendre lisible : une phrase qui
  s'appuie sur une ligne tronquée s'effondre dès que le triageur lance le script.

**Vérifications avant envoi**, mécaniques et rapides : (a) chaque corps complet cité apparaît
verbatim dans le fichier de run ; (b) chaque ligne de statut du rapport (libellé + code) existe dans
ce run ; (c) aucun jeton résiduel d'un run antérieur (identités, uuid, horodatages) ; (d) tout vient
d'**un seul** run. Si le script change, même pour un rename, relancer et réaligner — sinon le rapport
cite une sortie que le fichier publié ne produit plus.

**Vérifier l'artefact publié, pas la copie locale.** Cloner le gist dans un dossier vide et
l'exécuter de là. Comparer par contenu (hash / `diff`), pas par date. Voir
[[deployed-code-not-head]] : même exigence, autre surface.

Complémentaire de [[report-no-self-devaluation]] : celui-là interdit de céder ce qu'on a prouvé,
celui-ci interdit d'affirmer ce qu'on n'a pas exécuté.
