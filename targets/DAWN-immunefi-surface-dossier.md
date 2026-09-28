# TARGET DOSSIER — Dawn (Immunefi) | xsurface-prioritize

TARGET: Dawn Internet (Andrena) — DePIN broadband sur Solana
PLATFORM: Immunefi — https://immunefi.com/bug-bounty/dawn/information/
ON-CHAIN PROGRAM (source): DAWN-Foundation/dawn @ db5396c (2026-09-18), Anchor 0.32.1
MAINNET PROGRAM ID: DawnxS4Adzh591GmqiDNfrSZBS4ENdQ9VDRStRJJ8qt7
DATE: 2026-09-28

## LIMITE DE VÉRIFICATION (à lire en premier)
- immunefi.com et depinhub.io sont bloqués par le proxy d'egress de cette session.
  => Je n'ai PAS pu lire le scope Immunefi officiel : liste exacte des assets-in-scope,
     table de récompenses, KYC, ni si le scope couvre l'off-chain (firmware routeur,
     backend API, pipeline oracle "proof-of-bandwidth" des challenger nodes Jito).
- Tout ce qui suit sur la surface ON-CHAIN est vérifié en lisant le source du programme.
  Tout ce qui touche le scope Immunefi est marqué [NON VÉRIFIÉ].

## FAIT DÉCISIF — LE PROGRAMME DÉPLOYÉ EST UN "MINIMAL DEPLOY"
Le module `#[program] mod dawn` (programs/dawn/src/lib.rs) n'expose que 5 instructions vivantes :
  1. init_token            (init one-time : TokenConfig PDA + mint DAWN PDA-owned)
  2. init_fee_accounts     (init one-time : PDAs fee/dao/validator/medallion)
  3. initialize_config     (init one-time : PDA seed fixe b"config", fixe authority=caller)
  4. init_metadata         (init one-time : metadata Metaplex)
  5. update_config         (gardé : constraint caller.key() == config.authority)

TOUT le reste est COMMENTÉ (bloc "// --- DISABLED: ... DAWN-minimal-deploy-squads ---") :
claim, subscribe / subscribe_for, extend / extend_for, add_l2/l3_plan, service_agreement,
add_device(_for), add_device_model, verify_device_location, tout AMF (register_auth_method,
register_credential(_for), revoke_credential, register/revoke_connection), tout IPAM
(init_root_ip_block, allocate_ip, lease_subscriber_ip(_for), revoke_ip).
Le code de ces handlers est compilé (`#[allow(dead_code)]`) mais N'EST PAS un point d'entrée
=> non atteignable via l'ABI du programme déployé.

## ASSETS (valeur terminale)
  A1: pools de tokens DAWN détenus par le programme (fee_pool/dao/validator/medallion) — vol de fonds
  A2: mint DAWN (autorité = TokenConfig PDA) — mint non autorisé
  A3: intégrité paiement/récompense (claim/payment/swap) — vol / bad accounting
  A4: [NON VÉRIFIÉ] pipeline off-chain proof-of-bandwidth (challenger nodes) — fabrication de récompenses
  A5: [NON VÉRIFIÉ] firmware/hardware routeur Dawn R1 — RCE device, usurpation d'identité device

