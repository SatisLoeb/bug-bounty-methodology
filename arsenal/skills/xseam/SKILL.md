---
name: xseam
description: >
  Activer ce skill UNE FOIS la cible engagée — post-xsurface-prioritize (go/no-go tranché),
  accès obtenu par source publique OU par RE (solfork sur closed-Solana). La question n'est plus
  "quelle cible" mais "OÙ est le bug que l'essaim n'a pas vu". Oriente la lecture profonde vers la
  classe qui a payé sur Perena #83 : staleness d'une valeur-invariant produit à une couture
  write-paresseux / read-non-gardé — concrètement le SIBLING NON-GARDÉ d'un chemin déjà
  audité-et-gardé. Principe : le RE et l'accès ne sont JAMAIS l'edge, le choix du mécanisme l'est
  (même RE, sans ce choix, Perena ne donnait rien). Utiliser dès que la question est "où je regarde",
  "quel mécanisme", "quelle est la vraie faille ici", "le RE ne suffit pas à trouver", "trouve le
  sibling non-gardé", "quel invariant ce produit promet". Tourne EN AVAL de xsurface-prioritize (qui
  tranche la cible) et EN AMONT de la vérif exécutée (solfork/Foundry) + du killjoy-triage. NE
  remplace NI la priorisation de surface (amont) NI le triage rabat-joie (aval). Opérationnalise UNE
  instance haute-valeur de la SEAM-THESIS (la couture temporelle intra-protocole) en drill répétable.
handles: xvush, MalikX
---

# XSEAM — Chasse à la Couture d'Invariant (Mechanism-Down)

## Principe Fondamental

xsurface-prioritize tranche "cette cible vaut-elle mon temps". solfork/RE donne l'ACCÈS au bytecode
closed. Ni l'un ni l'autre ne trouve le bug. Le bug vient d'un endroit où tu **choisis** de regarder,
et ce choix est le seul edge durable — sur Perena, avec le même RE et sans ce choix, tu ne trouvais
rien.

L'essaim chasse des CLASSES DE CODE (overflow, reentrancy, access control). Ce skill chasse un
INVARIANT PRODUIT à sa couture. C'est mechanism-down : d'abord ce que le produit PROMET, ensuite la
valeur stockée qui porte la promesse, ensuite le chemin qui la touche sans le garde que ses frères
ont reçu. Le RE t'a mis dans la pièce ; xseam te dit quel mur tapoter.

Grounding — Perena #83 (High). `instant_unstake_junior` price la sortie sur un `share_price` stocké
que seul un booking admin (`apply_capital_loss`) rafraîchit : la tranche PROMET d'absorber les pertes,
mais le chemin de sortie lit la promesse périmée. Ce n'est pas une faille de code, c'est une couture
d'invariant. Et c'est le sibling non-gardé : M-01 (Hashlock, commit 97b69ae) avait gardé les parents
mint/burn ; l'unstake tranche, ajouté APRÈS l'audit, n'a hérité de rien.

---

## LA CLASSE

Une valeur STOCKÉE `V` qui incarne un invariant du produit, ÉCRITE paresseusement (souvent par une
instruction privilégiée/périodique séparée), et LUE par un chemin money-move non-gardé qui consomme
`V` périmée dans la fenêtre entre deux écritures.

Les trois pièces, toujours :
- **L'invariant** — la promesse du produit (junior absorbe la perte ; le collatéral vaut X ; le
  staker reçoit son yield pro-rata).
- **Le porteur** — la valeur d'état qui encode l'invariant (`share_price`, NAV, valeur collatéral,
  reward-index, funding, cumulative-index).
- **La couture** — l'écart temporel/trust entre qui ÉCRIT `V` (lazy, privilégié, séparé) et qui la
  LIT pour bouger de l'argent (exit, liquidate, settle, redeem, borrow) SANS forcer sa fraîcheur.

Le finding = la fenêtre. Le SHARP finding = le chemin qui saute le check de fraîcheur/sanity que ses
siblings appliquent (Perena : l'unstake junior est le SEUL exit découplé du vault qui saute le sanity
check `RoundingImpact` sur lequel tous les autres exits revert).

