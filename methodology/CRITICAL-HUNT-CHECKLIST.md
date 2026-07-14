# Critical Fund Theft Hunting Checklist

Systematic checklist for every target audit. Focus: **critical severity only** — direct fund theft, not DoS/griefing.

---

## 0. RECON RAPIDE (5 min)

- [ ] TVL actuel (DeFiLlama) — si < $1M, skip
- [ ] Audits existants — lire conclusions, chercher ce qu'ils ont manque
- [ ] Historique d'exploits — le protocole ou ses forks ont-ils deja ete hacked ?
- [ ] Stack technique — Solidity/Vyper/Rust, version compilateur, unchecked blocks, unsafe ops
- [ ] Upgradeable ? — proxy pattern, storage collision potential
- [ ] Dependances externes — quels oracles, quels bridges, quels tokens acceptes

---

## 1. LOGIQUE METIER ET INVARIANTS MATHEMATIQUES

### 1.1 Asymetrie des arrondis (Rounding Asymmetry)

- [ ] **Identifier toute division** dans deposit/withdraw/swap paths
- [ ] **Verifier direction** : deposits arrondis vers le bas (bon) ET withdrawals arrondis vers le bas (bon). Si withdraw arrondi vers le HAUT → extraction possible
- [ ] **Micro-loop test** : simuler 1000 cycles deposit(1 wei)/withdraw → le solde du contrat diminue-t-il ?
- [ ] **Fonctions a cibler** : `previewDeposit()` vs `previewRedeem()`, `convertToShares()` vs `convertToAssets()`
- [ ] **Pattern Vyper** : `unsafe_div` (arrondi vers zero), `math._ceil_div` (arrondi vers le haut) — verifier coherence
- [ ] **Pattern Solidity** : `mulDiv(x, y, z, Rounding.Up)` vs `Rounding.Down` — qui beneficie ?
- [ ] **Ref exploit** : Balancer V2 2025 ($125M) — rounding errors combines avec access control

### 1.2 Depassement de capacite (Overflow/Underflow)

- [ ] **Solidity <0.8.0** : TOUT est unchecked par defaut — scanner immediatement
- [ ] **Solidity >=0.8.0** : scanner chaque bloc `unchecked { }` — le dev a-t-il raison de skip la verification ?
- [ ] **Vyper** : scanner chaque `unsafe_add`, `unsafe_sub`, `unsafe_mul`, `unsafe_div` — justification valide ?
- [ ] **Cast dangereux** : `uint256` → `int256` (perd le bit de signe si > 2^255), `uint256` → `uint128` (tronque), `int256` → `uint256` (negatif → enorme)
- [ ] **Multiplication avant division** : `a * b / c` peut overflow meme si le resultat final tient dans uint256
- [ ] **Ref exploit** : Cetus Protocol 2025 ($223M) — overflow dans calcul de liquidite sur Sui

### 1.3 Rupture d'invariant (Invariant Breaking)

- [ ] **Identifier l'invariant central** du protocole (ex: `x*y=k`, `sum(balances)=D`, `totalAssets >= totalShares * pricePerShare`)
- [ ] **Fuzzer avec extremes** : montants 1 wei, montants max_uint256, prix oracle 0, prix oracle max
- [ ] **Test post-operation** : l'invariant tient-il APRES chaque operation ? Pas juste avant
- [ ] **Sequences d'operations** : deposit→withdraw→deposit dans le meme bloc — l'invariant survit-il ?
- [ ] **StableSwap specifique** : injecter desequilibre extreme dans un pool (99.9%/0.1%) → l'equation tient ?
- [ ] **Custom bonding curves** : tracer la courbe mathematiquement — existe-t-il des points singuliers ou discontinuites ?

### 1.4 Inflation de parts (Share/Token Manipulation)

- [ ] **Donation attack** : envoyer tokens directement au vault (sans deposit()) → `totalAssets()` augmente mais `totalSupply()` non → premier deposant vole les suivants
- [ ] **Premier deposant** : si vault vide, peut-on deposer 1 wei, donner 10M tokens, puis le prochain deposant perd tout ?
- [ ] **Protection existante** : virtual shares/assets ? dead shares ? minimum deposit ? `_decimalsOffset()` ?
- [ ] **balanceOf(this) vs comptabilite interne** : le contrat utilise-t-il `balanceOf(address(this))` ou un tracking interne ? Si balanceOf → manipulable par donation
- [ ] **ERC4626 specifique** : verifier `totalAssets()`, `convertToShares()`, `maxWithdraw()` — coherence entre preview et execution
- [ ] **Mirror invariant ERC4626** (voir §3.6) : `deposit` / `withdraw`, `mint` / `redeem`, `convertToShares` / `convertToAssets` — pour chaque paire, comparer V_in / V_out. `convertToShares` et `convertToAssets` doivent arrondir dans des directions OPPOSÉES (shares rounded down on deposit, rounded up on redeem) — tout alignement = finding-candidate.
- [ ] **Ref exploit** : MakinaFi 2026 ($4M) — LP token inflation via spot price manipulation

### 1.5 Manipulation de prix/Oracle

- [ ] **Oracle type** : spot price (manipulable par flash loan) vs TWAP (manipulable sur duree) vs Chainlink (fiable mais staleness)
- [ ] **Flash loan + oracle** : le prix peut-il etre manipule PENDANT la transaction ?
- [ ] **Stale price** : le contrat verifie-t-il `updatedAt` ou `answeredInRound` pour Chainlink ?
- [ ] **Decimal mismatch** : l'oracle retourne 8 decimales mais le code attend 18 ? Ou inverse ?
- [ ] **Multi-oracle** : si plusieurs sources de prix, peut-on les mettre en contradiction ?
- [ ] **LP token comme oracle** : `reserves * price / totalSupply` est manipulable — le protocole fait-il ca ?
- [ ] **Ref exploit** : Moonwell 2026 ($1.78M) — cbETH mispricing from decimal mismatch

---

## 2. CONTROLE D'ACCES ET REENTRANCY

### 2.1 Reentrancy

- [ ] **Hooks ERC777/ERC1155** : `tokensReceived()`, `onERC1155Received()` — callback avant mise a jour d'etat ?
- [ ] **Pattern CEI** : le contrat suit-il Checks-Effects-Interactions ? Sinon → reentrancy classique
- [ ] **Cross-function reentrancy** : function A appelle external, qui re-entre par function B (meme contrat, meme lock ?)
- [ ] **Read-only reentrancy** : function view lit un etat inconsistant pendant qu'une autre function est en cours
- [ ] **Cross-contract reentrancy** : contrat A appelle contrat B qui re-entre contrat A par un chemin different
- [ ] **Uniswap V4 hooks** : callbacks personnalises dans le flow de swap — reentrancy possible ?
- [ ] **nonReentrant scope** : le guard protege-t-il TOUTES les fonctions critiques ou juste certaines ?
- [ ] **Ref exploit** : GMX V1 2025 ($42M) — executeDecreaseOrder reentrancy

### 2.2 Controle d'acces

- [ ] **Fonctions sans modifier** : `external` sans `onlyOwner`/`onlyAdmin` — qui peut appeler ?
- [ ] **Initializer non protege** : `initialize()` peut-elle etre appelee par n'importe qui ? Ou re-appelee ?
- [ ] **Delegatecall** : le contrat peut-il etre force a executer du code arbitraire via delegatecall ?
- [ ] **Selfdestruct** : le contrat ou ses dependances utilisent-ils `selfdestruct` ? (deprecie mais encore dangereux)
- [ ] **tx.origin vs msg.sender** : le contrat utilise-t-il `tx.origin` pour l'authentification ? → phishing possible
- [ ] **Ref exploit** : Yearn Finance 2025 ($9M) — legacy yETH governance mint sans access control

### 2.3 Gestion des tokens

- [ ] **Fee-on-transfer tokens** : le contrat suppose-t-il `amount` recu = `amount` envoye ? Si oui → comptabilite cassee
- [ ] **Rebasing tokens** : `balanceOf()` change sans transfert — le contrat gere-t-il ca ?
- [ ] **Tokens avec decimales non-standard** : USDC (6), WBTC (8), certains ERC20 (0 ou 24)
- [ ] **Return value** : le contrat verifie-t-il le retour de `transfer()`/`transferFrom()` ? USDT ne retourne pas bool
- [ ] **approve(0) requis** : USDT requiert `approve(0)` avant `approve(newAmount)` — gere ?
- [ ] **Tokens deflationnaires/inflationnaires** : le contrat presume-t-il un supply constant ?

---

## 3. INFRASTRUCTURE CROSS-CHAIN ET BRIDGES

> **⚠️ Avant toute chose sur un bridge: §3.6 Mirror Invariant Audit est GATING** — pour chaque paire in/out (transferToAgent / transferToken, lock / unlock, mint / burn, encode / decode), écrire explicitement V_in vs V_out dans les notes. "File audited clean" sans la comparaison miroir = audit incomplet. Voir §3.6 pour la méthodologie.

### 3.1 Fonctions fantomes (Ghost Functions)

