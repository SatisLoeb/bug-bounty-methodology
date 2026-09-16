---
name: xsurface-prioritize
description: >
  Threat modeling & allocation de surface TOP-DOWN, à lancer AVANT toute lecture profonde de code :
  "voici le système, où sont les chemins à haute valeur atteignables, et cette cible vaut-elle mon
  temps ?". Le ROI principal n'est PAS de trouver plus de chaînes — c'est de ne PAS brûler des
  semaines sur des cibles ingagnables (les findings meurent d'exclusion de scope / dup / atteignabilité
  absente, pas d'un défaut technique). Modélise assets→valeur terminale, frontières de confiance,
  acteurs, graphe de chemins, PUIS front-load les gates (atteignabilité q2 manuel + recevabilité :
  scope-exclusion, dup, edge-fit) et n'engage la profondeur QUE sur ce qui survit. Utiliser dès que la
  question est "par où commencer", "cette cible vaut-elle mon temps", "quel chemin prioriser", "go /
  no-go sur cette cible", "threat model", "allocation de surface", "modélise la surface". Tourne EN
  AMONT de xseam (couture d'invariant) et de xchain-triage-mindset (escalade bottom-up une fois
  dedans) : ce skill décide SI et OÙ on entre ; eux fournissent les techniques une fois la cible
  engagée.
handles: xvush, MalikX
---

# XSURFACE-PRIORITIZE — Threat Modeling & Allocation de Surface (Top-Down)

## Principe Fondamental

XCHAIN est bottom-up : "j'ai un bug, avec quoi je le chaîne ?" — escalade depuis un finding. Ce skill
est top-down : "voici le système, où sont les chemins à haute valeur atteignables, et cette cible
vaut-elle mon temps ?" — allocation AVANT les findings.

Le ROI principal n'est PAS de trouver plus de chaînes. C'est de ne pas brûler des semaines sur des
cibles ingagnables. Les findings meurent rarement d'un défaut technique. Ils meurent d'exclusion de
scope (admin-trust, arbitrage cross-chain), de dup, ou d'atteignabilité absente. Ce skill filtre ces
morts AVANT la lecture profonde du code, pas après.

Règle de fonctionnement : on ne lit pas 35 contrats pour découvrir au bout qu'aucun chemin n'est
recevable. On modélise d'abord, on filtre, puis on engage la profondeur uniquement sur ce qui survit.

---

## ÉTAPE 1 — ASSETS & VALEUR TERMINALE

On trie la surface par ce qui se vole ou se casse, et combien — pas par endpoint trendy. C'est ce qui
rend une priorisation une priorisation.

Hiérarchie type (DeFi), de la plus haute valeur à la plus basse :

1. Vol direct de fonds (drain de vault/pool).
2. Insolvabilité du protocole (bad debt, sous-collatéralisation forcée).
3. Intégrité de prix / oracle (manipulation exploitable financièrement).
4. DoS de fonds (fonds bloqués, retraits cassés).
5. Capture de gouvernance.
6. Information (souvent faible en SC ; plus élevé en web2 si PII/contrats).

Pour chaque asset : noter le max loss ($ ou criticité). C'est le numérateur du scoring. Pas de chiffre
inventé : ancrer sur le TVL exposé réel ou la valeur du rôle/donnée.

---

## ÉTAPE 2 — FRONTIÈRES DE CONFIANCE & POINTS D'ENTRÉE

Où l'input non fiable franchit l'exécution fiable. Lister TOUS les points d'entrée :

**SC / DeFi :**
- Fonctions external/public.
- Fonctions privilégiées mais réellement atteignables (vérifier l'access control réel, pas supposé).
- Handlers de messages cross-chain (lzReceive, CCIP receive, bridge onMessage).
- Lectures oracle (Chainlink, TWAP, spot Uniswap).
- Surfaces de callback / hook (afterSwap, beforeSwap, hooks ERC777/ERC721, callbacks de flashloan).
- Fonctions initialize / upgrade / proxy admin.
- Math de fees / shares / NAV (entrée des edge cases : totalSupply == 0, division, arrondi).
- Vérification de signature (permit, SIWE, EIP-712, schémas threshold).

**Web2 / API / IA :** router vers xchain-triage-mindset *(process manuel)* pour l'énumération de
surface (/ai/, /llm/, /mcp/, vector DB, secrets bundle), puis appliquer ce wrapper par-dessus.

---

## ÉTAPE 3 — ACTEURS & CAPACITÉS

Qui peut quoi, et ce que donne le franchissement d'une frontière.

Pour chaque acteur, noter : capacité AUTORISÉE | ce qu'un franchissement de frontière lui donnerait.

- Anonyme / caller externe
- Token holder / LP
- Keeper / relayer / bot
- Admin / owner / governance
- Peer cross-chain (contrat distant supposé de confiance)
- MEV searcher
- Protocole tiers qui compose par-dessus

Point critique : un acteur "de confiance" (peer cross-chain, keeper) est une frontière, pas une
garantie. Le vrai chemin part souvent d'un acteur supposé bénin dont l'hypothèse de confiance ne tient
pas (cf. M-H1 Bridge Peer Trust Surface).

---

## ÉTAPE 4 — GRAPHE DE CHEMINS

Modéliser le système en graphe :

- **Nœuds** = états / capacités (ex. "attaquant anonyme", "détient role X", "fonds dans vault", "prix corrompu").
- **Arêtes** = fonctions / messages qui font transiter d'un nœud à l'autre.
- Un finding candidat = un CHEMIN d'un nœud attaquant-atteignable vers un nœud asset (Étape 1).

C'est la version DÉRIVÉE DU SYSTÈME du chaînage, pas une liste de paires fixes.

Sources des arêtes candidates :
- **Pattern DB (M-H1)** : injecter les anti-patterns connus comme arêtes à tester en priorité (ex.
  "destructive ops ont une auth plus faible que les reads", "Library Stock vs Audit Custom", "Bridge
  Peer Trust Surface").
- **XCHAIN** : fournit les heuristiques de pivot (paires auth-bypass + privesc, etc.) pour raccorder
  des arêtes en chemin.

Sortie de l'étape : liste de chemins candidats P-01, P-02, … chacun écrit comme
`[entrée] →(arête)→ [pivot] →→ [asset]`.

---

## ÉTAPE 5 — GATE D'ATTEIGNABILITÉ (MANUEL — logique q2)

Étape manuelle. Le Kill Gate q2 n'est pas branché programmatiquement ici ; on l'exécute à la main.

Pour CHAQUE arête de CHAQUE chemin candidat, répondre explicitement :
1. Cette arête est-elle appelable par l'acteur supposé, compte tenu de l'access control RÉEL (lu dans
   le code, pas supposé) ?
2. L'état précondition de cette arête est-il atteignable par une séquence d'appels autorisés ?

Verdict par chemin :
- **reachable** — chaque arête confirmée appelable + préconditions atteignables.
- **conditionnel(état X)** — atteignable seulement si un état non confirmé existe (à vérifier passivement).
- **unreachable** — au moins une arête est bloquée par l'access control ou une précondition impossible.

`unreachable` → DROP immédiat. Ne pas continuer à scorer un chemin mort. `conditionnel` → ne peut PAS
être P0 tant que l'état n'est pas confirmé (cast call / lecture de state read-only).

---

## ÉTAPE 6 — GATE DE RECEVABILITÉ (front-loaded)

C'est la colonne vertébrale du skill. Il tourne AVANT l'audit profond, pas après. Trois filtres :
exclusion de scope, dup, edge-fit.

### 6a. Exclusion de scope

**EXCLUSIONS DURES** — si c'est le SEUL chemin d'impact → no-go immédiat :
- Centralisation / admin-trust : un rôle privilégié qui "se comporte mal". (a tué Centrifuge #283)
- Arbitrage cross-chain / MEV comme seul impact. (a tué Centrifuge #283)
- Précondition = clé déjà compromise ou admin déjà malveillant.
- Composant / contrat hors du scope explicite du programme.
- "Théorique" : aucun chemin d'exploit concret, "pourrait en principe".
- Déjà connu : acknowledged dans un audit antérieur, listé en known-issues, ou self-reported.
- User error / phishing / frontend-only.

**EXCLUSIONS MOLLES** — downgrade probable, pas forcément no-go :
- Governance / timelock peut corriger avant impact.
- Griefing / gas sans perte de fonds (dépend du programme).
- Précondition externe improbable mais possible (oracle dans un état spécifique).

Procédure : matcher chaque chemin contre les DURES d'abord. Si l'unique chemin d'impact touche une dure
→ DROP. C'est le filtre qui aurait sauvé Symbiotic et Centrifuge avant la lecture profonde.

### 6b. Risque de dup

**HIGH dup (deprioritize) :**
- Contest public très peuplé (beaucoup de wardens — typiquement C4 public).
- Audité récemment par une bonne firme : le textbook est déjà parti.
- Finding "évident" (reentrancy classique sur protocole populaire).
- PoC public ou incident similaire dans DefiHackLabs.

**LOW dup (= ton edge, peu de concurrence) :**
- Inconsistance cross-langage Rust/Solidity (peu de wardens lisent le Rust).
- Correctness crypto (FROST/CLSAG/Schnorr/signatures, decimals, key overlap).
- Config cross-chain / peer trust / DVN.
- Périphérie post-audit / config drift / hygiène secrets.

### 6c. Edge-fit

**HIGH (joue ton avantage comparatif) :**
- Audit cross-program Rust + Solidity (drift d'implémentation entre langages).
- Protocoles cryptographiques.
- Surface cross-chain / bridge peer / config.
- Chaînes SC multi-étapes profondes (type `_afterSwap` underflow → deadlock → drain).
- Périphérie post-audit (config, secrets, état on-chain post-déploiement).

**LOW (commoditisé, forte concurrence, faible marge) :**
- XSS / CSRF web2 générique.
- "Surface IA trendy" sans angle unique mesurable.

---

## ÉTAPE 7 — SCORING & SORTIE

Le scoring ORDONNE TON TEMPS. Ce n'est pas le score du rapport. Le score du rapport est piloté par
l'impact terminal et vit dans XCHAIN — jamais une somme de catégories, jamais un float inventé.

Pour chaque chemin survivant aux gates, noter en Low / Med / High :
- **VALEUR** (Étape 1, impact terminal)
- **ATTEIGNABILITÉ** (Étape 5)
- **EDGE-FIT** (6c)
- **Pénalités** : SCOPE-EXCLUSION MOLLE résiduelle, DUP

Règle de décision (ordinal, pas de faux float) :
- **P0** — commit profond : VALEUR High + reachable + EDGE-FIT High + DUP Low.
- **P1** — vaut un PoC : VALEUR ≥ Med + reachable + (EDGE-FIT High OU DUP Low).
- **P2 / watch** : conditionnel(état X) non confirmé, ou valeur moyenne avec dup moyen.
- **DROP** : exclusion DURE sur l'unique chemin, OU unreachable, OU (VALEUR Low + DUP High).

### Template de sortie (un dossier par cible)

```
TARGET: [nom] | PLATFORM: [Cantina/C4/...] | SCOPE: [contrats/endpoints in-scope]

ASSETS (triés par valeur terminale):
  A1: [asset] — max loss: [$/criticité]
  A2: ...

ENTRY POINTS / TRUST BOUNDARIES:
  - [liste]

ACTORS:
  - [acteur] : autorisé=[...] | franchissement donne=[...]

CANDIDATE PATHS:
  P-01: [entrée] →(arête)→ [pivot] →→ [asset A1]
        reachability (q2 manuel): reachable | conditionnel(état X) | unreachable
        scope-exclusion: [aucune | molle: ... | DURE: ...]
        dup: Low|Med|High  ([raison])
        edge-fit: Low|Med|High
        → TIER: P0|P1|P2|DROP   ([1 ligne de rationale])
  P-02: ...

DÉCISION GLOBALE: [GO profond sur P-0x | NO-GO cible (raison) | WATCH jusqu'à confirmation de X]
TEMPS ALLOUÉ: [estimation honnête]
```

---

## ROUTING

- Cible = smart contract / DeFi → mode SC (défaut). Étapes 1→7 avec entrées SC.
- Cible = web2 / API / IA → router l'énumération de surface vers xchain-triage-mindset *(process
  manuel)*, PUIS appliquer ce wrapper (valeur / atteignabilité / recevabilité) par-dessus. Le threat
  model décide SI on entre ; XCHAIN fournit les techniques une fois dedans.
- N-day détecté → le pipeline vitesse de XCHAIN ne se déclenche QU'APRÈS qu'une cible a passé ce gate
  de recevabilité. La vitesse ne court-circuite jamais la recevabilité. Une fenêtre courte ne justifie
  pas un rapport non triagé.

---

## MÉTA — REQUIS / INTERDITS

**REQUIS :**
- Vérification passive uniquement (cast call, curl read-only, grep, lecture de repo public).
- Scope checking avant toute chose.
- Divulgation responsable, timeline correcte.
- Le gate de recevabilité (Étape 6) tourne AVANT l'audit profond.
- Un chemin n'est "valide" que via son maillon prouvé ET in-scope le plus faible.

**INTERDIT :**
- Hardcoder un 0-day ou un version-pin spécifique dans ce skill. Les hypothèses actives (ex. une lib X
  version Y suspectée) vivent dans les notes d'engagement actif, PAS dans la méthodo durable. Une
  hypothèse sans PoC n'est pas un finding.
- Claim empirique absolu ("100% sans auth"). Heuristique oui, certitude non.
- Scorer une chaîne comme la somme de catégories. Sévérité = impact terminal concret.
- Technique active, write, modification d'état, typosquat, package malveillant, cible hors scope.

---

## SKILLS & ASSETS LIÉS

- **xchain-triage-mindset** *(process MANUEL — pas un skill invocable)* : escalade bottom-up une fois la cible engagée (techniques, chaînage, reporting chaîné).
- **Pattern DB (M-H1)** : fournit les arêtes candidates du graphe (Étape 4).
- **Kill Gate** : q2 (atteignabilité — ici manuel), q6 (known vuln → signal de dup), q7 (upgradeability), q9 (post-audit periphery).
- **xseam** : AVAL — une fois la cible P0/P1, chasse la couture d'invariant (staleness write-lazy / read-non-gardé).
- **chill** : rédaction du rapport — uniquement APRÈS triage adversarial complet du finding retenu, jamais avant.
