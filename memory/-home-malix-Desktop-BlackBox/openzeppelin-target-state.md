---
name: openzeppelin-target-state
description: OpenZeppelin Immunefi — 8 seams mesurés (2026-08-18), 1 seul submittable (AntiSandwich tickBitmap Medium, PoC exécuté) ; core = NO-GO chiffré.
metadata:
  type: project
---

Intake + chasse complète le 2026-08-18. Dossier : `~/Desktop/BlackBox/oz/OZ-DOSSIER.md` (237 lignes).

**Économie du programme (le vrai gate)** : $48k payés en 5 ans. Critical = 10% des fonds affectés,
et la lib ne détient aucun fonds ⇒ plancher $5k. Medium FLAT $2.5k, Low FLAT $1k. PoC obligatoire
toutes sévérités. Primacy of RULES.

**SOUMIS 2026-08-18 : Immunefi #89316 (@MalikX31)** — LimitOrder stale-checkpoint theft, target uniswap-hooks, impact theft-of-unclaimed-yield (High). Reframe live-in-v1.2.0 + #138 divulguée + registre known-issues cité (pas de clause inventée). PoC gist secret SatisLoeb/ed61e29. Posture post-soum : pas de relance avant SLA ; si close known (correct ici) -> pas de dispute, remercier + passer ; ~20-30% proba. NEXT = re-source, les 2 veines du repo prises.

**⚠️ DEDUP v1.1 SOURCE-PRIMAIRE (gh issue view, pas WebFetch-résumé) a changé le verdict :**
- AntiSandwich tickBitmap = **DUP de l'issue OUVERTE #120** "AntiSandwich: Beginning-of-block checkpoint is mutated
  and incomplete" (2026-02-18) — dit verbatim "it never copies tickBitmap", cite L173-207, recommande de snapshot le
  tickBitmap. Couvre aussi 2 siblings (checkpoint muté par Pool.swap en storage ; loop skip via slot0). **NE PAS SOUMETTRE.**
  Leçon : mon check "bitmap absent des PDF d'audit" était un faux-négatif — le dup était dans un GitHub issue ouvert.
- LimitOrder stale-checkpoint theft = **SURVIT** au dedup primaire (distinct de #116/#121/#127/#129/#132 lus en entier ;
  #129 = corner opposé : fees déjà réalisées → underflow DoS ; moi = fees non-réalisées → over-collect theft). Seul submittable.
  Risque triage résiduel : zone accounting LimitOrder saturée (5 issues ouvertes), #129 rec = "replace checkpoint scheme".

**UPGRADE (2026-08-18, 4 Fable-5 hunters + operator exec) : un 2e finding HIGH trouvé, séparé.**
LimitOrderHook stale-checkpoint theft (`oz/REPORT-LimitOrder-StaleCheckpoint.md`, PoC `test/POC_UP_Graver.t.sol`
3/3 exécuté). `placeOrder` fige `checkpoints[msg.sender]=currency*Total` (L284-285) AVANT que son propre
`modifyLiquidity` réalise les fees en attente du position partagé (L306-311). Un joiner tardif sur un ordre à fees
NON-réalisées rafle `liq_joiner/liq_total` des fees gagnées avant lui : exécuté = attaquant prend F0/2 en currency0
(= pur yield volé, currency0 sur un ordre zeroForOne rempli = uniquement des fees). IMPACT = theft of unclaimed
yield = HIGH ($2.5k-$5k). Fix-bypass de H-02 RÉSOLU ("Accrued Limit Order Fees Can Be Stolen", RC1→checkpoint→RC2),
DISTINCT de #127 (cancel/freeze) et #129 (underflow/DoS). Darkside : le test dev `test_withdraw_feesAccruedJIT`
masque le bug en réalisant les fees par cancelOrder avant le join. Fix = déplacer le checkpoint APRÈS L306-311.
Le sweep d'upgrade sur AntiSandwich lui-même = 3 angles exécutés-NULL (sandwich/theft/freeze/DoS tous réfutés) → base
reste Medium ; mais durci (drain réfuté, exactOut aussi touché, objection-sandwich pré-emptée).

**Submittable #1 (Medium) : `AntiSandwichHook` calcule sa cible début-de-bloc à liquidité CONSTANTE.**
`_beforeSwap` (src/general/AntiSandwichHook.sol:89-119) copie slot0 + ticks + feeGrowthGlobals + liquidity
dans `_lastCheckpoints[poolId].state` mais JAMAIS `state.tickBitmap` (`grep tickBitmap src/` = 0 hit).
`Pool.swap` ne trouve le tick suivant que via `tickBitmap.nextInitializedTickWithinOneWord` (Pool.sol:348)
et n'atteint `crossTick` que sous `if (step.initialized)` ⇒ la simulation ne traverse aucun tick.
PoC exécuté (`oz/hooks/test/POC_AntiSandwichBitmap.t.sol`) : un swap honnête PREMIER DU BLOC, sans sandwich,
perd 183→364 bps ; la sortie côté hook reste figée à ~47.6185e15 quelle que soit la vraie liquidité (×50).
Vérifié indépendamment par l'agent refuteur (refuted=false, medium). Risque dup = lignée RC1 C-02
(« Asymmetric First In-Block Swap Initialization », marquée résolue en copiant les ticks — cette copie est
morte sans le bitmap). Le mot « bitmap » n'apparaît dans AUCUN des 3 PDF d'audit.

**Mon finding perso, plus faible** : `ERC7984Hooked.maxModules()` = 15 dépasse le plafond HCU du fhEVM
(20M/tx, HCULimit.sol:54). +1,608,256 HCU/module mesurés : transfer meurt à N=12, transferAndCall à N=6.
MAIS `uninstallModule` marche encore ⇒ récupérable ⇒ Medium au mieux, Low si triage strict.

**Mesuré-clos (ne pas rouvrir sans déclencheur)** : oracle panoptic (port V3 fidèle, clamp auto-cohérent),
fee machinery, base accounting (ledger abstrait = côté intégrateur), dérive post-audit confidential v0.5.3
(les 4 fixes ACL sont corrects), divergence release-vs-master (les 5 fixes sécurité ONT été cherry-pick
dans v0.5.3 — le piège d'ascendance ne donne rien), hook framework + Rwa.

**Core openzeppelin-contracts = NO-GO chiffré** : 164 fichiers non-mock modifiés en 12 mois, 35 neufs,
18 specs FV en couvrent ZÉRO, dernier audit fév-2026 (v5.6) avec 121 fichiers touchés depuis, v5.7.0
entièrement non audité. RLP/TrieProof/BlockHeader/RateLimiter/PaymasterERC20 lus à fond = 0 payable
(la chaîne de commitment keccak de TrieProof est transitive, pas absente). Seul instrument qui pourrait
retourner ça : un fuzz différentiel RLP+TrieProof contre une MPT de référence.

**Outillage prêt** (coûteux à rebâtir) : `oz/occ-v053` compile (127 fichiers) avec le mock FHE hardhat et
expose `fhevm.computeTransactionHCU`; `oz/hooks` a ses submodules v4-core peuplés et `forge test` tourne.
Voir [[deployed-code-not-head]], [[recevability-gate-before-poc]], [[bounty-playbook-5-gates]].
