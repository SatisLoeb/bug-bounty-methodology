---
name: wide
description: >-
  Veine ALLOCATION — Stage 0 sur une cible multi-surface (échange, wallet + extension + web + webview, suite d'apps). Activer AVANT toute profondeur, pour décider OÙ la dépenser. Structure = SURVOL LARGE puis DÉCISION : lis le programme par ratio capacité-veine/plafond AVANT de plonger, jamais "ça a l'air intéressant". Range les surfaces par capacité×plafond×accessibilité-solo×(1/dup) ; profondeur sur une seule. Sort sur une question gating à l'opérateur (coût d'exécution réel).
---

# wide — allocation Stage 0 (où dépenser la profondeur)

## PATTERN BANK (corpus-query, SC-surfaces only) - alimente la Phase 1/3 (densité de classe)

> **Caveat domaine (corpus-integration fix, 2026-06-23) :** `corpus-query <shape>` ne couvre que les shapes SC (amm/lending/bridge…). wide est MULTI-SURFACE — pour les surfaces web/extension/mobile que wide alloue aussi, la densité-de-classe vient de `H1-HUNTING-PATTERNS` + `precedent-scan.sh`, PAS du corpus.

    ~/arsenal/tools/corpus-query.sh <shape>   # amm|lending|vault|bridge|perp|staking|stablecoin|governance|nft|other

Émet par shape : la priorité densité-de-classe (quelles classes paient le plus + leur
detection_tell), les patterns nommés P-XXX de la shape, et le set P-ORACLE cross-cutting.
En Phase 1 (lecture-plafond) et Phase 3 (veines-capacité par surface), c'est la mesure de
densité qui dit quelle classe-capacité paie sur chaque surface. `--json` pour parser.
Corpus en place : ~/Desktop/BUGS/c4-patterns/PATTERN-TAXONOMY.md + ~/Desktop/BUGS/solodit-corpus/.


Veine = ALLOCATION (la décision d'OÙ creuser, avant de creuser).
Structure = survol large → décision. La leçon Morph : lire le programme par
ratio capacité-veine/plafond AVANT la profondeur, pas "looks interesting".
[Formalisé 2026-06-22 depuis l'usage réel bitget-wide/analysis/{STAGE0-ALLOCATION,ALLOCATION-DECISION}.md.
Version canonique (skill nouveau, n'a jamais existé ailleurs) ; affiner à l'usage.]

## Phase 1 — LECTURE DE PLAFOND (en premier, avant tout dig)

Mappe chaque surface → son plafond $ + quelles CLASSES-CAPACITÉ paient le top tier.
(Bitget : web 20k, extension 50k, "core w/ financial impact" 1M, desktop 1.5k→SKIP.)
Ratio veine-capacité/plafond GOOD = on continue, MAIS seulement si on touche une
CAPACITÉ PAYANTE — bouger-la-valeur, agir-pour-autrui, OU (selon ce que le programme
paie) geler/DoS une fonction sensible, exposer la donnée/identité d'autrui (deanon/PII).
Plafond élevé sur une surface sans AUCUNE capacité payante = mirage ; mais une "view"
qui fuit la donnée d'un tiers, ou un DoS qui bloque des fonds, N'EST PAS un mirage —
c'est une capacité sur l'axe confidentialité/disponibilité que le programme paie.

## Phase 2 — MURS DE SCOPE DURS (lire avant de digger)

- contraintes programme : anti-AI (→ chill + report-nerve + verify manuel obligatoires),
  LIVE-target-pas-repo (→ gated-is-not-a-verdict + jamais-toucher-compte-non-opérateur ;
  la plupart des piercings finissent en HARNESS+SUSPEND), scope-literalism (sous-domaines/
  ISV/versions OOS), débit ≤Nreq/s.
- liste EXCLUS instant-close : ne génère JAMAIS ces classes (headers, self-XSS, CSRF-sans-
  impact, URL-spoof, clickjacking-non-sensible, rate-limit-non-auth, DoS réseau, root-only…).

## Phase 3 — ÉNUMÉRER LES VEINES-CAPACITÉ PAR SURFACE

Par surface, liste les veines CAPACITÉ (move-value / act-as-another / sign-on-behalf),
pas les views. (extension : silent-signing, key-exfil, recipient/amount altéré post-approval.
web : mass-ATO, auth-bypass-at-scale, IDOR-write sur action-fonds, withdraw/apikey-CSRF.
webview : tx-affichée≠tx-signée, DApp-injecté dans la liste officielle.) Le seam web2↔web3
que personne ne possède = haute densité.

## Phase 4 — DISPATCH RECON LARGE (parallèle, read-only)

Lance N agents read-only, un par surface, en mapping-veine-capacité (pas en exploit).
Chacun rend : "l'endpoint/seam existe + le gate est uniforme/tient" — le map, pas le verdict.

## Phase 5 — DÉCISION D'ALLOCATION (après retour des maps)

Classe chaque candidat : CAPACITÉ-PAYANTE (observée, pas inférée — bouger-valeur ·
agir-pour-autrui · geler/DoS-fonction-sensible · exposer-donnée-d'autrui/deanon) vs
VIEW-INERTE (lecture de donnée publique · DoS non payé · missing-valid sans impact).
Un leak de la donnée d'autrui et un DoS qui bloque des fonds SONT des capacités-payantes,
PAS des views inertes (`~/.claude/skills/IMPACT-LEDGER-PLAYBOOK.md`).
Range par **capacité × plafond × accessibilité-solo × (1/dup-risk)**. Profondeur sur UNE
seule — la plus haute. Favorise la veine SOUS-explorée (les N rapports existants ont déjà
pris les veines évidentes : XSS reflété, open-redirect, IDOR-endpoint-évident).

## Phase 6 — QUESTION GATING (à l'opérateur)

Quel est le COÛT D'EXÉCUTION de la veine n°1 ? (2 comptes KYC ? un wallet ? l'app+device ?)
Tout ce qui exige une session authentifiée ou un vrai wallet = HARNESS-OPÉRATEUR (suspend +
probe exacte), jamais un touch autonome. Je map et je construis la probe ; l'opérateur l'exécute.
- opérateur peut → build le harness de la veine n°1.
- opérateur ne peut pas → PARK l'account-gated, et bascule sur le FALLBACK ACCOUNT-FREE :
  endpoints unauth qui sont eux-mêmes des power-ops (signature-login wallet/sign, tg/signV2 :
  un nonce/HMAC faible = mass-ATO prouvable SANS 2 comptes), bugs statiques du bundle.

## DISCIPLINE 2e-MAXIME (sur tout retour d'agent)
L'agent MAP où vit le flux ; je n'accepte JAMAIS son verdict "a un nonce → fortress" /
"pas de nonce → vein". Je lis en adversaire : pas "comment marche le flux" mais "quel
input/état le dev n'a PAS imaginé". Sur un signature-login : le serveur ecrecover-il
l'adresse DU message signé, ou la prend-il d'un champ publicAddress SÉPARÉ ? Si séparé →
signe avec MA clé, mets TON adresse → ATO cross-compte avec UN wallet jetable, zéro 2-comptes.
Chaque KILL = ligne-croyance + ligne-adversariale + résultat-EXÉCUTÉ.

## DETTE DE VALIDATION (honnête)
Validé sur Bitget (allocation faite : web>webview>extension par ratio ; harnesses designés ;
exécution parquée faute de comptes opérateur). La boucle complète "alloue → exécute → paie"
n'a pas bouclé en réel ; la lecture-plafond et le rang capacité×accessibilité sont validés,
la conversion en payout via harness-opérateur ne l'est pas encore.
