---
name: nullguard
description: >
  Activer ce skill AU MOMENT EXACT où une session (Claude Code ou chat) est sur le point
  de conclure qu'une cible est "trop dure", "une forteresse", "imprenable pour un chercheur
  solo", "trop saturée", ou "rien d'exploitable ici". Déclenche l'audit adversarial du VERDICT
  NÉGATIF lui-même — le symétrique de killjoy, qui, lui, audite un finding positif. Objectif n°1 :
  interdire toute capitulation NON MESURÉE, sans supprimer les capitulations MESURÉES. Un verdict
  de difficulté n'est valide que s'il cite un chiffre (score de saturation), une veine
  nommée-et-testée-nulle, ou une exclusion Phase-0 nommée. Sinon ce n'est pas un verdict, c'est
  une passe superficielle déguisée en résultat — et le skill force soit la continuation, soit
  l'aveu explicite "non concluant". Tourne EN AVAL de xsurface-prioritize (qui décide GO/NO-GO
  au jour 1) : nullguard intercepte le NO-GO tardif prononcé À MI-CHASSE.
handles: xvush, MalikX
---

# NULLGUARD — Gate de Discipline sur les Verdicts Négatifs

## Principe Fondamental

killjoy audite un finding POSITIF avant soumission : "ta preuve tient-elle ?"
nullguard audite un verdict NÉGATIF avant abandon : "ton abandon tient-il ?"

Le déclencheur est un moment LINGUISTIQUE, pas une phase de workflow. Dès qu'une session
produit — spontanément — l'une de ces formes, ce skill s'active AVANT que la phrase ne parte :

- "c'est trop dur / trop complexe pour trouver quelque chose"
- "c'est une forteresse"
- "pour un chercheur solo, c'est hors de portée"
- "cette cible est trop saturée / trop auditée"
- "je ne trouve rien d'exploitable / la surface est propre"

Ces phrases ont un défaut structurel commun : ce sont des affirmations FORTES ("imprenable")
tirées de preuves FAIBLES (une passe partielle de la surface). C'est exactement le security
theatre que Malik chasse chez les autres — une conclusion dont la confiance dépasse la mesure —
retourné contre le modèle lui-même. nullguard est le détecteur de ce theatre appliqué aux nulls.