---

## POURQUOI L'ESSAIM LA RATE

1. **Invariant-produit, pas pattern-code.** Il faut modéliser l'économie du produit AVANT de voir
   qu'il y a un invariant à casser. Un scanner/warden pattern-matche du code ; ça demande de savoir
   ce qu'une tranche / un vault / un LST PROMET. Corpus mince = personne n'a le modèle.
2. **Couture inter-instructions.** L'audit review instruction par instruction ; chaque ix est correcte
   isolée. La faille vit dans leur RELATION temporelle, invisible à une revue séquentielle. (Cf. ton
   meilleur Push : un seam, pas un money-path.)
3. **LE SIBLING NON-GARDÉ — la forme la plus TROUVABLE.** La staleness n'est pas inconnue : les audits
   la fixent (M-01). Ce que personne ne regarde, c'est le chemin NEUF qui a hérité de zéro des gardes
   que ses aînés audités ont reçus. = post-audit periphery drift (Kill Gate q9). Ne cherche pas un
   mécanisme inexaminé (vague) — cherche le frère qui a raté le garde des autres.

---

## ÉTAPE 1 — L'INVARIANT PRODUIT (économie d'abord)

Avant une ligne de code : qu'est-ce que ce produit PROMET, formellement ? Écris-le comme une égalité
qui doit tenir À TOUT INSTANT.
- Tranche : "junior absorbe la perte AVANT senior, pro-rata."
- Vault : "un share vaut exactement sa part de la NAV live."
- Lending : "on n'emprunte pas au-delà de la valeur FRAÎCHE du collatéral."
- Staking : "on reçoit exactement le reward accumulé jusqu'à MAINTENANT."
- Perps : "le PnL/funding réglé reflète l'index à l'instant du règlement."

Le bug, c'est un instant où l'égalité ne tient pas parce qu'une valeur est en retard.

---

## ÉTAPE 2 — LA VALEUR STOCKÉE QUI LE PORTE

Trouve le champ d'état `V` dont dépend l'invariant, décode-le sur l'artefact DÉPLOYÉ (lecture directe
de compte + offsets empiriques ; Perena : `share_price` lu au comptant sur le TrancheState mainnet).
`V` doit être STOCKÉE, pas recalculée à la lecture — sinon pas de couture.

**Test de découplage (détection, pas juste preuve — Perena Step 3) :** mute la source live (vault,
oracle, pool) et re-drive le reader. Payout BYTE-IDENTIQUE ⇒ le reader lit du stocké, pas du live ⇒
la couture existe. C'est le single-input-mutation appliqué à la DÉTECTION.

---

## ÉTAPE 3 — ÉCRIVAINS vs LECTEURS

Énumère (bytecode/source), pour `V` :

ÉCRIVAINS — qui écrit `V`, et COMMENT :
- eager (chaque tx) vs **LAZY** (une ix séparée)
- non-privilégié vs **PRIVILÉGIÉ** / keeper / admin
- continu vs **PÉRIODIQUE** / epoch / booking

→ Le danger vit quand l'écriture est lazy + privilégiée + séparée des money-moves : c'est ce qui crée
la fenêtre. (Perena : `apply_capital_loss`, admin, latence de booking = la fenêtre entière.)

