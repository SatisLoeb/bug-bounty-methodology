---
name: hedera-target-state
description: Hedera/Hiero (Immunefi $30k) — état après fan-out 11 agents Fable-5 sur toute la surface
metadata:
  type: project
---

Hedera/Hiero (Immunefi, max $30k, KYC, PoC-required). 8 repos in-scope: consensus-node, cryptography, json-rpc-relay, mirror-node, sdk-go/js/java, hashgraph/transaction-tool. Fan-out 2026-08-21 : 11 agents Fable-5 supervisés, toute la surface + tous impacts (pas que Critical). Code local cn/=0.78 + hiero-cryptography ; clones frais des 6 autres. Stable déployé = consensus-node v0.76.1 ; main=0.79-SNAPSHOT (in-scope ref). Snapshot-drift 0.78→0.79 a TUÉ 2 faux positifs (deleted-account staking + prefix-mismatch sort, tous deux fixés en 0.79).

7 findings PRIORS déjà minés (submissions/hiero/) = tout crypto : wraps-Nova-circuit(C), ceremony-S3-traversal(C), hints-FiatShamir-forgery(C), history-proof-cache(H), relay-hbar-limiter(H), CRS-rebasing(M), groth16-no-verify(H).

RÉSULTAT : near-forteresse, 0 clean Critical/High slam-dunk. LEADS payables (mesurés) :
1. **A4 birthRound-OOM** [REPORT DÉVELOPPÉ submissions/hiero/09, PoC exécuté OOM 58ms sur vraie classe StandardSequenceMap ; High contesté aBFT ; deployed v0.76.1] [CONFIRMÉ par orchestrateur sur main] : gossip event birthRound=R+1.5e9 passe DefaultEventFieldValidator (LOWER-bound only) -> StandardEventDeduplicator (allowExpansion=true) AVANT sig-validation -> AbstractSequenceMap.expandCapacity() alloue ~2.14e9 array+objets -> OOM -> crash node network-wide. High-impact (aBFT violation, 1 node halt réseau). RECEV CONTESTÉE : exige node gossipant = "malicious node" OOS + permissioned-council downgrade VS mappe aux impacts PAYÉS "network partition/consensus failure". Submittable avec framing aBFT, Hedera tranche.
2. **A7 mirror stale/missing authoritative balances** : /api/v1/balances getBalancesQuery met le filtre balance DANS le WHERE du `distinct on ... order by consensus_timestamp desc` -> filtre sur snapshots STALES puis distinct -> balance stale@ts-courant (VÉRIFIÉ : sibling tokens.js wrappe en CTE = le fix manquant). Medium "incorrect records", recev la plus PROPRE (unauth, in-scope asset, not-malicious-node). + #4 unordered-LIMIT drop rows. Nuance : "export TO mirror"(importer=robuste) vs "mirror SERT faux"(serving-side).
3. **A2 scheduled ops-duration bypass** [DOWNGRADÉ LOW, executed] : bypass RÉEL (scheduled exclu du ops-duration throttle, by-design documenté #21890, présent v0.76.1) MAIS matérialité = ARTEFACT DE MÉTRIQUE. Microbench Besu 26.2.0 exécuté : CALL réel = 1.27x STATICCALL vs poids ops-duration 47x (CALL sur-pondéré ~37x, #20702 'worst case'). 1 scheduled CALL-spam 15M-gas = 335ms réel MAIS 22.7x le budget-proxy. Pas de DoS >=30%/block-delay. Low/info, PAS Medium. [ancien texte] : ContextTransactionProcessor:155 shouldApplyOpsDurationThrottle=enabled && !scheduled() -> tx schedulée ni check ni deduct ops-duration (seul limiteur EVM-compute car gas-throttle OFF default). Borné à ~2.2x par gas-cap forcé à la création. Medium "resource>=30% sans brute-force", TX-REACHABLE (recev propre), magnitude dépend calibration ops-duration->wall-clock (non-mesurable read-only).
4. A7 tokens-name byte-vs-char pool-exhaust DoS(#3) + eth_call inflated-balance(#2) : Medium, need 1 runtime confirm.

FORTERESSES mesurées-null : HTS/system-contracts (A1, key-activation+allowance hold), staking/records (A3, net-zero-hbar+800-cap), sig-verify+schedule (A10, crown-jewel crypto-binding sound), block-stream #26721 merkle (A11, 2nd-preimage-safe+hashers≡+sig-binds-full-root), cryptography (A5, main durci 7 fixes/3sem), SDK (A8, crypto core solide, divergences MITM/self-inflicted), transaction-tool (A9, non-custodial, no server key). Voir FINDINGS.md dans scratchpad (éphémère) pour détail.

Voir aussi [[deployed-code-not-head]] [[recevability-gate-before-poc]] [[report-no-self-devaluation]] [[measure-before-asserting-in-reports]].
