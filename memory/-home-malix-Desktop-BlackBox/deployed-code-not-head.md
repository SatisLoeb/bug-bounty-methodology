---
name: deployed-code-not-head
description: "Auditer le commit DÉPLOYÉ, pas le HEAD — et le prouver par le bytecode, pas par les adresses."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0e186640-6bf5-4757-9c53-148601ee9cbf
  modified: 2026-08-06T21:35:23.497Z
---

Avant toute lecture profonde d'une cible on-chain : établir quel commit produit le **bytecode déployé**,
et y baser la lecture (worktree dédié).

**Why:** sur The Graph (août 2026), le HEAD était très en avance sur Arbitrum. Des heures de lecture ont
porté sur du code non déployé (`reclaimRewards`, `AllocationHandler`, `adjustThaw`), pendant que le code
réellement en production contenait une surface entière **invisible au HEAD** : un `fallback()` de
HorizonStaking en delegatecall vers un HorizonStakingExtension legacy.

**How to apply:** des adresses d'implémentation identiques entre chaîne et address-book ne prouvent RIEN —
elles disent juste que les deux désignent le même contrat. La preuve est le **bytecode** : `cast code` puis
recherche de sélecteurs (`cast sig`) présents/absents, en test différentiel entre les versions candidates.
Chercher aussi les tags de déploiement annotés (`git ls-remote --tags | grep deploy/`) : leur corps
enregistre le commit. Voir [[recevability-gate-before-poc]].

**Corollaire — les clones locaux de BlackBox sont SHALLOW.** Vérifié sur `cosmos/ibc-go` (2026-08-06) :
`git rev-parse --is-shallow-repository` → true, refspec `+refs/heads/main:refs/remotes/origin/main`
seul, **un seul tag** dans tout le clone. Conséquences directes sur la méthode :
- `git tag --list '<motif>'` qui ne renvoie rien **ne prouve pas** l'absence de release amont — c'est un
  artefact du clone. Ça a failli produire une conclusion de scope fausse sur 08-wasm.
- `git log -S` / `--grep` sont **tronqués** : le hit le plus ancien n'est pas le commit d'introduction,
  donc l'archéologie « ce défaut est-il déjà connu ? » y est non concluante en négatif.
Réflexe : lancer `git rev-parse --is-shallow-repository && git tag | wc -l` **avant** de baser quoi que ce
soit sur l'historique. Une preuve tirée de la **source lue** (un commentaire, une branche `#[cfg]`, un
fichier absent) est indépendante de la profondeur du clone — la préférer quand elle suffit.
