# TARGET DOSSIER — Dawn / InfraFi (Immunefi) | xsurface-prioritize

TARGET: Dawn Internet (Andrena) — surface financière InfraFi (infrastructure.finance)
PLATFORM: Immunefi — https://immunefi.com/bug-bounty/dawn/information/
DATE: 2026-09-28 (v2 — scope Immunefi réel intégré)

## CORRECTION MAJEURE vs v1
Le scope Immunefi ne porte PAS sur le programme Solana `dawn` (analysé en v1, minimal-deploy,
NO-GO — voir §ANNEXE). Le scope réel est la couche **InfraFi** : un vault de crédit sur
Loopscale (Solana) dont le taux de change / prix de part est publié cross-chain vers un
contrat récepteur sur BNB Chain, plus le stablecoin USD.tel. C'est exactement le WATCH
off-chain (oracle/rate pipeline) signalé en v1.

## SCOPE OFFICIEL (4 targets, texte Immunefi fourni par l'utilisateur — autoritatif)
  T1  Loopscale credit vault (Solana, addr ...LQ9vZkSh, ajouté 21/09/2026)
  T2  Loopscale credit vault (Solana, addr ...yXAwuXSn, ajouté 11/08/2026)
      In scope: config & intégration du vault InfraFi — deposit/withdraw, borrow/repay,
      intégration de la deal-valuation ; autorisation du borrower ; sémantique
      exchange-rate / share-price que DAWN lit ET publie. IDL Anchor fetchable on-chain.
      HORS SCOPE: internals du protocole/programme Loopscale.
  T3  Contrat InfraFi sur BNB Chain (addr b...0778744c1, ajouté 15/07/2026)
      Reçoit/valide/stocke le taux de change publié par infrafi-api ; sanity checks ;
      consommation oracle downstream. In scope: autorisation de publication du taux,
      staleness/validation, tout chemin pour poster un taux manipulé ou ripcord-bloqué.
  T4  USD.tel — stablecoin M0 wrapped-M, Solana Token-2022 extension Pausable (15/07/2026)
      In scope: config du mint InfraFi et opération de la pause-authority.

## ARCHITECTURE (docs.infrastructure.finance + texte scope)
  Depositors -> Vault crédit sur Loopscale (Solana) -> part sUSD.infra (taux = NAV/parts).
  DAWN = SEUL borrower whitelisté, via multisig Squads V4, emprunte le capital du vault.
  infrafi-api (off-chain, closed-source) lit l'exchange-rate on-chain -> PUBLIE vers le
  contrat BNB -> le contrat BNB valide (staleness, sanity, "ripcord"/circuit-breaker) et
  stocke -> consommation oracle downstream.
  Loopscale value les sous-jacents via Pyth (decompose les LP). USD.tel = USD.infra (peg $1).

## LIMITE DE VÉRIFICATION (honnête)
  - immunefi.com, docs.infrastructure.finance, explorers/RPC : bloqués par l'egress proxy.
  - Le code in-scope n'est PAS open-source : l'org GitHub `infrafi` est une COLLISION DE NOMS
    (protocole de collatéralisation de nodes DePIN OORT/Helium, NodeVaultUpgradeable — RIEN
    à voir : grep loopscale/usd.tel/susd/squads/ripcord = 0). NE PAS auditer github.com/infrafi.
  - Donc la reachability (gate q2) est NON CONFIRMÉE depuis cette session. Conséquence skill :
    aucun chemin ne peut être P0 tant que la reachability n'est pas vérifiée sur artefact réel.