LECTEURS money-move — tout chemin qui consomme `V` pour bouger de l'argent : exit / unstake / redeem /
withdraw / liquidate / borrow / settle / claim. Liste-les TOUS, variantes comprises (instant vs queued,
junior vs senior, et surtout **les nouveaux ajoutés après l'audit**).

---

## ÉTAPE 4 — LES DEUX QUESTIONS-COUTURE (par lecteur)

Pour CHAQUE lecteur money-move :
1. **Force-t-il la fraîcheur ?** Settle/refresh/mark-to-market `V` AVANT usage, ou lit-il le stocké ?
   Piège : "run le settle existant" ne ferme rien si ce settle ne fait que réconcilier du DÉJÀ-booké
   (Perena) — vérifie ce que le settle **LIT**, en exécution, pas à la lecture.
2. **Est-il le sibling non-gardé ?** Existe-t-il un garde de fraîcheur/sanity que CERTAINS lecteurs
   appliquent (et revert) et que celui-ci SAUTE ? Le lecteur découplé qui passe là où les autres
   revert = le sharp finding.

Un "non" à (1) OU un "oui" à (2) = candidat couture. L'écart écrivain-lazy ↔ ce lecteur = le finding.

---

## ÉTAPE 5 — LE RACCOURCI SIBLING-NON-GARDÉ (entrée la plus rentable)

Ne balaie pas à l'aveugle. Laisse l'historique d'audit te DONNER la classe de garde :
1. Pull les audits / known-issues / fix-history de la cible (Perena : Hashlock, commit 97b69ae).
2. Identifie la CLASSE de garde qu'un fix a posée (M-01 : staleness gate sur mint/burn).
3. Cherche le chemin NEUF ou périphérique que cette classe DEVRAIT couvrir mais ne couvre pas —
   typiquement ajouté APRÈS l'audit (le code tranche n'existait pas au review). C'est le sibling.
4. Prouve la distinction directement des DEUX chemins (le garde vit sur l'un, pas l'autre),
   indépendamment du scope d'audit — ça pré-désamorce le knock "dup".

C'est Kill Gate q9 rendu directionnel : le fix passé est une CARTE des siblings à vérifier.

---

## TEMPLATES PAR CLASSE DE PRODUIT

⟨valeur stockée / frontière d'écriture (lazy) / lecteur à interroger⟩ — où POINTER l'Étape 1-4 par
type de cible (pas un finding, un point de départ) :

- **Tranche** : `share_price` / booking de perte (admin) / instant-unstake, redeem. (Perena)
- **Vault (ERC-4626-like)** : NAV, `pricePerShare` / harvest, accrual, report / withdraw, redeem.
- **Lending** : valeur collatéral / refresh oracle, accrue-interest / borrow, liquidate,
  withdraw-collateral (le chemin qui saute le refresh que la liquidation force).
- **Staking / LST** : reward-index, exchange-rate / update d'epoch, rebase / unstake, claim, redeem.
- **Perps** : funding-index, mark-price / funding-update périodique / settle, close, liquidate.
- **AMM / stableswap** : reserves, virtual-price / rebalance, ramp-A, rebase-token / swap, remove-liq.
- **Bridge / intent** : root, attestation, filled-status / relayer-settle (lazy) / claim, refund,
  double-fill (le read qui ne revalide pas l'état de settlement).

---

## HANDOFF VÉRIF

Un candidat couture est une AFFIRMATION de fraîcheur d'état. Elle ne vaut rien tant qu'elle n'est pas
EXÉCUTÉE (grep-of-closure : chaque number cite un run). Prouve-la :
- **State-fork** l'artefact déployé (solfork mode-b sur Solana ; Foundry fork sur EVM).
- **Single-input mutation** : mute UNE source (vault/oracle/pool), tiens le reste, byte-compare la
  valeur logguée par le programme lui-même. Inchangé sous mutation = découplé = couture confirmée.
- **Filtre-affordance** : le verdict se lit sur les capacités de l'attaquant MAINNET, jamais sur les
  affordances du fork (deploy-at-AUTH / sigVerify:false / setup-state). Une couture "atteignable" sur
  le fork ne l'est que si un chemin réel produit l'état stale ET le reader favorable.

Puis → killjoy-triage (dup / scope-exclusion / mapping barème / attrape ton propre overclaim) avant
"soumets", puis → chill pour la rédaction.

---

## SÉVÉRITÉ

Un bris d'invariant-produit mappe naturellement sur du HAUT tier : c'est une "disruption to core
protocol operations" — l'op qui DÉFINIT le produit échoue dans le scénario pour lequel elle existe
(Perena = High sur cette clause exacte, sans plancher $).

Discipline ni-under-ni-over : présente les faits bornés comme des faits, mappe l'impact à la clause
core-op du barème RÉEL du programme, LAISSE-LES placer. Ne pré-écris pas le tier — ni Medium par
prudence, ni Critical par reach. La magnitude bornée SIZE la likelihood ; elle ne fixe pas le tier
quand le barème key sur la disruption d'op, pas sur les dollars.

---

## TEMPLATE DE SORTIE (un dossier par couture candidate)

```
TARGET: [nom] | INVARIANT: [la promesse formelle, une égalité qui doit tenir à tout instant]
V (valeur stockée): [champ] @ [offset/emplacement] — porte: [l'invariant]

ÉCRIVAINS de V:
  W1: [ix] — lazy? [o/n] | privilégié? [o/n] | périodique? [o/n]
  → fenêtre = [intervalle entre écritures]

LECTEURS money-move de V:
  R1: [ix] — force fraîcheur? [o/n] | garde sibling? [applique / SAUTE]
  R2: ...

COUTURE CANDIDATE:
  [écrivain lazy W_i] ⟷ [reader non-gardé R_j]
  découplage prouvé: [byte-identique sous mutation de X | non]
  sibling non-gardé: [le garde vit sur R_k, pas R_j — provable des deux chemins]
  fenêtre exploitable: [borne + qui la produit + MEV-harvestable ?]
  → VÉRIF: [state-fork run réf] | TIER (clause barème): [High core-op / ...]
```

---

## ROUTING

- **Produit NOVEL (LST / tranche / intent / RWA récent)** = rendement max : invariant neuf →
  l'essaim n'a pas de checklist → couture vierge. Priorise ces cibles pour xseam.
- **Closed-Solana** → l'accès vient de solfork ; xseam oriente ce que tu décodes/drives.
- **EVM vérifié** → l'accès est gratuit (source) ; xseam est ton edge SUR l'essaim (disciplines +
  raccourci sibling battent la lecture générique), mais l'edge y est plus mince (l'essaim a Foundry
  aussi) → concentre sur la tranche non-vérifiée + la périphérie post-audit.