- [ ] **Interfaces obsoletes** : chercher `deposit()` vs `depositETH()`, `withdraw()` vs `withdrawTo()` — la vieille version est-elle encore active ?
- [ ] **Fonctions desactivees mais pas supprimees** : le code est commente mais la fonction existe encore dans l'ABI
- [ ] **Fallback/receive** : le contrat a-t-il un `fallback()` ou `receive()` qui accepte ETH sans logique ?
- [ ] **Ref exploit** : CrossCurve 2026 ($3M) — malicious message crafting to ReceiverAxelar

### 3.2 Verification cryptographique

- [ ] **Merkle root 0x00** : le contrat verifie-t-il `require(root != bytes32(0))` ?
- [ ] **Signature malleability** : `ecrecover` sans verification `s < n/2` ? Replay possible
- [ ] **Hash collision** : `abi.encodePacked` avec types dynamiques adjacents → collision possible (`abi.encode` est safe)
- [ ] **EIP-712** : domain separator correct ? chainId hardcode ou dynamique ?

### 3.3 Desynchronisation d'etat

- [ ] **msg.value vs token accounting** : le contrat peut-il recevoir ETH natif ET traiter des wrapped tokens ? Double-comptage ?
- [ ] **Mint sans burn** : cote source on burn, cote destination on mint — peut-on mint sans avoir burn ?
- [ ] **Nonce replay** : les messages cross-chain ont-ils un nonce ? Peut-on rejouer un message ?
- [ ] **Finality gap** : l'attestation de pontage est-elle basee sur un bloc non-final ? Reorg possible ?
- [ ] **Ref exploit** : Ronin Network 2022 ($620M) — validator key compromise

### 3.4 Reorg d'etat

- [ ] **L2 → L1** : le message de pontage attend-il la finalite de la L2 ?
- [ ] **Optimistic rollup** : challenge period respecte ? 7 jours pour OP, variable pour autres
- [ ] **Sequencer manipulation** : le sequenceur peut-il reordonner les transactions de pontage ?

### 3.5 Cross-Chain Messaging Integration (NEW 2026)

Detection — identify messaging protocol:
```bash
# LayerZero
grep -rn "ILayerZeroEndpoint\|lzReceive\|lzSend\|OApp\|OFT\|ONFT" --include="*.sol"
# Axelar
grep -rn "IAxelarGateway\|AxelarExecutable\|expressExecute\|executeWithToken" --include="*.sol"
# Wormhole
grep -rn "IWormhole\|parseAndVerifyVM\|publishMessage" --include="*.sol"
# Hyperlane
grep -rn "IMailbox\|IInterchainSecurityModule\|dispatch" --include="*.sol"
# CCIP
grep -rn "IRouterClient\|CCIPReceiver\|ccipReceive" --include="*.sol"
# Generic
grep -rn "srcChainId\|sourceChain\|trustedRemote\|setPeer" --include="*.sol"
```

**If ANY detected → complete all checks below:**

- [ ] **Source validation** in EVERY message-receiving function (chain ID AND sender address, not just one)
- [ ] **Trusted remotes immutable or admin-protected** (public setter = attacker reconfigures)
- [ ] **expressExecute path** has SAME validation as normal path (CrossCurve $3M bug)
- [ ] **Replay protection** — messages can't be processed twice (nonce/messageId check)
- [ ] **No ordering assumption** — or graceful handling of out-of-order delivery
- [ ] **Message expiration** — old messages rejected after conditions change
- [ ] **Gas limit validated** — attacker can't cause partial execution via low gas limit
- [ ] **Failed messages handled** — no silent drops, no blocking queue exploitable for DoS
- [ ] **Atomic token+message** — no split-brain between message and token transfer
- [ ] **DVN/ISM configuration** — how many required? (1 DVN = single point of failure). Admin-changeable?
- [ ] **LayerZero V1 vs V2** — V1 trustedRemoteLookup vs V2 setPeer (different security models)
- [ ] **Ref**: CrossCurve $3M (Axelar expressExecute), IoTeX Bridge $4.3M (validator key + upgrade)

### 3.6 Mirror Invariant Audit (MANDATORY — CLAUDE.md rule #41)

For bridges, vaults, escrow, and any paired state-changing protocol, validation of an invariant on one side of the flow **requires the same validation on the mirror side** or an articulable design reason for the asymmetry. Run this BEFORE declaring any in/out file "audited clean".

**Enumerate bidirectional pairs in the target:**

```bash
# Bridges
grep -nE "function (transferToAgent|transferFromAgent|transferToken|transferEther|lock|unlock|registerToken|unregisterToken|processInbound|processOutbound|handleMessage|dispatchMessage|encodeMessage|decodeMessage|sendMessage|receiveMessage)" src/

# Wrapped token mirrors
grep -nE "function (mint|burn|wrap|unwrap|deposit|withdraw)\b" src/

# Message codec mirrors
grep -nE "function (encode|decode|pack|unpack|serialize|deserialize)" src/
```

**For each pair, extract V_in / V_out side-by-side:**

| Validation | V_in (ingress fn) | V_out (egress fn) | Asymmetry? | Design reason? |
|---|---|---|---|---|
| Balance delta check | ✓ / ✗ | ✓ / ✗ | | |
| isContract() check | ✓ / ✗ | ✓ / ✗ | | |
| Nonce/replay guard | ✓ / ✗ | ✓ / ✗ | | |
| Source chain ID | ✓ / ✗ | ✓ / ✗ | | |
| Sender address match | ✓ / ✗ | ✓ / ✗ | | |
| Pause / mode gate | ✓ / ✗ | ✓ / ✗ | | |
| Amount bounds | ✓ / ✗ | ✓ / ✗ | | |
| Recipient allowlist | ✓ / ✗ | ✓ / ✗ | | |

**Decision rule for each asymmetry row:**
- (a) One-sentence articulable design reason? (e.g., "ingress pulls from attacker-controlled source via `transferFrom`; egress pushes to user-controlled destination via `transfer` — different trust domains justify different checks")
- (b) Different-layer guarantee? (e.g., "the registry validates token semantics at registration, so egress trusts already-registered tokens") — verify by reading the guarantor code, not by assuming
- (c) Documented in code comment or spec?
- If none of a/b/c hold → **oversight → finding-candidate → apply Kill Gate**

**Mechanical gate for audit completeness:** if audit notes say "file X audited clean" for any in/out file WITHOUT a companion line stating the mirror comparison result, the file is NOT clean, audit is mid-flight. Force both halves to be written.

**Example — Snowbridge SNOW-002 (2026-04-20):**
```
Pair: Functions.transferToAgent (ingress) / AgentExecutor.transferToken (egress)
V_in:  { isContract, nonZeroAmount, balanceDeltaCheck, revertOnShortDelivery }
V_out: { safeTransferReturnCheck }
Diff V_in \ V_out: { balanceDeltaCheck, revertOnShortDelivery }
Design reason? NO — same codebase, same 1:1 invariant, PR #1636 explicitly added the ingress check with comment "Tokens with Fee-On-Transfer behaviour are not supported". No spec or code comment justifies the egress gap.
→ ASYMMETRY → finding-candidate → Kill Gate PROCEED → SNOW-002 High severity
```

**Why this rule exists:** the 2026-04-19 Snowbridge audit session recorded both sides in the same notes pass — "Functions.sol (transferToAgent has FoT protection)" AND "AgentExecutor.sol audited clean" — without performing the mirror comparison. V12 (Zellic LLM auditor) found the bug the following day because it applies the same 5 checks uniformly to every function. Mirror audit is how human auditors replicate that uniformity for the in/out bug class. Absence-of-protection bugs are invisible to presence-scanning; they require a **comparison discipline** that checkbox audit does not produce.

See `feedback_mirror_invariant_audit.md` for the full methodology and grep pairs per protocol topology (bridges, vaults, escrow, mint/burn wrapped, message codecs).

---

## 4. CRYPTOGRAPHIE ZERO-KNOWLEDGE

### 4.1 Circuits sous-contraints

- [ ] **Assignations non contraintes** : chercher `<--` sans `===` correspondant dans Circom
- [ ] **Witness forgeable** : peut-on soumettre un witness qui satisfait les contraintes mais represente un etat invalide ?
- [ ] **Signal inutilise** : un input public qui n'est pas contraint dans le circuit → ignorable

### 4.2 Faille Fiat-Shamir

- [ ] **Transcript incomplet** : tous les inputs publics sont-ils hashes dans le challenge ? Si un parametre manque → preuve forgeable
- [ ] **Weak Fiat-Shamir** : le hash utilise-t-il un domain separator unique ? Sinon → cross-protocol replay

### 4.3 Depassement de champ (Field Overflow)

- [ ] **Range check manquant** : l'input est-il verifie `< p` (ordre du champ) ? Sinon, `x mod p` donne un resultat different
- [ ] **Num2Bits** : la decomposition binaire force-t-elle le nombre de bits correct ?
- [ ] **Negative values** : dans un champ premier, `-1 = p-1` — le circuit gere-t-il les "negatifs" correctement ?

### 4.4 Groth16 Verification Key (NEW 2026)

- [ ] **delta2 == gamma2** : Si ces points sont egaux dans le verifier contract → TOUTES les preuves sont forgeables. Check on-chain.
- [ ] **Trusted setup integrity** : Le setup ceremony a-t-il ete verifie ? Contribution logs publics ?
- [ ] **Ref exploit** : FOOMCASH Feb 2026 ($2.26M) — copycat de Veil Cash, delta2 = gamma2
- [ ] **Tooling** : zkFuzz (IEEE S&P 2026) — mutation fuzzer pour circuits Circom/Noir, 85+ bugs trouves

