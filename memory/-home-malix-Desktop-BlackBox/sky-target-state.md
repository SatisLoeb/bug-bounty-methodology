---
name: sky-target-state
description: "Sky/MakerDAO (Immunefi, $10M max) — SC: Diamond PAU + vault stUSDS mesuré-clos 0 finding ; Web&App: 4 assets mesuré NO-GO 2026-08-20 (5 veines mortes par artefact exécuté)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 926ccf4a-cfee-413f-baee-f7ad819193dc
  modified: 2026-08-20T11:22:48.985Z
---

Cible ouverte le 2026-08-07. 249 assets. Sources dans `~/Desktop/BlackBox/sky/` (diamond-pau, stusds, dss-emergency-spells). RPC public qui marche : `https://ethereum-rpc.publicnode.com`. Foundry (cast/forge) installé. Chainlog JSON : `https://chainlog.sky.money/api/mainnet/active.json` (suivre le 301, 513 entrées).

**La nouveauté est datée :** 6 juillet 2026 = Diamond PAU (30 assets d'un coup) ; 21 juillet 2026 = 3 spells `EMSP_STUSDS_*` (les plus récents du programme entier).

**Diamond PAU (`sky-ecosystem/diamond-pau`) — mesuré, quasi-fermé :**
- Archi : `ALMProxy` détient les fonds et expose `doCall/doDelegateCall` en `onlyRole(CONTROLLER)` ; le `Controller` détient ce rôle et son `fallback()` **n'a aucun contrôle d'accès** ; toute l'authz repose sur `onlyRole(ALLOCATOR_ROLE)` dans chaque facet (`src/facets/Facet.sol`). Le Beacon mappe `callSelector → (facet, delegateSelector)`.
- Sweep exécuté : **236 fonctions external/public implémentées, 12 sans `onlyRole`**, toutes légitimes (onlyAdmin / `initializer`+`_disableInitializers()` / `msg.sender == proxy` dans WEETHModule).
- Surface de callback : **VIDE**. Aucun `unlockCallback`/`lzReceive`/`handleReceiveMessage`/`uniswapV3SwapCallback`. Un seul `msg.sender ==` dans tout `src/`.
- Dérive post-déploiement : **nulle**. Seul changement `src/` après le 30 juin = ajout du facet Aave v4 (non déployé, hors scope). Audits v1140 committés le 7 juillet = au déploiement. 33 PDF d'audit (ChainSecurity, Cantina, Certora, Octane, Unvariant).
- On-chain : `PAU_BEACON` = `0x829dC2b7E94B1954F0764E573f2E0d45Afa28199`, **25 intégrations câblées = exactement le scope**, `VERSION()` figé à "1.0.0" partout (inutilisable pour dater).
- Le commit HEAD « Add pre existing balance checks (SC-1550) » (4 août) ne touche **aucun `src/`** — 35 fichiers de test seulement. C'est un marqueur de paranoïa sur la classe `balanceOf(proxy)` vs delta, pas un correctif.

**La veine restante :** `dss-emergency-spells/src/stusds` — 3 spells, **337 lignes de Solidity de prod**, commit unique `45651a4` du 2026-07-09 « Refactor: StUsds Audit Feedback », déployés le 21 juillet. **Postérieurs à TOUS les audits stUSDS listés** (ChainSecurity 2026-04-10, Cantina 2025-08-18, Cantina 2026-05-04 pour stUSDSMom). Explicitement dans le scope Immunefi. Ils gardent un vault de **198,3 M USDS** (`STUSDS` = `0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9`, totalAssets 1.983e26, totalSupply 1.856e26).

**Veine stUSDS — ouverte puis refermée par lecture (2026-08-07) :** les 3 spells + `StUsdsMom` (114 l) + `StUsdsRateSetter` (213 l) lus intégralement.
- `DssEmergencySpell.schedule()` est **public sans authz** ; le seul rempart est `StUsdsMom.auth` → `authority.canCall(spell,...)` = le spell doit être le hat. Devenir le hat = « basic governance attack » = OOS.
- Piste `done()` insatisfiable sur `Param.LINE` (exige `vatLine==0` alors que `zeroLine` ne touche pas le Vat) : **MORTE** — `zeroLine` appelle `stusds.drip()` qui fait `_setLine()` → `vat.file(ilk,"line",_min(line,…))` = 0. Le commentaire dev de `StUsds.sol:245` prouve qu'ils connaissaient le piège.
- Les appels du Mom satisfont bien les validations du RateSetter (`maxLine` 0 passe `data==0||data>=RAD` ; `maxCap` 0 passe `data<RAD`).
- Ordre dans `RateSetter.set()` correct : `file("line")` → `drip()` (accrue au vieux taux + propage la line) → `file("str")` ; puis `jug.drip` → `jug.file(duty)`.
- Downcast `chi = uint192(nChi)` : le commentaire est JUSTE, maxUint256/RAY ≈ 1.16e50 < maxUint192 ≈ 6.28e57. (Vérifié — j'avais failli l'affirmer faux.)
- Immutables du spell gelés depuis le chainlog au déploiement ⇒ frein inerte + `done()==true` après migration d'un composant. Tué explicitement par l'OOS : « missing/extra/wrong/inconsistent Chainlog values are assumed a non-issue ».
- **Seul écart réel trouvé, sévérité Low :** `StUsdsRateSetterDissBudSpell.description` est une constante qui **n'embarque pas le `bud` ciblé**, alors que `StUsdsWipeParamSpell.description` embarque son `param`. Deux spells DissBud visant des keepers différents sont indiscernables par description. Asymétrie interne au même dossier.
- État live vérifié : wards tous à 1, `mom.owner()`=MCD_PAUSE_PROXY, `mom.authority()`=`0x929d9A1435662357F54AdcF64DcEE4d6b867a6f9`, `halt.done()`=false, cap 2.12e26, line 1.88e53, `bad`=0.

**REPRISE 2026-08-10 — la veine des spells est close, le VAULT a été lu (il ne l'avait pas été).**
Clone avec historique : `~/Desktop/BlackBox/sky-spells` (dss-emergency-spells, HEAD=45651a4, 182 commits).
Audits stUSDS en local : `~/Desktop/BlackBox/sky/stusds/audit/` (4 PDF : CS 2025-08-12, Cantina 2025-08-18,
CS 2026-04-10, Cantina 2026-05-04 stusdsmom).
- **FAIT STRUCTUREL QUI EFFONDRE TOUTE LA CLASSE `done()` :** `DssEmergencySpell.schedule()` fait
  `_emergencyActions()` **sans aucun `require(!done())`**. `done()` est donc PUREMENT INFORMATIONNEL
  (outillage/monitoring). Un `done()` faux ne bloque JAMAIS le frein d'urgence ⇒ impact au mieux
  « monitoring », jamais Critical. Corrige ma note précédente sur le « frein inerte ».
- **Branche « bypass du fix » ouverte puis vide :** le commit `45651a4` (2026-07-09,
  « Refactor: StUsds Audit Feedback ») est postérieur aux 4 audits ET antérieur au déploiement du
  21 juillet ⇒ c'est bien le code déployé. Son diff sur `src/stusds` : suppression de wards checks
  « superflus », et surtout ajout du check `vatLine` dans `done()` (c'est là qu'a atterri le
  flip-flop RAD/WAD des messages de commit). Tout est dans `done()` ⇒ sans effet sécurité.
- **Vrai cible = `StUsds.sol` (592 l), vault ERC4626 UUPS.** Proxy `0x99CD4Ec3…`, impl
  `0x7A61B7adCFD493f7CF0F86dFCECB94b72c227F22` (slot EIP-1967), `ilk = LSEV2-SKY-A`,
  vow `0xA95052…`, clip `0x836F5675…`. Discriminants du proxy conformes à la source (`version()="1"`,
  `str/rho/ilk/vow/clip/getImplementation`) ⇒ **Gate 7 OK, le code lu est le déployé.**
- **Vérifié correct :** les 4 arrondis ERC4626 vont tous dans le sens du vault (deposit/redeem down,
  mint/withdraw up via `_divup`) ; l'attaque par donation/inflation est **structurellement impossible**
  (`chi` est une variable d'état pilotée par le temps, jamais dérivée de `balanceOf(this)`) ;
  `_burn` applique la limite dette-aware `Art*rate + clip.Due() + assets*RAY <= totalSupply*chi` avec
  `jug.drip(ilk)` rafraîchi, et le contrôle est CONSERVATEUR (compare `assets*RAY` alors que la
  réduction réelle est `shares*chi ≥ assets*RAY` dans les deux chemins) ⇒ invariant post-burn a fortiori ;
  `_mint` vérifie le cap ; `file("str")` exige `rho == block.timestamp` (pas de rétroactivité) ;
  downcast `uint192(nChi)` sûr ; unités de `_setLine` cohérentes (wad×ray = rad).
- **État live mesuré (2026-08-10) :** totalAssets 201,57 M USDS, totalSupply 188,62 M, chi 1,0686 RAY,
  cap 212 M, line 1,88e53 rad, `str` ≈ 5,96 % APY, `clip.Due()` = 0, Art·rate = 156,95 M
  ⇒ **invariant OK, ratio dette/valeur 77,87 %, marge retirable 44,6 M USDS.**
⇒ 0 finding. Le vault est bien construit ; ne pas re-parcourir spells ni ERC4626 sans déclencheur.

**Piège de recevabilité à ne jamais oublier ici :** « wards fully trusted », « subdao proxies, facilitators and permissioned keepers assumed fully trusted », « impacts relying on governance approval of a malicious spell » = OOS. Donc tout bug de facet atteignable seulement par l'allocateur est mort. Il faut une perte sous opérateur HONNÊTE, ou un acteur non-privilégié. Et : « the vulnerability must exist in the deployed smart contract ».

**SURFACE WEB & APP — assessée 2026-08-20, verdict NO-GO / RE-SOURCE (mesuré, pas concédé).**
4 named assets : `app.sky.money` (dApp Vite/React + @jetstreamgg SDK v2, Vercel/Cloudflare), `sky.money` + `skyeco.com` (Webflow marketing), `chainlog.sky.money` (301→chainlog.skyeco.com), `vote.sky.money` (gasless relay). Recon fan-out 6 agents + probes exécutés en direct. Les 5 veines tier-vol/High **mortes par artefact exécuté** :
1. **Address-substitution chainlog→app : MORTE.** Adresses = constantes codegen `@wagmi/cli` (generated.ts, maps par chainId figées dans le bundle) ; `chainlog` = 0 occurrence dans app.main.js/sky-hooks ET absent du CSP `connect-src` (un fetch navigateur serait CSP-bloqué). Chainlog sert les intégrateurs/build, PAS la dApp live.
2. **Backend-API CORS (api.sky.money) : MORTE.** Probes curl exécutés : allowlist **exact-match https strict** — `Origin: evil.example`/`app.sky.money.evil.example`/`null`/`http://` (scheme-downgrade) ⇒ **AUCUN `access-control-allow-origin` renvoyé** ; seuls `https://{app,vote,sky}.sky.money` sont reflétés. `access-control-allow-credentials:true` est **inerte** sans reflet. Preflight OPTIONS sur `/terms-acceptance/add` **rejette evil origin** + `allow-headers: Authorization` ⇒ écritures gated par header Authorization, **pas cookie** ⇒ CSRF classique N/A. La seule façon d'abuser l'accès crédencié = depuis un origin `*.sky.money` déjà whitelisté = il faut d'abord un XSS (sink introuvable).
3. **Subdomain-takeover `*.sky.money` : MORTE.** CT enum (certspotter, crt.sh 502) = 25 hosts ; résolution CNAME/A exécutée : **tous les `*.sky.money` in-scope = Cloudflare-proxied A-direct ou NXDOMAIN, ZÉRO CNAME dangling.** Seuls CNAME tiers = `insights/www/apex skyeco.com`→webflow + `docs.skyeco.com`→gitbook (HORS liste named-scope) et **tous live/claimed (HTTP 200/301/307, aucun 404 unclaimed)**. `app-failover.sky.money`=NXDOMAIN (pas claimable), `e.sky.money`=europehog ESP live.
4. **sky.money reflection/redirect : MORTE** (agent exécuté : entity-encoded, pas de redirect endpoint).
5. **vote.sky.money vote-forgery (gasless relay) : MORTE** — sig vérifiée off+on-chain, nonce pinné par contrat, pas de cookie ; `GASLESS_BACKDOOR_SECRET` skip l'éligibilité pas la sig.
**Seuls résidus non-exécutés (ne clearent PAS la barre recevabilité solo) :** (a) Lead #2 — router/spender `tx.to` tiré d'une API quote/claim (CoW/Merkl/Morpho/Pendle) atteignant le tx-builder sans lookup static-map : ceiling Critical mais **dup HAUT** + 3-5h de trace source-map ; (b) Lead #3 — content-injection stored via champ **delegate-profile / poll-creator** de vote.sky.money (rehype-sanitize schema-REPLACE au lieu de merge, `lib/markdown.ts`) : ceiling High, **dup MOYEN** (canal métadata bas-de-gamme que les auditeurs zappent au profit du markdown gouvernance-PR), 2-3h — MAIS sonde décisive = POST de HTML crafté en prod = write outward-facing (consentement opérateur requis). Frontend $10M/19 rapports picked-clean ⇒ ROI solo négatif. Rouvrir Web&App seulement si : nouveau widget/module dApp, ou si un champ vote-metadata bas-bar est confirmé non-audité.

**SC DELTA depuis 2026-08-10 — triagé 2026-08-20, verdict NO-GO / RE-SOURCE (mesuré). CORRIGE la note "newest=21 juillet stUSDS" : les 2 plus récents du programme entier = 17 août 2026.**
Fan-out 9 agents (source réelle + vérif on-chain via `https://ethereum-rpc.publicnode.com` + chainlog). Assets neufs/non-couverts triagés :
- **SBEBeam.sol (MCD_SBEBEAM `0xc8b61d21…49a9`, 17 août 2026, repo dss-flappers @655d2dd) — MORT.** `set(kbump,burn,hop)` est toll (buds=facilitator Safe=**TRUSTED→OOS**) ; file/rely/kiss=auth(PAUSE_PROXY). Seule veine survivante = honest-operator freeze du farm reward → **tuée par arithmétique** : `rewardRate=leftover/hop` ne tronque à 0 que si `leftover<hop`, or hop capé à 5 ans (≈1.58e8) ⇒ leftover<1.6e-10 USDS = poussière, pas un freeze payable ; + desync Splitter.hop/farm.rewardsDuration self-healing (burn=WAD⇒pay=0⇒pas de notify) ; + StakingRewards modifié (setRewardsDuration sans require period-finished ⇒ jamais de revert). Dup low mais 0 surface.
- **FarmOwner.sol (OWNER_REWARDS_LSSKY_USDS `0xA3d3…2b0e`, 17 août 2026) — MORT.** Bytecode désassemblé : 8 mutateurs, **8 reverts wards-auth**, `wards(PAUSE_PROXY)=1`, zéro sibling non-gardé. 100% ward-gated ⇒ OOS. Résidu FoT dust ward-triggered non-payable.
- **OFT/LayerZero cluster (SkyOFTAdapter `0x1e1D…01B8`, sky-oapp-oft, 19 nov 2025) — MORT, faux lead démonté.** La synthèse avait mis en #1 un "drift post-audit commits #22/#23/#32 poussés 2026-08-20" = **HALLUCINATION** de l'agent dup (a confondu repo `pushed_at` = activité de BRANCHES avec main). Vérif `gh api` exécutée : **main HEAD=`0baba10c7` (2025-12-26)**, rien de plus récent sur main ; **#23 (rewrite OFT: SkyOFTAdapter/Core/RateLimiter + lz_receive Solana) daté 2025-10-15 = 2j AVANT ChainSecurity (17 oct), 13j avant Cantina (28 oct) ⇒ DANS le scope audité** ; #22 (gov) idem pré-audit ; #35 (30 oct, seul post-Cantina pré-deploy) = package.json+pnpm-lock+1 task script, **zéro logique** ; deploy=#34 (19 nov). Deployed==audited. + Gates : `endpoint.clear()` DVN-committed (forge=OOS "trust the DVN") + peer/remote bind admin-only ; **GovernanceOAppReceiver EVM PAS déployé mainnet** (Sender seul, gov unidirectionnel EVM→Solana). RE-OUVRIR si un GovernanceOAppReceiver Solana→EVM est un jour déployé (foot-gun srcSender délégué à la cible).
- **Chief.sol (MCD_ADM `0x929d…a6f9`, 15 sep 2025) — FORTERESSE, dup HAUT.** Live confirmé (live()=1, liftCooldown=10, launchThreshold=2.4e9, maxYays=5). **Entièrement permissionless** (mappe direct sur les 2 Critical gov : déviation de tally + prévention de participation) MAIS : Certora spec prouve les transitions par-fn + accounting exact (etch strict-ordering⇒unicité, vote overlap-preserving Assert 7/9, lock/free ±wad symétrique) ; flash-loan hat-grab **défendu live** (`free` exige `block.number>last`, `lift` set `last`) ; SKY ERC20 sans hooks. Seul angle non-percé = couverture Certora de la composition multi-tx launch↔lift↔free (harness Foundry 1-2j, dup TRÈS haut). Rouvrir si un spell redéploie Chief avec liftCooldown==0 ou tally modifié.
- **Kicker.sol (`0xD889…c1Fc`) — MORT/DUP** : flap() permissionless mais tous les leviers = params gov, dans l'audit juillet-2026, flow canonique 2023.
- **StarGuard (10+ instances *_STARGUARD) — FORTERESSE/DUP** : exec() permissionless mais ne tire qu'un payload gov-plotted codehash-pinné (plot=ward=OOS) ; v101 audité==déployé.
- **LockstakeCappedOsmWrapper (oct 2025) — MORT** : `_min(osm,cap)` clamp vers le BAS (ne peut sur-évaluer) ; readers toll-gated ; poke() = simple forward.
⇒ Toute cellule fraîche est soit forteresse-auditée (Chief/StarGuard/OFT) soit trusted-gated (SBEBeam/FarmOwner/Kicker/CappedOsm). **Sky = forteresse sur les 3 surfaces (SC-core + SC-delta + Web&App). RE-SOURCE.** Leçon : l'adversarial-verify a tué le faux #1 en 1 appel `gh api` ; ne jamais soumettre un "drift" sur foi d'une date de push de repo.

Voir [[deployed-code-not-head]], [[recevability-gate-before-poc]], [[weak-substitute-binding-class]], [[measure-before-asserting-in-reports]], [[zest-v2-target-state]] (même discipline de diff appliquée).
