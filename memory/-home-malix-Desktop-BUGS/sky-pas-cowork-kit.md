---
name: sky-pas-cowork-kit
description: "Kit tâche récurrente Cowork (machine locale) — surveillance ON-CHAIN quotidienne du Sky PAS : la moitié que la routine CCR ne peut pas voir (RPC bloqués dans l'environnement remote). Script tools/sky-pas-onchain-watch.sh + prompt prêt à coller."
metadata:
  node_type: memory
  type: project
---

# Kit Cowork — surveillance on-chain Sky PAS

## Pourquoi deux canaux

| | Routine CCR (déjà armée) | Tâche Cowork locale (ce kit) |
|---|---|---|
| Source | Repos de spells (git ls-remote, PRs incluses) | État on-chain mainnet (event logs, read-only) |
| Voit | Le code des spells AVANT exécution | Ce qui s'est réellement exécuté, y compris HORS spell (SubProxy direct, actions cBeam) |
| Réseau | git seulement (proxy egress) | RPC libre (ta machine) |
| Fréquence | Quotidienne 08:00 UTC, `trig_01QNtYtsK6jjKgv3M2rzByTi` | Quotidienne (à créer dans l'app Cowork) |

## Prérequis machine

- `cast` (Foundry), `python3`, `curl` — déjà présents si tu utilises `tools/evm-anchor.sh`.
- Un RPC mainnet : `export ETH_RPC_URL=...` (défaut : `https://ethereum-rpc.publicnode.com`, sans clé). Pas de clé Etherscan nécessaire.
- Ce repo synchronisé sur la machine (le script est `tools/sky-pas-onchain-watch.sh`).

## Ce que le script détecte

Event logs des 7 contrats (BeamState, Configurator, Timelock, RateLimits+AccessControls de Grove et d'Osero), décodés et triés :

**ALERTES (exit 20)** — les WATCH conditions du dossier `sky-pas-beamstate-immunefi-engagement.md` :
- **W1 / P-01 ARMÉ** : `AddInitRateLimits` avec `maxAmount == max && slope > 0` → le gap unlimited-slope (PoC dans le dossier) devient exploitable → analyser et préparer la soumission Immunefi (targets PAS_STATE / PAS_CONFIGURATOR).
- **W2** : default générale `address(0)` → cross-Star (Grove/Osero partagent le namespace de clés, vérifié par hash).
- **W3** : calldata controller approuvée en slot général `address(0)`.
- **W4** : `Unpaused` sur le Timelock → le flux DELAYED s'active.
- **P-01 ÉTAT ARMÉ** : `RateLimitDataSet(key, max, slope>0)` directement dans un PAU — clé unlimited per PAU non protégée par le Configurator.
- **ZEROING** : un cBeam met une clé à (0,0) via le Configurator — porte à sens unique, récupération = spell.
- **ADMIN** : grant/revoke de `DEFAULT_ADMIN_ROLE` sur un RateLimits/AccessControls/Timelock.

**ÉVÉNEMENTS (exit 10)** — activité à lire mais pas alarmante par défaut : chaque `setRateLimit` cBeam (surveiller la cadence de ratchet : >1 augmentation/16h/clé = anomalie, +20 % max par step), `CallScheduled` sur le Timelock (lire la proposal avant exécution), nouvelles pairings, Stop/Start, SetHop/SetMaxChange, defaults spécifiques bénignes.

**Exit 0** : rien depuis le dernier bloc scanné.

État local : `~/.sky-pas-watch/` (dernier bloc scanné + dernier rapport). Premier run : bisection du bloc de déploiement de GroveRateLimits puis scan complet — plusieurs minutes, une seule fois.

## Statut de validation — honnête

- Décodeur testé unitairement avec des logs synthétiques couvrant les 7 chemins d'alerte : tous corrects (session du 2026-09-20).
- Topics `cast keccak` cross-checkés contre les valeurs canoniques connues (Rely, RoleGranted, Paused, CallScheduled).
- **La couche RPC (cast logs/code/block-number) n'a PAS pu être testée depuis l'environnement remote (proxy bloque tous les RPC). Le premier run local est le run de validation** : si un RPC public tronque `eth_getLogs`, réduire `CHUNK` (40000 → 5000) ou passer un RPC dédié via `ETH_RPC_URL`.

## Prompt de la tâche récurrente Cowork (quotidienne) — à coller tel quel

```
Tâche quotidienne sky-pas-onchain-watch (surveillance on-chain du Sky PAS, Immunefi $10M).

1. Va dans le repo bug-bounty-methodology local (git pull d'abord, branche master ou
   claude/sky-pas-state-audit-shdcpl si pas encore mergée — le script et le dossier y sont).
2. Exécute : ETH_RPC_URL=${ETH_RPC_URL:-https://ethereum-rpc.publicnode.com} ./tools/sky-pas-onchain-watch.sh
3. Interprète le code de sortie :
   - 0 → rien. Termine en silence, ne me notifie pas.
   - 10 → lis les ÉVÉNEMENTS du rapport (~/.sky-pas-watch/report.txt). Vérifie en particulier
     la cadence des setRateLimit cBeam (la règle : max +20 % par step, 1 step par 16 h par clé ;
     une cadence supérieure ou des montants incohérents = anomalie à me signaler).
     Sinon, ajoute une ligne de synthèse datée dans
     memory/-home-malix-Desktop-BUGS/sky-pas-beamstate-immunefi-engagement.md (section à créer
     "JOURNAL ON-CHAIN" en fin de fichier), commit + push. Ne me notifie que si quelque chose
     sort de l'ordinaire.
   - 20 → ALERTE. Lis la section "WATCH conditions précises" et la description de P-01 dans
     memory/-home-malix-Desktop-BUGS/sky-pas-beamstate-immunefi-engagement.md, puis :
     * W1 ou "P-01 ÉTAT ARMÉ" → le finding P-01 (gap unlimited-slope du Configurator, PoC déjà
       écrit dans le dossier) devient exploitable sur l'état réel. Refais l'analyse adversariale
       contre l'état on-chain exact (cast call getRateLimitData/getInitRateLimits pour confirmer),
       et si ça tient, prépare un brouillon de rapport Immunefi (targets PAS_STATE /
       PAS_CONFIGURATOR, sky-ecosystem/pas commit 947e71c) SANS le soumettre — je valide avant
       toute soumission. Notifie-moi immédiatement.
     * W2/W3/W4/ZEROING/ADMIN → analyse l'impact réel (pas de théâtre : distingue action de
       gouvernance légitime vs anomalie), mets à jour le dossier, notifie-moi avec ton verdict
       et les faits, pas des suppositions.
   - Autre code / erreur réseau → réessaie une fois ; si ça persiste, signale l'erreur brute.
4. Règle permanente : verdicts honnêtes, faits vérifiables uniquement. Un événement de
   gouvernance normal n'est pas une alerte.
```

## Création de la tâche

App Cowork sur ta machine → tâches planifiées → nouvelle tâche quotidienne (choisir une heure décalée de la routine CCR de 08:00 UTC, p.ex. 14:00 locale, pour deux points de mesure par jour) → coller le prompt ci-dessus. La tâche doit tourner sur la machine où ce repo est synchronisé (elle a besoin du script, du dossier, et du réseau ouvert).