---

## 5. FLASH LOANS ET MEV

### 5.1 Flash loan attack chains

- [ ] **Peut-on emprunter → manipuler → profiter → rembourser dans un seul tx ?**
- [ ] **Collateral inflation** : deposer via flash loan → emprunter plus → rembourser flash loan → garder l'excedent
- [ ] **Pool skew** : flash loan pour desequilibrer un pool → profiter de l'arbitrage → re-equilibrer
- [ ] **Governance flash** : emprunter tokens de governance → voter → rembourser
- [ ] **Ref exploit** : Beanstalk 2022 ($182M) — flash-borrowed governance votes

### 5.2 MEV et sandwich

- [ ] **Swap sans slippage** : `minOut = 0` ou slippage trop large → sandwich garanti
- [ ] **Transactions privilegiees** : liquidations, rewards claims — front-runnable ?
- [ ] **Commit-reveal** : le protocole expose-t-il des intentions avant execution ?
- [ ] **Private mempool** : le protocole utilise-t-il Flashbots/MEV protection ?
- [ ] **Ref exploit** : Balancer V2 forks 2025 ($125M) — reordering + invariant distortion

### 5.3 Structural MEV Analysis (NEW — if not excluded by program)

**Pre-gate: Check program exclusions FIRST**
```bash
# If program excludes "frontrunning", "MEV", "sandwich" → SKIP this entire section
# Only proceed on Primacy of Impact programs with NO frontrunning exclusion
```

- [ ] **Pre-gate passed** — frontrunning NOT excluded in program scope
- [ ] **Window-actor check** — does any candidate finding need an intermediate state to PERSIST (saturation/liquidation/unlock/oracle-stale window)? Three deaths: (i-a) targeted reset, (i-b) INCIDENTAL reset by routine traffic (payoff ~0, kills you anyway), (ii) front-run of your extraction AT maturity. Bots present at **t=0**, not a future risk. Payoff recomputed POST-PoC (window+value are PoC outputs). → KILL-GATE **Q5b**

#### Price function manipulability
```bash
grep -rn "getAmountOut\|getSpotPrice\|slot0\b" --include="*.sol"  # spot price (manipulable)
grep -rn "PERIOD\|WINDOW\|secondsAgo\|cardinality" --include="*.sol"  # TWAP params
grep -rn "totalAssets\|totalSupply\|getReserves" --include="*.sol"  # reserve-based pricing
```

- [ ] **Price oracle type** : spot (manipulable) / TWAP / Chainlink
- [ ] **TWAP window** sufficient? (<30 min = manipulable)
- [ ] **Reserve-based pricing** — moveable by deposit/withdrawal in same block?

#### Liquidation MEV
```bash
grep -rn "liquidat" --include="*.sol"
grep -rn "liquidationBonus\|liquidationIncentive\|CLOSE_FACTOR" --include="*.sol"
grep -rn "flashLoan\|flash\b" --include="*.sol"
```

- [ ] **Liquidation incentive** quantified — X% bonus = X% extractable
- [ ] **Flash loan + liquidation** possible in single tx?
- [ ] **No Dutch auction** — fixed discount = deterministic MEV

#### Quantification
```
MEV_per_event = price_impact × volume
annual_MEV = MEV_per_event × events_per_year
If annual_MEV / TVL > 1% → material design flaw
If > 0.1% → reportable under Primacy of Impact
If < 0.01% → not worth reporting (Kill Gate fails)
```

- [ ] **MEV quantified** with concrete numbers
- [ ] **Annual extraction estimated** vs TVL

---

## 6. GOVERNANCE ET UPGRADEABILITY

### 6.1 Proxy et storage

- [ ] **Storage collision** : le proxy et l'implementation partagent-ils un slot de storage ?
- [ ] **Uninitialized implementation** : `initialize()` appelee sur le proxy mais pas sur l'implementation → attaquant initialise l'implementation et `selfdestruct`
- [ ] **Function clashing** : le proxy a-t-il une fonction avec le meme selector que l'implementation ?

### 6.2 Gouvernance malicieuse

- [ ] **Timelock bypass** : existe-t-il un chemin qui contourne le timelock ?
- [ ] **Emergency functions** : `pause()`, `kill()`, `emergencyWithdraw()` — qui peut les appeler ?
- [ ] **Parameter bounds** : les parametres de gouvernance ont-ils des limites ? (fee max, delay min, etc.)
- [ ] **Ref exploit** : Cream Finance V3 2025 ($43M) — GOV token hijack

### 6.3 Upgrade Chain Deep Trace (NEW 2026)

- [ ] **Every proxy** has full chain resolved per DEFI-FULLSTACK §F4.1
- [ ] **Implementation initialization** verified (uninitialized = HIGH)
- [ ] **Timelock presence** verified at every level
- [ ] **Multi-chain admin divergence** — one chain uses EOA while others use Safe?
- [ ] **Emergency bypass** — timelock has emergency executor without delay?
- [ ] **Beacon proxy** — compromising beacon upgrades ALL proxies simultaneously
- [ ] **Storage layout compatibility** between current and potential new implementation
- [ ] **Ref**: Bybit ($1.4B) — Safe{Wallet} UI → upgrade. zkSync ($5M) — admin key. CPIMP 2025 — init front-run

---

## 6b. NOUVELLES CLASSES 2025-2026

### 6b.1 EIP-7702 Delegation Phishing (Post-Pectra)

- [ ] **tx.origin == msg.sender bypass**: EIP-7702 allows EOAs to delegate to contracts. Any check `require(tx.origin == msg.sender)` for "EOA-only" is now bypassable. Scanner: `grep -rn "tx.origin" --include="*.sol"`
- [ ] **Flash loan guard bypass**: Protocols using `tx.origin` to block flash loans are vulnerable — delegated EOAs execute atomic sequences
- [ ] **Cross-chain replay**: EIP-7702 auth tuples can replay across all EVM chains where victim address exists
- [ ] **Ref exploit**: Inferno Drainer 2025 — $9M from 30K wallets via EIP-7702 delegation phishing

### 6b.2 Uniswap V4 Hook Exploitation

- [ ] **Hook caller validation**: Does `beforeSwap/afterSwap/beforeAddLiquidity` verify `msg.sender == PoolManager`? If not → arbitrary contract can impersonate pool callbacks
- [ ] **Hook permission encoding**: Do hook address LSBs match implemented functions? Misalignment → silent function skips
- [ ] **Custom accounting (ERC-6909)**: Can LP token minting be abused recursively across pools?
- [ ] **Delta sign inversion**: Does hook correctly handle swap delta semantics? Misunderstanding → value extraction
- [ ] **Dynamic fee manipulation**: If fee = 0 + missing OVERRIDE_FEE_FLAG → fee logic silently fails
- [ ] **Flash accounting reentry**: Can hook interaction unlock global reentrancy guards?
- [ ] **Fake market creation**: Can hooks accept arbitrary parameters without validating token legitimacy?
- [ ] **Ref exploit**: Cork Protocol May 2025 ($11M) — missing beforeSwap access control. BunniDEX Sep 2025 ($8.4M) — LDF rounding in rebalancing.

### 6b.3 Transient Storage Exploitation (EIP-1153)

- [ ] **Slot aliasing**: Same transient storage slot used for multiple purposes in single execution flow → overwrite == impersonation
- [ ] **Cross-function contamination**: Transient storage not cleared between internal calls → stale data from previous function
- [ ] **Compiler bug SOL-2026-1**: Solidity 0.8.28-0.8.33, `--via-ir` + `delete` on transient + clearing persistent of matching type → wrong opcode (sstore vs tstore)
- [ ] **Missing tload/tstore in audit**: New opcodes not covered by older audit tools
- [ ] **Ref exploit**: SIR Protocol 2025 — transient slot reuse allowed Uniswap pool impersonation

### 6b.4 CPIMP — Proxy Initialization Front-Running

- [ ] **Unprotected initialize()**: Can an attacker front-run proxy initialization to insert malicious implementation?
- [ ] **Transparent forwarding**: Malicious proxy layer forwards ALL calls to legitimate impl except backdoor functions → invisible during normal operation
- [ ] **CREATE2 prediction**: If proxy address is deterministic via CREATE2, attacker can deploy before legitimate deployer
- [ ] **Ref exploit**: Industry-wide CPIMP campaign 2025 — transparent proxy-in-the-middle with batch token draining

### 6b.5 Perp DEX Oracle-Liquidity Manipulation

- [ ] **Thin-liquidity perp markets**: Can positions be opened in low-liquidity perps where oracle price is manipulable?
- [ ] **Spot-to-oracle pipeline**: Does perp price derive from spot market manipulable via CEX trading?
- [ ] **Community vault absorption**: Does protocol design force a shared vault (HLP) to absorb bad positions?
- [ ] **Position size limits**: Are there caps relative to available liquidity?
- [ ] **Ref exploit**: Hyperliquid JELLY Mar 2025 ($12.6M) — spot pump 429% on CEX, HLP absorbed bad debt

### 6b.6 Supply Chain UI Compromise

