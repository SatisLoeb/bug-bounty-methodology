---
name: nuke
description: >-
  NUKE — barrage d'analyse statique LOCAL + fusion pour cibles Solidity/EVM ET non-EVM
  (Rust/CosmWasm, Solana/Anchor, Go/Cosmos-SDK) en bug bounty. La couche d'exécution MÉCANIQUE sous
  l'arsenal cognitif de l'opérateur : détecte l'écosystème (foundry/Cargo.toml/go.mod) et tire le bon
  jeu de scanners en parallèle — EVM : Slither+Aderyn+Semgrep(Decurity) ; Rust : cargo-audit+deny+
  clippy+geiger ; Go : golangci-lint+govulncheck+gitleaks+nilaway+CodeQL — fusionnés via SARIF en UNE
  surface de triage avec CORROBORATION inter-outils et — le vrai point — l'ESPACE NÉGATIF (les classes
  de vulns qu'aucun outil n'a signalées = l'angle mort de l'auteur, à chasser à la main ; sur non-EVM,
  cet espace négatif est une worklist de VOL CURÉE car aucun scanner ne voit l'authz/reentrancy/bridge).
  Zéro réseau par défaut (OPSEC). Move/Cairo : NUKE ne fake pas un barrage (1 outil faible) et route
  vers les méthodes formelles/Prover. Activer sur toute nouvelle cible dès que le code est accessible,
  AVANT l'audit manuel profond, pour convertir le bruit brut des outils en une worklist rangée. Déclencheurs : "/nuke",
  "nuke", "run nuke", "barrage local", "lance les scanners", "scan local outillé",
  "slither+aderyn+semgrep", "static pass", "pré-triage outillé", "nuke diff", "barrage du patch",
  "post-audit drift", "audit de patch", "code changé", "diff base..head". NUKE est mécanique-only et conforme
  U-1 : il lance les SCANNERS lui-même mais ne fait que PROPOSER la veine cognitive suivante (/intake
  /extract /invfuzz /power /darkside /solidity-auditor /x-ray /fizz) — il n'auto-spawn jamais un skill
  de chasse et ne divulgue jamais. Un hit d'outil est un SIGNAL (hypothèse non exécutée), jamais un
  finding : la promotion exige un artefact Foundry EXÉCUTÉ (references/verify.md). Compose l'arsenal ;
  n'en remplace aucun.
---

# NUKE

**Ce que NUKE EST :** le marteau. La couche déterministe qui exécute les scanners locaux, mesure
où plusieurs moteurs pointent le même endroit (corroboration), et surtout calcule **ce qu'aucun
n'a vu** (espace négatif). Il transforme le bruit d'outil en worklist.

**Ce que NUKE N'EST PAS :** un auditeur. Il ne décide aucun finding, ne juge aucune sévérité comme
vraie, ne lance aucun skill cognitif, ne divulgue rien. Les scanners sont des *chiens qui aboient* —
NUKE range les aboiements ; c'est toi qui creuses.

> Maxime 1 — un detector/gate signale que le contrôle **EXISTE** là, jamais qu'il **TIENT**.
> Maxime 2 — le bug vit dans la phrase que l'auteur n'a **pas écrite** : lis l'espace négatif AVANT la liste des hits.

---

## Flux (5 étapes)

```
0. DÉTECTE      nuke.sh <target>         → écosystème (foundry / Cargo.toml / go.mod / Move.toml / Scarb.toml)
1. BARRAGE      (auto par écosystème)    → EVM: slither+aderyn+semgrep · Rust: cargo-audit+deny+clippy+geiger · Go: golangci+govulncheck+gitleaks+nilaway+codeql
2. FUSION       aggregate.py (auto)      → signals.md / signals.json / TRIAGE.md   (SARIF = colonne de normalisation)
3. LECTURE      toi                      → espace négatif D'ABORD, puis clusters corroborés
4. ROUTE        toi (PROPOSE, U-1)       → la veine adéquate (references/routing.md)
5. PROMOTION    toi                      → PoC/preuve EXÉCUTÉ (references/verify.md) → finding
```

## Commandes

```bash
# barrage complet (workdir = <target>/.nuke/<timestamp>/)
nuke <target-dir-ou-fichier>            # ou : bash ~/.claude/skills/nuke/scripts/nuke.sh <target>

# barrage FOCALISÉ sur le patch (post-audit drift)
nuke diff <base>[..<head>] [repo] [--window N]

# options : --quick (timeout 120s)  --no-build  --online-rules (ajoute p/smart-contracts, appel réseau)
# pont vers intake     : nuke digest [workdir|target]  (émet nuke-digest.md = veines pré-rangées)
# matrice d'outils      : nuke env
# preuve que ça tire    : nuke selftest     (barrage sur le fixture vulnérable → 3★ sur delegatecall)
```

Chaque barrage émet aussi **`nuke-digest.md`** à côté de `signals.json` : les classes détectées/corroborées
(leads concrets `file:line`) + l'espace négatif → **veines pré-rangées** (`/extract /power /darkside …`).
C'est le **pont vers `/intake`** : intake le lit en Phase 0 pour ancrer sa classification et son routage
dans ce que le code CONTIENT (au lieu que tu relises signals.md à la main). Prior à raffiner par le
corpus, pas un remplacement.

