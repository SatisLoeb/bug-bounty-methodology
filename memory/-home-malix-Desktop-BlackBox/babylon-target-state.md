---
name: babylon-target-state
description: Babylon Labs (Immunefi) BTC-staking — fan-out state, near-fortress node core, off-chain payable leads (V-1 vigilante slasher HIGH)
metadata:
  type: project
---

Babylon Labs (Immunefi, max $500k, KYC, PoC-required). 2026-08-21: fan-out 12 Fable-5 over the WHOLE
Blockchain/DLT surface. Workspace: ~/Desktop/BlackBox/babylon (node@release/v4.4.x, vigilante@0.24.x,
covenant-emulator@0.15.x + v016@0.16.x, finality-provider@v2.x, staking-queue-client@v1.x,
staking-expiry-checker@v1.x, cli-tools@v0.2.x). Full notes: babylon/NOTES-main-opus.md + BRIEF.md.

NODE CORE = NEAR-FORTRESS, 0 clean payable (multi-audited; concurrent independent traces + own Opus crown-jewel
verification concur): EOTS extract math sound; adaptor sig faithful + covenant key NOT extractable (encKey=FP pk);
finality pub-rand uniqueness closes different-R-to-avoid-slash; stake-expansion nets +(new-old) atomically;
BLS PoP cross-binds both keys; epoched-staking bypass STRUCTURALLY dead (raw staking Msg svc unregistered);
btclightclient=canonical btcd (>100blk divergence needs out-mining BTC=OOS); reward F1 core coherent.

PAYABLE LEADS ALL OFF-CHAIN:
- V-1 (WIN, HIGH "avoiding slashing", CONFIRMED-by-trace): vigilante atomicslasher/types.go:184,197
  parseSlashingTxWitness labels covenant Schnorr sig with UNSORTED covPKs[i] but witness is reverse-lex SORTED
  (node btc_slashing_tx.go:250-252; SortBIP340PKs desc; SetParams stores CovenantPks unsorted; routines.go:151
  passes raw). => tryExtractFPSK pairs adaptor sig w/ wrong schnorr sig => a single malicious FP's selective
  slashing is never detected/reported => escapes GLOBAL slashing. Dup LOW (TODO-fuzz, no unit test, e2e NumCovenants=1
  makes sort a no-op). PoC: unit test w/ 3-cov committee whose param order != SortBIP340PKs order.
- C-2 covenant-signer HMAC binds body only (no method/path/nonce) + /v1/lock ignores body => replay captured MAC to
  /v1/lock, indefinitely halts signer. HIGH "prevent covenant activation". On-path precondition (TLS unimpl).
- C-4 cli-tools unbonding_pipeline.go never validates unbonding OUTPUT before covenant-sign+broadcast (only staking
  input). HIGH avoid-slash. Crux OUT-OF-WORKSPACE (staking-api-service / covenant-signer v0.2.11 validation).
