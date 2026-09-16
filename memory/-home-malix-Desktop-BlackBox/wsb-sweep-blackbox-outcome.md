---
name: wsb-sweep-blackbox-outcome
description: "Sweep « substitut faible lié en silence » sur les 13 cibles BlackBox (2026-08-07) — 0 finding, 33 réfutations exécutées, 4 portes ouvertes nommées."
metadata: 
  node_type: memory
  type: project
  originSessionId: 0e186640-6bf5-4757-9c53-148601ee9cbf
  modified: 2026-08-06T23:46:35.587Z
---

Sweep de la classe [[weak-substitute-binding-class]] sur stacks / cosmos / cn / hiero-cryptography /
lombard-sol / sonobe / up-groth16 / relay / dcl-web, le **2026-08-07**. 47 agents, 5,4 M tokens,
1947 appels d'outils, 1 h 49. **Résultat : 0 CONFIRMED, 0 PLAUSIBLE, 33 REFUTED.**

**Ne pas relancer ce sweep.** L'espace négatif est établi et coûte cher à reproduire.

Axe de mort primaire : axe 0 (prior-art) 12 · axe 4 (pas plus faible) 9 · axe 3 (ne lie pas) 7 ·
axe 2 (scope) 4 · axe 5 (ne paie pas) 1.

**Le signal méthodologique :** 9 candidats sur 33 ont survécu aux axes 0-3 et sont morts sur l'axe 4.
Mécanisme réel, arm faible réellement expédié — mais un contrôle aval redondant rend les deux arms
équivalents. C'est la signature de cette classe sur du code mature : le sélecteur existe, la faiblesse
non. Réfutations exécutées, pas raisonnées (différentiel 411 534 payloads sur ibc-go rate-limiting ;
18 236 cas natif-vs-Java sur les précompiles Besu ; 10 730 tests clarity sous `rollback_value_check`).

**Le meilleur candidat, vérifié à la source à la main (mécanisme RÉEL, tué sur le scope) :**
`ibc-go/modules/light-clients/attestations/signature.go`. `normalizeSignature:102-109` ne remappe que
27→0 et 28→1 ; tout le reste passe. En aval, geth v1.17.5 diverge par build tag : l'arm cgo
(`crypto/secp256k1/secp256.go:167`) rejette `sig[64] >= 4` ; l'arm nocgo (`signature_nocgo.go:51`) fait
`btcsig[0] = v + 27` sans contrôle, et decred (`ecdsa/signature.go:869-882`) accepte [27,34] puis
`& 3`. Donc **v ∈ {4,5,6,7} est accepté par un binaire `CGO_ENABLED=0` et rejeté par un binaire cgo**,
en récupérant la même adresse d'attestor. Non-déterminisme entre builds dans une vérif consensus →
classe apphash-mismatch. **FERMÉE le 2026-08-07 sur DEUX axes indépendants, ne pas rouvrir :**
- *Axe 3 (binding, le kill dur)* : `gh search code "attestations.NewLightClientModule"` → le seul
  consommateur Go hors simapp/docs est `cosmos/sandbox-ledger:app/app.go`. Son `docker.yml` publie en
  multi-arch (`linux/amd64,linux/arm64`) **sans `build-args`**, donc Dockerfile par défaut
  `BUILDTYPE=source` → compilation dans `golang:1.25-alpine` **avec `apk add build-base`**, et le
  Makefile fait `go build` sans `CGO_ENABLED=0`. Cgo activé sur les deux arches publiées ⇒ **l'arm
  faible ne lie dans aucun artefact expédié**. Le chemin `BUILDTYPE=prebuilt` est un crochet sans
  producteur : `release.yml` ne construit que des contrats Solidity.
- *Axe 2 (scope)* : `doc.go:5` / `README.md:10` « This package is EXPERIMENTAL and is not yet
  stable » ; zéro tag de release du module ; `sandbox-ledger` = 1 étoile, « showcasing » ;
  `cosmos/ibc-attestor` est en **Rust** (il signe, il ne vérifie pas) ; Gonka (`6block/gonkascan`)
  n'a que les protos générés, aucun code Go qui enregistre le client.
Ne ressusciter que si une chaîne à valeur réelle enregistre le client ET publie un binaire
`CGO_ENABLED=0` — et l'annotation EXPERIMENTAL plafonnera quand même.

**Trois autres portes, chacune avec son artefact unique** (aucune n'est un finding) :
- ~~`KeysAndCertsGenerator` / `pcli generate-keys`~~ — **FERMÉE le 2026-08-07, ne pas rouvrir.**
  Le générateur est bien déterministe (javadoc `:64-65` « generated as a function of the node ID » ;
  impl `:73-84` = pure fonction de nodeId, zéro entropie), mais il n'a **aucun chemin de production**,
  prouvé sur quatre traces : (1) `gh search code --repo hiero-ledger/solo` → **zéro** hit pour `pcli`,
  `generate-keys` et `KeysAndCertsGenerator` ; solo utilise `solo keys consensus generate
  --gossip-keys --tls-keys`. (2) `gh search code --owner hiero-ledger '"pcli generate-keys"'` →
  **zéro** hit org-wide. (3) Le seul invocateur est `hedera-node/hedera-app/build.gradle.kts:163`,
  tâche Gradle de run **local** (`-local 0`), où le déterminisme est délibéré et PORTEUR — commentaire
  `:154-156` : le cert doit matcher le `gossipCaCertificate` pré-inscrit dans
  `configuration/dev/genesis-network.json`. (4) L'overload déterministe `generate(NodeId)` n'atteint
  `src/main` que via `ConsensusNoOpModules` → `pcli/DiagramCommand` (dessin de diagramme) et
  `src/test/`. Les vraies clés viennent de `hedera-node/data/keys/generate.sh` (`keytool -genkeypair`).
- `stacks-common/src/util/secp256k1/wasm.rs:236` — divergence low-S natif/wasm exécutée. Ne lie dans
  aucun artefact stacks-core. Artefact : `@stacks/clarinet-sdk` → cible hirosystems/clarinet, pas
  stacks-core, plafond Low/Info.
- `ibc-go/modules/apps/rate-limiting/keeper/packet.go:233` — fail-open réel, 0 paquet exploitable
  contre ICS20. Rouvre seulement si un stack de prod met un terminal app NON-ICS20 sous
  `ratelimiting.NewIBCMiddleware` (rien dans `SetUnderlyingApplication` ne l'empêche).

**Ce qui est prouvé propre et n'est plus à refaire :** `process.env` truthy dans relay (9 occurrences,
aucune en condition) · fuite de la feature `testing` de stacks (toutes les arêtes en dev-dependencies,
repro resolver-2 exécuté) · RNG à graine fixe dans les six arbres ZK · `#[cfg]` sur validation/owner/
signer/PDA dans lombard-sol · `System.getProperty(x) != null` dans `cn` · `_ = *Verify(...)` dans les
modules Go cosmos. L'inventaire complet des build tags cosmos est clos.

**Le durcissement `debug_assert` a tenu partout et n'a rien donné :** aucun `[profile.release]` de
BlackBox ne réactive `debug-assertions`, donc les assertions SONT retirées — mais dans chaque cas le
code aval rejette l'état invalide de lui-même (fail-closed), ou l'assertion était disjointe du défaut
qu'on lui prêtait (simulation sonobe : 3,48 M évaluations, 0 violation corrélée).