Après le barrage, **lis toujours** `<workdir>/signals.md`. Ne te contente jamais du résumé stdout.

## Mode diff — barrager que le code changé (post-audit drift)

`nuke diff <base>` (base vs arbre de travail) ou `nuke diff <base>..<head>` cible ce qu'un patch a
**introduit ou touché** — le cas « le code a été audité au commit X, qu'est-ce qui a bougé depuis ? ».
Mécanique : les analyseurs compilent **tout** le projet (obligé — Slither a besoin de l'unité de
compilation), Semgrep est scopé aux seuls fichiers changés, puis la surface de triage est **filtrée
aux lignes du patch**. `signals.md` a alors deux buckets : **🎯 DANS LE PATCH** (priorité) et
**🕓 pré-existant dans les fichiers touchés** (contexte — l'audit initial l'a peut-être déjà vu) ;
tout ce qui est hors fichiers changés est supprimé.

- Fenêtre de contexte : **±0 par défaut** (le signal est SUR une ligne changée — `git --unified=0`
  donne l'ensemble exact). `--window N` élargit si tu audites une fonction modifiée en place dont le
  scanner ancre le finding quelques lignes au-dessus du changement.
- **Alignement des lignes** : le filtrage suppose que l'arbre de travail correspond au côté HEAD du
  range. Pour `nuke diff <base>` seul (base vs arbre de travail) c'est toujours vrai. Pour un range à
  deux réfs, `git checkout <head>` d'abord si nécessaire.
- L'espace négatif en mode diff = les classes muettes **dans le patch** : « le patch touche du code
  mais reste silencieux sur oracle/flashloan — en a-t-il introduit une ? ». Croise avec
  `/expand-surface` (playbook post-audit drift).

## Lire `signals.md` — la discipline

1. **Espace négatif en premier.** La section 🕳️ liste les classes muettes. C'est le lieu le plus
   probable du Critical : les scanners ne parlent pas la logique métier. Chaque case cochable est une
   question — « ai-je exécuté un test qui EXCLUT cette classe ? ». Non = zone à creuser.
2. **Corroborés ensuite.** `★★★ aderyn+semgrep+slither` sur un même locus = trois moteurs indépendants
   d'accord. C'est un point de départ solide, **pas** une preuve. La corroboration monte la priorité,
   jamais la certitude.
3. **Un signal high non corroboré** peut valoir plus qu'un cluster ★★★ trivial (ex. un
   `controlled-delegatecall` seul > trois `solc-version` d'accord). Juge par PLAFOND DE PRIME de la classe
   sur CE programme (capacité de vol, MAIS aussi de freeze/halt/takeover-untrusted/insolvency/deanon — un
   chain-halt Cosmos ou un perma-freeze peut dépasser un vol), pas par nombre d'étoiles ni par `loss=$X` seul.
4. **`gate → moving on` est interdit.** Un detector qui « voit un require » ne prouve pas que le
   require tient. Pierce chaque gate (authn≠authz · sibling non gardé · gate satisfaisable · fuite
   différentielle · math du gate) avant d'écrire « bloqué ».

## Router la veine (étape 4 — U-1 : tu PROPOSES, l'opérateur lance)

NUKE ne spawn **jamais** un skill cognitif automatiquement. Il te fait lire `references/routing.md`
et tu **proposes** à l'opérateur la ou les veines pertinentes selon ce que le barrage + l'espace
négatif ont fait ressortir. L'opérateur confirme et lance. Rappels de routage rapides :

- math de valeur (vault/AMM/lending) muette → **propose `/extract`**
- ré-implémentation d'une math de référence → **propose `/invfuzz`**
- surface à rôles / authz → **propose `/power`**
- cible auditée, chasse des coins sombres → **propose `/darkside`**
- besoin d'un fan-out agent LLM → **propose `/solidity-auditor`** (puis `/x-ray`, `/fizz`)
- nouvelle cible, tu ne sais pas par où → **propose `/intake`** (le vrai front door)

**Non-EVM** : chaque classe de la worklist curée porte déjà sa veine (`→ propose /power|/extract|/darkside|/upshift`
dans `signals.md`, agrégée dans `nuke-digest.md`). Suis-la. Bridges/keepers/off-chain (Peggy, IBC,
orchestrateur) → `/upshift`/`/upshift2` (le seam) ; CosmWasm/Cosmos audité → `/darkside` (Door A/C).

## Multi-écosystème (EVM + non-EVM)

NUKE détecte l'écosystème à l'étape 0 et tire le bon barrage. **Le pipeline de fusion, le clustering,
la corroboration ★ et l'espace négatif sont identiques partout** — seuls les scanners et la carte des
classes muettes changent.

| Écosystème | Tell | Barrage (local, OPSEC) | Espace négatif |
|-----------|------|------------------------|----------------|
| **EVM** | `foundry.toml` / `hardhat.config.*` / `*.sol` | slither + aderyn + semgrep(Decurity) | taxonomie EVM par soustraction |
| **Rust/CosmWasm** | `Cargo.toml` + `cosmwasm-std` | cargo-audit + cargo-deny + clippy(→SARIF) + geiger + **lecture `overflow-checks`** | worklist de VOL CURÉE (21 classes) |
| **Solana/Anchor** | `Cargo.toml` + `anchor-lang`/`solana-program` | cargo-* + solana-lints(Dylint) + semgrep(Decurity rust) + sec3(opt-in) | worklist CURÉE (22 classes) |
| **Go/Cosmos-SDK** | `go.mod` + `cosmos-sdk`/`cometbft` | golangci-lint + govulncheck + gitleaks + nilaway + opengrep(ToB) + codeql(opt-in) | worklist CURÉE (23 classes) |
| **Move / Cairo** | `Move.toml` / `Scarb.toml` | ❌ pas de barrage (1 outil faible) | → **Prover/formel** (aptos move prove ; Aegis/Horus + snforge) |

**Non-EVM : l'espace négatif EST le livrable.** Aucun scanner ne voit les classes d'IMPACT PAYANT
— ni vol (authz `authn≠authz`, reply-reentrancy, bridge sig-scope, Token-2022, oracle) NI non-vol
(chain-halt/liveness, perma/temp-freeze de fonds, gouvernance/valset-capture par un acteur untrusted,
insolvency, deanon) — et sur un scope Blockchain/DLT (L1/consensus Cosmos) un halt est **Critical**,
souvent > un vol. La worklist curée (`references/negative-space.json`, `money-path` + `tell` par classe)
est ce sur quoi tu chasses ; ajoute-lui la ligne d'impact-payant NON-VOL par classe et range par plafond
de prime (`~/.claude/skills/IMPACT-LEDGER-PLAYBOOK.md`).
Un barrage vert non-EVM ne dit **RIEN** ; il ne couvre que le substrat mécanique (deps/panics/overflow/
secrets). **SARIF est la colonne de normalisation** : golangci-lint/govulncheck/osv/gitleaks/opengrep/
codeql/clippy émettent tous du SARIF → un loader générique ; les rustc/JSON (cargo-audit, cargo-deny,
solana-lints, sec3, nilaway) ont un adaptateur dédié.

**Gates OPSEC non-EVM :** `cargo audit --no-fetch` (advisory-db pré-clonée, zéro réseau) ; les SCA
réseau (govulncheck, osv-scanner) ne tirent qu'avec `--online-rules` ou un miroir local ;
sec3/radar (Docker + pull image) et CodeQL (build DB lourd) sont **opt-in** (`NUKE_SEC3=1`,
`NUKE_CODEQL=1`). Installe l'arsenal via `scripts/setup.sh`.

## Promotion (étape 5 — la seule qui crée un finding)

Un signal devient un finding **uniquement** avec un artefact **exécuté** : un `forge test` qui vole,
un `cast call` qui montre le delta, une trace. Le hand-reading ne promeut jamais. Voir
`references/verify.md` pour le protocole et le template de PoC. Remplis `TRIAGE.md` par signal : angle
de percée → artefact exécuté → delta chiffré → verdict (réel / mort-prouvé / à re-sourcer).

## Règles dures

- **U-1 / no-auto-orchestration.** NUKE lance les scanners (mécanique), jamais un skill de chasse ni
  `/disclose`. Toute action sortante ou difficile à annuler reste operator-gated.
- **OPSEC.** Par défaut, **zéro réseau** : règles Decurity locales, aucune sortie de code. `--online-rules`
  contacte le registre Semgrep — ne l'active que sur du code déjà public. Ne pousse jamais une cible
  vers un SaaS d'audit (ChainGPT/Nethermind/DeepScan) sauf code public routé via Tor.
- **Écosystème = jeu de scanners.** EVM/Rust/Go ont un vrai barrage ; **Move/Cairo n'en ont pas**
  (1 outil faible, low-recall) — NUKE ne **fake jamais** une couverture, il route vers le Prover/formel.
  Sur un langage non couvert (autre chose que EVM/Rust/Go/Move/Cairo), dis-le, ne bricole pas.
- **Non-EVM : la worklist de VOL curée est le livrable, pas les hits.** Aucun scanner ne voit
  authz/reentrancy/bridge — un barrage vert non-EVM est **muet sur le vol**, jamais une absence de bug.
- **Un signal n'est pas un finding.** Jamais. Même ★★★.

## Composition avec l'arsenal

NUKE est le socle mécanique ; il **compose**, ne remplace pas : `/intake` route, `/firmaudit` fait
l'engagement profond, `/extract` `/invfuzz` `/power` `/wide` `/darkside` sont les veines,
`/solidity-auditor` `/x-ray` `/fizz` sont la couche agent LLM (Pashov), `report-nerve` + `chill` +
`immunefi-submit` ferment la boucle. NUKE se place AVANT eux : il donne la worklist outillée + les
angles morts sur lesquels ces skills vont travailler.