- [ ] **Multisig signing UX**: Does protocol use web-based multisig signing (Safe, custom)? If yes → signing layer is attack surface
- [ ] **Hardware wallet blind signing**: Signers using Ledger/Trezor with web UI cannot verify transaction content independently
- [ ] **Developer AWS/GCP credentials**: If signing UI hosted on cloud, developer credentials = protocol control
- [ ] **Ref exploit**: Bybit Feb 2025 ($1.4B) — Safe{Wallet} developer machine compromised, malicious JS injected into signing UI

### 6b.7 zkSNARK Verification Key Misconfiguration

- [ ] **delta2 == gamma2**: Check Groth16 verifier contract — if these are equal, ALL proofs are forgeable
- [ ] **On-chain check**: Read verifier contract storage, compare delta2 and gamma2 points
- [ ] **Ref exploit**: FOOMCASH Feb 2026 ($2.26M) — copycat of Veil Cash, delta2 = gamma2

### 6b.8 Rounding-Plus-Inflation Compound Attacks

- [ ] **Empty vault window**: Does protocol have a window where vaults are fresh/empty before deposits?
- [ ] **Donation + floor division**: Can attacker donate tokens + exploit floor division in share calculation?
- [ ] **Race condition on vault deployment**: Can attacker front-run first legitimate deposit?
- [ ] **Missing dead shares**: Does ERC-4626 vault use virtual shares/assets or minimum deposit protection?
- [ ] **Ref exploit**: Resupply Jun 2025 ($9.5M) — flash loan donation on 1.5h-old vault. wUSDM Feb 2026 — exchange rate inflated from 1.06 to 1.7.

### 6b.9 Deflationary Token Pool Accounting

- [ ] **Fee-on-transfer detection**: Does protocol assume `amount` transferred == `amount` received? `grep -rn "transferFrom" --include="*.sol"` then check if balance delta is used
- [ ] **Burn mechanics exploitation**: Deflationary burn removes tokens from pool → price spike without AMM accounting update
- [ ] **Balance-based vs accounting-based**: Does pool use `balanceOf(this)` or internal tracking? If balanceOf → manipulable by donation AND deflation
- [ ] **Ref exploit**: PumpToken, NGP Token, RANT Token 2025 — systematic arbitrage via deflationary mechanics

### 6b.10 Null-Gate / Type-Confusion Bypass in Auth Layers (NEW 2026)

A security check gated on a type-narrowing operation (cast, parse, `toSignedJWT()`, `instanceof`) that returns null/None for **spec-valid** input types causes the entire check to be silently skipped, while the authenticated action still proceeds.

**Generalized pattern:**
```
// Layer 1 succeeds (decryption, parsing, deserialization)
innerObject = layer1_process(input);  // OK

// Type narrowing — returns null for spec-valid alternative types
narrowed = innerObject.toExpectedType();  // null if PlainJWT, wrong subclass, etc.

// Security check GATED on narrowing result
if (narrowed != null) {       // ← THE BUG: null = check skipped entirely
    verify(narrowed);          //    but action proceeds regardless
}

// Authenticated action runs with unverified claims
processAuthenticated(innerObject);  // ← attacker's arbitrary payload accepted
```

- [ ] **JWT: PlainJWT inside JWE** — `toSignedJWT()` returns null for unsigned tokens → signature verification skipped. Attacker encrypts PlainJWT with public key → full auth bypass. `grep -rn "toSignedJWT\|signedJWT.*null\|JWTClaimsSet\|JwtAuthenticator" --include="*.java"`
- [ ] **JWT: alg:none variant** — `alg` header set to `none` → some libraries skip verification entirely. Different from PlainJWT-in-JWE but same null-gate class
- [ ] **OAuth2 token type confusion** — Access token vs refresh token vs authorization code accepted interchangeably. If token type check returns null for unexpected type → elevated privileges
- [ ] **SAML assertion type confusion** — Signed vs unsigned assertions in encrypted SAML responses. Same pattern as JWT PlainJWT-in-JWE but XML-based
- [ ] **Protobuf/gRPC oneof confusion** — `oneof` field deserialized to unexpected variant → auth check on wrong branch → skipped
- [ ] **Deserialization type confusion** — Java `instanceof` check returns false for polymorphic subclass → security check skipped → gadget chain proceeds
- [ ] **WebSocket upgrade bypass** — HTTP auth middleware doesn't cover WebSocket upgrade handshake → unauthenticated WS connection
- [ ] **GraphQL operation type** — Auth middleware checks `query` but not `mutation` (or vice versa) → type mismatch bypasses auth

**Hunting methodology:**
1. Identify ALL security checks gated on `if (X != null)`, `if (X instanceof Y)`, `if (X.isPresent())`, `if (X is T)`
2. For each: can an attacker control the **type** of the input to make the narrowing return null/false?
3. If yes: does the code path AFTER the check still use the un-narrowed original object?
4. If yes: does the spec/protocol allow the alternative type? (PlainJWT is RFC 7519 valid, `alg:none` is spec-valid)

**Grep patterns (multi-language):**
```bash
# Java
grep -rn "toSignedJWT\|instanceof.*JWT\|getAlgorithm.*none\|signedJWT != null\|signedJWT == null" --include="*.java"
grep -rn "JwtAuthenticator\|JWTProcessor\|JWTClaimsSet\|SignedJWT\|PlainJWT" --include="*.java"

# Python
grep -rn "isinstance.*JWT\|decode.*verify.*False\|algorithms.*none\|jwt\.decode" --include="*.py"

# JavaScript/TypeScript
grep -rn "jwt\.verify\|jsonwebtoken\|jose\|JWTPayload\|alg.*none" --include="*.js" --include="*.ts"

# Go
grep -rn "jwt\.Parse\|Claims.*interface\|MapClaims\|StandardClaims" --include="*.go"

# Rust
grep -rn "jsonwebtoken\|jwt::decode\|Algorithm::None\|dangerous_insecure" --include="*.rs"

# Generic null-gate patterns (any language)
grep -rn "!= null.*verify\|!= nil.*verify\|\.is_some().*verify\|is not None.*verify" --include="*.java" --include="*.py" --include="*.go" --include="*.rs"
```

- [ ] **Ref exploit**: CVE-2026-29000 (pac4j-jwt, CVSS 10.0) — PlainJWT inside JWE bypasses signature verification. Public RSA key is the only prerequisite. Patched in pac4j 4.5.9/5.7.9/6.3.3
- [ ] **Ref exploit**: CVE-2022-21449 (Java 15-18 ECDSA, "Psychic Signatures") — blank signature accepted. Same class: type/value narrowing that skips verification
- [ ] **Ref pattern**: JWT `alg:none` (CVE-2015-9235 and many others) — the original null-gate bypass, still found in production

### 6b.11 JWK Header Auto-Trust (RFC 8725 §2.4 Violation) — NEW 2026

When a JWT library auto-trusts the `jwk` parameter embedded in the token header for key material (especially when the application-provided key is `None`/`null`/missing), an attacker signs with their own key, embeds their public key in the header → signature verification passes.

**Vulnerable pattern (Authlib <= 1.6.8, confirmed AUTH-001):**
```python
# Key resolution with header fallback — THE BUG
if callable(key):
    key = key(header, payload)
elif key is None and "jwk" in header:  # Attacker-controlled header trusted
    key = header["jwk"]               # Attacker's public key used for verification
key = algorithm.prepare_key(key)
```

**Grep patterns:**
```bash
# Python
grep -rn "jwk.*header\|header.*jwk\|key is None.*jwk\|key == None.*jwk" --include="*.py"
grep -rn "jku.*fetch\|jku.*url\|x5c.*cert\|x5c.*chain" --include="*.py"
grep -rn "deserialize_compact\|deserialize_json\|decode.*key.*None" --include="*.py"

# JavaScript/TypeScript
grep -rn "header\.jwk\|header\[.jwk.\]\|jku.*fetch\|importJWK.*header" --include="*.js" --include="*.ts"

# Java
grep -rn "getJWKUrl\|getJWK\|jwk.*header\|JWKSource\|RemoteJWKSet" --include="*.java"

# Go
grep -rn "Header.*JWK\|header\.JSONWebKey\|EmbeddedKeys\|jwk.*header" --include="*.go"
```

- [ ] **Check `jwk` header handling** — does the library auto-trust embedded keys?
- [ ] **Check `jku` handling** — is there a URL allowlist? Is HTTPS enforced?
- [ ] **Check `x5c` handling** — does the library validate the cert chain against trusted roots?
- [ ] **Check key=None fallback** — does the library fall back to header keys when app key is missing?
- [ ] **Internal inconsistency** — is JWT API protected but JWS/JWE API not?
- [ ] **Ref: AUTH-001** — Authlib <= 1.6.8, silently fixed v1.6.9. ~3.5M downloads/month affected.
- [ ] **Ref: RFC 8725 §2.4** — "Applications SHOULD NOT trust keys embedded in JWS/JWE headers"

### 6b.12 DER Algorithm Confusion (CVE-2024-33663 Bypass) — NEW 2026

Algorithm confusion uses an asymmetric public key as HMAC secret. CVE-2024-33663 fixed this by detecting PEM-format keys. But **DER-encoded keys are binary** (no `-----BEGIN` marker) and bypass PEM-only checks.

