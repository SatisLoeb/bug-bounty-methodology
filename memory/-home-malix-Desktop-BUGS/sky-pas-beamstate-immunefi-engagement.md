---
name: sky-pas-beamstate-immunefi-engagement
description: "Sky PAS (Immunefi $10M) — CLOS 2026-09-20 en mode WATCH dormant : 4/4 targets core auditées (BeamState, Configurator, Timelock, Mom) @ 947e71c, 0 soumissible, 1 chemin vivant (P-01 unlimited-slope, PoC vert) armable par les futures defaults de prod ; 2 moniteurs quotidiens actifs (spells watch 08:00 UTC + go/no-go artifact 13:04 UTC) + kit Cowork en secours ; réveil sur W1-W4"
metadata:
  node_type: memory
  type: project
---

# Sky PAS — PAS_STATE (BeamState.sol) — Immunefi

**TARGET**: `sky-ecosystem/pas` @ `947e71cd5dbaaf9c5b3840dd1b23e8e99d9a564d` (HEAD au 2026-09-20), fichier cible Immunefi `src/BeamState.sol` (268 lignes). | **PLATFORM**: Immunefi Sky, max $10M (Critical), live 2022-02-10, target ajoutée 2026-09-01. | **SCOPE demandé**: cette seule target, en profondeur.

**Système**: PAS = framework de gouvernance pour opérations rate-limitées. BeamState = registre central (wards + rôles bitmask par selector). Configurator = interface opérationnelle des cBEAMs (multisigs "mostly trusted") qui ajuste les RateLimits du Spark ALM (`setRateLimitData`) et exécute des actions controller pré-approuvées par hash exact de calldata. Timelock OZ étendu + PASMom (circuit breaker). Rôles réels (PASInit) : DELAYED=Timelock (`start`, `setHop`, `setMaxChange`, tous les `add*`), IMMEDIATE=Core Council (`stop`, tous les `del*`, `set/unsetCBeamFor*`).

## Faits structurants (vérifiés, pas supposés)

