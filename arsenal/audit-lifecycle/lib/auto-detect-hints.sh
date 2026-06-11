#!/usr/bin/env bash
# Auto-detect target hints from scope URL + cloned repo in workspace.
# Emits a single space-separated line of deduped keywords on stdout.
# Never fails — always exits 0, empty stdout if nothing found.
#
# Usage: auto-detect-hints.sh <workspace_path> [scope_url]
#
# Detection sources (cumulative, non-exclusive):
#   1. Scope URL   → platform from host (cantina/c4/sherlock/hackenproof/h1/bugcrowd/intigriti)
#                  → fetched HTML body scanned for tech-stack keywords
#   2. Workspace   → repo clones (.git), manifests (Cargo.*, package.json, go.*,
#                    requirements.txt, foundry.toml, Anchor.toml, hardhat.config.*),
#                    docs (README/ARCHITECTURE/DOCS), source file extensions,
#                    directory name heuristics (relayer/, bridge/, oracle/, ...)
#
# Output contract: space-separated list of hints, newline-terminated. Compatible
# with TARGET_HINTS env var. Empty output = nothing detected (callers should
# fall back to manual hints or leave unset).

set -uo pipefail

WORKSPACE="${1:-}"
SCOPE_URL="${2:-}"

# All collected hints go here, one per line. Deduped at the end.
HINTS_FILE=$(mktemp)
trap 'rm -f "$HINTS_FILE"' EXIT

# ==============================================================================
# scan_text_for_hints
#   Reads stdin (lowercased), greps for known keyword patterns, emits one
#   hint per line to HINTS_FILE. Safe to call multiple times with different
#   inputs — the merge + dedup happens once at the end.
# ==============================================================================