**Vulnerable pattern (python-jose all versions, confirmed JOSE-001):**
```python
# CVE-2024-33663 "fix" — only checks PEM format
if is_pem_format(key) or is_ssh_key(key):    # Only matches text patterns
    raise JWKError("asymmetric key...")
# DER bytes (binary) pass through here undetected
self._key = key  # RSA/EC public key DER bytes accepted as HMAC secret
```

**Grep patterns:**
```bash
# Python
grep -rn "is_pem_format\|is_ssh_key\|BEGIN.*END" --include="*.py"
grep -rn "HMACKey\|hmac_key\|symmetric.*key" --include="*.py"
grep -rn "algorithms.*None\|algorithms.*=.*None\|verify.*=.*False" --include="*.py"

# JavaScript/TypeScript
grep -rn "createHmac\|HMAC.*key\|symmetric.*secret" --include="*.js" --include="*.ts"

# Java
grep -rn "SecretKeySpec\|HmacSHA\|Mac.getInstance" --include="*.java"

# Go
grep -rn "hmac\.New\|crypto\.Hash\|\[\]byte.*key" --include="*.go"
```

**Combined attack chain (JOSE-001):**
1. Server uses python-jose with RS256 + RSA public key
2. Attacker obtains public key from JWKS endpoint (public)
3. Converts to DER: `openssl rsa -pubin -in pub.pem -outform DER -out pub.der`
4. Signs HS256 token using DER bytes as HMAC secret
5. `algorithms` defaults to None → no restriction → HS256 accepted
6. Server verifies HMAC using same DER bytes → match → full auth bypass

- [ ] **Check HMAC key constructor** — does it reject asymmetric keys in ALL formats (PEM, DER, SSH, JWK)?
- [ ] **Check algorithms parameter** — does it default to None/null (skipping allowlist)?
- [ ] **Check verify_signature param** — does False skip ALL checks?
- [ ] **Test DER bypass** — can DER-encoded EC/RSA public key be used as HMAC secret?
- [ ] **Check if library is maintained** — unmaintained = no fix coming, recommend migration
- [ ] **Ref: JOSE-001** — python-jose all versions (unmaintained, ~5M/month). FastAPI's default JWT lib.
- [ ] **Safe libs**: PyJWT 2.11+, go-jose/v4, lestrrat-go/jwx v3, Hono 4.11.4+, Authlib 1.6.9+

### 6b.14 ERC-4337 Account Abstraction (NEW 2026)

Account Abstraction bundlers and paymasters are the newest and least audited EVM infrastructure. Each bundler independently implements ERC-7562 validation rules — divergences between implementations create exploitable simulation-execution gaps.

**Detection — identify AA components:**
```bash
# EntryPoint and UserOp handling
grep -rn "IEntryPoint\|handleOps\|UserOperation\|PackedUserOperation" --include="*.sol"
grep -rn "validateUserOp\|_validateSignature\|missingAccountFunds" --include="*.sol"

# Paymaster patterns
grep -rn "IPaymaster\|validatePaymasterUserOp\|postOp\|PaymasterAndData" --include="*.sol"
grep -rn "getHash.*paymaster\|_packPaymasterData\|verifyingSigner" --include="*.sol"

# Modular accounts
grep -rn "installModule\|IModule\|IValidator\|IExecutor\|IHook\|IFallback" --include="*.sol"

# Factory patterns
grep -rn "createAccount\|deployCounterFactual\|accountFactory" --include="*.sol"

# Nonce management
grep -rn "getNonce\|nonceKey\|nonceSequence\|nonce.*2d" --include="*.sol"
```

**If ANY detected -> complete all checks below:**

- [ ] **Paymaster signature binding** — does the signed hash include ALL of: sender, nonce, callData, chainId, paymaster address? Missing field = replay/cross-account/cross-chain attack
- [ ] **Paymaster expiry** — `validUntil`/`validAfter` present? No expiry = signature valid forever = unlimited replay
- [ ] **Paymaster postOp reentrancy** — can UserOp execution manipulate state that `postOp()` reads? If yes -> paymaster accounting corruption (AA-010)
- [ ] **Factory front-running** — can attacker front-run `createAccount()` with different factory to control the account at the deterministic address? (AA-008)
- [ ] **Module installation** — for modular accounts (Kernel, Biconomy v2), can a malicious module be installed via social engineering? Are module permissions scoped correctly? (AA-009)
- [ ] **Gas estimation gap** — does UserOp cost differ between simulation and on-chain execution? Attacker submits ops that cost X in simulation but Y >> X on-chain -> bundler pays difference (AA-005)
- [ ] **Storage access violations** — does validation access banned storage per ERC-7562? Other accounts' storage, block-dependent values, DELEGATECALL to banned storage (AA-006)
- [ ] **Nonce management** — 2D nonces (key + sequence) — can attacker manipulate nonce key to bypass ordering or replay?
- [ ] **EntryPoint version** — v0.6 vs v0.7 have different security models. Mixing = inconsistencies
- [ ] **Ref**: See `ZERO-DAY-METHODOLOGY.md` Domain 3 for full bundler differential testing methodology

### 6b.13 Dependency Supply Chain (NEW 2026)

- [ ] **Frontend build dependencies** audited per DEFI-FULLSTACK §F2.4
- [ ] **Smart contract dependencies** (OpenZeppelin, Solmate) pinned to specific commit, not floating tag?
- [ ] **Foundry/Hardhat plugins** — malicious plugins can inject backdoors at build time
- [ ] **GitHub Actions / CI** — pinned to sha, not tag? `grep -rn "uses:" .github/workflows/*.yml | grep -v "@[a-f0-9]{40}"`
- [ ] **Docker base images** — `:latest` or pinned digest?
- [ ] **Ref**: Bybit ($1.4B), npm chalk/debug Sep 2025, event-stream 2018, Aerodrome DNS $700K

---

## 6c. BLOCKCHAIN NODE P2P — LOCK CONTENTION + ALGORITHMIC COMPLEXITY

**Cibles :** Tout client blockchain L1/L2 (java-tron, geth, reth, solana-validator, lighthouse, prysm, lodestar)
**Ref exploit :** TRON AdvService INVENTORY DoS (2026) — O(N²) CPU + consensus stall via shared lock, $100K bounty

### 6c.1 Lock Contention Cross-Subsystem Audit

Pour chaque lock/mutex/synchronized dans le codebase du nœud :

```
# Step 1: Map ALL locks
grep -rn "synchronized\|\.lock()\|\.tryLock\|RwLock\|Mutex::new\|Arc<Mutex" --include="*.java" --include="*.go" --include="*.rs" <service_dirs>/

# Step 2: For each lock, identify ALL threads that acquire it
# Classify: UNTRUSTED (P2P input, RPC handler) vs TRUSTED (consensus, block production)
```

- [ ] **Identifier TOUS les threads** qui acquièrent chaque lock
- [ ] **Classifier chaque thread** : trusté (consensus, block production, finality) vs non-trusté (P2P message handler, RPC handler, mempool)
- [ ] **Si un lock est acquis par BOTH trusté ET non-trusté** → escalation candidate
- [ ] **Mesurer le temps de hold max** pour le thread non-trusté (input size × complexity)
- [ ] **Comparer au timing critique** du thread trusté (block interval, slot duration, finality timeout)
- [ ] **Si hold_time > critical_timing** → consensus/availability impact **CONFIRMÉ**

### 6c.2 Internal Consistency — Message Type Protection Matrix

- [ ] **Lister TOUS les types de messages P2P** (inventory, block, transaction, sync, handshake, etc.)
- [ ] **Pour chaque type, documenter les protections** : rate limit, size limit, count limit, auth requirement
- [ ] **Comparer** — tout gap dans la matrice = signal d'attaque
- [ ] **Chercher les GitHub issues** : `rate limit`, `DoS`, `performance`, `timeout` → acknowledged but unpatched = confirmed surface
- [ ] **Pattern TRON** : INVENTORY BLOCK avait ZERO protection quand TRX INVENTORY, SYNC, FETCH avaient tous des rate limiters

### 6c.3 Algorithmic Complexity on Message Handlers

- [ ] **Pour chaque handler de message** qui itère une collection : quelle est la complexité ?
- [ ] **O(N) handler qui appelle O(N) function par élément = O(N²)** (pattern TRON: addInv → consumerInvToFetch per hash)
- [ ] **Tester avec des messages valides à volume maximal** (PAS des messages malformés — rester dans le frame limit)
- [ ] **Collections unbounded** (`HashMap`, `Vec`, `map`) dans les handlers → memory exhaustion potential
- [ ] **Calculer** : max_items_per_message × complexity_per_item vs gas_limit / block_interval

### 6c.4 Consensus Thread Starvation

- [ ] **Identifier le thread de production de blocs** (DPosMiner, miner, proposer, validator)
- [ ] **Tracer toutes les opérations qu'il fait** : generate → sign → broadcast → push
- [ ] **Est-ce que `broadcast()` traverse un lock partagé avec le P2P ?** → si oui, le P2P peut bloquer la production
- [ ] **Est-ce que le block producer tient un autre lock pendant qu'il attend ?** → deadlock potential ou cascade stall
- [ ] **Quantifier** : si N attaquants bloquent le broadcast pendant > block_interval → blocs manqués
- [ ] **Impact réseau** : combien de validators doivent être stalled pour briser la finalité ? (TRON: 18/27, ETH: 2/3)

