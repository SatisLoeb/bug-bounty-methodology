---
name: capyfi-target-state
description: CapyFi (Immunefi Web/App) — état de la chasse web
metadata: 
  node_type: memory
  type: project
  originSessionId: b1cded3a-04f3-465b-badc-0070a740089e
  modified: 2026-08-20T08:33:47.179Z
---

CapyFi = Compound v2 fork lending sur LaChain (Ripio/LatAm), Immunefi max $1M (= SC critical ; tier Web/App INCONNU, à lire sur la page). SC = forteresse 2-audits (Coinspect + OpenZeppelin @cf47234, repo LaChain/capyfi-sc) → RE-SOURCE vers web.

**2026-08-20, gravedigger web mesuré-CLOS 0 payable sur la SURFACE ATTEIGNABLE :**
- Surface vraie = 2 apps Vercel/Next.js hors-WAF, entrées in-scope par Primacy-of-Impact : **vault.capyfi.com** (stBTC vault, Web3Auth+Wagmi, Ethereum mainnet, NO CSP) + **mini-app-world.capyfi.com** (Worldcoin World-App mini-app, MiniKit, NO CSP). Les deux = dApps SDK-lourdes standard.
- vault : 71 chunks + serveur live-probé → CLEAN. Tous sinks XSS = library-internal (0 dangerouslySetInnerHTML app-authored), 11 postMessage handlers TOUS vendor-SDK origin+nonce-validés, contract addrs HARDCODED par chainId (pas de source mutable → pas de substitution), approve exact-amount+reset, PAS de backend CapyFi (que Web3Auth/RPC/analytics), CVE-2025-29927 middleware = byte-identical (exécuté), pas de source-maps, pas d'env leak.
- mini-app : 13+4 lazy chunks = 100% JS (lazy = Eruda[OFF en prod, runtime-confirmé] + viem). App ne fait QUE getPermissions+walletAuth ; AUCUN pay/sendTransaction app-invoqué ; username/profilePicture Worldcoin JAMAIS rendu dans un sink (JSX auto-escaped). SIWE authorize rejette payload malformé proprement (302, exécuté).

**RÉSIDUS nommés (operator-owned, NON balayés) :**
1. **app.capyfi.com + legacy.capyfi.com = ASSET PRIMAIRE listé, CF-IP-BLOCKED depuis cet env** (curl 403 + browser 403, exécuté). PAS un verdict — l'UI lending principale (Compound-v2-fork) = surface web la plus riche = NON ATTEINTE. L'operator doit tester sur SON IP résidentielle + vrai browser. C'est LÀ que la valeur web restante vit.
2. **SIWE authorize address-binding** (mini-app) : forge complète (signer SIWE avec clé contrôlée, réclamer une AUTRE adresse) non-lancée — plafond d'impact BAS (display shell, 0 action de valeur) + verifySiweMessage officiel Worldcoin recover-le-signer. Recette dans MASTER-VERDICT.
3. **Tier reward Web/App inconnu** — gate ROI PoC-hours.

Workspace: /home/malix/Desktop/BUGS/capyfi-audit/ (SCOPE/SURFACE-MAP/MASTER-VERDICT.md + wf-bundle-analysis.js). Subdomain-takeover CLOS (vault/mini=Vercel live, awsorg=Route53 zone live). Voir [[recevability-gate-before-poc]] [[report-no-self-devaluation]] [[measure-before-asserting-in-reports]].

**2026-08-20 SC ajouté (operator a fourni scope SC + Unitroller 0x0b9af1fd...2afA) — MESURÉ-FORTERESSE 0 payable :**
- Déployé sur ETH mainnet, 12 marchés (7 listés+5 non-listés). Comptroller 0x00dc...867E, oracle 0xfbA2712d...424A, gov 0x6C15e4Bc...eD24.
- Refutations EXÉCUTÉES : empty-market REFUTÉ (tous seedés, er≈0.02) ; oracle scaling CORRECT (prix vérifiés WBTC/USDT/USDC/ETH) ; oracle = poster trusted + Chainlink (non-atteignable) ; FoT SAFE (doTransferIn=balance-delta) ; **DRIFT=ZÉRO** (Comptroller/CToken/storage byte-identical au repo audité) ; IRM blocksPerYear=2628000 (12s correct ETH) ; whitelist by-design (redeem-always-works testé) ; exotic tokens = proxies issuer (OOS) neutralisés par CF=0/whitelist-active.
- Audits : Coinspect + OZ @cf47234 = 0C/0H/0M/4L (délta only). 2 acked : security-contact, oracle-staleness (OOS third-party).
- RÉSIDU unique réel = app.capyfi.com (UI lending, WAF-blocked depuis env) → operator IP. + 5 marchés non-listés (même code canonique).
- CONCLUSION : SC = forteresse mesurée (audité delta + core Compound canonique + config verrouillée + 0 drift). Web = clean sur surface atteignable. Seul non-atteint = app.capyfi.com (env IP block).

**CLOSED 2026-08-20 (operator).** Web (surface atteignable) + SC = mesuré-clos 0 payable. RÉOUVRIR SI : (a) app.capyfi.com testé sur IP résidentielle révèle un sink/auth client ; (b) NOUVEAU marché déployé (fenêtre empty-market/first-depositor rouvre — initializer ne câble pas la whitelist par défaut) ; (c) DRIFT du bytecode déployé (re-diff vs repo) ; (d) déploiement World Chain / LaChain entre en scope ; (e) SIWE authorize testable (World App). Ne pas re-sweeper ETH-SC (drift=0, forteresse).