- C-5 cli-tools one poison doc halts unbonding for ALL (wrapCrititical returns, state not advanced, sorted _id). HIGH freeze.
- C-3 fpd AddFinalitySignature = PROD proto RPC (no build tag), unauth (bare grpc.NewServer), CheckDoubleSign bool
  defaults false => UnsafeSignEOTS bypasses store, returns ExtractedSkHex. Loopback-gated => Medium/cond-Crit.
  Citable asymmetry: eotsd twin gated by DisableUnsafeEndpoints(#736)+HMAC, fpd got neither.

Reopen/next: build V-1 PoC to seal; probe staking-api-service (OOW) for C-4/C-5 crux; re-audit if release branches bump.

## PLAYBOOK RUN on V-1 (2026-08-21) — Gate-4 primary-source read changed the verdict:
Program clause (Immunefi): "Any vulnerabilities mentioned in [Babylon audit] reports, fixed or unfixed, are NOT
eligible." Read all 4 audits at my exact sink:
- Coinspect P1/P2 + Zellic P1: V-1 sink (atomicslasher parseSlashingTxWitness ordering) NOT present. Coinspect P2
  BP2-024 (eotsd/covenant key exposure) overlaps my SECONDARIES C-2/C-3 (dup risk on those).
- Zellic Genesis 2025-03: reviewed the atomic slasher. NO numbered finding on my sink; closest Finding 3.20
  "hide slashing targets by spamming" = pagination window (Low, Fixed 100->500) = DIFFERENT bug. BUT §5.13
  threat-model "Attack surface" note says "parsing issues... could cause it to miss selective slashing, and that
  would allow selective slashing" — a generic OVERLOAD-scoped surface statement at my exact component.
VERDICT: V-1 VALIDITE excellent (PoC executed, unfixed in main) but RECEVABILITE = MATERIAL RISK (broad clause +
§5.13 note = defensible known-issue close), MATERIALITE High-per-list but bounded (key self-revealed on-chain;
griefing). Borderline-GO only WITH a report that pre-empts+distinguishes the audit overlap and anchors to the
Immunefi impact list (High), NOT to 3.20 (Low). Lesson: front-loaded Gate-4 primary-source read caught the
liability BEFORE submission (wsts pattern, but weaker dup evidence — surface note not numbered finding).

## C-4/C-5 crux resolved (2026-08-21, pulled staking-api-service v0.3.8 + covenant-signer v0.2.11):
REFUTED both. staking-api-service UnbondDelegation -> VerifyUnbondingRequest (utils/btc.go) step4 RE-DERIVES the
canonical unbonding output (BuildUnbondingInfo, value=stakingValue-fee) and rejects any mismatch BEFORE queuing;
parseUnbondingTxHex runs CheckPreSignedUnbondingTxSanity; unbonding_queue sole writer = SaveUnbondingTx post-verify.
=> C-4 (malicious unbonding output) DEAD: output IS validated upstream; cli-tools missing-check = defense-in-depth.
=> C-5 (poison halt) hardening-only: no attacker-inject (all docs pre-validated); residual triggers = BTC reorg (OOS)
   or params-height inter-service inconsistency (operational). No payable freeze.
FINAL: V-1 is the ONLY clean submittable on Babylon. C-3 dup(BP2-024). C-2 contested fix-bypass backup.

## C-2 PoC'd + report ready (2026-08-21):
covenant-signer HMAC body-only replay -> POST /v1/lock zeroes covenant key -> indefinite (emulator never Unlocks).
PoC EXECUTED (real middleware+handlers+SignerApp+cosmos keyring): poc_hmac_replay_test.go, artifact POC-C2-output.txt.
Realism: client.go GetPublicKey readiness poll sends HMAC over EMPTY body => leaks constant lock token.
Report REPORT-C2-immunefi.md: High "preventing covenant signer activating indefinitely"; distinguishes BP2-024
(Fixed, confidentiality/oracle) from this availability/replay incompleteness of PR#109 HMAC; pre-empts "use TLS".
=> TWO submittables on Babylon: V-1 (High avoiding-slashing, vigilante) + C-2 (High prevent-activation, cov-signer).
Both PoC-executed, gate-clean, audit-overlap distinguished. Immunefi submission = operator action (manual).

## C-2 PREMISSES DISPOSITIVES VERIFIEES EN PRIMAIRE (2026-08-21) — GO opérateur:
- Premise-2 (version): git log -S "GenerateHMAC" release/v0.16.x = SEUL #109 ; hmac_auth.go = 2 commits (#109 intro +
  #134 lint blank-lines) ; body-only VERBATIM sur release/v0.16.x ET main (gh api ?ref=main) ; aucun PR/issue/GHSA
  post-#109 ne binde method/path/nonce (recherche gh: #111 body-size, #134 lint, #200 race-PrivKey — tous autres).
  => NON corrigé, NON dup, dans l'artefact listé. Le check qui pouvait tuer -> survit.
- Premise-1 (reachability): canal emulator<->signer = surface réseau BY DESIGN (remote signer isole la clé) ; projet
  a DEJA accepté l'attaquant on-path in-scope en PAYANT BP2-024 (Fixed) dont le fix EST le HMAC #109 ; le finding =
  ce fix est rejouable. Retourne l'exclusion "déjà privilégié" en son contraire.
- Persistence "indefinitely" citée primaire: covenant.Signer (expected_signer.go:11-17) n'a QUE SignTransactions+PubKey,
  PAS d'Unlock ; remotesigner:13/63/67 ; emulator ne ré-unlock jamais ; readiness poll ré-émet le token constant.
- Rapport RESTRUCTURE (REPORT-C2-immunefi.md, gate-clean, 79L): reachability+BP2-024 en LEAD, fail-open quarantiné
  ("assumes HMAC configured+active; fail-open distinct, not claimed"), persistence verrouillée file:line.
CALIBRATION opérateur: High défendable si le lead BP2-024 porte ; risque downgrade Medium si triager insiste sur la
difficulté de la position on-path. Mapping propre + PoC vrai code + classe "incomplétude fix #109" payable. Vaut le coup
sur $500k triagé Immunefi + arbitrage. LECON gravée: prémisses dispositives AVANT de construire, pas après.
- C-2 PoC secret gist (SatisLoeb): https://gist.github.com/SatisLoeb/8bd16e4aaefee18738c252fdb60c6e70 (poc_hmac_replay_test.go + RUN.md).

## C-2 STATUT RÉEL (corrigé): RESTRUCTURÉ défense-en-profondeur, PAS ENCORE SOUMIS, 2e passage adversarial opérateur à venir.
Vérif déploiement primaire (docs/): transport = plaintext http:// documenté (PAS de TLS ; seul TLS = server.go:44 TODO)
+ HMAC "Recommended for Production" (emulator-setup.md:185) => les 2 prémisses nommées FAVORABLES. MAIS 3e facteur:
signer-setup.md:366 "must be run in a secure network and only accessible by the emulator" = isolation réseau documentée.
PIVOT (retourne le contre avec LEUR doc): HMAC = emulator-setup.md:187 "an additional layer of security for the
communication between emulator and signer" => un contrôle défense-en-profondeur ajouté post-BP2-024 PARCE QU'ils ne
trustent pas l'isolation seule => casser cette couche EST dans le threat model qu'elle adresse, pas hors.
Argument central = PERSISTANCE défait-le-bornage: l'isolation borne l'attaquant réseau à sa présence (retirer accès =
service restauré) ; C-2 casse cette propriété = 1 passage bref (insider/lateral/misconfig) -> déni PERMANENT survivant
à la fermeture de la brèche (emulator n'a pas d'Unlock, expected_signer.go:11-17 ; re-lock par token constant).
Sévérité: forged-MAC->401 prouve qu'il faut OBSERVER un vrai token, pas forger => coupe "si t'es dans le réseau tu fais
tout". Calibration: High défendable défense-en-profondeur+persistance ; downgrade Medium = PLANCHER pas mode (contre
"hors threat model" faible sur un canal où ILS ont déployé le contrôle qu'on casse) ; arbitrage dispo. Rapport 84L
gate-clean, quotes verbatim. NE PAS soumettre avant le 2e passage adversarial opérateur.

## C-2 REPRODUCIBILITÉ VÉRIFIÉE (2026-08-21): fresh-clone triager repro = PASS.
Simulé le parcours triager: clone frais release/v0.16.x + fichier DEPUIS LE GIST (byte-identique au testé) déposé
dans covenant-signer/signerservice/ + `GOTOOLCHAIN=go1.25.0 go test -run TestC2_ -v ./...` => 2/2 PASS, 0.042s.
Seule friction documentée (RUN.md): GOTOOLCHAIN=go1.25.0 requis SI le triager a go1.26 (bug build transitif
bytedance/sonic, sans rapport avec le finding, auto-download du toolchain). Go<=1.25 => marche direct.
Gist secret 8bd16e4... = poc + RUN.md, byte-identique. Blindage final CONFIRMÉ. À supprimer post-soumission (hygiène).

## C-2 SOUMIS (statut réel, 2026-08-21): Immunefi #89885, par @MalikX31 (Whitehat), Babylon Labs, fee 50 USDC payée.
Titre: "Covenant-signer HMAC authenticates only the request body, so a replayed token from the emulator's own
readiness poll indefinitely locks the signer". High "Preventing a covenant signer from activating staking requests
indefinitely". Asset covenant-emulator release/v0.16.x. PoC gist secret 8bd16e4... (owner SatisLoeb, submitter MalikX31).
DERNIER passage a corrigé 2 inexactitudes avant envoi: (1) grep-line reformulée en fait direct (matchait le PoC lui-même),
(2) lien causal #109->BP2-024 assoupli (PR #109 ref pm/261 pas BP2-024; pivot porte sur la citation vendor "additional
layer" seule). Rapport gate-clean, PoC reproductible clone-frais.
STATUT: SUBMITTED, PAS ENCORE TRIAGÉ. Post-soumission discipline: NE PAS relancer avant SLA. Soumis != payé != à l'abri.
Recours si besoin (ask-for-help/arbitrage/médiation) = à garder, pas dégainer tôt. Calibration attendue: High défendable
défense-en-profondeur+persistance ; downgrade Medium possible si triager s'accroche "secure network only" (contre faible,
arbitrage dispo). Gist: garder tant que non-close (triager doit l'exécuter) -> gh gist delete SEULEMENT sur signal "close".
V-1 (vigilante atomic slasher, High avoiding-slashing) reste PRÊT non-soumis si on veut le second submittable.

## WEB & APP fan-out (2026-08-21, 12 Fable-5): NEAR-FORTRESS -> RE-SOURCE. Workspace babylon/web/ (babylon-toolkit@
simple-staking/v1.4.6 [core-ui/proto-ts/wallet-connector/simple-staking], btc-staking-ts@v2.8.2, staking-api-service@
v3.0.3, babylon-staking-indexer@v3.0.2). ALL 12 surfaces clean/refuted:
- dApp: NO XSS (zero raw-HTML sinks, React-escaped), no open redirect, no token exfil. Crown-jewel PSBT-taint REFUTED
  (params from Babylon governance; staking output always has staker timelock self-recovery leaf => no freeze; attacker
  spend paths covenant-quorum-gated=OOS; unbonding local-rebuild+getId assert; withdrawals self-addressed).
