# FOIL-ROUTING — la table complète (quel foil recruter, où l'obtenir, ce qu'une divergence signifie, quelle veine la tranche)

Référence de `nexus`. Le SKILL.md en donne le résumé ; ici le détail par ligne.

Colonnes :
- **Signal cible** — ce que tu observes en Phase 0 qui désigne ce foil.
- **Foil** — la seconde autorité recrutée (l'oracle emprunté).
- **Où l'obtenir** — la manip concrète.
- **Ce qu'une divergence SIGNIFIE** — pourquoi un écart ici est un candidat-bug.
- **Densité** — décisions-dans-le-domaine (richesse du gradient) : ★★★ jumeau > ★★ standard/lib > ★ interne/incident.
- **Veine aval** — le skill qui TRANCHE la divergence par exécution.

---

## 1. Le vrai jumeau  ★★★  (densité maximale)

- **Signal cible** : la cible est un fork, un dérivé, OU il existe une app auditée qui fait presque la même chose (le Haveno de NEXUS).
- **Foil** : le parent / le concurrent audité, au commit courant ET à ses incidents passés.
- **Où l'obtenir** : cloner le parent. `git log`/CVE/audit-reports du concurrent. Souvent déjà cloné localement.
- **Ce qu'une divergence signifie** : le jumeau a pris une décision (timeout d'escrow, ordre de cérémonie multisig, sélection d'arbitre) ; la cible a pris une AUTRE. Comme le jumeau est audité, la divergence penche : soit la cible a un bug là, soit elle a corrigé un bug du jumeau (rare). Chaque incident passé du jumeau → "la cible a-t-elle l'analogue ?" (ghost-finding transfer).
- **Veine aval** : selon la classe de la divergence — math → `invfuzz`, authz → `power`, value → `extract`, seam → `xseam`. Diff parent = Kill-Gate q10 (dérivés : MANDATORY).

## 2. La lib de référence  ★★  (la math canonique)

- **Signal cible** : la cible RÉ-IMPLÉMENTE une math connue — header-chain Bitcoin, primitive crypto, codec, parser de conformance, retarget de difficulté, EIP-712, courbe.
- **Foil** : la lib de référence (rust-bitcoin, la conformance impl, la primitive audited).
- **Où l'obtenir** : la crate/lib de référence + un harness qui appelle les deux sur les mêmes inputs-bord.
- **Ce qu'une divergence signifie** : une math ré-implémentée qui diverge sur un input ATTEIGNABLE = split de preuve / faux-consensus / over-rejection (fonds valides bloqués). Direction : la cible PLUS conservatrice que la référence = safe ; plus permissive = candidat.
- **Veine aval** : `invfuzz` (harness différentiel exécuté + gate de reachability amont).

## 3. Le commit audité — foil TEMPOREL  ★★  (l'audit est l'oracle)

- **Signal cible** : la cible a un audit public (C4/Sherlock/Cantina/firme) ET du code a changé après.
- **Foil** : le code au commit béni par l'audit. Tout après est non-béni.
- **Où l'obtenir** : `manufacture-foil.sh --audit-ref <commit/tag>` → liste fichiers+fonctions nés après la bénédiction.
- **Ce qu'une divergence signifie** : le delta est l'espace de recherche ENTIER, et il est minuscule. Le code neuf hérite rarement des gardes que l'audit a posés sur les parents (post-audit periphery drift).
- **Veine aval** : `xseam` (le sibling neuf non-gardé), Kill-Gate q9. La C4-pipeline (fix incomplet / downgraded / adjacent) est ce foil appliqué finding-par-finding.

## 4. La forme canonique du type  ★★  (autorité forte, densité faible)

- **Signal cible** : la cible conforme à un standard — ERC-4626, ERC-20, EIP-712, AMM x*y=k, JSON-Schema.
- **Foil** : la forme canonique correcte du type (ce qu'un ERC-4626 "correct" fait, décision par décision).
- **Où l'obtenir** : la spec + une implé de référence OZ/canonique. `darkside` Door C construit le diff.
- **Ce qu'une divergence signifie** : chaque endroit où la cible dévie de la forme canonique = une décision explicite du dev = un lead. ATTENTION : le standard n'épingle que le PEU qu'il a voulu fixer ; tout ce qu'il laisse "implementation-defined" est INVISIBLE à ce foil (sa limite).
- **Veine aval** : `darkside` Door C (thief-mode : liste chaque déviation, explicite l'invariant que le dev croit tenir "par construction", attaque-le).

## 5. La suite de tests adverse des devs  ★★  (ce qu'ils ont blindé dit ce qu'ils croient acquis)

- **Signal cible** : la cible a une suite de tests d'invariants / fuzz / adversariale.
- **Foil** : leur propre matrice money-path × couvert-Y/N.
- **Où l'obtenir** : lire leurs tests, bâtir la matrice. La colonne "pas testé" = worklist. `darkside` Door A.
- **Ce qu'une divergence signifie** : ce qu'ils ont blindé dit ce qu'ils CRAIGNENT ; le sibling qu'ils n'ont PAS testé dit ce qu'ils croient acquis "par construction" — l'angle mort.
- **Veine aval** : `darkside` Door A (defensive-coverage matrix, PRIMARY quand une suite adverse existe).

## 6. La cible contre elle-même — foil INTERNE / mirror  ★  (toujours disponible, gratuit)

- **Signal cible** : TOUJOURS applicable. La cible a des fonctions sœurs, un flux in/out de valeur, des rôles.
- **Foil** : la cible elle-même. La fonction/chemin X gardé est l'oracle de la sœur Y non-gardée.
- **Où l'obtenir** : `manufacture-foil.sh` (scan guard-asymétrie) + lecture. Rule 41 (mirror V_in vs V_out).
- **Ce qu'une divergence signifie** : X valide/garde, Y ne valide/garde pas = oversight, pas design (Rule 8 : "si le protocole se protège du même risque ailleurs, l'absence ici est un oubli"). La divergence est DANS l'angle mort exact du dev, qui se croit cohérent partout.
- **Veine aval** : `mirror V_in/V_out` (Rule 41), `power` (asymétrie d'authz voisine), `xseam` (sibling read non-gardé), `extract` (asymétrie d'arrondi).

## 7. Un incident passé de même classe — ghost-finding  ★  (densité 1, mais prouvé exploitable)

- **Signal cible** : la cible est du même type qu'un exploit/finding public connu (GMX, Balancer, Cetus, un CVE de classe).
- **Foil** : l'incident passé — sa décision unique est prouvée exploitable.
- **Où l'obtenir** : le writeup/PoC de l'incident. `expand-surface` ghost-finding transfer.
- **Ce qu'une divergence signifie** : "l'incident a cassé sur la décision D ; la cible a-t-elle l'analogue de D ?". Une seule décision, mais elle a déjà payé ailleurs.
- **Veine aval** : `expand-surface` (ghost-finding transfer) → la veine de la classe.

---

## Le cas FORTERESSE (aucun foil bon marché n'existe)

Quand la cible est multi-audit et qu'AUCUN delta temporel, AUCUNE lib de référence, AUCUNE
déviation canonique évidente ne donne de gradient — c'est que les foils bon marché sont épuisés
(les auditeurs les ont dépensés aussi). DEUX sorties honnêtes, jamais "forteresse → next" nu :

1. **La branche chère** : construis À LA MAIN l'invariant que PERSONNE n'a écrit — la couture que
   personne ne possède (composition inter-sous-systèmes, on-chain↔off-chain, spec↔impl, lang↔lang).
   C'est `darkside` Door C thief-mode + `xseam`. Le foil ici n'est pas donné : tu le fabriques en
   modélisant la promesse du produit, puis en cherchant l'instant où elle ne tient pas. C'est CHER,
   et c'est pour ça que ça paie (aucun essaim ne le fait).
2. **RE-SOURCE** : si le score de saturation est trop haut (`saturation-score.sh`), le p_bounty
   d'un NOUVEAU finding sur ce cœur ≈ 0. Va vers une surface fraîche / off-chain / web / access-gated
   où le foil est encore riche (le seul $10K historique venait d'une couture web, pas du cœur SC).

Le choix entre (1) et (2) est un jugement d'EV, pas un réflexe. Mais "forteresse" n'est JAMAIS un
verdict tant que tu n'as pas NOMMÉ les foils construits et montré leur registre d'exécution — sinon
c'est un stall type 1 (sans-gradient) déguisé en type 2 (cul-de-sac mesuré). Et vérifie d'abord que
tu as ATTEINT la surface la plus riche : une surface murée depuis ton env (IP-block / auth-gate) est
un stall type 3 (accès → HARNESS-SUSPENDED, change d'infra), pas une forteresse. Voir SKILL.md § LE VRAI PIÈGE.