### 6c.5 Quick Grep Patterns pour Blockchain Nodes

```bash
# Java (java-tron, besu)
grep -rn "synchronized" --include="*.java" **/service/ **/handler/ **/consensus/
grep -rn "private.*synchronized.*void" --include="*.java" | sort  # methods that hold instance lock
grep -rn "ConcurrentHashMap\|HashMap.*new\|ArrayList.*new" --include="*.java" **/service/ # unbounded collections

# Go (geth, cosmos-sdk)
grep -rn "sync.Mutex\|sync.RWMutex\|\.Lock()\|\.RLock()" --include="*.go" **/p2p/ **/consensus/ **/core/
grep -rn "make(map\|make(chan" --include="*.go" **/p2p/ **/handler/ # unbounded maps/channels

# Rust (reth, solana-validator, lighthouse)
grep -rn "Mutex::new\|RwLock::new\|\.lock()\|\.write()" --include="*.rs" **/p2p/ **/consensus/
grep -rn "HashMap::new\|Vec::new\|BTreeMap::new" --include="*.rs" **/handler/ # unbounded collections
```

### 6c.6 Attack Cost Estimation

```
connections_needed = target_validators × connections_per_validator
bandwidth = connections_needed × max_message_size / repeat_interval
cost_per_hour = cloud_vms × vm_hourly_rate

# TRON example:
# 27 SRs × 2 conn × 5MB / 15s = 18 MB/s, 27 VMs × $0.01/h = $0.27/hour
# → halt entire $25B market cap blockchain for $0.27/hour
```

---

## 7. PATTERNS DE CODE SPECIFIQUES A SCANNER

### Solidity

```
grep -rn "unchecked" --include="*.sol"
grep -rn "delegatecall" --include="*.sol"
grep -rn "selfdestruct" --include="*.sol"
grep -rn "tx.origin" --include="*.sol"
grep -rn "abi.encodePacked" --include="*.sol"
grep -rn "ecrecover" --include="*.sol"
grep -rn "block.timestamp" --include="*.sol"
grep -rn "balanceOf(address(this))" --include="*.sol"
grep -rn "msg.value" --include="*.sol"
grep -rn "assembly" --include="*.sol"
grep -rn "transferFrom.*amount" --include="*.sol"  # fee-on-transfer check
grep -rn "initialize\b" --include="*.sol"  # unprotected init
grep -rn "tstore\|tload\|transient" --include="*.sol"  # EIP-1153 transient storage
grep -rn "tx.origin" --include="*.sol"  # EIP-7702 bypass (post-Pectra)
grep -rn "beforeSwap\|afterSwap\|beforeAddLiquidity\|afterAddLiquidity" --include="*.sol"  # V4 hooks
grep -rn "IHooks\|BaseHook" --include="*.sol"  # V4 hook implementations
grep -rn "delta2\|gamma2\|vk\." --include="*.sol"  # Groth16 verification key
grep -rn "CREATE2\|create2" --include="*.sol"  # deterministic deployment (CPIMP risk)
grep -rn "sweepUnclaimed\|sweep\b" --include="*.sol"  # airdrop admin functions
grep -rn "JwtAuthenticator\|SignedJWT\|PlainJWT\|toSignedJWT\|alg.*none" --include="*.java"  # JWT null-gate bypass (CVE-2026-29000)

# Account Abstraction / ERC-4337 (§6b.14 — auto-triggered if detected)
grep -rn "IEntryPoint\|handleOps\|UserOperation\|PackedUserOperation" --include="*.sol"
grep -rn "validateUserOp\|_validateSignature\|missingAccountFunds" --include="*.sol"
grep -rn "IPaymaster\|validatePaymasterUserOp\|postOp\|PaymasterAndData" --include="*.sol"
grep -rn "getHash.*paymaster\|_packPaymasterData\|verifyingSigner" --include="*.sol"
grep -rn "installModule\|IModule\|IValidator\|IExecutor\|IHook\|IFallback" --include="*.sol"
grep -rn "getNonce\|nonceKey\|nonceSequence" --include="*.sol"

# Cross-chain messaging (§3.5 — auto-triggered if detected)
grep -rn "lzReceive\|_lzReceive\|_execute\|ccipReceive\|parseAndVerifyVM" --include="*.sol"
grep -rn "trustedRemoteLookup\|setPeer\|peers\[" --include="*.sol"
grep -rn "expressExecute\|validateContractCall\|registeredEmitters" --include="*.sol"
grep -rn "failedMessages\|storedPayload\|retryPayload" --include="*.sol"
```

### JWT/Auth Libraries (Python/JS/Java/Go) — 6b.11 + 6b.12

```bash
# 6b.11: JWK header auto-trust (AUTH-001 pattern)
grep -rn "jwk.*header\|header.*jwk\|key is None.*jwk\|key == None.*jwk" --include="*.py"
grep -rn "header\.jwk\|header\[.jwk.\]\|jku.*fetch\|importJWK.*header" --include="*.js" --include="*.ts"
grep -rn "getJWKUrl\|getJWK\|jwk.*header\|JWKSource" --include="*.java"
grep -rn "Header.*JWK\|header\.JSONWebKey\|EmbeddedKeys" --include="*.go"
grep -rn "x5c.*cert\|x5c.*chain\|x5u.*url" --include="*.py" --include="*.js" --include="*.java" --include="*.go"

# 6b.12: DER algorithm confusion (JOSE-001 pattern)
grep -rn "is_pem_format\|is_ssh_key\|BEGIN.*END\|pem_format" --include="*.py"
grep -rn "HMACKey\|hmac_key\|createHmac\|SecretKeySpec\|hmac\.New" --include="*.py" --include="*.js" --include="*.java" --include="*.go"
grep -rn "algorithms.*None\|algorithms.*=.*None\|algorithms.*undefined\|algorithms.*null" --include="*.py" --include="*.js" --include="*.ts" --include="*.java"
grep -rn "verify.*=.*False\|verify_signature.*False\|verify.*false\|skipVerification" --include="*.py" --include="*.js" --include="*.ts" --include="*.java"

# Combined: identify JWT library in use (triage which 6b.11/6b.12 checks apply)
grep -rn "import.*jose\|from jose\|import.*jwt\|from.*jwt\|require.*jsonwebtoken\|require.*jose\|import.*authlib" --include="*.py" --include="*.js" --include="*.ts"
grep -rn "go-jose\|lestrrat.*jwx\|golang-jwt\|dgrijalva.*jwt" --include="*.go"
grep -rn "nimbus.*jose\|pac4j.*jwt\|auth0.*jwt\|io\.jsonwebtoken" --include="*.java"
```

### Vyper

```
grep -rn "unsafe_" --include="*.vy"
grep -rn "raw_call" --include="*.vy"
grep -rn "create_from_blueprint" --include="*.vy"
grep -rn "balanceOf(self)" --include="*.vy"
grep -rn "send\|raw_call.*value" --include="*.vy"
grep -rn "extcall.*\\.transfer" --include="*.vy"  # return value check
```

### Rust (Solana/Sui/Cosmos)

```
grep -rn "unchecked" --include="*.rs"
grep -rn "unwrap()" --include="*.rs"
grep -rn "as u64\|as u128\|as i64" --include="*.rs"  # unsafe casts
grep -rn "invoke_signed" --include="*.rs"  # CPI calls
grep -rn "try_from.*unwrap" --include="*.rs"
```

---

## 7b. SOLANA / ANCHOR PATTERNS

**For Solana-specific deep dives, see the full checklist at `SOLANA-HUNT-CHECKLIST.md`.**

Quick surface scan patterns:

```bash
# Account validation gaps (most common Solana bug class)
grep -rn "AccountInfo" --include="*.rs"  # Raw accounts lack auto-validation
grep -rn "remaining_accounts" --include="*.rs"
grep -rn "invoke\|invoke_signed" --include="*.rs"  # CPI without program check

# Unsafe arithmetic
grep -rn "as u64\|as u128\|as i64\|as u32" --include="*.rs"
grep -rn "saturating_sub\|saturating_add" --include="*.rs"  # May mask real errors

# Oracle
grep -rn "get_price\|load_price\|price_feed" --include="*.rs"
grep -rn "publish_time\|last_update\|staleness" --include="*.rs"

# Token-2022
grep -rn "token_2022\|token_extensions\|transfer_hook" --include="*.rs"
```

Key Solana-specific categories:
- **Account Validation** — missing `has_one`, missing signer, missing owner check, PDA seed collision
- **CPI Security** — arbitrary CPI target, privilege escalation, CPI reentrancy
- **Anchor Pitfalls** — discriminator collision, remaining_accounts unvalidated, `close` without zero
- **Oracle (Pyth/Switchboard)** — staleness, confidence interval, negative price, spot vs TWAP

---

## 8. WORKFLOW D'ATTAQUE SYSTEMATIQUE

**IMPORTANT:** Every finding MUST pass the Kill Gate (KILL-GATE-TEMPLATE.md) BEFORE any report writing. Preflight Check (PREFLIGHT-CHECK.md) BEFORE any submission.

### 8.0 TARGET PROFILING (Step 0 — 2 min)