- API v3.0.3: public-by-design (no per-user auth), unbonding SIGNATURE-gated, Mongo NoSQL-inj structurally impossible,
  RCE/SSRF/sensitive-data ruled out. wallet-connector verbatim pass-through. core-ui/proto-ts clean. config/CI/deps clean.
- The ONE confirmed High = indexer sanitizeEvent parse-crash DoS (moniker "[a]"/"[]" -> isArray misdetect -> ParseTypedEvent
  fail -> bootstrap crash-loop; events.go:363; unfixed v3.0.2 AND v3.0.9, fixed main json.Valid) = *** DUP of Immunefi
  #74576 *** (PR #359 body "Report -> immunefi submission #74576", merged 2026-07-29). NOT submittable. Gate-4 front-load
  saved the fee (wsts lesson).
- Only other candidate = OFAC/chainalysis screening CLIENT-SIDE-ONLY bypass via localStorage cache-first
  (useAddressScreeningService.ts:18) = Medium "circumvent access restrictions" BUT weak/by-design (non-custodial dApp
  broadcasts to mempool.space => BTC leg un-enforceable server-side).
=> Babylon Web&App = RE-SOURCE, 0 clean non-dup payable. Babylon net so far: C-2 SUBMITTED #89885 (covenant-signer HMAC),
   V-1 vigilante in reserve, DLT core + Web both near-fortress.