## POINTS D'ENTRÉE VIVANTS & FRONTIÈRES DE CONFIANCE (on-chain, réels)
  - initialize_config : caller non contraint MAIS `init` sur PDA seed fixe => 1 seule fois.
    Sur un mainnet live ($18M levés, protocole opérationnel) le PDA config existe déjà
    => ré-init revert (Anchor `init` échoue si le compte existe). Front-run = non atteignable.
  - init_token / init_fee_accounts / init_metadata : mêmes PDAs one-time déjà consommés.
  - update_config : caller == config.authority (multisig Squads d'après les docs). Anon bloqué.
  - Frontière API : config.api_authority = clé qui agit "au nom des users" — pertinente
    UNIQUEMENT pour les instructions *_for, qui sont désactivées.

## ACTEURS
  - Anonyme : peut signer init_* / update_config mais tous échouent (déjà init / authority-gated).
  - authority (multisig) : update_config. Hors scope (admin-trust).
  - api_authority : agit pour les users sur les variantes *_for. Désactivées => inerte.

## CHEMINS CANDIDATS
  P-01: anon -> initialize_config -> devient authority -> draine via update_config
        reachability (q2): UNREACHABLE. PDA config déjà initialisé sur mainnet ; `init` revert.
        => DROP.
  P-02: anon -> claim/subscribe/payment/swap -> vol de fonds (A1/A3)
        reachability (q2): UNREACHABLE. Handlers non exposés (commentés dans mod dawn).
        => DROP pour la surface DÉPLOYÉE. Voir WATCH.
  P-03: anon -> IPAM/AMF -> détournement IP / credential (integrité)
        reachability (q2): UNREACHABLE. Handlers désactivés. => DROP.
  P-04: [NON VÉRIFIÉ] falsification métriques challenger -> récompenses fabriquées (A4)
        scope-exclusion: dépend du scope Immunefi ; logique off-chain probablement hors du repo.
        => WATCH / à qualifier une fois le scope Immunefi lisible.

## SURFACE LATENTE (WATCH — vaut une lecture quand les instructions seront réactivées)
Quand le "minimal deploy" s'ouvrira, la vraie surface à valeur haute est déjà écrite :
  - app/subscription/payment.rs (391 l.) — flux du token de paiement (USD.tel), fees.
  - app/claim.rs (353 l.) — claim de récompense, lockup 24h, CPI Raydium.
  - utils/swap.rs — prix calculé depuis les SOLDES SPOT des vaults Raydium
    (pool.token_price_x32 sur vault_0/vault_1 instantanés) => surface manipulation de prix /
    sandwich. Garde au call-site : min_dawn_out + deadline (MAX_DEADLINE_OFFSET_SECONDS).
    Edge à tester quand actif : robustesse de la borne slippage vs prix spot manipulable,
    cohérence du tri mint/vault (sort_accounts) sous pool malveillant/fake.
  - variantes *_for + api_authority : seam d'autorisation déléguée (qui peut agir pour qui).

## GATES (skill)
  - 6a scope-exclusion : le seul chemin on-chain réel restant (init front-run) est UNREACHABLE ;
    le reste est admin-trust (update_config) => exclusion DURE. Off-chain [NON VÉRIFIÉ].
  - 6b dup : surface déployée triviale et publique (repo public, un seul programme) => dup faible
    mais parce qu'il n'y a rien à trouver, pas parce qu'on a un edge.
  - 6c edge-fit : Rust/Anchor + Raydium CPI + pricing spot = edge-fit HIGH... mais sur du code
    NON DÉPLOYÉ => valeur atteignable nulle aujourd'hui.

## DÉCISION GLOBALE
NO-GO sur la surface ON-CHAIN DÉPLOYÉE aujourd'hui : les 5 instructions vivantes sont soit des
init one-time déjà consommés, soit authority-gated. Aucun chemin de valeur atteignable par un
attaquant externe. Un bug trouvé dans claim/payment/swap/ipam/amf porte sur du code non exposé
par l'ABI déployée => "not deployed / théorique" => mort en recevabilité, sauf si le scope
Immunefi rémunère explicitement le code destiné au déploiement (à confirmer).

CONDITIONNEL / WATCH :
  1. Off-chain (challenger nodes proof-of-bandwidth, backend API, firmware Dawn R1) : c'est là
     qu'est la vraie valeur ET la vraie nouveauté. Va/no-go IMPOSSIBLE à trancher tant que le
     scope Immunefi n'est pas lisible. ACTION : lire le scope depuis un réseau non bloqué.
  2. Réactivation des instructions désactivées : surveiller le repo/déploiement. Quand
     subscribe/claim/payment repassent en `#[program]`, re-trigger le skill : payment.rs +
     swap.rs (pricing spot) deviennent P0-candidats à edge-fit HIGH.

TEMPS ALLOUÉ (honnête) :
  - On-chain déployé : 0 (clos).
  - Confirmation active minimale : ~30 min — vérifier via RPC Solana que (a) le binaire déployé
    à DawnxS4... correspond bien à ce source minimal, (b) le PDA config est initialisé. (egress
    RPC bloqué dans cette session.)
  - Décision réelle du programme : conditionnée à la lecture du scope Immunefi (off-chain).