1. **BeamState n'a AUCUNE surface d'écriture non authentifiée.** 100% des setters sont `auth` (wards) ou `roleAuth` (bitmask `userRoles[msg.sender] & actionsRoles[msg.sig]`). Constructor ward = deployer, `switchOwner` dans PASDeploy (rely owner / deny deployer) — hygiène OK. Wards post-init = owner (pause proxy) + PASMom (mom standard, pas d'exec arbitraire, expose uniquement `stop()`/`pause()`).
2. **Audit ChainSecurity 2026-05-06** (dans le repo, `audit/`): 0 Critical/High/Medium/Low. Couvre jusqu'au commit `905cc21` (V3). **Notes 8.1–8.5 = known issues qui tuent la majorité des chemins** : soft deprecation non-cascadée (8.1), replay/idempotence des actions controller (8.2), Core Council compromis → prise de contrôle des RateLimits via DEFAULT_ADMIN_ROLE du Configurator (8.3), hazards des fallbacks `address(0)` cross-rateLimits/cross-controllers (8.4), configs incohérentes (8.5).
3. **Delta POST-audit** (= la seule zone à dup faible) : #10 init-data-in-spell, #12 remove wrappers, #13 PASAuthorizeInPAU + start paused, **#15 protection des clés unlimited (HEAD)** + README réécrit.
4. **Sémantique PAU vérifiée dans la source Spark** (`spark-alm-controller/src/RateLimits.sol`) : une clé est unlimited **ssi `maxAmount == type(uint256).max`, slope ignoré** (`getCurrentRateLimit` et `triggerRateLimitDecrease/Increase` court-circuitent sur maxAmount seul). `setRateLimitData` n'interdit PAS `(max, slope>0)`.
5. Tests du repo : 223/223 verts (forge 1.5.1, solc 0.8.24, hors fork mainnet).

## Chemins candidats et verdicts

- **P-01 — Gap sémantique du prédicat de protection #15** → **SEUL SURVIVANT, PoC-prouvé.** Détail ci-dessous. TIER: P2/report-optionnel.
- P-02 — cBeam baisse une clé unlimited protégée via un default général `address(0)` posé pour un autre RateLimits → reachable mais **documenté mot pour mot** (warning README + note 8.4). DROP (known).
- P-03 — Replay illimité d'une action controller approuvée (`callControllerAction` sans nonce) → note 8.2 + SECURITY.md ("Double execution"). DROP (known + trust).
- P-04 — Ratchet exponentiel maxChange (current × maxChange^N par hop, aucun plafond absolu type autoline `max`) → design assumé ("assumed to be monitored"), cBeam trusted. DROP (design/trust).
- P-05 — Bypass de hop en passant bounded→unlimited (branche unlimited sans check hop quand def=(max,0)) → def=(max,0) est une décision de gouvernance explicite. DROP (intended).
- P-06 — Sentinelles 0 : impossible d'exprimer "hop=0 / maxChange=0 / default=(0,0) spécifique" quand un général existe (fallback silencieux) → footgun documenté (README + 8.4). DROP (known).
- P-07 — `setCBeamForRateLimits/Controller` IMMEDIATE (pairing sans délai d'un cBeam déjà whitelisté) → commenté dans le code même (`BeamState.sol:222`, "known and assumed to be monitored"). DROP (known).
- P-08 — Escalade Core Council via calldata approuvée (revoke/grant DEFAULT_ADMIN_ROLE sur RateLimits) → note 8.3 + trust model ("Core Council very highly trusted"). DROP (known + admin-trust dur).
- P-09 — Soft deprecation : cBeam supprimé garde ses pairings → note 8.1 + commentaires code. DROP (known).
- Divers morts en lecture : bitmask rôles uint8 (≤255, ok dans bytes32), ABI struct vs tuple `getInitRateLimits` (compatible), overflow `current.maxAmount * maxChange` (court-circuit `||` avant multiplication, n'affecte que des valeurs ~2^128+), reentrancy (aucun call externe dans BeamState), pas de proxy/upgrade.

## P-01 — Le prédicat unlimited du Configurator est plus étroit que la sémantique du PAU

**Défaut** : `Configurator.setRateLimit` (post-#15) ne verrouille une clé "déjà unlimited sans default" que si `current.maxAmount == max && current.slope == 0`. Le PAU (Spark RateLimits) considère unlimited **tout `maxAmount == max`** — slope ignoré. Un état `(max, slope>0)` est donc fonctionnellement unlimited côté PAU (retraits illimités, `getCurrentRateLimit == max`) mais **non protégé** : la branche bounded s'applique et `maxAmount <= current.maxAmount(=max)` autorise n'importe quelle valeur, y compris `(0,0)`, sans hop (baisse). L'esprit du #15 ("a cBeam cannot unilaterally reset such a key to 0") est violé pour cette classe d'états ; la lettre du README (qui définit la classe protégée comme littéralement `(max, 0)`) est respectée.

**Séquence 100% in-protocol** (PoC verte, 2 tests) :
1. Timelock (DELAYED) enregistre `addInitRateLimits(key, rl, max, 1e18)` — default "slope plafonnée, maxAmount libre".
2. cBeam pose la clé à `(max, 1e18)` via Configurator (dans les bornes de la default). → clé unlimited per PAU.
3. Core Council (IMMEDIATE) fait `delInitRateLimits` — nettoyage explicitement encouragé par SECURITY.md ("removing old calldata/rate-limits in a timely manner").
4. cBeam appelle `setRateLimit(rl, key, 0, 0)` → **passe** (baseline `(max,0)` identique revert bien avec `Configurator/unlimited-incorrect-params`). Clé de retrait à zéro, instantanément.

**Fix une ligne** : aligner le prédicat sur le PAU — traiter `current.maxAmount == max` comme unlimited quel que soit slope (ou faire refuser `(max, slope>0)` par `BeamState.addInitRateLimits`).

**Verdict honnête (pas de théâtre)** :
- Réel, nouveau (post-audit ChainSecurity, dup Low), PoC reproductible, fix trivial.
- MAIS l'étape 1 (default `(max, slope>0)`) est une config de gouvernance bizarre — l'encodage naturel d'unlimited est `(max,0)`, et `defMaxAmount=max` signifie déjà "aucun plafond". Immunefi triagera : **précondition = misconfiguration d'un rôle privilégié → Low/Informational, très probablement $0** sur un programme qui paie Critical/High. L'impact terminal (freeze temporaire d'un chemin de retrait, réversible par gouvernance) ne porte pas un High seul.
- Valeur réelle : note de hardening au team Sky (dette de réputation positive, pipeline Sky long terme), pas un ticket bounty. Ne PAS le soumettre en High sur Immunefi — c'est un down-triage garanti.

### PoC (Foundry, autoportant — réplique exacte des sémantiques Spark RateLimits)

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { BeamState } from "src/BeamState.sol";
import { Configurator } from "src/Configurator.sol";

contract SparkRateLimitsReplica {
    struct RateLimitData { uint256 maxAmount; uint256 slope; uint256 lastAmount; uint256 lastUpdated; }
    mapping(bytes32 => RateLimitData) private _data;
    function setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope, uint256 lastAmount, uint256 lastUpdated) public {
        require(lastAmount <= maxAmount, "RateLimits/invalid-lastAmount");
        require(lastUpdated <= block.timestamp, "RateLimits/invalid-lastUpdated");
        _data[key] = RateLimitData(maxAmount, slope, lastAmount, lastUpdated);
    }
    function setUnlimitedRateLimitData(bytes32 key) external { setRateLimitData(key, type(uint256).max, 0, type(uint256).max, block.timestamp); }
    function getRateLimitData(bytes32 key) external view returns (RateLimitData memory) { return _data[key]; }
    function getCurrentRateLimit(bytes32 key) public view returns (uint256) {
        RateLimitData memory d = _data[key];
        if (d.maxAmount == type(uint256).max) return type(uint256).max; // PAU: unlimited ssi maxAmount == max
        return _min(d.slope * (block.timestamp - d.lastUpdated) + d.lastAmount, d.maxAmount);
    }
    function _min(uint256 a, uint256 b) internal pure returns (uint256) { return a < b ? a : b; }
}

contract PoC_UnlimitedSlopeGap is Test {
    BeamState beamState; Configurator configurator; SparkRateLimitsReplica rateLimits;
    address cBeam = address(0xBEA);
    bytes32 constant KEY = keccak256("LIMIT_USDS_TO_USDC");
    uint256 constant MAX = type(uint256).max;

    function setUp() public {
        vm.warp(30 days);
        beamState = new BeamState();
        configurator = new Configurator(address(beamState));
        rateLimits = new SparkRateLimitsReplica();
        beamState.addRateLimits(address(rateLimits));
        beamState.addCBeam(cBeam);
        beamState.setCBeamForRateLimits(address(rateLimits), cBeam);
        beamState.setHop(address(0), 1 days);
        beamState.setMaxChange(address(0), 10e18);
    }

    function test_baseline_protection_holds_for_slope0() public {
        rateLimits.setUnlimitedRateLimitData(KEY);
        vm.prank(cBeam);
        vm.expectRevert("Configurator/unlimited-incorrect-params");
        configurator.setRateLimit(address(rateLimits), KEY, 0, 0);
    }

    function test_gap_cBeam_zeroes_unlimited_key_with_residual_slope() public {
        beamState.addInitRateLimits(KEY, address(rateLimits), MAX, 1e18);      // DELAYED
        vm.prank(cBeam);
        configurator.setRateLimit(address(rateLimits), KEY, MAX, 1e18);        // in-bounds
        assertEq(rateLimits.getCurrentRateLimit(KEY), MAX);                    // unlimited per PAU
        beamState.delInitRateLimits(KEY, address(rateLimits));                 // IMMEDIATE cleanup
        vm.prank(cBeam);
        configurator.setRateLimit(address(rateLimits), KEY, 0, 0);             // ne revert PAS
        assertEq(rateLimits.getCurrentRateLimit(KEY), 0);                      // clé zéro, instantané
    }
}
```
Résultat : `2 passed` (forge 1.5.1, solc 0.8.24, commit `947e71c`).

---

# PASSE 2 (2026-09-20) — Delta Timelock post-audit (#12/#13) + PASAuthorizeInPAU vs état réel du PAU

**Fait nouveau côté programme** : `PAS_CONFIGURATOR` est une target Immunefi officielle distincte (ajoutée 2026-09-01) → P-01 (qui vit dans le code du Configurator) est formellement dans le scope du programme. Ne change pas la sévérité (précondition inchangée), change la recevabilité formelle.

## État réel de production (établi via spells publics — RPC/Etherscan/Blockscout tous bloqués par le proxy egress)

Spell Sky Core **2026-08-27** (`spells-mainnet/archive/2026-08-27-DssSpell`, dépendances PAS vendorées au commit audité `947e71c`) :
- `PAS_STATE` `0x1A1879E66547F90bfF87D45A5b0335950E019E02`, `PAS_CONFIGURATOR` `0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929`, `PAS_TIMELOCK` `0xB50a06Af02dDE44dB6EA7ee729403848c2B35293`, `PAS_MOM` `0xD44B8d01D5207aA792C666d0A712A1A161CD6171`, `PAS_CORE_COUNCIL` `0x148eF923d764CBdc1597CcADBbbC66499C1A1432` (tous au chainlog v1.20.20).
- **1 seul cBeam** : Grove `0x91dC2F6DbB8Adf76d373A54D408EDd7D736046C4`, pairé avec `GROVE_RATE_LIMITS` `0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1` et `GROVE_CONTROLLER` (diamond) `0xbf83F5974B932c7D842254042717D6A2706CE5eE`.
- hop général **16 h**, maxChange général **1.2 WAD**. **AUCUNE default `initRateLimits`, AUCUNE calldata controller approuvée** (le spell n'appelle pas `initLimitsAndControllerData`). **Timelock démarré EN PAUSE** (`pauseTimelock` avec MCD_PAUSE_PROXY en pauser temporaire).
- Spell Grove **2026-08-27** (`grove-labs/grove-spells`) : `PASAuthorizeInPAU.authorize` → le Configurator détient **DEFAULT_ADMIN_ROLE sur `PAU_ACCESS_CONTROLS` `0x4F6d1704700cd494DD4cd9bF59c0C39DA1Bc9164` et `PAU_RATE_LIMITS` `0xE016…`** du Grove Diamond PAU. Le Grove SubProxy garde son propre DEFAULT_ADMIN_ROLE (révocation possible).
- Spells 2026-09-10 et spell en préparation (`src/DssSpell.sol`) : **zéro action PAS** → l'état live = l'état genesis ci-dessus.

## Verdicts de la passe 2 — tout vérifié, aucun finding recevable nouveau

- **L2PASSpell.init sans access control** : sain. Modèle d'exécution = delegatecall du governance proxy/relay (confirmé par le test, mock delegatecall). Un appel direct s'exécute avec l'identité du spell, qui n'a aucun ward → revert au premier call auth'd. Pas de front-run des paramètres `coreCouncil`/`cancellers`/`pausers`.
- **`pauseTimelock` (#13)** : grant PAUSER → pause → revoke, atomique dans le spell. L'hypothèse "admin pas dans pausers" est commentée ; même violée, l'admin est role-admin (DEFAULT_ADMIN_ROLE) et se re-grant à volonté → auto-réparable, pas un finding.
- **Timelock.sol** : inchangé depuis l'audit ChainSecurity (dup max sur son interne). Re-vérifié quand même : ban des self-calls checké sur chaque `targets[i]` au scheduling (OZ 5.5.0 : `updateDelay` exige `msg.sender == address(this)`, inatteignable), `_revokeRole(DEFAULT_ADMIN_ROLE, address(this))` au constructor, `schedule`/`execute` single désactivés, exécution permissionless intentionnelle (`EXECUTOR_ROLE = address(0)`), cancel bloqué pendant pause (documenté, rationale inline), re-schedule d'un id exécuté impossible (état OZ Done ≠ Unset). Rien.
- **Suppression des wrappers (#12)** : Core Council = PROPOSER + CANCELLER directement sur le Timelock. Le pouvoir du Timelock se limite à son rôle DELAYED sur BeamState → un Core Council malveillant qui schedule de l'arbitraire = note 8.3 ChainSecurity mot pour mot (known + trust "very highly trusted" + cancellers).
- **PASAuthorizeInPAU vs PAU réel** : le RateLimits du `sky-ecosystem/diamond-pau` (stack Grove ET Osero) est une **copie identique** du RateLimits Spark — mêmes signatures, même struct 4 champs, unlimited ssi `maxAmount == max` slope ignoré. Aucun drift d'implémentation ; les hypothèses d'interface du Configurator sont correctes contre le PAU réellement déployé. AccessControls = 46 lignes (OZ AccessControl + `setRoleAdmin`), blast radius du grant auto-documenté dans le NOTE du fichier. Le pouvoir est **dormant** : ni AccessControls ni RateLimits ne sont whitelistés comme "controllers" dans BeamState, et zéro calldata approuvée.
- **P-01 contre l'état live** : les clés unlimited Grove existantes sont posées via `setUnlimitedRateLimitData` → slope 0 → protection #15 active. Zéro default enregistrée → l'état conditionnel `(max, slope>0)` n'existe pas aujourd'hui. P-01 reste **watch, pas live**.

## Blast radius live du cBeam Grove (quantifié, trust-excluded mais à connaître)

Avec zéro default et maxChange 1.2/hop 16h, le cBeam Grove peut aujourd'hui, seul : (a) ratchetter toute clé bounded Grove de +20 %/16 h — composé ≈ ×1.31/jour, ×45 en 2 semaines, sans plafond absolu (les defaults qui serviraient de plafond n'existent pas ; seule borne = monitoring + Mom.stop + Core Council) ; (b) **mettre à zéro n'importe quelle clé bounded — porte à sens unique via Configurator** : depuis (0,0), toute augmentation revert (plafond = max(def=0, current=0, current×1.2=0)), récupération uniquement par spell hebdo (SubProxy a gardé DEFAULT_ADMIN_ROLE sur RateLimits) ou dé-pause du Timelock + délai. Les deux sont couverts par le trust model (cBEAM multisig "mostly trusted", scénario retraits explicitement listé dans SECURITY.md) → non recevables Immunefi.

## Prochaine fenêtre réelle : onboarding Osero (2e Star)

- Spell Osero **2026-09-24** en review (`osero-io/osero-spells` PR #4) : même stack diamond-pau, `PASAuthorizeInPAU.authorize` vers le MÊME Configurator sur `OSERO_ACCESS_CONTROLS` `0x791D2a017532CfAD881c446e6bF93BbC3c0778b2` et `OSERO_RATE_LIMITS` `0xE9a78f34fe497e2186f81B8c014cd93B308BC62a`.
- La spell Sky Core suivante fera le premier `initLimitsAndControllerData` de production ("register Osero RateLimits and Controller, configure the approved defaults, register/pair the confirmed cBEAM" — hors du payload Osero).
- **Vérifié par hash : Grove et Osero partagent le namespace de clés** (`keccak256("LIMIT_USDS_MINT")` = `0xcb0537d5…` = la clé Osero ; constantes identiques dans diamond-pau). Donc une default générale `initRateLimits[key][address(0)]` ou une calldata approuvée en slot général `[hash][address(0)]` s'applique aux DEUX Stars d'un coup — l'amplification de SECURITY.md et le warning README deviennent concrets pour la première fois.

**WATCH conditions précises sur la prochaine spell Sky (dans `spells-mainnet`, PR ~fin septembre 2026) :**
1. Tout `addInitRateLimits` avec `maxAmount == type(uint256).max && slope > 0` → arme P-01 (soumettre alors, l'état devient atteignable sans misconfig supplémentaire).
2. Tout `addInitRateLimits(key, address(0), …)` (slot général) → cross-Star, vérifier l'effet sur la clé homonyme de l'AUTRE Star (surtout si elle y est unlimited-protégée : la default générale DÉSACTIVE la protection #15 sur l'autre Star — chemin documenté côté README mais une instanciation cross-Star involontaire serait soumissible comme misconfig live, à triager alors).
3. Tout `addInitControllerActions(data, address(0))` → calldata exécutable sur tous les controllers pairés (sélecteurs de facets identiques entre diamonds).
4. Dé-pause du Timelock → le flux DELAYED s'active réellement (Core Council peut alors proposer seul, délai + cancellers comme seule garde).

---

# PASSE 3 (2026-09-20) — Target PAS_TIMELOCK (src/timelock/Timelock.sol @ 947e71c)

**Cadrage** : Timelock.sol + Bytes32LinkedList.sol inchangés depuis l'audit ChainSecurity (V1) ET le submodule OZ identique entre le commit audité et HEAD (`a83d9aa` = OZ 5.5.0, vérifié par `git ls-tree`) → dup maximal sur l'interne. Le travail frais = valider mécaniquement ce que l'audit n'a fait qu'en lecture : l'invariant de la couche de tracking ajoutée par-dessus OZ, et les interleavings de reentrance.

## Vérifié mécaniquement (nouveaux tests, verts)

- **Invariant miroir `_operationIds.exists[id] ⟺ op Pending/Ready côté OZ` + `count` + payloads stockés** : structurellement étanche (OZ 5.5 n'écrit `_timestamps` que via `_schedule`/`cancel`/`_afterCall`, chacun apparié atomiquement à l'op de liste dans les overrides ; `schedule`/`execute` single désactivés = pas de chemin non apparié) et **fuzz-validé** : invariant Foundry, 64 runs × 100 de profondeur (~6 400 appels séquencés schedule/cancel/re-schedule/execute/warp), zéro violation. Conséquence : le scénario "remove-failed → op exécutable ni annulable" est inatteignable.
- **Reentrance sur la MÊME op** (plus fort que le CS-SKYPAS-001 acknowledged, qui ne couvre que le cross-op) : re-exécuter `executeBatch(A)` depuis un target de A — inner revert propagé OU avalé — fait toujours reverter le frame externe via `_afterCall` (état Done ≠ Ready) → **full unwind, aucune double-exécution possible, aucun état à moitié exécuté, liste intacte**. Idem `cancel(A)` re-entré pendant `execute(A)`. 3 tests dédiés verts.
- Cycle `schedule → cancel → re-schedule (même id) → execute` : miroir maintenu à chaque étape.
- Bytes32LinkedList relu en entier : sentinelle `bytes32(0)` correcte (un id est un keccak, jamais 0), cas tête/queue/élément-unique corrects, pas d'underflow de count. + 22 tests existants du repo.
- Constructor : OZ 5.5 self-grant `DEFAULT_ADMIN_ROLE` à `address(this)` → correctement révoqué ; ban des self-calls checké sur chaque `targets[i]` au scheduling ; `updateDelay` inatteignable par proposal (exige `msg.sender == address(this)`). Access control des overrides préservé (super porte les onlyRole).

## Chemins tués (known/design)

- Reentrance cross-op pendant exécution → **CS-SKYPAS-001, acknowledged** dans le rapport (targets = BeamState en pratique, trustés).
- Course execute-vs-cancel à la frontière Ready (executor permissionless peut front-runner un cancel) → inhérent au design "permissionless execution", mitigé par le mécanisme de pause (bloquer l'exécution, puis unpause+cancel atomique par l'admin — rationale commentée inline) + posture SECURITY.md (cancellers disponibles à court préavis). Known/design.
- Cancel bloqué pendant pause ; op devenue Ready pendant une pause = exécutable dès l'unpause → documenté inline avec la parade (cancel atomique post-unpause).
- Pauser qui DoS le timelock → trust-excluded (SECURITY.md).
- `updateDelayImmediately` → admin = PauseProxy, fully trusted.
- Ops à value / batch vide / arrays désalignés → comportements OZ standards, sans surprise.

## VERDICT PASS 3 : NO-GO bounty sur PAS_TIMELOCK

Code inchangé depuis l'audit, OZ inchangé, aucun finding recevable — et les deux angles que l'audit n'avait pas testés mécaniquement (miroir de tracking, double-exec même-op) sont maintenant prouvés sains par fuzz/tests. Détail de posture : le Timelock est **en pause depuis genesis**, donc toute cette surface est dormante jusqu'au W4 (dé-pause) — déjà surveillé par les deux moniteurs (routine CCR + kit Cowork on-chain).

Bilan programme après 3 targets (PAS_STATE, PAS_CONFIGURATOR, PAS_TIMELOCK) : le seul chemin vivant reste **P-01 en watch**, armable par la spell d'onboarding Osero (premières defaults de prod). Le code PAS lui-même est propre ; l'ore de ce programme est dans les évolutions de configuration, pas dans le code déployé.

---

# PASSE 4 (2026-09-20) — Target PAS_MOM (src/PASMom.sol @ 947e71c)

**Passe courte, proportionnée à la cible** : 106 lignes, mom Maker standard, **un seul commit dans toute l'histoire du repo** (PR #2, pré-audit), couvert par ChainSecurity §2.2.4 avec 0 findings, inchangé depuis → dup maximal, surface minuscule. 9/9 tests unitaires verts.

## Chemins déroulés — tous morts

- **P-M1 anonyme → stop/pause** : `auth` = owner OU `authority.canCall(src, this, sig)`. Owner = PauseProxy (hand-over atomique dans le deploy tx : `new PASMom` + `setOwner`, le deployer ne garde rien — vérifié dans PASDeploy). Authority = MCD_ADM (Chief), sémantique hat (`caller == hat`, prouvée sur fork mainnet par le test d'intégration contre le vrai Chief). Unreachable sans majorité de gouvernance.
- **P-M2 hat/owner compromis** : les deux seules actions sont `stop()` (halt Configurator) et `pause()` (halt Timelock) — **direction de-risk uniquement**, aucune capacité d'extraction ni de reconfiguration. Impact = griefing des ops, réversible par spell (PauseProxy est ward de BeamState → `start` direct ; unpause = DEFAULT_ADMIN). Un hat malveillant = majorité de gouvernance compromise = game over de toute façon. Trust-excluded.
- **P-M3 sur-privilège** : Mom est ward complet de BeamState (rely dans initMom) et PAUSER du Timelock, alors que son code n'expose que stop/pause — pas de delegatecall, pas d'exec arbitraire, donc le sur-privilège est inerte. Nit least-privilege (un rôle avec le seul sig `stop` suffirait), informational, déjà noté en passe 1.
- **P-M4 `setOwner(0)`/`setAuthority(0)`** : onlyOwner, classe erreur de gouvernance. `setAuthority(0)` laisse le chemin owner ; `setOwner(0)` laisse le chemin hat. Pas de brick total possible en une erreur.
- **P-M5 swap d'authority vers un canCall malveillant** : onlyOwner (PauseProxy). Trusted.
- **P-M6 idempotence d'urgence** : `stop()` idempotent (flag) ; `pause()` sur timelock déjà pausé revert (EnforcedPause OZ) — sans conséquence, l'objectif est déjà atteint. Note : timelock pausé depuis genesis → `Mom.pause()` reverterait AUJOURD'HUI, comportement attendu.
- Pas de mom sur les chaînes remote → SECURITY.md l'assume explicitement (multisigs à la place). Known.

## VERDICT PASS 4 : NO-GO bounty sur PAS_MOM

Rien à extraire : contrat de-risk-only, trust-gated aux deux entrées, audité, figé depuis sa création. Fin du scope PAS core (4/4 targets auditées).

## DÉCISION GLOBALE (fin de passe 1 — remplacée par la CLÔTURE ci-dessous)

**NO-GO bounty sur cette target seule.** BeamState @ HEAD est un registre serré : zéro surface non authentifiée, trust model qui exclut explicitement les acteurs privilégiés malveillants, et un rapport ChainSecurity dont les Notes couvrent déjà tous les footguns structurels. L'unique survivant (P-01) est un vrai défaut de cohérence sémantique, PoC-prouvé, mais gated par une misconfig de gouvernance → sous le seuil payable d'Immunefi. (Les pistes "delta Timelock / PASAuthorizeInPAU" évoquées ici ont été exécutées en passes 2-3 : rien de recevable.)

TEMPS BRÛLÉ: ~1 session. Coût évité: des jours sur P-02→P-09, tous morts en known/trust avant lecture profonde.

---

# CLÔTURE DE L'ENGAGEMENT (2026-09-20) — passage en mode WATCH dormant

## État final

**4/4 targets PAS core auditées, 0 finding soumissible aujourd'hui, 1 chemin vivant en watch (P-01).**

| Target | Verdict | Preuve |
|---|---|---|
| PAS_STATE | NO-GO | Threat model complet, 9 chemins tués (known ChainSecurity / trust model) |
| PAS_CONFIGURATOR | **P-01 en watch** | PoC Foundry vert (gap unlimited-slope post-#15, non couvert par l'audit) — non soumissible tant que la précondition n'existe pas on-chain |
| PAS_TIMELOCK | NO-GO | Invariant de tracking fuzz-prouvé (~6 400 séquences), double-exec même-op prouvée impossible, OZ identique au commit audité |
| PAS_MOM | NO-GO | 6 chemins morts, de-risk-only, trust-gated aux deux entrées |

Conclusion : le code déployé est propre ; **l'ore est dans les évolutions de configuration** (spells). Conditions de réveil = W1–W4 + P-01-état + zeroing + changements d'admin, toutes définies dans ce dossier.

## Inventaire des moniteurs actifs (vérifié via list_triggers à la clôture)

1. **`trig_01QNtYtsK6jjKgv3M2rzByTi` — "Sky PAS spells watch"** (08:00 UTC, se réveille dans la session d'audit `session_01JmCgEZ5HZ4mf4xs4Hqgouu` avec tout le contexte) : repos de spells via `tools/sky-pas-watch.sh` (git ls-remote, PRs incluses), état commité dans ce repo (`sky-pas-watch-state.txt`, baseline 614 refs).
2. **`trig_01Liv1vnqELwCyhFvosuL7x3` — "Sky PAS Watch — verdict go/no-go quotidien"** (13:04 UTC, sessions fraîches, créée par Malik post-kit) : pipeline artifact `claude.ai/artifact/31tV5G36pHhCqBLpPMAmW5` couvrant **on-chain (RPC Tenderly) + repos**, état persisté dans l'artifact, notifications push, brouillon de rapport auto sur GO (jamais de soumission auto). Dernier run : SUCCEEDED.
3. **Kit Cowork local** (`sky-pas-cowork-kit.md` + `tools/sky-pas-onchain-watch.sh`) : disponible en secours si le canal artifact/Tenderly casse un jour — non requis tant que le moniteur 2 tourne.

**Chevauchement assumé** : les moniteurs 1 et 2 couvrent tous deux les repos de spells (mécanismes et états indépendants : git-repo vs artifact ; 2 points de mesure/jour ; modes de panne disjoints). Redondance délibérée sur un programme à $10M — si un seul canal est voulu, désactiver le 1 (le 2 est le plus complet).

## Livrables (tous sur branche `claude/sky-pas-state-audit-shdcpl`)

- Ce dossier (threat model, 4 passes, watch conditions W1–W4)
- `poc-sky-pas-timelock-adversarial.t.sol` (invariant fuzz + tests reentrance Timelock)
- PoC P-01 inline dans le dossier (2 tests, verts sur `947e71c`)
- `tools/sky-pas-watch.sh` + baseline, `tools/sky-pas-onchain-watch.sh` + kit Cowork

## Ce qui rouvre le dossier

La routine 1 ou 2 remonte W1/P-01-armé → refaire l'analyse adversariale contre l'état on-chain exact, puis soumission Immunefi (PAS_STATE/PAS_CONFIGURATOR, commit `947e71c`) après validation de Malik. Tout le reste (W2/W3/W4/zeroing/admin) = analyse + verdict, pas de soumission réflexe. Événement clé attendu : **spell Sky Core d'onboarding Osero** (premières defaults de prod, ~fin sept 2026).

## JOURNAL WATCH

- **2026-09-22 (routine 08:00)** : 4 refs changées, toutes bénignes, aucune WATCH condition. (1) spells-mainnet PR#573 = spell Sky 2026-09-24 en préparation (stade instructions) : activation du cBeam Osero `0x42D1038017E466b413aa44Ae798E30FB80b2E180` + addRateLimits/addController Osero (`0xE9a7…C62a` / `0x2416…ca38`) + 2 pairings — **zéro addInitRateLimits, zéro addInitControllerActions, zéro slot général, pas de dé-pause** → P-01 reste non armé ; l'onboarding suit le chemin propre (pairings sans defaults, posture identique à Grove). (2) spells-mainnet PR#558 = suppressions de tests, PR#574 = CI only. (3) grove-spells PR#81 = archive de la spell Grove 24/09 : passe LIMIT_USDS_BURN / LIMIT_USDC_TO_USDS / LIMIT_4626_WITHDRAW en unlimited `(max,0)` via setUnlimitedRateLimitData → classe protégée #15, direction sécurisante. Intel live : « PAS steps these keys daily » — le cBeam Grove ratchette activement (~15M→17.9M ≈ ×1.194/step, cohérent maxChange 1.2/hop 16h). Fenêtre P-01 repoussée : pas de defaults dans le cycle du 24/09 ; à surveiller aux cycles suivants.
- **2026-09-23 (routine 08:00)** : 1 ref changée — spells-mainnet PR#573 (spell 2026-09-24) passe des instructions au **code implémenté**. Conforme : les 5 seuls appels BeamState sont addCBeam/addRateLimits/setCBeamForRateLimits/addController/setCBeamForController avec exactement les adresses annoncées (cBeam Osero 0x42D1…E180, RL 0xE9a7…C62a, controller 0x2416…ca38) ; l'interface du spell ne déclare même pas addInit*/unpause. Aucune WATCH condition. P-01 toujours non armé. Bénin.
- **2026-09-24 (routine 08:00)** : 3 refs changées, toutes bénignes, aucune WATCH condition. PR#573 (spell du jour) : delta = 1 ligne CI, code du spell inchangé depuis hier — exécution attendue aujourd'hui. PR#575 : DssSpell.t.base.sol uniquement. osero PR#5 : polish de review du spell 8/10 (public→internal, PSM_USDS_TO_USDC 5M→50M/jour bounded, OGUSDCP deposit slope→0 par design "refill par withdrawals uniquement") — côté PAU, pas d'action PAS. P-01 non armé.
- **2026-09-25 (routine 08:00)** : 3 refs, toutes bénignes. **Spell 2026-09-24 mergé sur master (#573) → le cBeam Osero est actif on-chain**, exactement les 5 pairings validés (zéro defaults, zéro calldata, Timelock toujours en pause — posture identique à Grove). PR#573 post-merge = archivage. Grove PR#82 (cycle 8/10) = offboarding de 4 vaults (deposit→0, withdraw reste unlimited (max,0) protégé) — direction sécurisante, côté PAU. Aucune WATCH condition ; P-01 non armé. État système : 2 Stars actifs (Grove, Osero), toujours zéro `initRateLimits`/`initControllerActions` en production.