## C-2 OUTCOME (2026-08-21): CLOSED DUPLICATE of Immunefi #62507 ("Insufficient HMAC Context Binding Enables
Cross-Endpoint Signature Replay", Medium). Same root (HMAC(Key,Body), no method/path/nonce), same pair GET /v1/public-key
-> POST /v1/lock empty-body identical sig, same exploit. Close CORRECT, not disputed. $50 fee lost (non-refundable).
KEY: #62507 = PRIVATE bounty submission, NOT in repo/audit/GHSA => INVISIBLE to any pre-submission check (git log -S,
primary-source audit read, all our gates). Irreducible dup-risk on a private channel. NOT a method failure.
SEVERITY SIGNAL: #62507 rated Medium on the SAME persistence angle ("automate replay to re-lock... liveness issues")
=> my High-via-persistence was OPTIMISTIC; program calibrates this griefing as Medium. StackingDAO/wsts pattern again
(technique solid, severity above what the program pays). Gist deleted post-close.
BABYLON NET: C-2 dead(dup), V-1 vigilante in reserve (High avoiding-slashing, cleaner tier-map than C-2, own §5.13 risk),
DLT core + Web both near-fortress. Web indexer DoS also dup(#74576). RE-SOURCE Babylon.

## V-1 REINFORCED GATE-4 (2026-08-21, pre-fee, post-C-2-dup lesson): CLEAN on all measurable axes.
- parseSlashingTxWitness buggy lines (types.go:184 covPKs[i], :194 fpPKs[i]) UNFIXED on release/v0.24.x AND main.
- NO fix PR referencing an immunefi submission (the signal that caught indexer dup #74576 is ABSENT).
- NO GHSA on vigilante. NO numbered audit finding on sink (Zellic §5.13=generic note, 3.20=spam, Coinspect P2=no atomicslasher).
- Open atomic-slasher issues #121 (metrics/efficiency/cache housekeeping) + #282 (empty, "routines.go 50% coverage") = NOT the ordering bug.
- Risk profile BETTER than C-2: not a trodden-vein audited-control (un-tested fn, TODO:fuzz); tier-map CLEAN (avoiding-slashing=listed
  High verbatim, not persistence-escalation); §5.13 recev-risk is MEASURABLE+distinguished not invisible.
- Irreducible residual = private prior submission (unmeasurable, structural, as #62507 was for C-2).
=> V-1 clears reinforced Gate-4. Cleanest Babylon candidate. Proceed to gist+submit (fee = user's informed call).

## V-1 THREE DISPOSITIVE CHECKS (2026-08-21, pre-fee):
#1 (DISPOSITIVE, mainnet order): Babylon mainnet covenant committee = 9 keys quorum 6 (/babylon/btcstaking/v1/params,
   verified polkachu+lavenderfive). Stored order = COMPLETE DERANGEMENT of reverse-lex sort, 0/9 fixed points
   (perm 0->3,1->7,2->8,3->4,4->6,5->1,6->0,7->2,8->5). => bug fires UNCONDITIONALLY on live committee, any quorum.
   RSK-trap (defect-not-triggered-in-prod) does NOT apply — opposite. Magnitude PROVEN not asserted. artifact:
   babylon/MAINNET-covenant-order-V1.txt.
#2 (dup-density on sink): git log -S parseSlashingTxWitness / orderedCovPKs on release/v0.24.x = ONLY introducing
   commit #43; no fix in flight; no open atomicslasher PR. Clean public channel (private-dup irreducible).
#3 (version): mispairing verbatim in release/v0.24.x (types.go:184 covPKs[i], :194 fpPKs[i]).
=> ALL THREE CLEAR. Report updated: "essentially always" replaced by concrete mainnet 0/9-derangement fact,
   quorum-selection demoted to robustness. Gist https://gist.github.com/SatisLoeb/0cb872043475fa72a55a9c197b4c5240.
   Fresh-clone repro PASS. V-1 = GO for fee (High avoiding-slashing, cleanest Babylon candidate, magnitude proven).

## V-1 SOUMIS (2026-08-21): Immunefi #89920, @MalikX31 (Whitehat), Babylon Labs. High "Avoiding slashing despite
malicious behavior". Asset vigilante release/v0.24.x. PoC gist secret 0cb872043475fa72a55a9c197b4c5240.
Prémisses fermées AVANT le fee: #1 mainnet order = dérangement 0/9 (déclenchement inconditionnel, vérifiable triager en
1 requête, 2 LCD) ; #2 dedup sink = commit #49-only, aucun fix/PR ; #3 version verbatim v0.24.x (types.go:184/194).
Report corrigé (:197->:194). STATUT: SUBMITTED, pas triagé. Post-soumission: NE PAS relancer avant SLA. Si contesté:
défendre la distinction §5.13 Zellic (overload≠correctness-mispairing) + sévérité (mainnet inconditionnel, pas griefing)
SANS concession non-sollicitée. Gist: garder tant que non-close (triager exécute) -> gh gist delete au close.
BABYLON NET: C-2 mort(dup #62507), V-1 #89920 en triage, indexer-DoS mort(dup #74576). DLT+Web near-fortress. RE-SOURCE
après V-1 résolu.

## V-1 OUTCOME (2026-08-21): CLOSED DUPLICATE. Prior report "Witness identity mismatch in the live atomic slasher..."
(Medium, escalated Apr 26 2026 — ~4 months before us). IDENTICAL: same sink (parseSlashingTxWitness covSigMap[covPKs[i]]),
same mechanism, same mainnet-derangement fact (same 9 covenant keys, "all nine positions differ"), same PoC structure
(real babylon crypto, sorted-vs-unsorted, control-shows-fix). $50 fee lost. Prior report was PRIVATE (Immunefi dashboard,
not repo/audit/GHSA) => structurally INVISIBLE to my reinforced Gate-4 (git log -S, PR scan, audit read all correctly clean).
SEVERITY: prior report rated MEDIUM (reporter tried High/Critical "direct loss", landed Medium). 3rd severity over-call.
=> BABYLON NET: C-2 dup#62507(Med), V-1 dup(Med), indexer-DoS dup#74576. 3 findings, 3 dups, 0 payout, ~$100+ fees.
Program is HEAVILY FARMED. RE-SOURCE OFF BABYLON ENTIRELY. Gist deleted.
