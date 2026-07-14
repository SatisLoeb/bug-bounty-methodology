# NUKE — doctrine

## Pourquoi un barrage AVANT l'audit manuel

Le hand-reading d'une cible fraîche adopte le modèle mental du dev (maxime 2 : « plus tu comprends,
plus tu ADHÈRES »). Lancer les scanners d'abord fait deux choses que ta lecture ne fait pas :

1. **Il énumère le connu mécaniquement** — tu ne dépenses plus d'attention sur les patterns qu'un
   detector attrape en 3 s. La réentrance classique, le `tx.origin`, le `delegatecall` contrôlé : lus
   par la machine, pas par toi.
2. **Il révèle l'espace négatif par contraste** — ce que les outils NE disent pas sur une cible
   devient visible. Une cible lending où *aucun* outil ne parle `oracle/price` ni `flashloan/economic`
   ne prouve pas l'absence de bug : elle prouve que le bug, s'il existe, est trop sémantique pour eux —
   donc c'est exactement là que ta valeur d'humain est maximale.

## Les trois moteurs et ce qu'ils couvrent (complémentaires, pas redondants)

| Moteur   | Nature | Force propre | Angle mort |
|----------|--------|--------------|------------|
| Slither  | dataflow/taint sur IR | réentrance cross-fn, arbitrary-send, delegatecall contrôlé, tautologies | logique métier, valeur |
| Aderyn   | AST Rust rapide | hygiène, immutabilité, zero-check, patterns structurels, gros repos | exploit chains |
| Semgrep + Decurity | patterns dérivés d'exploits RÉELS | oracle-manip, readonly-reentrancy (Balancer/Curve/Compound), erc20/721 quirks, encode-packed collision, exact-balance | tout ce qui n'a pas de règle |

La **corroboration** (≥2 moteurs sur le même locus) est un signal de priorité, jamais de vérité :
trois moteurs peuvent être d'accord sur un faux positif (ex. une réentrance protégée par un guard
qu'aucun ne modélise). Inversement un seul moteur sur un `controlled-delegatecall` peut être le
Critical de tout l'engagement.

## La règle de promotion (non négociable)

```
signal  --(angle de percée EXÉCUTÉ)-->  candidat  --(delta chiffré + guard répliqué)-->  finding
```

- Un `forge test` qui déplace de la valeur d'une victime vers l'attaquant.
- Un `cast call` qui montre l'état avant/après.
- Une trace qui prouve le chemin d'atteinte depuis un acteur non-privilégié.

Le hand-reading ne franchit **jamais** une de ces flèches. Un `>2x` de magnitude dans un output brut
est presque toujours TA bug de valorisation, pas la leur — réplique le check du protocole (bon prix,
toutes les jambes) avant de crier au vol. (cf. les mémoires de l'opérateur.)

## Séquence recommandée sur une cible neuve

```
/nuke <repo>                     # barrage → signals.md
lire signals.md : espace négatif → corroborés
/intake <repo>                   # (proposé) route la veine, construit le dossier
→ veine choisie : /extract | /invfuzz | /power | /darkside | /wide
→ (option) fan-out agent : /solidity-auditor → /x-ray → /fizz
→ par candidat : PoC forge exécuté (verify.md) → TRIAGE.md → report-nerve → chill → submit
```

NUKE occupe la première ligne. Tout le reste est operator-gated.