**Ce que le skill NE fait PAS :** il ne force pas l'optimisme. Un "forteresse" MESURÉ au jour 1
(score de saturation ≥ 60, ou set d'audit couvrant la veine) est un outil qui SAUVE du temps —
c'est le verdict que `saturation-score.sh` existe pour produire. nullguard le laisse passer
intact. Il ne tue QUE le null non chiffré prononcé à mi-chasse par épuisement.

Règle de fonctionnement : un verdict de difficulté sans citation n'est pas rejeté comme faux —
il est REQUALIFIÉ en "passe superficielle, non concluant", ce qui interdit de le présenter
comme un résultat et force le prochain pas.

---

## ÉTAPE 0 — RESET DU PROFIL ACTEUR (retire l'inférence paresseuse par défaut)

Le mot "chercheur solo" dans "forteresse pour un chercheur solo" n'est PAS une comparaison
toi-vs-équipe. C'est le profil MÉDIAN que le modèle assigne par défaut faute de mieux : lecteur
à la main, sans corpus, sans fork, sans RE du bytecode, qui abandonne quand la surface est large.
Ce profil est faux pour cet opérateur. Réinjecter l'arsenal réel AVANT de raisonner sur la
difficulté :

- **NUKE** — saturation-score (RE-SOURCE au niveau repo) + vein-filter vierge/labouré (la
  saturation est une propriété de la MONEY-PATH, pas du repo).
- **solfork** — fork live du BPF DÉPLOYÉ, gate-piercing par forwarder, caller-reachability.
  Le closed-source n'est pas un mur : le bytecode déployé EST la vérité terrain.
- **xseam** — chasse mechanism-down (invariant produit → valeur stockée → writer paresseux
  vs reader money-move non gardé). Plus FORT sur les produits nouveaux (pas de checklist swarm).
- **Kill-gate Q5b** (fenêtre-acteur), **tombstone check** `git log -S` (index-fantôme des
  rapports fermés), **corpus** Solodit/zkBugs/OtterSec.

Conséquence : la seule différence réelle que ce profil ne comble pas est la COUVERTURE en
heures-homme (8 auditeurs × 6 semaines vs un opérateur). Mais cette différence ne rend pas la
cible imprenable — elle rend imprenable la STRATÉGIE "couvrir toute la surface". Or la stratégie
de cet opérateur n'est pas la couverture, c'est la veine vierge. Le verdict "forteresse" au niveau
couverture mesure la mauvaise chose.

---

## ÉTAPE 1 — NIVEAU DU VERDICT : REPO OU VEINE ?

Un "forteresse" prononcé au niveau REPO est INVALIDE PAR CONSTRUCTION — c'est la thèse centrale
de l'opérateur : "8 audits + 300 findings Solodit" dit que le REPO est populaire, pas que TA
VEINE est prise. Le modèle conclut presque toujours au niveau repo ("9 audits → forteresse").
C'est l'inférence la plus paresseuse qu'il fait.

- Si le verdict est au niveau REPO → REJET AUTOMATIQUE. Le reformuler au niveau veine : "la
  money-path X est-elle prise ?" Une money-path à la fois. Router vers le vein-filter de NUKE
  (vierge/labouré) et vers xseam (l'invariant produit non-checklisté).
- Si le verdict est au niveau VEINE ("la veine X spécifiquement est nulle") → passer à l'Étape 2,
  il est candidat à la validité.

---

## ÉTAPE 2 — LE GATE DE CITATION (le cœur du skill)

Un verdict de difficulté/null est VALIDE si et seulement s'il cite AU MOINS UN de ces quatre
artefacts mesurés. Sinon il est requalifié.

1. **SCORE DE SATURATION ≥ 60** — sortie de `saturation-score.sh` sur la cible (audit_count×10
   cap50 + top_tier 15 + devtests adverses 15 + fresh 10). ≥60 = HIGH = RE-SOURCE légitime.
   → verdict VALIDE : "RE-SOURCE, score N".
2. **VEINE NOMMÉE + TESTÉE-NULLE EN EXÉCUTION** — la veine est identifiée (⟨invariant-cassé,
   mécanisme, garde-manquante⟩, pas un nom de fonction) ET une passe exécutée l'a rendue nulle
   (fork solfork single-input null discipliné, Halmos sans contre-exemple avec assumptions
   listées, PoC qui refuse de construire l'état). Inférence ≠ exécution : "ça a l'air gardé" ne
   compte pas.
3. **EXCLUSION PHASE-0 NOMMÉE** — une exclusion dure identifiée par son nom (admin-trust, deployer
   responsibility, known-issue/audit-acknowledged, cross-chain-arb-seul, hors-scope, submission-fee
   non refundable, set d'audit solfork step 2b couvrant la veine déployée). → verdict VALIDE :
   "DROP, exclusion X".
4. **TOMBSTONE** — `git log -S "<phrase défensive>"` sur le repo cible renvoie un commit de doc
   défensive daté dans la vie du programme = rapport déjà fermé sur cette veine. → VALIDE : "déjà
   filé, tombstone commit <hash>". (⚠️ vérifier `git rev-parse --is-shallow-repository` d'abord :
   un clone shallow produit un faux négatif de tombstone — `git fetch --unshallow` avant de citer.)

**Si AUCUN des quatre n'est cité** → le verdict est requalifié en :
> "PASSE SUPERFICIELLE, NON CONCLUANT — fraction de surface couverte : [X], veines testées-nulles :
> [liste], veines non touchées : [liste]."

et la session est OBLIGÉE de choisir explicitement : (a) continuer sur une veine non touchée
nommée, ou (b) déclarer le RE-SOURCE mais alors le faire passer par l'Étape 3, PAS le présenter
comme un fait technique sur la cible.

---

## ÉTAPE 2bis — LA COUCHE GARDE EST UNE VEINE, PAS DE LA PLOMBERIE

Le trou de couverture le plus insidieux, parce qu'il produit un null qui SEMBLE mesuré : la
coverage-fraction de l'Étape 3 est honnête sur les veines *money-path* mais son **dénominateur
exclut silencieusement la couche GARDE** — le middleware qui décide QUI atteint la money-path
(auth, captcha, csrf, rate-limit, signature-check, allowlist/denylist, pause/state-gate, ownership).
"J'ai testé-null 4 des 6 veines money-path" peut être vrai ET le null quand même faux, parce que la
couche garde n'était même pas dans l'énumération des veines.

**Pourquoi c'est une veine à part entière, disjointe :**
- Prouver qu'un handler CONSERVE la valeur ne dit RIEN sur le fait que la porte qui l'admet TIENT.
  "Le money-path est robuste" et "le garde qui admet l'appelant enforce" sont **deux audits
  disjoints** — un handler parfaitement conservateur derrière un garde fail-open = n'importe qui
  atteint le money-path. Auditer le premier n'apprend rien sur le second.
- Le mode de défaillance d'un garde n'est JAMAIS une faute de valeur/crypto/arithmétique — c'est un
  **fail-open de control-flow** : `write-error-mais-pas-de-return`, `missing-return-après-réponse-erreur`,
  `continue` au lieu de `return`, erreur `logged-then-ignored`, break précoce, erreur avalée dans un
  defer. Ce défaut vit dans le CORPS du garde, **invisible à une trace de money-path**. Une passe
  money-flow peut être exhaustive et le rater intégralement.
- C'est la Maxime 1 exacte : la présence du contrôle (`RequiresCaptcha:true`, un `onlyOwner`, un
  filtre 401) prouve qu'il EXISTE, jamais qu'il TIENT. Concéder "porte présente → protégé" sans lire
  l'enforcement = l'hypothèse non-exécutée que la maxime interdit. Percer la porte ici = **lire le
  corps du garde**, pas le greper.

**Le gate mécanique (obligatoire avant tout null sur une cible avec surface authentifiée/gardée) :**
1. Énumère CHAQUE garde sur un chemin qui mute valeur/état, comme sa propre classe de veine (jamais
   fondue dans "money-path").
2. **Lis le corps de chaque garde EN ENTIER** (grep ≠ audit) et écris une ligne de coverage explicite :
   `<garde> : lu en entier, enforcement vérifié`. Si tu ne l'as que grepé → c'est **UNAUDITED**, dis-le
   dans le ledger, ce n'est pas testé-null.
3. **Aligne TOUTES les branches de rejet côte-à-côte** et vérifie que chacune `return`/abort AVANT
   l'appel protégé. Si N-1 branches abortent et 1 tombe à travers → **fail-open**, c'est le finding.
   Tell corroborant : un log/side-effect de succès qui tire aussi sur le chemin d'échec.
4. **"Utility / plomberie / infra" est la catégorie d'auto-tromperie** où se cache la surface
   non-auditée. Si tu as classé un garde là, il est UNAUDITED — sors-le et nomme-le.

Tells greppables du fail-open : `if <bad> { writeError(...) }` sans `return` en dessous ;
`http.Error`/`JsonErrorResponse`/`res.status(4xx)` suivi d'un fall-through vers le handler ;
`continue` là où les branches sœurs `return`.

**Sur cible N-audits :** l'AXIOME `P(bug-de-classe survit N audits)≈0` ne s'applique qu'à ce que les
auditeurs ont RÉELLEMENT couvert. Un garde dans un coin que tu n'as pas vérifié qu'ils couvraient
n'est PAS class-dead — il est non-audité. Le fail-open est une classe, et une classe non-balayée
n'est pas morte.

*(Origine terrain : Rootstock Flyover LPS, `captcha.go` — branche `!validCaptcha` écrit un 500 sans
`return` → `next.ServeHTTP` tourne → `acceptQuote` sans captcha → griefing de réservation de liquidité
sur tous les LP. J'avais tracé le money-flow "NULL-COÛTEUX exhaustif" et grepé le middleware sans lire
son corps. L'opérateur a aligné les 5 branches côte-à-côte ; 4 return, 1 non. Cf.
`feedback-audit-the-guard-not-just-the-money-path.md`.)*

---

## ÉTAPE 3 — COÛTEUX ≠ IMPRENABLE

Le glissement le plus fréquent : le modèle mesure "coûteux" (j'ai exploré 20 % de la surface, rien
de facile) et rapporte "imprenable" (la cible est un mur). Ce sont deux verdicts différents.

- **COÛTEUX** = décision de RESSOURCE. Légitime, mais c'est un arbitrage temps, pas une propriété
  de la cible. Le trancher avec le score de saturation (Étape 2.1), pas au feeling. "Je ne veux
  pas y passer 3 jours de plus" est honnête ; "c'est imprenable" ne l'est pas si tu n'as pas mesuré.
- **IMPRENABLE** = propriété de la cible. Exige la citation Étape 2.2/2.3/2.4 sur CHAQUE veine
  à haute valeur, pas seulement celles déjà lues.

Test mécanique : le verdict cite-t-il une FRACTION DE COUVERTURE ("j'ai testé-null 4 des ~6 veines
money-path, les 2 restantes sont [X,Y]") ? Sans fraction, "imprenable" extrapole depuis un
échantillon non déclaré = theatre. Avec fraction, c'est un état d'avancement honnête, et les
veines non couvertes sont la prochaine action, pas la preuve du mur.

---

## ÉTAPE 4 — SORTIE

Un et un seul de ces trois verdicts sort du gate. Jamais un "trop dur" nu.

```
CIBLE: [nom] | VEINE(S) EN CAUSE: [liste au niveau money-path, pas repo]

VERDICT: [ RE-SOURCE | CONTINUER | NON-CONCLUANT ]

  RE-SOURCE (cible morte, mesurée) — cite:
    [ score saturation N≥60 | exclusion Phase-0 nommée | set d'audit couvre la veine (solfork 2b) ]
    → prochaine cible / tier-migration.

  CONTINUER (verdict null invalidé) — la ou les veines non couvertes:
    [ V-01: ⟨invariant, mécanisme, garde-manquante⟩ — non touchée ]
    [ V-02: ... ]
    → engager V-0x. Interdit de conclure avant de l'avoir testée-nulle EN EXÉCUTION.

  NON-CONCLUANT (passe superficielle honnête) — état, pas résultat:
    couverture money-path: [fraction]  |  veines testées-nulles: [liste]  |  non touchées: [liste]
    couche GARDE: [chaque garde: lu-en-entier+branches-alignées / UNAUDITED-grepé-seulement]
    → soit continuer (route CONTINUER), soit ranger la cible en WATCH avec la dette explicite.
```

---

## MÉTA — REQUIS / INTERDITS

REQUIS :
- Toute assertion de difficulté cite un artefact mesuré (Étape 2) OU se rebaptise NON-CONCLUANT.
- Un null n'est "prouvé" que via une veine EXÉCUTÉE-nulle, jamais inférée d'une lecture.
- Le verdict s'exprime au niveau VEINE / money-path, jamais au niveau repo.
- La fraction de couverture est déclarée dès que le mot "imprenable/forteresse/propre" apparaît.
- **La couche GARDE (auth/captcha/csrf/rate-limit/signature/allowlist/pause/ownership) est une classe
  de veine séparée dans le dénominateur de couverture (Étape 2bis).** Chaque garde sur un chemin
  mutant a une ligne `lu en entier, branches de rejet alignées` — sinon il est UNAUDITED, pas
  testé-null.

INTERDIT :
- **Déclarer un null / "surface propre" quand un garde n'a été que GREPÉ, pas lu en entier.** Grep ≠
  audit ; un garde non-lu est une porte non-percée. Un money-path prouvé conservateur ne couvre PAS
  la porte qui l'admet (audits disjoints, Étape 2bis).
- **Supprimer un verdict de difficulté MESURÉ.** C'est le miroir cassé du problème : Ammalgam
  prouve qu'un "forteresse" chiffré au jour 1 sauve du temps. nullguard déplace le verdict en
  amont et le mesure ; il ne l'interdit pas. Un skill qui ne dit jamais RE-SOURCE brûle les 50 $
  et les 8 rounds que `saturation-score.sh` existait pour éviter.
- Conclure "chercheur solo ne peut pas" sans avoir passé l'Étape 0 (reset profil).
- Extrapoler "imprenable" depuis une fraction de surface non déclarée.
- Citer un tombstone / une absence lu sur un clone shallow sans `--unshallow` préalable.
- Transformer nullguard lui-même en objet à polir. Le skill s'exécute et rend un verdict ; il ne
  se raffine pas à la place de la chasse. (Même piège que le core saturé : l'outil infiniment
  améliorable qu'on perfectionne au lieu de courir la cible fraîche.)

---

## SKILLS & ASSETS LIÉS

- **xsurface-prioritize** : tranche GO/NO-GO au JOUR 1 (allocation amont). nullguard intercepte le
  NO-GO prononcé TARD, à mi-chasse — le cas que xsurface ne couvre pas parce que la cible avait
  déjà passé le gate d'entrée.
- **saturation-score.sh** (NUKE) : fournit la citation Étape 2.1. C'est l'artefact chiffré qui
  rend un RE-SOURCE valide.
- **NUKE vein-filter** : fournit la reformulation Étape 1 (repo → veine, vierge/labouré).
- **solfork** : fournit la citation Étape 2.2 (fork-null exécuté) et 2.3 step 2b (set d'audit).
- **xseam** : fournit les veines non couvertes de l'Étape 4 CONTINUER (l'invariant produit que le
  swarm ne checkliste pas — la réponse à "la surface est propre").
- **killjoy** (triageur rabat-joie) : le SYMÉTRIQUE positif. killjoy tue un finding faible ;
  nullguard tue un abandon faible. Même discipline, signe opposé.
- **feedback-audit-the-guard-not-just-the-money-path** (mémoire) : le writeup complet de l'Étape 2bis
  — pourquoi la couche garde est un audit disjoint, la classe fail-open, et le trou de couverture
  "plomberie" qui a fait passer un vrai finding (Flyover LPS captcha) sous un "NULL exhaustif".
