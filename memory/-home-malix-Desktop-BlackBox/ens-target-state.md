---
name: ens-target-state
description: "ENS — comp Immunefi = apps-only ; SC WrapperRegistry tué by-design ; apps = #1 false-success registration SOUMIS #89327, #2 migration role-assignee RÉFUTÉ, cluster Low api-worker ouvert."
metadata: 
  node_type: memory
  type: project
  originSessionId: fcc7d312-e6c4-471a-a52c-b9b70879eda2
  modified: 2026-08-22T11:27:37.448Z
---

Cible ENS, mesurée le 2026-08-18. DEUX repos distincts, ne pas les confondre.

**Scope réel de la comp (18 août → 14 sept 2026, $49k).** 5 assets, TOUS Web & App, dans
`github.com/immunefi-team/audit-comp-ens@audit-comp-ready` (commit gelé `1c9b47f`, fork privé de
ensdomains/apps-monorepo@63772fd → pas de veine drift, l'upstream est inaccessible) :
`apps/manager` `apps/portal` `workers` `packages/transaction-manager` `packages/smart-account`.
Verbatim page scope : "The ENS smart contracts, subgraph/indexer, and NFT metadata service are out of scope".
⚠️ `packages/migration` `packages/l2-primary` `packages/indexer` `packages/utils` ne sont PAS des assets —
une finding qui y prend racine doit être ancrée sur un fichier `apps/manager|portal`.

**Les 4 axes de mis-signing nommés par le programme : chain, sender, target, arguments. Seuls chain
(EXP-4337-002) et sender (EXP-4337-003) sont brûlés en known-issue. `to` et `data` étaient le trou.**
Les carve-outs qui DÉFINISSENT une finding neuve (à relire avant toute soumission) : QA-03 (displayed total vs
amount actually charged), R2-03 (authority beyond stated lifetime/permissions), R2-02 (an actual injection sink),
QA-01 (role combination granting unintended authority), SEC-TXM-002 (a concrete attack path), et la Code Freeze
Assurance : "Bypassing a deployed fix is considered a new, valid bug".

**Côté smart contracts (ensdomains/namechain, HORS SCOPE ici) :** finding "WrapperRegistry root roles survive
the sale" TUÉ par mesure — `contracts/README.md:124-128` documente le comportement (exemple Alice/Bob/Charlie),
et le même plant survit sur un `.eth` ordinaire avec un effet pire. Voir [[by-design-gate-not-just-git-dup]].

**Côté apps — #1 SOUMIS, #2 RÉFUTÉ, cluster Low ouvert.** (Ne plus présenter #2 comme un lead vivant — mesuré-tué 18 août, réaffirmé réfuté.) Détail complet, file:line et négatifs mesurés :
`~/Desktop/BUGS/ens-app-verdict/STATE.md` (245 l.). Repos clonés : `~/Desktop/BUGS/ens-app`, `~/Desktop/BUGS/namechain`.
1. FALSE "Registration Complete" — SOUMIS #89327 (2026-08-18, @MalikX31, asset transaction-manager, impact 'display incorrect transaction detail', sévérité HIGH ancrée R3-01..R3-04). — `transaction.machine.ts:300` `isReverted: receipt?.status==='reverted'` +
   `confirming.always` tombe direct sur `success` ; `waitForTransactionReceipt` appelé SANS `onReplaced` et
   `receipt.transactionHash` jamais comparé à `context.hash` ; `registration.machine.ts:1426-1441` câble le
   vérificateur on-chain UNIQUEMENT sur `onError`. Un "Cancel" wallet (self-send 0 au même nonce, receipt success)
   ⇒ l'app affirme la registration. Les 2 fichiers ont ZÉRO test.
2. MIGRATION role assignee — `buildRoleGrantCalls.ts:23` signe `grantRoles(resource, ROLE_SET_RESOLVER, managerAddress)`
   où managerAddress vient UNIQUEMENT du subgraph (`classifyNames.ts:162`), alors que le token owner est vérifié
   on-chain deux fois. Révocable (le owner a ROLE_SET_RESOLVER_ADMIN) ⇒ Medium, pas Critical.
#2 (migration role-assignee) MESURÉ-TUÉ 2026-08-18 : owner.id vient SEUL du subgraph (HORS SCOPE verbatim) ; subgraph honnête => check on-chain immatériel (restaure le vrai manager v1, déjà en contrôle resolver) ; révocable + by-design 'manager restoration' ; QA-01 non atteinte. NE PAS SOUMETTRE. Migration flow par ailleurs mesuré-clean.
3. Low api-worker : rate-limit email contournable par aliasing (+tag/points), oracle d'énumération, replay
   webhook SendGrid (timestamp signé jamais borné), application d'events non scopée par user, telegram bindable
   à N comptes.

**Leçon transversale :** R2-03 et `HCA_SESSION.md`/`sessionGate.ts` décrivent un modèle de session MORT
(plain owner). Le code déployé est une SmartSession scopée, 24h, bornée on-chain. Une known-issue peut être
périmée — vérifier le code avant de conclure "dup". Voir [[measure-before-asserting-in-reports]],
[[recevability-gate-before-poc]], [[bounty-playbook-5-gates]].
