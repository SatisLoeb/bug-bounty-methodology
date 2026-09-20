---
name: sky-pas-beamstate-immunefi-engagement
description: "Sky PAS BeamState.sol (Immunefi $10M) — audit profond exécuté 2026-09-20 sur commit 947e71c; 1 survivant PoC-prouvé (gap sémantique unlimited-slope, post-audit #15) mais précondition = misconfig gouvernance → probablement non payable; tout le reste tué par known-issues ChainSecurity + trust model"
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

## DÉCISION GLOBALE

**NO-GO bounty sur cette target seule.** BeamState @ HEAD est un registre serré : zéro surface non authentifiée, trust model qui exclut explicitement les acteurs privilégiés malveillants, et un rapport ChainSecurity dont les Notes couvrent déjà tous les footguns structurels. L'unique survivant (P-01) est un vrai défaut de cohérence sémantique, PoC-prouvé, mais gated par une misconfig de gouvernance → sous le seuil payable d'Immunefi. Options : (a) l'envoyer comme note de hardening (gratuit, réputation), (b) le garder en watch — il devient exploitable/payable seulement si un default `(max, slope>0)` apparaît on-chain un jour (vérification passive : lire `initRateLimits` sur le BeamState déployé quand l'adresse sera publique). **Si on veut du payable sur Sky/PAS, la surface à travailler est le delta post-audit du Timelock (#12/#13) et l'intégration PASAuthorizeInPAU côté PAU réel — pas BeamState.**

TEMPS BRÛLÉ: ~1 session. Coût évité: des jours sur P-02→P-09, tous morts en known/trust avant lecture profonde.