Before ANY work, classify the target into one or more profiles. This determines
which sections fire, which EV parameters apply, and which OUTCOMES fields to fill.

```
PROFILE DETECTION — check ALL that apply:

  DEFI          Smart contract, vault, AMM, lending, staking
  BRIDGE        Cross-chain messaging, relayer, validator set
  ZK            Circuits, provers, verifiers, Groth16/PLONK
  GOVERNANCE    Timelock, multisig, token voting, upgradeability
  SOLANA        Anchor, Solana programs, SPL tokens
  NEXTJS        React Server Components, middleware, RSC payloads
  FINTECH       Neobank API, payment flow, card issuance, KYC
  OPENBANKING   PSD2/Berlin Group/UK OB API, consent, SCA, PISP/AISP
  PAYMENT_INFRA Payment SDK (Stripe/Adyen/PayPal), webhook, IBAN
  PARSER_LIB    Serialization library, format parser, native addon
  AUTH          JWT/OAuth2/SAML, session management, MFA

Compound profiles are normal: "DEFI + BRIDGE" or "FINTECH + AUTH".
```

### 8.1 PROFILE → CHECKLIST ROUTING TABLE

```
PROFILE         STEP 2 (SURFACE)          STEP 5 (DEEP DIVE)                    STEP 6 (EXTENDED)       EV DOMAIN
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
DEFI            §7 grep + §6b.13          §1, §2, §5, §6b                       FULLSTACK if web app    defi
  + V4 Hook       + §6b.2 AUTO             + §6b.2 MANDATORY                                            defi
  + Post-Pectra   + §6b.1 AUTO             + §6b.1 EIP-7702                                             defi
BRIDGE          §7 + §3.5.1 AUTO          §3, §3.5, §2, §6b.6                  FULLSTACK               defi
ZK              §7                        §4, §4.4, §6b.7                      —                       defi
GOVERNANCE      §7 + §6b.13              §6, §6.3, §5, §6b.4                  FULLSTACK if web app    defi
SOLANA          §7b                       SOLANA-HUNT-CHECKLIST.md              —                       defi
NEXTJS          §7 (JS patterns)          NEXTJS-HUNT-CHECKLIST.md             —                       defi
AA/WALLETS      §7 + §6b.14 AUTO          §6b.14 + ZERO-DAY D3                —                       defi

FINTECH         §FIN-1→4 full scan        §FIN-1 (payment logic)               FULLSTACK §F1-F3        fintech
                                          §FIN-2 (KYC bypass)                  JWT-ARSENAL if token
                                          §FIN-3 (card exploit)
                                          §FIN-4 (notification)

OPENBANKING     §OB-1 (sandbox)           §OB-2 (consent)                      §OB-5 (certificates)    openbanking
                                          §OB-3 (SCA)                          TLS/headers audit
                                          §OB-4 (payment initiation)

PAYMENT_INFRA   §3.3.1 webhook grep       §3.3.2 webhook attacks               §3.4 IBAN diff          payment_infra
                §3.4 IBAN corpus           §3.2 ISO 20022 XML fuzzing           ZERO-DAY D9
                                          SDK internals audit

PARSER_LIB      ZERO-DAY D1/D9 seed       Differential fuzzing                 Crash isolation          payment_infra
                                          Native addon source audit             Downstream blast radius  OR defi

AUTH            §6b.10-12 AUTO            JWT-ARSENAL (8 tools)                §30 auth consistency     fintech
                                          §19-22 null-gate/alg confusion        matrix                  OR openbanking
```

### 8.2 AUTO-TRIGGER RULES (Step 2 Surface Scan)

These fire automatically based on grep detection during surface scan.
No manual decision needed — if the pattern matches, the section activates.

```
GREP PATTERN                                           TRIGGERS                     PROFILE ADDED
──────────────────────────────────────────────────────────────────────────────────────────────────
lzReceive|AxelarExecutable|ccipReceive|IMailbox         §3.5 cross-chain             BRIDGE
IEntryPoint|UserOperation|IPaymaster|validateUserOp     §6b.14 AA/ERC-4337           AA/WALLETS
beforeSwap|afterSwap|IHooks|PoolManager                 §6b.2 V4 hooks               DEFI (V4)
eyJ[A-Za-z0-9]|Bearer |jsonwebtoken|jose|PyJWT          §6b.10-12 + JWT-ARSENAL      AUTH
stripe|adyen|braintree|plaid|square.*payment             §FIN-1 + §3.3 webhooks       FINTECH
/v1/consents|/v1/payments|NextGenPSD2|openbanking        §OB-1→5                      OPENBANKING
iso20022|pacs\.|camt\.|pain\.|swift.*message             §3.2 ISO 20022               PAYMENT_INFRA
IBAN|BIC|schwifty|iban.tools                             §3.4 IBAN validation          PAYMENT_INFRA
constructEvent|verifyHeader|Webhook.*construct            §3.3 webhook verification    PAYMENT_INFRA
cbor|msgpack|protobuf|bson|avro|thrift                   ZERO-DAY D9 serialization    PARSER_LIB
xml.*parse|XMLParser|libxml|expat|SAXParser              ZERO-DAY D1 parser           PARSER_LIB
```

### 8.3 MAIN WORKFLOW

```
Pour chaque target :

0. PROFILE (2 min)         → §8.0 target classification
                             Assign one or more profiles
                             Determine EV domain (defi|fintech|openbanking|payment_infra)

1. RECON (5-30 min)        → Section 0 (DeFi: TVL, audits, stack)
                             FINTECH: + mobile app decompile, API docs, OpenAPI specs
                             OPENBANKING: + sandbox discovery (§OB-1), standard identification
                             PAYMENT_INFRA: + npm/PyPI download counts, dependent list

2. SURFACE SCAN (15 min)   → Run grep patterns per §8.1 routing table
                             ALL auto-triggers from §8.2 fire here
                             Output: activated sections list + compound profile

3. ENTRY POINTS (30 min)   → DEFI: list external/public, classify by fund-touching
                             FINTECH: list API endpoints, classify by auth level
                             OPENBANKING: map consent/payment/account endpoints
                             PAYMENT_INFRA: identify parsing entry points, webhook handlers
                             PARSER_LIB: identify decode/parse functions, native addon boundary

4. KILL GATE (30 min/finding) → KILL-GATE-TEMPLATE.md — Q1-Q12 + domain extensions:
                                FINTECH:     + Q13 (regulatory impact PSD2/PCI-DSS/SOX)
                                OPENBANKING: + Q13 + Q14 (sandbox-only vs production?)
                                PAYMENT_INFRA: + Q15 (downstream blast radius count)
                                EV gate uses domain-calibrated base_rates (see §8.4)

5. DEEP DIVE (2-4h)        → Sections per §8.1 routing table
                             Multiple profiles = union of all sections

6. FULLSTACK (if web app)  → DEFI-FULLSTACK-CHECKLIST.md (incl. F2.4, F3.4-F3.6, F4.1)
                             FINTECH: + §FIN-1→4 if not already in step 5
                             AUTH: + §30 authorization consistency matrix

7. POC (1-2h)              → DEFI: fork mainnet (vm.createSelectFork)
                             SOLANA: anchor test
                             FINTECH: authenticated API requests with curl/script
                             OPENBANKING: sandbox API calls with consent flow
                             PAYMENT_INFRA: differential fuzzer or crash PoC
                             PARSER_LIB: minimal reproducer + subprocess crash isolation

8. PREFLIGHT (15 min)      → PREFLIGHT-CHECK.md (min 22/24 to submit)
                             FINTECH/OPENBANKING: include regulatory references
                             PAYMENT_INFRA: include downstream impact count

9. WRITE-UP (30 min)       → /disclose
                             DEFI: direct to protocol team
                             FINTECH: HackerOne/Bugcrowd/Intigriti
                             OPENBANKING: bank security team or national regulator (NCA)
                             PAYMENT_INFRA: GHSA on library repo

10. OUTCOMES (5 min)       → Append to OUTCOMES.jsonl with domain-specific fields (§8.5)
```

### 8.4 EV GATE — DOMAIN-CALIBRATED BASE RATES

EV parameters differ by domain. Use the correct base_rate and payout_range
for the target's profile when computing EV in the Kill Gate.

```
DOMAIN          PLATFORM              BASE_RATE    TYPICAL PAYOUT RANGE     NOTES
─────────────────────────────────────────────────────────────────────────────────────
defi            Direct disclosure     0.40         $5K-$50K (Critical)      No intermediary
defi            C4 contest (High)     0.15         $5K-$25K                 Competitive
defi            C4 contest (Med)      0.25         $1K-$10K                 Competitive
defi            Cantina bounty        0.30         $1K-$25K                 First-come
fintech         HackerOne             0.35         $500-$25K                Less competition
fintech         Bugcrowd              0.30         $500-$15K                Less competition
fintech         Intigriti             0.25         $100-$10K                VDP = lower payout
openbanking     Direct to bank        0.45         €1K-€15K                 Regulatory pressure
openbanking     Via regulator (NCA)   0.50         N/A (compliance fix)     Compliance = can't dismiss
payment_infra   GHSA + downstream     0.60         $0 (CVE) + N×bounty     Multiplication model
payment_infra   SDK vendor bounty     0.40         $500-$25K                Stripe/Adyen/PayPal

MULTIPLIER ADJUSTMENTS (applied to base_rate):
  Regulatory violation (PSD2/PCI-DSS)  → ×1.3 (harder to dismiss)
  On-chain state proof included        → ×1.2
  Downstream blast radius >100 deps    → ×1.2 (for parser_lib findings)
  Sandbox-only (no prod confirmation)  → ×0.6
  View function / no direct fund loss  → ×0.7
  Known vuln class (first-depositor)   → ×0.5

EV THRESHOLDS (unchanged):
  STRONG GO  >$5K
  GO         $1K-$5K
  WEAK GO    $200-$1K (fast track only, <4h total)
  SKIP       <$200
```