## ASSETS (valeur terminale)
  A1: principal du vault (capital des depositors InfraFi) — perte directe si borrower-auth
      contournée ou share-price manipulée à la sortie.
  A2: consommateurs downstream du taux publié sur BNB — mispricing si taux manipulé/stale
      accepté (c'est ici que vit "oracle manipulation -> drain" ; magnitude = ce qui consomme).
  A3: détenteurs sUSD.infra — intégrité du prix de part (mint/redeem au mauvais taux).
  A4: peg/supply USD.tel — mint non autorisé ou abus/DoS de la pause-authority.

## CHEMINS CANDIDATS (top-down, avant lecture profonde)
  P-01  Manipulation du taux cross-chain (JOYAU)
        attaquant -> influence l'exchange-rate lu par infrafi-api sur Solana OU fait accepter
        au contrat BNB un taux manipulé / stale / contournant le ripcord -> mispricing
        downstream -> extraction.
        scope: EXPLICITEMENT in-scope (T3 : "any path to posting a manipulated or
        ripcord-blocked rate", rate-publishing authorization, staleness/validation).
        edge-fit: HIGH (oracle cross-chain, peer-trust du publisher, staleness, ripcord =
        glue bespoke). dup: LOW. value: HIGH (si consommation downstream matérielle).
        reachability: NON CONFIRMÉE (besoin source BNB + auth infrafi-api). => TIER P1.
  P-02  Sémantique share-price / deal-valuation
        La NAV du vault inclut le prêt DAWN. Si la valuation d'un deal peut être forcée
        (mark stale, write-down de défaut manqué, timing d'accrual d'intérêts) -> le
        share-price publié est faux -> withdraw à prix gonflé draine, ou dépôts dilués.
        frontière: doit rester dans l'INTÉGRATION/config InfraFi (le wording "deal-valuation
        integration" garde ça in-scope), PAS dans la valuation interne Loopscale (hors scope).
        edge-fit: HIGH. dup: LOW-MED. value: HIGH. reachability: NON CONFIRMÉE. => TIER P1.
  P-03  Bypass d'autorisation du borrower
        DAWN seul borrower whitelisté via Squads V4. Chemin laissant un principal non
        whitelisté emprunter, ou emprunter hors du gate multisig -> drain direct du vault.
        frontière: l'angle in-scope est la CONFIG InfraFi de cette autorisation ; si le check
        est purement natif Loopscale -> risque HORS SCOPE.
        edge-fit: MED-HIGH. dup: MED. value: HIGH. reachability: NON CONFIRMÉE. => TIER P1/P2.
  P-04  Config mint / pause-authority USD.tel (Token-2022 Pausable)
        mint non autorisé (qui détient la mint authority ?), DoS via pause (geler transfers ->
        bloquer redemptions/liquidations), ou état de pause non réversible. M0 wrapped-M : un
        bug de config du mint peut casser le wrap 1:1.
        exclusion: si l'unique chemin est "la pause-authority pause méchamment" = admin-trust
        => DROP. Angle in-scope non trivial: MISCONFIG laissant un non-admin mint/pause, ou
        pause impossible à lever. edge-fit: MED. dup: MED. => TIER P2.

## EXCLUSIONS À GARDER EN TÊTE (gate 6a)
  - Internals programme/protocole Loopscale => HORS SCOPE (frontière dure). Tout finding
    enraciné là meurt quelle que soit l'impact.
  - Signers Squads / pause-authority "se comportant mal" = admin-trust => DROP sauf misconfig
    atteignable par un non-admin.
  - Arbitrage cross-chain / MEV comme seul impact => DROP.

## DÉCISION GLOBALE
GO CONDITIONNEL — allocation de recherche sur le SEAM oracle/rate-publishing (P-01, P-02),
PAS sur le programme on-chain dawn (tué en v1). Valeur et edge réels, dup faible, c'est le
type de cible que le skill privilégie. MAIS reachability entièrement non confirmée depuis
cette session (code in-scope closed-source ; explorers/RPC bloqués). Donc P1 "vaut un PoC"
contingent à l'obtention des artefacts, pas P0.

CONVERSION P1 -> P0 (à faire depuis un réseau non bloqué) :
  1. BscScan : source vérifiée du contrat BNB (b...0778744c1) -> lire auth de publication,
     fenêtre de staleness, logique ripcord, modèle de signer (single ECDSA = peer-trust ?).
  2. Solana RPC : IDL Anchor des deux vaults Loopscale (...LQ9vZkSh, ...yXAwuXSn) -> config
     du vault : enforcement du whitelist borrower, comptes share-price/exchange-rate, câblage
     deal-valuation. Confirmer ce qui est config InfraFi (in-scope) vs natif Loopscale (hors).
  3. infrafi-api : comment le publisher s'authentifie auprès du récepteur BNB (clé, signature).
  4. USD.tel Token-2022 mint (Solana) -> détenteurs mint authority + pause authority, config.

TEMPS ALLOUÉ (honnête) :
  - Programme on-chain dawn : 0 (clos, cf. annexe).
  - InfraFi rate-seam : GO pour la phase de reachability (~0.5–1 j) dès que les 4 artefacts
    ci-dessus sont lisibles. Décision P0 profonde conditionnée à ce que la reachability passe.

## ANNEXE — v1 : programme on-chain `dawn` = NO-GO (toujours valide, mais HORS scope Immunefi)
DAWN-Foundation/dawn @ db5396c, program-id mainnet DawnxS4Adzh591GmqiDNfrSZBS4ENdQ9VDRStRJJ8qt7.
Minimal-deploy : seules 5 instructions vivantes (init_token, init_fee_accounts,
initialize_config, init_metadata, update_config) ; toutes des init one-time déjà consommées
sur mainnet, ou authority-gated (update_config: caller==config.authority). Tout le reste
(claim, subscribe, payment, swap, IPAM, AMF) commenté/désactivé => non atteignable via l'ABI
déployée. Aucun chemin de valeur atteignable par un attaquant externe. Ce programme n'est de
toute façon pas dans le scope Immunefi ci-dessus.

## MAJ v3 — table de sévérité Immunefi + scope Web&App + reachability réseau

### Mapping valeur terminale -> sévérité Immunefi (impacts in-scope publiés)
  Critical : theft of user funds (at-rest/in-motion), permanent freezing of funds,
             protocol insolvency, unauthorized minting, manipulable RNG, gov manipulation.
  High     : temporary freezing of funds, theft/permanent-freeze of unclaimed yield.
  Medium   : griefing (pas de profit mais dommage), block stuffing, unbounded gas,
             contrat inopérant par manque de fonds.
  Low      : ne délivre pas le rendement promis mais sans perte de valeur.
  (La liste template mentionne NFTs/royalties — non pertinents ici ; ignorer.)

### Sévérité attendue par chemin (numérateur du scoring)
  P-01 taux manipulé -> mispricing downstream :
        - si extraction de fonds / insolvency        => CRITICAL
        - si ripcord bloque un taux légitime -> gel   => HIGH (temp) / CRITICAL (permanent)
  P-02 share-price faux -> withdraw à taux gonflé      => CRITICAL (theft / insolvency)
  P-03 bypass borrower-auth -> drain vault             => CRITICAL (direct theft)
  P-04 USD.tel :
        - mint non autorisé                            => CRITICAL (unauthorized minting)
        - pause non réversible -> gel permanent        => CRITICAL (permanent freezing)
        - pause griefing temporaire                    => HIGH (temp freeze) / MEDIUM (grief)

### Scope Web & App (nouveau) — probablement le meilleur ratio reachability
  Le programme a une catégorie "Web & App" en plus de "Smart Contract". Les deux hôtes live :
    - api.infrastructure.finance  == infrafi-api (le PUBLISHER du taux, cœur de T3)
    - app.infrastructure.finance  == frontend
  Implication : l'autorisation de publication du taux (T3) est peut-être testable côté WEB
  (bypass d'auth sur l'endpoint de publication, faille de validation côté API) — souvent
  reachability plus haute et dup plus basse que le versant on-chain. À prioriser si la liste
  Web&App confirme ces endpoints in-scope. [Liste Web&App non encore fournie.]

### Reachability réseau depuis CETTE session : NULLE
  curl vers api./app./docs.infrastructure.finance = 403 CONNECT tunnel (egress proxy).
  BscScan, Solana RPC : bloqués. GitHub : ok (mais code in-scope pas open-source).
  => Toute la phase de reachability/PoC doit se faire depuis un réseau non bloqué. Ce dossier
     est le plan de tir ; il ne peut pas être exécuté ici.

### Ordre d'attaque recommandé (quand artefacts/réseau dispo)
  1. api.infrastructure.finance : mapper l'API (endpoints, auth, chemin de publication du taux).
     Chercher : qui peut POSTer un taux ? signature/clé vérifiée ? rejeu ? borne staleness ?
  2. Contrat BNB (b...0778744c1) sur BscScan : auth de setRate, staleness, ripcord, single-signer.
     Croiser avec (1) : le contrat fait-il confiance à un signer que l'API expose/mal protège ?
  3. Vaults Loopscale (IDL) : câblage share-price/deal-valuation + enforcement whitelist borrower
     qui soit CONFIG InfraFi (in-scope) et non natif Loopscale (hors scope).
  4. USD.tel Token-2022 : mint authority + pause authority holders, réversibilité de la pause.
