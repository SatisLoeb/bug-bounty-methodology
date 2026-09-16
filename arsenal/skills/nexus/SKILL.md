---
name: nexus
description: >-
  Veine-MÈRE DIFFÉRENTIEL — la Phase 0 de toute cible, AVANT d'ouvrir le code. Le germe (vécu par l'opérateur) : la profondeur sur NEXUS n'est pas venue de la volonté, elle est venue d'un FOIL (Haveno) — un différentiel qui a transformé une recherche ouverte sans fond ("trouve une faille" → tu bloques) en comparaison fermée ("eux protègent X, et nous ? eux ont raté Y en mai, et nous ?" → chaque écart est un fil, et tirer un fil fait apparaître le suivant). Thèse : la chasse à l'aveugle est dure parce qu'elle n'a pas d'ORACLE — ton seul modèle du programme est celui du dev, absorbé en lisant (comprendre à 100% = être d'accord à 100% = aveugle là où LUI l'était, la SECONDE MAXIME). Un foil est un oracle EMPRUNTÉ : le comportement de la référence est la bonne réponse, toute divergence est un candidat-bug, et l'ensemble des divergences est à la fois ta DIRECTION et ta condition d'ARRÊT. nexus ne trouve pas le bug — il RECRUTE l'esprit qui diverge du dev à ta place, puis ROUTE la divergence vers la veine exécutée (invfuzz / darkside Door C / xseam / extract / power). Cœur opérationnel = CLASSER LE STALL en 3 (self-knowledge ; UN SEUL est une vraie limite de profondeur) : (1) sans-gradient = foil jamais construit → fabrique le foil en Phase 0 ; (2) cul-de-sac mesuré = jumeau appliqué + divergences exécutées-nulles → RE-SOURCE (victoire déguisée en frustration, pas un échec de profondeur) ; (3) accès muré = gradient riche mais surface IP/auth-bloquée depuis l'env → HARNESS-SUSPENDED, nomme la capacité manquante (problème d'infra, pas de cerveau). Deux questions tranchent : "le foil existe-t-il ET la surface est-elle atteignable depuis mon env ?" puis "ai-je dépensé les divergences par exécution ?". Grounding capyfi (SC = type 2, app.capyfi.com CF-bloquée = type 3). Activer quand la question est "par quoi je compare cette cible", "quel différentiel / contre quoi", "je bloque / je ne vais pas assez profond / y a rien ici", "fabrique le foil", "trouve le jumeau", "recrute l'esprit qui diverge", ou au tout début de tout engagement. Déclencheurs : "/nexus", "nexus", "fabrique le foil", "quel foil", "différentiel Phase 0", "contre quoi je compare". NE remplace NI intake/wide (priorisation de surface, amont) NI les veines exécutées (aval) — nexus DÉCIDE contre quoi tu compares ; elles TRANCHENT la divergence.
---

# nexus — la veine-mère du différentiel (recruter l'esprit qui diverge)

Veine = DIFFÉRENTIEL (la profondeur ne vient pas de la volonté, elle vient d'un FOIL
importé : une seconde autorité qui est en désaccord avec le dev à ta place, dont chaque
désaccord est un candidat-bug).
Structure = RECRUTEMENT PUIS CONSOMMATION. nexus ne trouve rien — il choisit contre QUOI
tu compares (Phase 0, avant le code), range les divergences, et route chacune vers la
veine qui la TRANCHE. Le foil est un oracle emprunté ; l'exécution reste le juge.
[Formalisé depuis un usage VÉCU — la profondeur NEXUS↔Haveno, côté constructeur — et
depuis des pièces déjà éparses (invfuzz = foil lib-de-référence ; darkside Door C = foil
forme-canonique ; xseam/mirror = foil sibling-interne ; Kill-Gate q9 = foil temporel).
nexus est le principe-mère de ces éclats ; affiner à l'usage.]

## ⚠️ STATUT (2026-09-04) — OBSERVATION, PAS ENCORE MÉTHODE PROUVÉE

Stress-testé par l'opérateur le jour de sa création. Verdict retenu, honnête :

- **NOYAU = vécu / validé.** Le foil génère une pente (NEXUS↔Haveno, côté constructeur — fait
  d'expérience). Le MÉCANISME du foil a DÉJÀ PAYÉ, implicitement : Royco (reentrancy trouvée en
  lisant le diff post-audit = foil TEMPOREL) ; scene-signer (seam split-normalisation = foil
  INTERNE/mirror). Le classement du stall a corrigé une VRAIE décision (capyfi : SC=type-2
  walk-away correct, web=type-3 armé au lieu de faux-null). Cette part se garde.
- **APPAREIL de fabrication = OBSERVATION NON-EXERCÉE.** Les 7 types, la table de routage, et
  `manufacture-foil.sh` n'ont AUCUN cadavre-qui-paie pour le *rituel Phase-0-explicite* (nommer le
  foil AVANT le code, systématiquement) — seulement pour son usage *implicite*. Le rituel est une
  HYPOTHÈSE sur comment aller plus profond, pas la correction d'un échec mesuré.
- **PACKAGING-RISK = le danger CENTRAL de ce skill** (`feedback-apparatus-is-packaging-not-discovery`,
  `poke-d'abord`). Tell anti-théâtre, remonté ICI et pas enfoui : sous stress, CLASSER le foil est du
  CONFORT, pas de la découverte. Une divergence non exécutée n'est PAS traitée. **Si la Phase 0
  dépasse ~45 min sans pointer une surface CONCRÈTE, l'appareil est devenu l'emballage → STOP, chasse
  en lecture directe.** Ta méthode directe marche déjà sans nexus ; nexus doit PROUVER une marge, pas la supposer.
- **PROMOTION → méthode active : SEULEMENT via le TEST 1-CIBLE.** Cible fraîche + dure + atteignable
  (pas type-3) + NON-déjà-lue. (1) Passe lecture-directe timeboxée d'abord, log ses leads. (2) PUIS
  nexus. nexus gagne son statut actif SI et seulement s'il produit un lead EXÉCUTÉ que la passe directe
  avait raté, ET sans que la Phase-0 dérive en harness. Sinon → reste OBSERVATION. Une cible, un test,
  une comparaison honnête contre la baseline — pas de promotion sans preuve exécutée.

**RÉSULTAT DU TEST 1-CIBLE (Sky/Immunefi, 2026-09-04) — 3 surfaces :** (1) PAS = jumeau familier
→ nexus ≈ lecture directe (jumeau OZ déjà en tête + déviations dev-documentées ; confirme la critique
packaging). (2) BasinFacet = jumeau NON-familier → nexus a révélé la vraie nature de GroveBasin (info
que la lecture du facet seul ne pouvait pas avoir) → franchit la barre "valeur marginale nulle", mais
n'encaisse rien (facet défensif = mesure-actuals + slippage appelant ; la classe de vol vit dans
GroveBasin, HORS-scope). (3) Famille de 30 facets → nexus a pointé la bonne surface et la mirror-matrix
exécutée a écarté les déviants bon marché (slippage appliqué par type-de-venue : market→slippage,
fixe→aucun ; les outliers WSTETH/PSM3 s'expliquent). **VERDICT : nexus est un skill de CIBLAGE/SCOPING
validé (3/3 décisions de routage correctes, effort réel économisé, suspicion packaging RETIRÉE), PAS un
générateur de findings — il n'a rien encaissé ; chaque cash exige la lecture profonde par-surface qu'il
scope mais n'exécute pas.** Statut : passe de "peut-être vide" à "targeting-skill validé" ; promotion en
"générateur de findings actif" TOUJOURS en attente d'un lead encaissé que la lecture directe aurait raté.

## LE GERME (d'où ça vient, mot pour mot)

La sécurité de NEXUS est partie d'une comparaison avec une app qui fait presque la même
chose (Haveno). Sans ce foil, on ne serait jamais parti aussi profond. La raison n'est ni
le talent ni la volonté : c'est qu'une comparaison **génère une pente**. "Eux protègent X,
et nous ?", "eux ont raté Y, et nous ?" — chaque écart est un fil, et tirer un fil fait
apparaître le suivant. Une recherche ouverte ("trouve une faille") n'a pas de pente : rien
ne pointe vers la question d'après, donc tu stalles, donc tu restes en surface. Le manque
n'était jamais la méthode. C'était le FOIL — et un foil se FABRIQUE en Phase 0, il ne se
reçoit pas par hasard.

## LA THÈSE EN TROIS LIGNES

1. **Le problème de l'oracle.** Une chasse à l'aveugle n'a pas d'oracle (rien ne dit "cette
   ligne est fausse" sauf ton modèle — qui est celui du dev, absorbé en lisant). Un foil est
   un oracle EMPRUNTÉ : la référence est la bonne réponse, la divergence est le candidat.
2. **Le foil est une carte de saillance.** La sameness porte zéro signal ; la différence
   porte 100% du signal. Le foil jette 95% de l'espace de recherche et te laisse les 5% où
   quelqu'un a pris une décision — et les décisions, c'est là que vivent les bugs.
3. **Le foil donne la DIRECTION *et* l'ARRÊT.** Sans lui la chasse est à la fois directionless
   ET endless (l'attaquant n'a pas de "terminé"). L'ensemble fini des divergences EST la
   worklist ; les avoir toutes exécutées EST la condition d'arrêt (= le NULL-COÛTEUX honnête).

## 🎯 LE VRAI PIÈGE — CLASSER LE STALL (self-knowledge, le cœur)

Quand tu bloques, tu es dans l'UN de TROIS états. Les confondre est la faute capitale, et
**un seul des trois est une vraie limite de profondeur** — les deux autres sont mal nommés
"je ne vais pas assez profond" alors que ce n'en est pas.

- **STALL type 1 — SANS-GRADIENT.** Tu bloques parce que tu n'as **jamais construit le foil**
  (recherche ouverte, pas de jumeau). "Y a rien ici" est FAUX : tu n'as simplement pas d'oracle.
  → **le SEUL des trois qui est une vraie limite de profondeur.** Fix : FABRIQUER le foil en
  Phase 0. Terminal = NOT-STARTED (tu n'as pas commencé l'engagement).
- **STALL type 2 — CUL-DE-SAC MESURÉ.** Jumeau appliqué, gradient épuisé, réfutations EXÉCUTÉES,
  registre d'artefacts en main. S'arrêter est CORRECT ; continuer serait de la persistance
  non-mesurée, que `nullguard` interdit précisément. Ce n'est pas un échec de profondeur —
  **c'est une victoire déguisée en frustration.** Fix : RE-SOURCE. Terminal = NULL-COÛTEUX.
- **STALL type 3 — ACCÈS MURÉ.** Le gradient EXISTE et il est riche, mais la surface est murée
  depuis ton env (IP-block Cloudflare, auth-gate, capability out-of-band manquante). **Pas un
  problème de cerveau — un problème d'INFRA** (IP résidentielle + vrai browser, session throwaway,
  RE d'un binaire). Insister en-env = du temps brûlé. Fix : NOMMER la capacité manquante + armer
  le probe exact. Terminal = HARNESS-SUSPENDED (jamais un null — la surface reste ouverte, armée).

Grounding — **capyfi** sépare les trois sur UNE même cible : `capyfi-SC` (le contrat) = type 2,
cul-de-sac mesuré (jumeau appliqué, divergences exécutées-nulles → RE-SOURCE, victoire déguisée) ;
`app.capyfi.com` (le vrai lending UI, la surface la PLUS riche) = type 3, CF-IP-bloquée depuis
l'env → HARNESS-SUSPENDED (IP résidentielle + browser), pas un null. Deux stalls, deux terminaux,
zéro type-1 : la profondeur n'était jamais le problème sur capyfi.

Les erreurs de classement, toutes fatales (la PREMIÈRE MAXIME au niveau du stall) :

- **Prendre un (2) pour "j'aurais dû creuser"** → auto-flagellation, chasse aux fantômes sur une
  forteresse, mine déjà vidée. (Biais sunk-cost. `feedback-depth-is-an-edge-only-where-ore-remains`, `nullguard` autorise la capitulation MESURÉE.)
- **Prendre un (1) pour un (2)** → "y a rien ici" sans avoir construit le foil. Null prématuré.
  (Biais closure. `feedback-closure-bias-expand-voies-hunt-seams`, `feedback-predicting-executed-null-before-executing-is-a-negative-posture`.)
- **Prendre un (3) pour un (2)** → "forteresse / rien d'exploitable" alors que tu n'as jamais
  ATTEINT la surface riche. Tu enterres la meilleure veine sous un mur d'infra. La surface
  n'est pas nulle — elle est INACCESSIBLE depuis ici. (`wallet-tg-telegram-bfla-engagement`, `desyn-onchain-inert-shell-offchain-frontier`.)
- **Prendre un (3) pour un (1)** → t'acharner à "creuser plus / fabriquer un autre foil" pour
  compenser un mur d'IP. Le cerveau n'y peut rien ; change le vecteur d'accès.

**LES DEUX QUESTIONS QUI TRANCHENT (dans l'ordre) :**

1. *« Le foil/gradient existe-t-il, et la surface est-elle ATTEIGNABLE depuis mon env ? »*
2. *« Ai-je DÉPENSÉ les divergences par exécution ? »*

| Q1 | Q2 | Type | Terminal / Action |
|---|---|---|---|
| Pas de foil nommé / pas de jumeau | — | **1 sans-gradient** | NOT-STARTED. Fabrique le foil (Phase 0). N'écris PAS "null". |
| Foil riche existe mais surface MURÉE | — | **3 accès** | HARNESS-SUSPENDED. Nomme la capacité manquante, arme le probe, sors de l'env. PAS un null. |
| Foil construit + surface atteignable | Non | mi-chasse | Va exécuter le résidu. |
| Foil construit + surface atteignable | Oui, tout mort + registre | **2 cul-de-sac** | NULL-COÛTEUX. RE-SOURCE. N'auto-flagelle pas. |

**Le tell mécanique :** ne peux pas NOMMER le foil → type 1 (retour Phase 0). Peux nommer le foil
mais pas ATTEINDRE la surface → type 3 (change d'infra, ne creuse pas). Peux nommer le foil ET
montrer le registre d'exécution sur une surface atteignable → type 2 (RE-SOURCE, arrête de te flageller).

## PHASE 0 — RECRUTER LE FOIL (avant d'ouvrir le code)

Range les foils par **densité-de-décisions dans le domaine de la cible** (plus la référence a
pris de décisions concrètes dans le même domaine, plus le gradient est riche). Prends le plus
riche disponible ; les deux derniers sont TOUJOURS disponibles et gratuits.

1. **Le vrai jumeau** (fork parent, concurrent audité, l'app qui fait presque pareil = ton
   Haveno). Densité maximale : des milliers de micro-décisions sous les mêmes contraintes.
   → route selon la classe de divergence (voir table). C'est le foil-roi ; cherche-le d'abord.
2. **La lib de référence** (rust-bitcoin, la primitive crypto canonique, le codec standard)
   quand la cible ré-implémente une math connue. → **invfuzz** (harness différentiel exécuté).
3. **Le commit audité (foil TEMPOREL)** : l'audit est l'oracle, tout après le commit béni est
   non-béni. Delta minuscule = espace entier. → **xseam** (sibling post-audit) / Kill-Gate q9.
   Mécanisable : `scripts/manufacture-foil.sh --audit-ref <ref>`.
4. **La forme canonique du type** (ERC-4626/-20 correct, EIP-712, l'AMM x*y=k) quand la cible
   conforme à un standard. Densité faible mais autorité forte sur le peu qu'elle tranche.
   → **darkside Door C** (diff contre la forme canonique, liste chaque déviation).
5. **La suite de tests adverse des devs** : la colonne "pas testé" de leur matrice = worklist.
   → **darkside Door A** (defensive-coverage matrix).
6. **La cible contre ELLE-MÊME (foil INTERNE / mirror)** : la fonction X garde l'input, la
   sœur Y ne garde pas → X est l'oracle de Y. Aucun artefact externe, et la divergence est
   dans l'angle mort exact du dev (il se croit cohérent partout). → **mirror V_in/V_out**
   (Rule 41), **power** (asymétrie d'authz voisine), **xseam** (sibling non-gardé).
   Mécanisable : `scripts/manufacture-foil.sh` (scan guard-asymétrie).
7. **Un incident passé de même classe** (ghost-finding transfer) : densité 1, mais cette
   décision est prouvée exploitable. → **expand-surface** (ghost-finding transfer).

## LA TABLE DE ROUTAGE (signal de cible → foil → veine qui TRANCHE)

Détail complet dans `references/FOIL-ROUTING.md`. Résumé :

| La cible… | Foil à recruter | Veine aval |
|---|---|---|
| est un fork / dérivé | le parent | diff parent (Rule 43, Kill-Gate q10) → la veine de la classe |
| ré-implémente une math de référence | la lib de référence | **invfuzz** |
| a un audit public + du code postérieur | le commit audité (temporel) | **xseam** / q9 |
| conforme à un standard (ERC/EIP) | la forme canonique | **darkside Door C** |
| a une suite de tests adverse | colonne "pas testé" | **darkside Door A** |
| protocole in/out de valeur | lui-même (mirror) | **mirror V_in/V_out**, **extract** |
| surface authentifiée à rôles | la sœur voisine gardée | **power** |
| valeur-invariant stockée + lazy-write | le sibling read gardé | **xseam** |
| forteresse multi-audit, AUCUN delta | *aucun foil bon marché* | construis l'invariant-non-écrit à la main (**darkside Door C** thief-mode) OU RE-SOURCE |

## CONSOMMER LE FOIL (il se DÉPENSE, il ne s'admire pas)

Un foil n'est réel que **consommé**. Le danger (cf. `feedback-apparatus-is-packaging-not-discovery`,
`poke-d'abord`) : "fabriquer le foil" dégénère en jolis harness de diff qui ne produisent
aucun lead — pire que pas de foil, car ça fabrique une fausse couverture.

- Le foil crache une liste RANGÉE de divergences. Range-les par chaînabilité-à-un-impact-payable
  (vol d'abord ; puis gel / halt / gouvernance / insolvabilité / deanon où le programme paie).
- Dépense depuis le HAUT. Chaque divergence = un artefact EXÉCUTÉ (fork, `cast`/`curl` lu,
  disconfirmer + sa sortie), jamais "par inspection / probablement / semble".
- Arrête quand l'EV chute (cap ~6 tentatives exécutées par ligne d'impact qui meurent à 0 → RE-SOURCE).
- Une divergence non exécutée n'est PAS traitée. Un tableau de 200 diffs jamais triés = null type 1.

## LE RENVERSEMENT DE POSTURE (garde la tête du constructeur en étant attaquant)

Sur NEXUS tu étais le **constructeur** : "aller profond" avait un plancher naturel (la garantie
est-elle complète ?). Sur une prime tu es l'**attaquant** : "aller profond" n'a aucun fond, d'où
le stall. Le fix : garde la tête du constructeur en étant attaquant. Reconstruis la garantie que
le dev croit tenir **"par construction"** (son invariant jamais écrit), puis attaque cette
croyance-là avec un acteur non-fiable. Ça redonne à l'attaque une CIBLE (l'invariant) et un
PLANCHER (l'énumération finie des invariants = le registre du NULL-COÛTEUX). C'est la SECONDE
MAXIME rendue offensive : trouver la phrase que le dev n'a pas écrite mais qui compile.

## SORTIE

- **Foil recruté + divergences rangées** → lance la veine aval (proposée, jamais auto-invoquée : U-1).
- **Divergences toutes exécutées-nulles, foil nommé** → NULL-COÛTEUX type 2 (rare, cher, avec
  registre) → RE-SOURCE vers une surface payable. Jamais un badge, jamais de l'auto-flagellation.
- **Foil riche mais surface MURÉE (IP-block / auth-gate / capability out-of-band manquante)** →
  HARNESS-SUSPENDED type 3 : nomme la capacité manquante (IP résidentielle + vrai browser, session
  throwaway, RE du binaire closed), arme le probe EXACT, sors de l'env. La surface reste OUVERTE,
  jamais un null. Problème d'infra, pas de cerveau — ne creuse pas plus pour compenser un mur d'IP.
- **Forteresse multi-audit sans delta** = aucun foil bon marché n'existe → soit la branche chère
  (construire à la main l'invariant que personne n'a écrit — la couture que personne ne possède,
  darkside Door C / xseam), soit RE-SOURCE si le score de saturation est trop haut.
- **Aucun foil nommé** → tu es en stall type 1 : tu n'as pas commencé l'engagement. Retour Phase 0.

## DETTE DE VALIDATION (honnête)

Voir le § STATUT en tête : NOYAU vécu/validé (foil→pente ; mécanisme-foil déjà payé Royco/scene-signer ;
classement du stall a corrigé une vraie décision sur capyfi) ; APPAREIL de fabrication (7 types, routing,
`manufacture-foil.sh`) = OBSERVATION non-exercée, packaging-risk central, promotion SEULEMENT via le
test 1-cible. Nuances restantes : (a) le RITUEL Phase-0-explicite n'a pas de cadavre-qui-paie distinct
de son usage implicite ; (b) la grille 1/2/3 est validée comme DIAGNOSTIC (elle a corrigé une décision),
pas comme générateur de findings ; (c) `manufacture-foil.sh` = worklist heuristique, pas un verdict,
jamais lancé sur une vraie cible engagée. La table de routage est un point de départ, pas une loi.

## ROUTING / SKILLS LIÉS

- **AMONT** — `intake` / `wide` / `xsurface-prioritize` tranchent OÙ dépenser (surface, go/no-go).
  nexus entre APRÈS le go, sur la cible choisie : il décide *contre quoi* tu la compares.
- **AVAL (la veine qui TRANCHE la divergence)** — `invfuzz` (foil lib), `darkside` Door A/C (foil
  suite-de-tests / forme-canonique), `xseam` (foil temporel / sibling), `extract` (mirror math),
  `power` (mirror authz). nexus PROPOSE, l'opérateur confirme et lance (no-auto-orchestration).
- **GARDE** — `nullguard` intercepte le NO-GO tardif non mesuré (= le type-1-lu-en-2). nexus lui
  donne le tell : "aucun foil nommé = pas un verdict". Pour le **type 3 (accès muré)** le terminal
  est HARNESS-SUSPENDED : `solfork` (RE d'un binaire closed), IP résidentielle + vrai browser,
  session throwaway ; nomme la capacité, arme le probe, jamais un null. `killjoy` / `chill` / `report-nerve` = aval rédaction.
- **PRINCIPE** — SECONDE MAXIME (comprendre = agréer = aveugle), PREMIÈRE MAXIME (les deux échecs
  opposés sont fatals), `IMPACT-LEDGER-PLAYBOOK.md` (l'unité d'impact payable par programme).

## MÉTA — REQUIS / INTERDITS

REQUIS :
- Le foil AVANT le code (Phase 0). Sauter ça = retomber en chasse à l'aveugle sans oracle.
- NOMMER le foil explicitement. Un null sans foil nommé est un stall type 1, pas un verdict.
- Chaque divergence percée par un artefact EXÉCUTÉ avant d'être traitée. Le foil se dépense.
- Classer le stall (1 vs 2) avant d'écrire "null" OU de creuser plus. La question qui tranche est obligatoire.

INTERDIT :
- Hardcoder une cible / un jumeau précis / un 0-day dans ce skill. Les hypothèses actives vivent
  dans les notes d'engagement, pas dans la méthodo durable.
- Auto-invoquer la veine aval (U-1). nexus propose ; l'opérateur lance.
- Admirer un foil (tableau de diffs non exécuté) et l'appeler couverture. Non exécuté = non traité.
- Conclure "forteresse / null" sans avoir NOMMÉ le foil construit ni montré le registre d'exécution.
- Auto-flageller sur un type 2 mesuré (chasse aux fantômes) OU pré-déclarer un type 2 sans foil (null prématuré).