scan_text_for_hints() {
  local body
  body=$(cat)
  [ -z "$body" ] && return 0

  # --- Platform / context ---
  echo "$body" | grep -qE 'cantina\.xyz|cantina\.com' && echo "cantina" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'code4rena\.com|c4\.code4rena' && { echo "code4rena" >> "$HINTS_FILE"; echo "c4" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'sherlock\.xyz|audits\.sherlock' && echo "sherlock" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'hackenproof\.com' && echo "hackenproof" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'hackerone\.com' && { echo "hackerone" >> "$HINTS_FILE"; echo "h1" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'bounty|bug[[:space:]]*bounty' && echo "bounty" >> "$HINTS_FILE"

  # --- SC language + tooling ---
  echo "$body" | grep -qE 'pragma[[:space:]]+solidity|\.sol\b|\bsolidity\b|\bsolc\b' && { echo "solidity" >> "$HINTS_FILE"; echo "evm" >> "$HINTS_FILE"; echo "smart.contract" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'anchor[-_]?lang|solana[-_]?program|@solana/web3' && { echo "solana" >> "$HINTS_FILE"; echo "anchor" >> "$HINTS_FILE"; echo "smart.contract" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bmove[[:space:]]+(language|module|vm)|sui[[:space:]]*move|aptos[[:space:]]*move' && echo "move" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'cairo[[:space:]]*(lang|program|compiler)|starknet' && echo "cairo" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'aztec/noir|nargo|\.nr\b' && { echo "noir" >> "$HINTS_FILE"; echo "zk-circuit" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bcircom\b|snarkjs' && { echo "circom" >> "$HINTS_FILE"; echo "zk-circuit" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bhalo2\b|arkworks|plonky2|plonky3|risc0|risc[-_]zero|\bsp1\b' && echo "zk-circuit" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'foundry|forge[[:space:]]+(test|build|script)' && echo "foundry" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'hardhat' && echo "hardhat" >> "$HINTS_FILE"
  echo "$body" | grep -qE '\bvyper\b' && echo "vyper" >> "$HINTS_FILE"

  # --- Node / L1 / L2 / consensus ---
  echo "$body" | grep -qE 'consensus|validator[[:space:]]*set|p2p[[:space:]]*(layer|network)|libp2p|gossipsub|full[-_]?node' && { echo "blockchain.node" >> "$HINTS_FILE"; echo "p2p" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'sequencer|batch[[:space:]]*poster|rollup|op[-_]?stack|zksync|arbitrum|optimism|scroll|linea' && echo "sequencer" >> "$HINTS_FILE"

  # --- Web / API / Mobile ---
  echo "$body" | grep -qE 'rest[[:space:]]*api|graphql|openapi|swagger|\btrpc\b' && { echo "web" >> "$HINTS_FILE"; echo "api" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'next\.js|nextjs|/_next/|__next_data__' && { echo "web" >> "$HINTS_FILE"; echo "nextjs" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bdashboard\b' && { echo "dashboard" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; echo "frontend" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'web[[:space:]]*app|\bwebapp\b' && { echo "webapp" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; echo "frontend" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bdapp\b|decentralized[[:space:]]*app' && { echo "dapp" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; echo "frontend" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\badmin[[:space:]]*(panel|portal|interface|dashboard)|\badmin\.' && { echo "admin" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bfrontend\b|\breact\b|vue\.js|\bsvelte\b' && { echo "frontend" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; }
  # Subdomain heuristics from URL-like strings in docs/manifests (api.foo.com, app.foo.io)
  echo "$body" | grep -qE '\bapi\.[a-z0-9-]+\.(com|io|xyz|finance|app|fi|co|net|org)\b' && { echo "api" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bapp\.[a-z0-9-]+\.(com|io|xyz|finance|app|fi|co|net|org)\b' && { echo "dashboard" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bdashboard\.[a-z0-9-]+\.(com|io|xyz|finance|app|fi|co|net|org)\b' && { echo "dashboard" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\badmin\.[a-z0-9-]+\.(com|io|xyz|finance|app|fi|co|net|org)\b' && { echo "admin" >> "$HINTS_FILE"; echo "web" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'android|\.apk\b|\bios[[:space:]]*(app|build)|react[[:space:]]*native|flutter' && echo "mobile" >> "$HINTS_FILE"

  # --- Auth / JWT / OAuth ---
  echo "$body" | grep -qE '\bjwt\b|json[[:space:]]*web[[:space:]]*token|\bjose\b|\bjwks\b|authlib|pyjwt|jsonwebtoken' && { echo "jwt" >> "$HINTS_FILE"; echo "jwt.lib" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'oauth[[:space:]]*2|\boidc\b|openid[[:space:]]*connect|\bsiwe\b|sign[-_]?in[-_]?with[-_]?ethereum' && { echo "web" >> "$HINTS_FILE"; echo "oauth" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'privy|dynamic\.xyz|web3auth|magic\.link|\bauth0\b|\bclerk\b|firebase[[:space:]]*auth' && { echo "web" >> "$HINTS_FILE"; echo "auth" >> "$HINTS_FILE"; }

  # --- Crypto libraries (N-way amplifier signal) ---
  echo "$body" | grep -qE 'ed25519[-_]consensus|ed25519[-_]dalek|\bed25519\b' && { echo "ed25519" >> "$HINTS_FILE"; echo "crypto.lib" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'libsecp256k1|\bsecp256k1\b|\bk256\b|@noble/secp256k1' && { echo "secp256k1" >> "$HINTS_FILE"; echo "crypto.lib" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '@noble/curves|@noble/hashes' && { echo "noble" >> "$HINTS_FILE"; echo "crypto.lib" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'frost[-_]core|frost[-_]ed25519|frost[-_]secp256k1|frost[-_]dalek|\bfrost\b' && { echo "frost" >> "$HINTS_FILE"; echo "threshold" >> "$HINTS_FILE"; echo "crypto.lib" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bdkg\b|distributed[[:space:]]*key[[:space:]]*generation|gennaro' && echo "dkg" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'tss[-_]lib|multi[-_]party[-_]ecdsa|cggmp21|schnorr[-_]fun' && { echo "mpc" >> "$HINTS_FILE"; echo "threshold" >> "$HINTS_FILE"; echo "crypto.lib" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bmpc\b|threshold[[:space:]]*signature|multi[-_]party|shamir[[:space:]]*secret' && { echo "mpc" >> "$HINTS_FILE"; echo "threshold" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bbls\b|bls12[-_]381|\bblst\b|@noble/bls12' && { echo "bls" >> "$HINTS_FILE"; echo "crypto.lib" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'libsodium|tweetnacl|\bnacl\b' && echo "crypto.lib" >> "$HINTS_FILE"

  # --- Infra-adjacent ---
  echo "$body" | grep -qE '\brelayer\b|meta[-_]?tx|gasless|biconomy|gelato[[:space:]]*relay|openzeppelin[[:space:]]*defender|erc[-_]?2771' && echo "relayer" >> "$HINTS_FILE"
  echo "$body" | grep -qE '\bbridge\b|cross[-_]?chain|inter[-_]?chain' && echo "bridge" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'layerzero|lz[[:space:]]*endpoint|\blzreceive\b' && { echo "layerzero" >> "$HINTS_FILE"; echo "bridge" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\baxelar\b|interchain[-_]?token' && { echo "axelar" >> "$HINTS_FILE"; echo "bridge" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'wormhole|guardian[[:space:]]*set|\bvaa\b' && { echo "wormhole" >> "$HINTS_FILE"; echo "bridge" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\bccip\b' && { echo "ccip" >> "$HINTS_FILE"; echo "bridge" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'hyperlane' && { echo "hyperlane" >> "$HINTS_FILE"; echo "bridge" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'connext|nxtp[[:space:]]*router' && { echo "connext" >> "$HINTS_FILE"; echo "bridge" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE '\boracle\b|price[[:space:]]*feed|aggregator|chainlink|pyth[[:space:]]*network|\bapi3\b|redstone' && echo "oracle" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'chainlink' && echo "chainlink" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'pyth[[:space:]]*(network|oracle)' && echo "pyth" >> "$HINTS_FILE"
  echo "$body" | grep -qE '\bapi3\b' && echo "api3" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'redstone' && echo "redstone" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'the[[:space:]]*graph|thegraph\.com|subgraph|goldsky|envio|\bponder\b' && { echo "indexer" >> "$HINTS_FILE"; echo "subgraph" >> "$HINTS_FILE"; }
  echo "$body" | grep -qE 'thegraph' && echo "thegraph" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'goldsky' && echo "goldsky" >> "$HINTS_FILE"
  echo "$body" | grep -qE '\bkeeper\b|liquidation[[:space:]]*bot|chainlink[[:space:]]*automation|\bgelato\b' && echo "keeper" >> "$HINTS_FILE"
  echo "$body" | grep -qE '\bgelato\b' && echo "gelato" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'chainlink[[:space:]]*automation' && echo "automation" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'fireblocks|\bfordefi\b|safe\{core\}|safe[[:space:]]*global|safe[[:space:]]*wallet|gnosis[[:space:]]*safe' && { echo "mpc" >> "$HINTS_FILE"; echo "fireblocks" >> "$HINTS_FILE"; }

  # --- Specialty ecosystems ---
  echo "$body" | grep -qE 'eigenlayer|symbiotic|karak|\brestaking\b|restaker' && echo "restaking" >> "$HINTS_FILE"
  echo "$body" | grep -qE '\blrt\b|liquid[[:space:]]*restaking|ether\.fi|\bpuffer\b|\brenzo\b|\bkelp\b' && echo "lrt" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'erc[-_]?4337|\bentrypoint\b|\buserop\b|\bbundler\b|\bpaymaster\b' && echo "aa-4337" >> "$HINTS_FILE"
  echo "$body" | grep -qE 'celestia|eigenda|avail[[:space:]]*da|blobstream|data[[:space:]]*availability' && echo "da-layer" >> "$HINTS_FILE"

  # --- DeFi / fintech ---
  echo "$body" | grep -qE '\bdefi\b|\btvl\b|total[[:space:]]*value[[:space:]]*locked' && echo "defi" >> "$HINTS_FILE"
  echo "$body" | grep -qE '\bfintech\b|open[[:space:]]*banking|\bpsd2\b|pci[-_]?dss|\bremittance\b' && echo "fintech" >> "$HINTS_FILE"
}

# ==============================================================================
# detect_from_url
# ==============================================================================

detect_from_url() {
  local url="$1"
  [ -z "$url" ] && return 0

  # Platform from URL host (works even if fetch fails)
  case "$url" in
    *cantina.xyz*)      echo "cantina" >> "$HINTS_FILE" ;;
    *code4rena.com*)    echo "code4rena" >> "$HINTS_FILE"; echo "c4" >> "$HINTS_FILE" ;;
    *sherlock.xyz*|*audits.sherlock.xyz*) echo "sherlock" >> "$HINTS_FILE" ;;
    *hackenproof.com*)  echo "hackenproof" >> "$HINTS_FILE" ;;
    *hackerone.com*)    echo "hackerone" >> "$HINTS_FILE"; echo "h1" >> "$HINTS_FILE" ;;
    *immunefi.com*)     echo "immunefi" >> "$HINTS_FILE" ;;
    *bugcrowd.com*)     echo "bugcrowd" >> "$HINTS_FILE" ;;
    *intigriti.com*)    echo "intigriti" >> "$HINTS_FILE" ;;
  esac

  # Fetch page body and scan
  local html
  html=$(curl -sL --max-time 10 \
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/120.0" \
    "$url" 2>/dev/null) || return 0
  [ -z "$html" ] && return 0

  echo "$html" | tr '[:upper:]' '[:lower:]' | scan_text_for_hints
}

# ==============================================================================
# detect_from_workspace
# ==============================================================================

detect_from_workspace() {
  local ws="$1"
  [ -z "$ws" ] || [ ! -d "$ws" ] && return 0

  # Build candidate source roots: workspace + common clone subdirs + any .git parent
  local candidates=("$ws" "$ws/src" "$ws/contracts" "$ws/node" "$ws/protocol" "$ws/packages")
  while IFS= read -r git_dir; do
    local parent
    parent=$(dirname "$git_dir")
    candidates+=("$parent")
  done < <(find "$ws" -maxdepth 3 -type d -name ".git" 2>/dev/null | head -10)

  # Dedup candidates
  local seen_file
  seen_file=$(mktemp)
  local src_roots=()
  for c in "${candidates[@]}"; do
    [ -d "$c" ] || continue
    local real
    real=$(readlink -f "$c" 2>/dev/null) || real="$c"
    if ! grep -qxF "$real" "$seen_file" 2>/dev/null; then
      echo "$real" >> "$seen_file"
      src_roots+=("$c")
    fi
  done
  rm -f "$seen_file"

  # --- 1. Extension-based language classification ---
  for root in "${src_roots[@]}"; do
    find "$root" -maxdepth 4 -type f \( \
      -name "*.sol" -o -name "*.move" -o -name "*.cairo" -o -name "*.circom" \
      -o -name "*.nr" -o -name "*.vy" \
      \) 2>/dev/null | head -20 | while read -r f; do
      case "$f" in
        *.sol)    printf "solidity\nevm\nsmart.contract\n" >> "$HINTS_FILE" ;;
        *.move)   echo "move" >> "$HINTS_FILE" ;;
        *.cairo)  echo "cairo" >> "$HINTS_FILE" ;;
        *.circom) printf "circom\nzk-circuit\n" >> "$HINTS_FILE" ;;
        *.nr)     printf "noir\nzk-circuit\n" >> "$HINTS_FILE" ;;
        *.vy)     echo "vyper" >> "$HINTS_FILE" ;;
      esac
    done
  done

  # --- 2. Build-tool config files (strong signal) ---
  for root in "${src_roots[@]}"; do
    [ -f "$root/foundry.toml" ] && printf "foundry\nevm\nsolidity\nsmart.contract\n" >> "$HINTS_FILE"
    [ -f "$root/Anchor.toml" ] && printf "solana\nanchor\nsmart.contract\n" >> "$HINTS_FILE"
    [ -f "$root/hardhat.config.ts" ] || [ -f "$root/hardhat.config.js" ] && printf "hardhat\nevm\nsolidity\nsmart.contract\n" >> "$HINTS_FILE"
    [ -f "$root/Move.toml" ] && printf "move\nsmart.contract\n" >> "$HINTS_FILE"

    # Also check one level down (common for monorepos)
    find "$root" -maxdepth 3 -name "foundry.toml" 2>/dev/null | head -1 | grep -q . && printf "foundry\nevm\nsolidity\nsmart.contract\n" >> "$HINTS_FILE"
    find "$root" -maxdepth 3 -name "Anchor.toml" 2>/dev/null | head -1 | grep -q . && printf "solana\nanchor\nsmart.contract\n" >> "$HINTS_FILE"
  done

  # --- 3. Manifest + dep scan (the richest signal for crypto-lib playbook) ---
  for root in "${src_roots[@]}"; do
    # Collect manifest contents (capped) into one blob, lowercase it, scan
    {
      find "$root" -maxdepth 4 \( \
        -name "Cargo.toml" -o -name "Cargo.lock" \
        -o -name "package.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" \
        -o -name "go.mod" -o -name "go.sum" \
        -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "Pipfile" \
      \) 2>/dev/null | head -20 | while read -r f; do
        head -c 200000 "$f" 2>/dev/null  # cap per file, bound runtime
      done

      # Docs scan — README, ARCHITECTURE, any .md in top levels
      find "$root" -maxdepth 3 \( -iname "README*" -o -iname "ARCHITECTURE*" -o -iname "DOCS*" \) -type f 2>/dev/null | head -10 | while read -r f; do
        head -c 50000 "$f" 2>/dev/null
      done
    } | tr '[:upper:]' '[:lower:]' | scan_text_for_hints
  done

  # --- 4. Directory name heuristics ---
  for root in "${src_roots[@]}"; do
    find "$root" -maxdepth 3 -type d 2>/dev/null | while read -r d; do
      local name
      name=$(basename "$d" | tr '[:upper:]' '[:lower:]')
      case "$name" in
        relayer|relayers)                        echo "relayer" >> "$HINTS_FILE" ;;
        bridge|bridges)                          echo "bridge" >> "$HINTS_FILE" ;;
        oracle|oracles)                          echo "oracle" >> "$HINTS_FILE" ;;
        sequencer)                               echo "sequencer" >> "$HINTS_FILE" ;;
        indexer|indexers)                        echo "indexer" >> "$HINTS_FILE" ;;
        subgraph|subgraphs)                      printf "indexer\nsubgraph\n" >> "$HINTS_FILE" ;;
        keeper|keepers|bot|bots)                 echo "keeper" >> "$HINTS_FILE" ;;
        contracts|contract)                      echo "smart.contract" >> "$HINTS_FILE" ;;
        circuits|circuit)                        echo "zk-circuit" >> "$HINTS_FILE" ;;
        dashboard)                               printf "dashboard\nweb\nfrontend\n" >> "$HINTS_FILE" ;;
        webapp)                                  printf "webapp\nweb\nfrontend\n" >> "$HINTS_FILE" ;;
        dapp)                                    printf "dapp\nweb\nfrontend\n" >> "$HINTS_FILE" ;;
        admin)                                   printf "admin\nweb\n" >> "$HINTS_FILE" ;;
        frontend|app|ui|web)                     printf "web\nfrontend\n" >> "$HINTS_FILE" ;;
        api|backend|server)                      printf "web\napi\n" >> "$HINTS_FILE" ;;
        mobile|android|ios)                      echo "mobile" >> "$HINTS_FILE" ;;
        crypto|cryptography)                     echo "crypto.lib" >> "$HINTS_FILE" ;;
      esac
    done
  done
}

# ==============================================================================
# Main
# ==============================================================================

detect_from_url "$SCOPE_URL"
detect_from_workspace "$WORKSPACE"

# Emit deduped, sorted hints on a single space-separated line
if [ -s "$HINTS_FILE" ]; then
  sort -u "$HINTS_FILE" | tr '\n' ' '
  echo
fi