- **Web2 / off-chain** → HORS classe. xseam suppose un artefact déterministe, état stocké, frontières
  d'écriture lisibles. Router vers xchain-triage-mindset *(process manuel — pas un skill invocable)* ;
  ne force pas xseam là.

---

## MÉTA — REQUIS / INTERDITS

REQUIS :
- L'invariant AVANT le code (Étape 1). Sauter ça = retomber en chasse de classe-de-code.
- Chaque couture candidate est VÉRIFIÉE en exécution (single-input mutation, byte-compare) avant
  d'être un finding. Une couture "évidente à la lecture" n'est pas un finding.
- Le sibling non-gardé se prouve des DEUX chemins directement (le garde vit sur l'un, pas l'autre),
  indépendamment du scope d'audit — pour pré-désamorcer le dup.
- Divulgation responsable ; vérification passive ; scope-check avant tout.

INTERDIT :
- Hardcoder une cible / un 0-day / un version-pin dans ce skill. Les hypothèses actives vivent dans
  les notes d'engagement, pas dans la méthodo durable.
- Conclure "couture" sur inférence de lecture seule (le settle qui "a l'air" de rafraîchir — vérifie
  ce qu'il LIT en exécution ; Perena a failli te coûter le fix sur cette inférence).
- Pré-écrire le tier. Sévérité = clause du barème réel × impact prouvé, placement au programme.
- Traiter une valeur recalculée-à-la-lecture comme une couture (pas de valeur stockée = pas de
  staleness).

---

## SKILLS & ASSETS LIÉS

- **xsurface-prioritize** : AMONT — tranche la cible (go/no-go) ; xseam n'entre que sur un P0/P1.
- **solfork** : fournit l'ACCÈS (RE + state-fork) sur closed-Solana ; xseam dit quoi y chercher.
- **SEAM-THESIS** : xseam en est l'instance opérationnalisée (couture temporelle intra-protocole) ;
  la thèse couvre aussi les seams inter-composants / off-chain→on-chain.
- **Kill Gate q9** (post-audit periphery) : le raccourci sibling-non-gardé en est la version directionnelle.
- **Filtre-affordance** (caller_reachability) : garde la vérif honnête (capacité mainnet, pas fork).
- **killjoy-triage / chill** : AVAL — triage adversarial puis rédaction, jamais avant la vérif exécutée.
