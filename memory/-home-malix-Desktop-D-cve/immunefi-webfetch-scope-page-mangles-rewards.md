---
name: immunefi-webfetch-scope-page-mangles-rewards
description: WebFetch on Immunefi /scope/ SPA pages hallucinates reward $ amounts; verify the grid on /information/ (Rewards by Threat Level) or by browser
metadata: 
  node_type: memory
  type: reference
  originSessionId: 842c0079-8868-49b2-b252-41a2746966cf
  modified: 2026-09-09T19:12:49.965Z
---

Le petit modèle de **WebFetch mange/hallucine les montants de récompense** sur les pages Immunefi (SPA JS). Vu deux fois: sur Stacks (extraction initiale à corriger) et sur Strata (fetch /scope/ a sorti High $150k/Med $50k/Low $10k alors que le vrai est High $10k/Med $5k/Low $1k).

**How to apply:** ne JAMAIS citer un tier de reward Immunefi depuis un fetch de la page /scope/. Vérifier la grille sur la page **/bug-bounty/<prog>/information/** avec un prompt laser "Rewards by Threat Level verbatim, exact Max/Min" (plus fiable), ou via le navigateur (Claude in Chrome) pour le DOM réel, ou demander à l'opérateur. Croiser au moins deux sources indépendantes avant de baser une décision d'EV/tier sur un montant. Le reste de la page /scope/ (liste d'assets, impacts, OOS) est fiable; seuls les CHIFFRES sont à re-vérifier. Corollaire général: front-load la recevabilité mais avec des chiffres vérifiés, pas des chiffres de fetch.

**MÉTHODE GROUND-TRUTH (2026-09-14, Pyth):** les pages Immunefi sont du Next.js RSC streamé. `curl -A firefox <page>` puis extraire les `self.__next_f.push([n,"..."])` et `json.loads` chaque string → blob décodé = source serveur exacte. Les rewards y sont en objets structurés (`smartcontract_rewards`/`web_rewards` PEUVENT être `[]` = leurre; la vraie grille est une liste d'objets `{max,min,"range"|"fixed"}` en fin de payload, ex. ids 50890-50897). Les 30 impacts en objets `{id,type,severity,title}`. Sur Pyth le fetch WebFetch avait raison sur la grille mais a halluciné "30 impacts critical" (30 = TOTAL, 13 critical). → décoder le RSC est plus fiable que croiser 2 WebFetch. Artefacts sauvés dans `pyth/.recon/`.