### 8.5 OUTCOMES.jsonl — UNIFIED SCHEMA

Every submission across all three revenue streams gets logged with this schema.
The `domain` and `target_type` fields enable cross-domain EV calibration.

```jsonc
{
  // === CORE (all domains) ===
  "id": "STRIPE-H01",                    // {PROTOCOL}-{severity}{number}
  "domain": "fintech",                   // defi | fintech | openbanking | payment_infra
  "target_type": "neobank",              // see taxonomy below
  "protocol": "Stripe",
  "platform": "hackerone",               // hackerone | bugcrowd | intigriti | direct | ghsa | cantina | c4
  "finding": "Webhook HMAC timing side-channel",
  "severity_claimed": "High",
  "date_submitted": "2026-04-01",
  "date_resolved": "2026-04-15",
  "outcome": "bounty_paid",             // bounty_paid | fixed | acknowledged | rejected | duplicate | ignored
  "payout_usd": 5000,

  // === EV TRACKING ===
  "ev_pre_submit": {
    "p_acceptance": 0.35,
    "max_payout": 15000,
    "ev_usd": 5250,
    "time_hours": 6,
    "hourly_opp_cost": 75,
    "net_ev": 4800,
    "base_rate_used": 0.35,              // from §8.4 table
    "multipliers_applied": ["none"]       // regulatory, on-chain, blast_radius, etc.
  },

  // === DOMAIN-SPECIFIC FIELDS ===

  // fintech only:
  "fintech_category": "payment_logic",   // payment_logic | kyc_bypass | card_exploit | notification | auth
  "regulatory_reference": "",            // "PSD2 Art. 97" | "PCI-DSS Req. 6.5" | ""

  // openbanking only:
  "ob_pattern_id": "",                   // OB-001 through OB-010
  "ob_standard": "",                     // berlin_group | uk_ob | stet | polish_api
  "ob_sandbox_vs_prod": "",              // sandbox | production | both

  // payment_infra only:
  "blast_radius_weekly_downloads": 0,    // npm/PyPI weekly downloads
  "blast_radius_dependents": 0,          // direct dependent count
  "downstream_bounties_filed": 0,        // bounties filed on downstream consumers
  "downstream_bounties_paid_usd": 0,     // total from downstream
  "cve_id": "",                          // CVE-2026-XXXXX if assigned

  // defi only (existing fields):
  "poc_type": "fork",                    // fork | mock | anchor | unit | script
  "impact_category": "",                 // direct_theft | data_leak | compliance_violation | fraud_enablement

  // === REJECTION ANALYSIS (if rejected) ===
  "rejection": {
    "vector": "",                        // poc_quality | design_intent | scope | duplicate | known_issue
    "triage_quote": "",
    "which_step_should_have_caught_it": "",
    "preventable_in_hindsight": false
  },

  // === META ===
  "tags": [],
  "lesson": ""
}
```

**Target type taxonomy:**

```
defi:           vault | amm | lending | staking | bridge | zk | governance | hook
fintech:        neobank | payment_processor | card_issuer | kyc_provider | trading_platform
openbanking:    bank_api | aggregator | tpp
payment_infra:  payment_sdk | message_parser | iban_validator | webhook_lib | auth_lib
```

### 8.6 AUTO-TRIGGER SUMMARY (quick reference)

```
SIGNAL DETECTED IN STEP 2          → SECTIONS ACTIVATED          TIME ADDED
────────────────────────────────────────────────────────────────────────────
Cross-chain imports                → §3.5 mandatory               +60 min
AA/ERC-4337 imports                → §6b.14 + ZERO-DAY D3         +45 min
V4 hook interface                  → §6b.2 mandatory              +30 min
JWT/Bearer token                   → §6b.10-12 + JWT-ARSENAL      +30 min
Payment SDK imports                → §FIN-1 + §3.3 webhooks       +90 min
Open Banking endpoints             → §OB-1→5 full suite           +4h (separate workflow)
ISO 20022 / SWIFT messages         → §3.2 XML fuzzing             +2h
IBAN/BIC handling                  → §3.4 differential            +30 min
Webhook handler                    → §3.3 webhook attacks         +30 min
Serialization library              → ZERO-DAY D9                  +2h
XML parser                         → ZERO-DAY D1                  +2h
MEV-relevant (+ no exclusion)      → §5.3 structural analysis     +60 min
Supply chain (any web target)      → §6b.13                       +30 min
```

---

## 8.7 ATTACK CHAIN COMPOSITION (after all testing phases)

**Trigger:** 2+ findings exist on the same target after all testing phases (§1-§8) complete.

Run `ATTACK-CHAIN-PLAYBOOK.md` (in gravedigger skill) to compose individual findings into multi-step attack chains before Kill Gate. Finding A enabling finding B produces combined severity greater than the sum of parts.

- [ ] **All finding pairs** evaluated for causal dependency (A enables B)
- [ ] **Attack graphs** built (entry → pivot → impact) with combined severity
- [ ] **Chain-specific PoCs** demonstrate full multi-step path
- [ ] **Dismissal counters** pre-built for "these are separate issues" responses

**Ref:** `~/.claude/skills/gravedigger/ATTACK-CHAIN-PLAYBOOK.md`

---

## 9. REFERENCES EXPLOITS RECENTS (2025-2026)

| Date | Protocole | Montant | Vecteur | Categorie |
|------|-----------|---------|---------|-----------|
| Feb 2025 | **Bybit** | **$1.4B** | Safe{Wallet} UI supply chain, delegatecall impl rewrite | **Supply Chain** |
| May 2025 | **Cetus** | **$223M** | checked_shlw overflow mask error (Sui) | Overflow |
| Nov 2025 | **Balancer V2** | **$128M** | Rounding asymmetry + batchSwap (7 chains) | Logic + Math |
| Jul 2025 | GMX V1 | $42M | executeDecreaseOrder reentrancy + GLP inflation | Reentrancy |
| Jan 2026 | Matcha/SwapNet | $13.5M | Arbitrary call drains open allowances | Access Control |
| Mar 2025 | Hyperliquid JELLY | $12.6M | Thin-liquidity perp + spot oracle pump 429% | Oracle + Design |
| May 2025 | Cork Protocol | $11M | V4 hook beforeSwap() missing access control | **V4 Hooks** |
| Feb 2026 | YieldBlox | $10.2M | VWAP oracle temporal gap exploitation (Stellar) | Oracle |
| Jun 2025 | Resupply | $9.5M | Donation attack on fresh vault, flash loan + 1 wei | **Inflation** |
| Sep 2025 | BunniDEX | $8.4M | V4 LDF rounding in rebalancing | **V4 Hooks** |
| Apr 2025 | KiloEx | $7.5M | Permissionless TrustedForwarder.execute() | Access Control |
| Mar 2025 | 1inch Fusion | $5M | Buffer overflow modifies interactionLength | Overflow |
| Apr 2025 | zkSync | $5M | Admin key sweepUnclaimed() on airdrop | Key Compromise |
| Jan 2026 | MakinaFi | $4.1M | LP inflation + spot price oracle | Oracle + Flash |
| Feb 2026 | IoTeX Bridge | $4.3M | Validator key compromise + malicious upgrade | Bridge |
| Feb 2026 | CrossCurve | $3M | Axelar expressExecute message spoofing | **Cross-chain** |
| Feb 2026 | FOOMCASH | $2.26M | Groth16 delta2 == gamma2 proof forgery | **ZK Config** |
| Nov 2025 | Moonwell | $1M | Chainlink wrstETH at $5.8M erroneous price | Oracle |
| Nov 2025 | Aerodrome | $700K | DNS hijack via NameSilo registrar compromise | Infrastructure |
| May 2025 | Curve Finance | $3.5M | DNS hijack at registrar level | Infrastructure |
| 2025 | Yearn | $9M | Legacy yETH governance mint, unsafe_div accumulator | Governance |
| 2025 | SIR Protocol | - | Transient storage slot reuse → pool impersonation | **EIP-1153** |
| 2025 | POT Token | - | EIP-7702 delegation bypasses tx.origin guard | **EIP-7702** |
| 2022 | Beanstalk | $182M | Flash-borrowed governance votes | Flash + Gov |
| 2022 | Ronin | $620M | Validator key compromise | Bridge |
| Mar 2026 | **pac4j-jwt** | **CVSS 10** | PlainJWT inside JWE bypasses signature verification (null-gate) | **Auth Bypass** |
| 2022 | Java ECDSA | **CVSS 7.5** | Psychic Signatures — blank ECDSA signature accepted (CVE-2022-21449) | **Auth Bypass** |
| 2016 | The DAO | $60M | Recursive call reentrancy | Reentrancy |
