#!/usr/bin/env bash
# NUKE — local static-analysis barrage + fusion for Solidity/EVM bug-bounty targets.
# Deterministic mechanical layer. No network by default (local Decurity rules only).
# It PRODUCES a triage surface; it does NOT decide findings and never discloses.
#
# Usage:
#   nuke.sh <target-dir|file> [--out DIR] [--quick] [--online-rules] [--no-build]
#   nuke.sh env         # print the tool matrix NUKE can use
#   nuke.sh selftest    # run the barrage on the bundled vulnerable fixture and assert it fires
set -uo pipefail

# resolve through symlinks (the `nuke` launcher is a symlink into ~/.local/bin)
_SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$_SELF")" && pwd)"
NUKE_HOME="$(dirname "$SCRIPT_DIR")"
DECURITY="$NUKE_HOME/vendor/semgrep-smart-contracts"
MEDUSA_BIN="$NUKE_HOME/vendor/bin/medusa"

c_red=$'\e[31m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_blu=$'\e[34m'; c_dim=$'\e[2m'; c_rst=$'\e[0m'
say(){ printf '%s\n' "$*"; }
hdr(){ printf '\n%s== %s ==%s\n' "$c_blu" "$*" "$c_rst"; }

have(){ command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------------ env matrix
print_env(){
  hdr "NUKE tool matrix"
  say "${c_dim}— EVM (slither/aderyn/semgrep barrage) —${c_rst}"
  for t in slither aderyn semgrep forge solc solc-select jq python3; do
    if have "$t"; then printf "  %s%-14s%s %s\n" "$c_grn" "$t" "$c_rst" "$($t --version 2>&1 | head -1)"
    else printf "  %s%-14s%s missing\n" "$c_red" "$t" "$c_rst"; fi
  done
  if [ -x "$MEDUSA_BIN" ] || have medusa; then printf "  %s%-14s%s %s\n" "$c_grn" "medusa" "$c_rst" "(fuzzer, optional)"
  else printf "  %s%-14s%s missing (fuzzer, optional)\n" "$c_yel" "medusa" "$c_rst"; fi
  if [ -d "$DECURITY" ]; then printf "  %s%-14s%s %s rule files\n" "$c_grn" "decurity" "$c_rst" \
      "$(find "$DECURITY" \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | wc -l | tr -d ' ')"
  else printf "  %s%-14s%s missing\n" "$c_red" "decurity" "$c_rst"; fi

  say "${c_dim}— Rust / CosmWasm + Solana (cargo-* suite, shared) —${c_rst}"
  for t in cargo cargo-audit cargo-deny cargo-geiger clippy-sarif cargo-dylint; do
    if have "$t"; then printf "  %s%-14s%s ok\n" "$c_grn" "$t" "$c_rst"
    else printf "  %s%-14s%s missing\n" "$c_yel" "$t" "$c_rst"; fi
  done
  if have opengrep; then printf "  %s%-14s%s ok (rule engine, rules per-eco)\n" "$c_grn" "opengrep" "$c_rst"
  elif have semgrep; then printf "  %s%-14s%s semgrep present (opengrep absent — préférer opengrep: taint intra-fichier libre)\n" "$c_yel" "opengrep" "$c_rst"
  else printf "  %s%-14s%s missing\n" "$c_yel" "opengrep" "$c_rst"; fi
  printf "  %s%-14s%s %s\n" "$c_dim" "sec3/radar" "$c_rst" "opt-in Docker (NUKE_SEC3=1 ; réseau)"

  say "${c_dim}— Go / Cosmos-SDK barrage —${c_rst}"
  for t in golangci-lint govulncheck gitleaks nilaway osv-scanner codeql go; do
    if have "$t"; then printf "  %s%-14s%s ok\n" "$c_grn" "$t" "$c_rst"
    else printf "  %s%-14s%s missing\n" "$c_yel" "$t" "$c_rst"; fi
  done
  [ -d "$NUKE_HOME/vendor/semgrep-rules/go" ] && printf "  %s%-14s%s ok (ToB go rules)\n" "$c_grn" "tob-rules" "$c_rst" \
    || printf "  %s%-14s%s missing (setup.sh clones trailofbits/semgrep-rules)\n" "$c_yel" "tob-rules" "$c_rst"

  say "${c_dim}— agent-hunt layer (Pashov) —${c_rst}"
  for s in solidity-auditor x-ray fizz; do
    [ -e "$HOME/.claude/skills/$s" ] && printf "  %s%-14s%s /%s\n" "$c_grn" "skill" "$c_rst" "$s"
  done
  say "${c_dim}non-EVM negative-space maps: $(python3 -c "import json;d=json.load(open('$NUKE_HOME/references/negative-space.json'));print(', '.join('%s(%d)'%(k,len(v['silent_classes'])) for k,v in d.items() if isinstance(v,dict)))" 2>/dev/null)${c_rst}"
}

# ------------------------------------------------------------------ solc pinning (raw mode)
pin_solc(){
  local root="$1"
  have solc-select || return 0
  local ver
  ver="$(grep -rhoE 'pragma solidity[^;]*' "$root" 2>/dev/null \
        | grep -oE '0\.[0-9]+\.[0-9]+' | sort -V | tail -1)"
  [ -z "$ver" ] && ver="$(grep -rhoE 'pragma solidity[^;]*' "$root" 2>/dev/null \
        | grep -oE '0\.[0-9]+' | sort -V | tail -1).0"
  [ -z "$ver" ] || [ "$ver" = ".0" ] && return 0
  say "${c_dim}[solc] pinning $ver${c_rst}"
  solc-select install "$ver" >/dev/null 2>&1
  solc-select use "$ver" >/dev/null 2>&1
}

# ------------------------------------------------------------------ ecosystem detection
# Echoes ONE of: evm | cosmwasm | solana | rust-generic | cosmos-go | go-generic | move | cairo | unknown.
# EVM wins first (preserves existing behavior). Non-EVM = new barrages.
detect_ecosystem(){
  local root="$1"
  [ -f "$root/foundry.toml" ] && { echo evm; return; }
  ls "$root"/hardhat.config.* >/dev/null 2>&1 && { echo evm; return; }
  [ -f "$root/Move.toml" ] && { echo move; return; }
  [ -f "$root/Scarb.toml" ] && { echo cairo; return; }
  if [ -f "$root/go.mod" ]; then
    grep -rqiE 'cosmossdk\.io|github\.com/cosmos/cosmos-sdk|github\.com/cometbft|tendermint' "$root" --include='go.mod' 2>/dev/null \
      && { echo cosmos-go; return; }
    echo go-generic; return
  fi
  if find "$root" -maxdepth 2 -name Cargo.toml 2>/dev/null | grep -q .; then
    grep -rqiE 'anchor-lang|solana-program|solana-sdk' "$root" --include=Cargo.toml 2>/dev/null && { echo solana; return; }
    grep -rqiE 'cosmwasm-std|cosmwasm-schema|cw-storage-plus|sylvia' "$root" --include=Cargo.toml 2>/dev/null && { echo cosmwasm; return; }
    echo rust-generic; return
  fi
  find "$root" -maxdepth 3 -name '*.sol' 2>/dev/null | grep -q . && { echo evm; return; }
  echo unknown
}

# ------------------------------------------------------------------ barrage bookkeeping (shared)
# Non-EVM barrages populate these globals and _await() joins on them (bash can't pass arrays cleanly).
_P=(); _N=(); _O=()
_track(){ _P+=("$1"); _N+=("$2"); _O+=("$3"); }   # pid  name  expected-output-file
_await(){
  local OUT="$1" i=0 pid nm of rc
  say "${c_dim}running ${#_P[@]} scanners in parallel...${c_rst}"
  for pid in "${_P[@]}"; do
    wait "$pid"; nm="${_N[$i]}"; of="${_O[$i]}"; rc="$(cat "$OUT/.$nm.rc" 2>/dev/null)"
    if [ -s "$OUT/$of" ]; then say "  ${c_grn}✓ $nm${c_rst} (rc=$rc)"
    else say "  ${c_yel}⚠ $nm : sortie vide (rc=$rc) — voir $nm.log${c_rst}"; fi
    i=$((i+1))
  done
}

# ------------------------------------------------------------------ fusion + report (shared EVM/non-EVM)
fuse_and_report(){
  local OUT="$1" TARGET="$2" ECO="${3:-evm}"
  hdr "fusion"
  local aggr=(--workdir "$OUT" --target "$TARGET" --ecosystem "$ECO")
  [ -n "${NUKE_DIFF_MAP:-}" ] && aggr+=(--diff-map "$NUKE_DIFF_MAP" --diff-window "${NUKE_DIFF_WINDOW:-0}")
  python3 "$SCRIPT_DIR/aggregate.py" "${aggr[@]}"
  python3 "$SCRIPT_DIR/digest.py" --signals "$OUT/signals.json" 2>/dev/null

  hdr "NUKE done"
  say "  signals : ${c_grn}$OUT/signals.md${c_rst}"
  say "  digest  : $OUT/nuke-digest.md   (pré-remplissage /intake)"
  say "  triage  : $OUT/TRIAGE.md   (promotion = artefact exécuté)"
  say "  raw     : $OUT/  (*.json · *.sarif · *.log)"
  say ""
  say "${c_yel}Next (operator-gated — NUKE ne lance rien tout seul):${c_rst}"
  if [ "$ECO" = evm ]; then
    say "  1. Lis signals.md : d'abord l'ESPACE NÉGATIF (classes muettes), puis les corroborés."
  else
    say "  1. Lis signals.md : la ${c_grn}worklist de VOL${c_rst} (espace négatif) EST le livrable — les scanners non-EVM"
    say "     ne couvrent que le substrat mécanique (deps/panics/overflow/secrets). Un barrage vert ne dit RIEN sur l'authz/reentrancy/bridge."
  fi
  say "  2. Route la veine → /intake lit nuke-digest.md et pré-remplit le dossier (ou directement /extract /power /darkside …)."
  say "  3. Hunt agent LLM optionnel → /solidity-auditor  ou  /x-ray  puis  /fizz  (EVM) · sinon /darkside /power /extract à la main."
  say "  4. Chaque candidat : PoC/preuve EXÉCUTÉ avant promotion (voir references/verify.md)."
  printf '%s\n' "$OUT"
}

# ------------------------------------------------------------------ non-EVM barrage: Rust (cosmwasm / solana / rust-generic)
run_barrage_rust(){
  local ROOT="$1" TARGET="$2" OUT="$3" ECO="$4" TO="$5" ONLINE="${6:-0}" QUICK="${7:-0}"
  say "framework: ${c_grn}cargo${c_rst} (rust)"
  _P=(); _N=(); _O=()

  # CosmWasm/Solana repos pin a rust-toolchain.toml (often a MINIMAL profile lacking cargo/clippy, or a
  # channel not installed) -> the cargo-* tools fail trying to provision it (real, common trap). cargo-audit
  # /deny read only Cargo.lock (toolchain-agnostic) and clippy/geiger just need A working toolchain, so we run
  # them under a known-good one (rustup default, or $NUKE_RUST_TOOLCHAIN) instead of the project pin.
  local TC="${NUKE_RUST_TOOLCHAIN:-}"
  [ -z "$TC" ] && TC="$(rustup default 2>/dev/null | awk '{print $1}')"
  [ -z "$TC" ] && TC="stable"
  if [ -f "$ROOT/rust-toolchain" ] || [ -f "$ROOT/rust-toolchain.toml" ]; then
    say "  ${c_dim}toolchain: le repo épingle un rust-toolchain — barrage forcé sous '${TC}' (NUKE_RUST_TOOLCHAIN pour changer)${c_rst}"
  fi

  # supply-chain: cargo-audit (RustSec incl CosmWasm CWA advisories). OPSEC: --no-fetch by default (uses a
  # pre-cloned advisory-db, zero network); --online-rules allows the one-time fetch.
  if have cargo && cargo audit --version >/dev/null 2>&1; then
    local ca_fetch="--no-fetch"; [ "$ONLINE" = 1 ] && ca_fetch=""
    ( cd "$ROOT"; timeout "$TO" env RUSTUP_TOOLCHAIN="$TC" cargo audit $ca_fetch --json >"$OUT/cargo-audit.json" 2>"$OUT/cargo-audit.log"; echo $? >"$OUT/.cargo-audit.rc" ) & _track $! cargo-audit cargo-audit.json
  else say "  ${c_yel}⚠ cargo-audit manquant${c_rst} (cargo install cargo-audit)"; fi

  # supply-chain superset: cargo-deny (advisories + bans + sources + licenses). NDJSON diagnostics on stderr.
  if have cargo && cargo deny --version >/dev/null 2>&1; then
    ( cd "$ROOT"; timeout "$TO" env RUSTUP_TOOLCHAIN="$TC" cargo deny --format json check 2>"$OUT/cargo-deny.json" >"$OUT/cargo-deny.log"; echo $? >"$OUT/.cargo-deny.rc" ) & _track $! cargo-deny cargo-deny.json
  else say "  ${c_yel}⚠ cargo-deny manquant${c_rst} (cargo install cargo-deny)"; fi

  # panic/overflow/cast substrate: clippy -> SARIF (via clippy-sarif) else raw rustc-json fallback.
  if have cargo && cargo clippy --version >/dev/null 2>&1; then
    if have clippy-sarif; then
      ( cd "$ROOT"; timeout "$TO" env RUSTUP_TOOLCHAIN="$TC" bash -c 'cargo clippy --workspace --message-format=json -- -W clippy::arithmetic_side_effects -W clippy::unwrap_used 2>/dev/null | clippy-sarif' >"$OUT/clippy.sarif" 2>"$OUT/clippy.log"; echo $? >"$OUT/.clippy.rc" ) & _track $! clippy clippy.sarif
    else
      ( cd "$ROOT"; timeout "$TO" env RUSTUP_TOOLCHAIN="$TC" cargo clippy --workspace --message-format=json -- -W clippy::arithmetic_side_effects -W clippy::unwrap_used >"$OUT/clippy.rustc.json" 2>"$OUT/clippy.log"; echo $? >"$OUT/.clippy.rc" ) & _track $! clippy clippy.rustc.json
    fi
  else say "  ${c_yel}⚠ clippy manquant${c_rst} (rustup component add clippy)"; fi

  # unsafe-surface heat-map (low yield; skip in --quick, it must build)
  if [ "$QUICK" != 1 ] && have cargo-geiger; then
    ( cd "$ROOT"; timeout "$TO" env RUSTUP_TOOLCHAIN="$TC" cargo geiger --output-format Json >"$OUT/cargo-geiger.json" 2>"$OUT/cargo-geiger.log"; echo $? >"$OUT/.cargo-geiger.rc" ) & _track $! cargo-geiger cargo-geiger.json
  fi

  # MANDATORY read (not a scanner): [profile.release] overflow-checks. Its ABSENCE = a live wraparound finding.
  if ! grep -rqsE '^\s*overflow-checks\s*=\s*true' "$ROOT"/Cargo.toml "$ROOT"/*/Cargo.toml 2>/dev/null; then
    say "  ${c_red}‼ overflow-checks absent de [profile.release]${c_rst} — underflow de balance silencieux dans le wasm déployé (FINDING, pas une note)."
    printf 'overflow-checks=true ABSENT du/des Cargo.toml [profile.release] — arithmetique brute sur balances = wraparound silencieux en release. VERIFIE chaque balance-amount vs checked_sub.\n' >"$OUT/overflow-checks.WARN"
  fi

  if [ "$ECO" = solana ]; then
    # Sealevel lints (Dylint) — needs the pinned nightly + [workspace.metadata.dylint] configured
    if have cargo-dylint; then
      ( cd "$ROOT"; timeout "$TO" env RUSTUP_TOOLCHAIN="$TC" cargo dylint --all --workspace -- --message-format=json >"$OUT/solana-lints.json" 2>"$OUT/solana-lints.log"; echo $? >"$OUT/.solana-lints.rc" ) & _track $! solana-lints solana-lints.json
    else say "  ${c_dim}solana-lints (Dylint) absent — cargo install cargo-dylint dylint-link + [workspace.metadata.dylint]${c_rst}"; fi
    # Decurity rust rules ARE Solana-only -> useful here (local, OPSEC-clean)
    local rustrules="$DECURITY/rust"
    if [ -d "$rustrules" ] && { have opengrep || have semgrep; }; then
      local sg="semgrep" mflag="--metrics=off"; if have opengrep; then sg="opengrep"; mflag=""; fi
      ( cd "$ROOT"; timeout "$TO" "$sg" scan --config "$rustrules" --sarif --output "$OUT/opengrep.sarif" $mflag --exclude .nuke . >"$OUT/opengrep.log" 2>&1; echo $? >"$OUT/.opengrep.rc" ) & _track $! opengrep opengrep.sarif
    fi
    # sec3 X-Ray / Radar = Docker + image pull (network) -> OPT-IN only (OPSEC: zero network by default)
    if [ "${NUKE_SEC3:-0}" = 1 ] && have docker; then
      ( timeout "$TO" docker run --rm -v "$ROOT:/src" ghcr.io/sec3-product/x-ray:latest /src >"$OUT/sec3.log" 2>&1; cp "$ROOT"/.xray/*.json "$OUT/sec3-xray.json" 2>/dev/null; echo $? >"$OUT/.sec3-xray.rc" ) & _track $! sec3-xray sec3-xray.json
    else say "  ${c_dim}sec3-xray / radar : opt-in (NUKE_SEC3=1 + docker ; pull réseau, hors OPSEC défaut)${c_rst}"; fi
  fi

  _await "$OUT"
}

# ------------------------------------------------------------------ non-EVM barrage: Go (cosmos-go / go-generic)
run_barrage_go(){
  local ROOT="$1" OUT="$2" TO="$3" ONLINE="${4:-0}" QUICK="${5:-0}"
  say "framework: ${c_grn}go${c_rst} (cosmos-sdk)"
  _P=(); _N=(); _O=()

  # own-code fusion runner: gosec+staticcheck+errcheck+govet -> ONE SARIF
  if have golangci-lint; then
    ( cd "$ROOT"; timeout "$TO" golangci-lint run --out-format sarif ./... >"$OUT/golangci.sarif" 2>"$OUT/golangci.log"; echo $? >"$OUT/.golangci.rc" ) & _track $! golangci golangci.sarif
  else say "  ${c_yel}⚠ golangci-lint manquant${c_rst}"; fi

  # secrets across code + git history (local)
  if have gitleaks; then
    ( cd "$ROOT"; timeout "$TO" gitleaks detect --no-banner --source "$ROOT" --report-format sarif --report-path "$OUT/gitleaks.sarif" >"$OUT/gitleaks.log" 2>&1; echo $? >"$OUT/.gitleaks.rc" ) & _track $! gitleaks gitleaks.sarif
  else say "  ${c_dim}gitleaks absent (secrets/mnémoniques)${c_rst}"; fi

  # interprocedural nil-deref (nil in a Msg/EndBlock path = chain halt). Beta.
  if have nilaway; then
    ( cd "$ROOT"; timeout "$TO" nilaway -json ./... >"$OUT/nilaway.json" 2>"$OUT/nilaway.log"; echo $? >"$OUT/.nilaway.rc" ) & _track $! nilaway nilaway.json
  fi

  # ToB Go rules via OpenGrep (concurrency/nil/race ~ non-determinism proxy). Local, needs the ruleset cloned.
  local gorules="$NUKE_HOME/vendor/semgrep-rules/go"
  if [ -d "$gorules" ] && { have opengrep || have semgrep; }; then
    local sg="semgrep" mflag="--metrics=off"; if have opengrep; then sg="opengrep"; mflag=""; fi
    ( cd "$ROOT"; timeout "$TO" "$sg" scan --config "$gorules" --sarif --output "$OUT/opengrep.sarif" $mflag --exclude .nuke . >"$OUT/opengrep.log" 2>&1; echo $? >"$OUT/.opengrep.rc" ) & _track $! opengrep opengrep.sarif
  fi

  # reachability SCA — hits network (vuln.go.dev / osv.dev) -> ONLINE only (or a local GOVULNDB mirror)
  if have govulncheck && { [ "$ONLINE" = 1 ] || [ -n "${GOVULNDB:-}" ]; }; then
    ( cd "$ROOT"; timeout "$TO" govulncheck -format sarif ./... >"$OUT/govulncheck.sarif" 2>"$OUT/govulncheck.log"; echo $? >"$OUT/.govulncheck.rc" ) & _track $! govulncheck govulncheck.sarif
  elif have govulncheck; then say "  ${c_dim}govulncheck : réseau requis — --online-rules ou GOVULNDB=file://mirror (OPSEC: off par défaut)${c_rst}"; fi
  if have osv-scanner && [ "$ONLINE" = 1 ]; then
    ( cd "$ROOT"; timeout "$TO" osv-scanner --format sarif -r . >"$OUT/osv.sarif" 2>"$OUT/osv.log"; echo $? >"$OUT/.osv.rc" ) & _track $! osv osv.sarif
  elif have osv-scanner; then say "  ${c_dim}osv-scanner : réseau (osv.dev) — --online-rules pour l'activer${c_rst}"; fi

  # CodeQL — the ONLY cosmos-semantic non-determinism SAST + custom Peggy/keeper-authz queries. Heavy (builds a DB).
  if [ "$QUICK" != 1 ] && [ "${NUKE_CODEQL:-0}" = 1 ] && have codeql; then
    ( cd "$ROOT"
      timeout "$TO" codeql database create "$OUT/codeql-db" --language=go --overwrite >"$OUT/codeql.log" 2>&1 \
        && timeout "$TO" codeql database analyze "$OUT/codeql-db" --format=sarif-latest -o "$OUT/codeql.sarif" >>"$OUT/codeql.log" 2>&1
      echo $? >"$OUT/.codeql.rc" ) & _track $! codeql codeql.sarif
  elif have codeql; then say "  ${c_dim}codeql : lourd (build DB) — NUKE_CODEQL=1 pour l'activer (+ pack crypto-com/cosmos-sdk-codeql)${c_rst}"; fi

  _await "$OUT"
}

# ------------------------------------------------------------------ the barrage
run_scan(){
  local TARGET="$1"; shift
  local OUT="" QUICK=0 ONLINE=0 BUILD=1
  while [ $# -gt 0 ]; do case "$1" in
    --out) OUT="$2"; shift 2;;
    --quick) QUICK=1; shift;;
    --online-rules) ONLINE=1; shift;;
    --no-build) BUILD=0; shift;;
    *) shift;;
  esac; done

  [ -e "$TARGET" ] || { say "${c_red}target not found: $TARGET${c_rst}"; exit 2; }
  TARGET="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
  local ROOT; if [ -d "$TARGET" ]; then ROOT="$TARGET"; else ROOT="$(dirname "$TARGET")"; fi

  local TS; TS="$(date +%Y%m%d-%H%M%S)"
  [ -z "$OUT" ] && OUT="$ROOT/.nuke/$TS"
  mkdir -p "$OUT"
  local TO=600; [ "$QUICK" = 1 ] && TO=120

  hdr "NUKE barrage → $TARGET"
  say "workdir: $OUT   timeout/tool: ${TO}s"

  # ecosystem routing — EVM falls through to the existing flow; non-EVM dispatches to its own barrage.
  local ECO; ECO="$(detect_ecosystem "$ROOT")"
  say "ecosystem: ${c_grn}$ECO${c_rst}"
  case "$ECO" in
    cosmwasm|solana|rust-generic)
      run_barrage_rust "$ROOT" "$TARGET" "$OUT" "$ECO" "$TO" "$ONLINE" "$QUICK"
      local FUSE_ECO="$ECO"; [ "$ECO" = rust-generic ] && FUSE_ECO="rust-generic"
      fuse_and_report "$OUT" "$TARGET" "$FUSE_ECO"; return;;
    cosmos-go|go-generic)
      run_barrage_go "$ROOT" "$OUT" "$TO" "$ONLINE" "$QUICK"
      fuse_and_report "$OUT" "$TARGET" "cosmos-go"; return;;
    move|cairo)
      say "${c_yel}$ECO : pas de barrage statique mûr (1 membre faible, low-recall). NUKE ne fake pas une couverture.${c_rst}"
      say "  Route → ${c_grn}méthodes formelles / Prover${c_rst} :"
      say "    move  → 'aptos move prove' (z3/boogie, local) · asymptotic sui-prover — couche invariant-comptable, spec à écrire."
      say "    cairo → Aegis (Lean4) / Horus (SMT) pour UN invariant durci + snforge (property tests) + audit manuel du bridge/AA/upgrade."
      say "  ${c_dim}Semgrep reste une passe de triage-flag mince (écris tes règles) — jamais une claim de couverture.${c_rst}"
      printf '%s\n' "$OUT"; return;;
    unknown)
      say "${c_yel}écosystème non reconnu — ni EVM ni Rust/Go/Move/Cairo. Les scanners ne mordront pas ; rien à barrer.${c_rst}"
      printf '%s\n' "$OUT"; return;;
    evm|*) : ;;   # fall through to the EVM flow below
  esac

  # framework detection
  local FW="raw"
  [ -f "$ROOT/foundry.toml" ] && FW="foundry"
  ls "$ROOT"/hardhat.config.* >/dev/null 2>&1 && FW="hardhat"
  say "framework: $FW"

  # ensure deps are present so ALL scanners (esp. aderyn, which compiles independently) resolve imports
  if [ "$FW" != "raw" ] && [ -f "$ROOT/.gitmodules" ] && [ -d "$ROOT/.git" ] \
     && { [ ! -d "$ROOT/lib" ] || [ -z "$(ls -A "$ROOT/lib" 2>/dev/null)" ] || git -C "$ROOT" submodule status 2>/dev/null | grep -q '^-'; }; then
    say "${c_dim}[deps] git submodule update --init (libs manquantes)${c_rst}"
    ( cd "$ROOT" && timeout "$TO" git submodule update --init --recursive >/dev/null 2>&1 )
  fi
  if [ "$FW" = "foundry" ] && [ "$BUILD" = 1 ] && have forge; then
    say "${c_dim}[forge] build...${c_rst}"; ( cd "$ROOT" && timeout "$TO" forge build >/dev/null 2>&1 ); fi
  [ "$FW" = "raw" ] && pin_solc "$ROOT"

  # --- launch the three scanners in parallel ---
  local pids=() names=()

  if have slither; then
    ( cd "$ROOT"
      timeout "$TO" slither "$TARGET" --json "$OUT/slither.json" >"$OUT/slither.log" 2>&1
      echo $? > "$OUT/.slither.rc"
    ) & pids+=($!); names+=("slither")
  else echo "missing" > "$OUT/.slither.rc"; fi

  if have aderyn; then
    ( timeout "$TO" aderyn "$ROOT" -o "$OUT/aderyn.json" >"$OUT/aderyn.log" 2>&1
      echo $? > "$OUT/.aderyn.rc"
    ) & pids+=($!); names+=("aderyn")
  else echo "missing" > "$OUT/.aderyn.rc"; fi

  if have semgrep; then
    local secdir="$DECURITY/solidity/security"
    [ -d "$secdir" ] || secdir="$DECURITY/solidity"
    [ -d "$secdir" ] || secdir="$DECURITY"
    local cfg=("--config" "$secdir")
    [ "$ONLINE" = 1 ] && cfg+=("--config" "p/smart-contracts")
    local sgt=("$TARGET")   # diff mode narrows semgrep to just the changed files
    if [ -n "${NUKE_SEMGREP_FILES+x}" ] && [ ${#NUKE_SEMGREP_FILES[@]} -gt 0 ]; then sgt=("${NUKE_SEMGREP_FILES[@]}"); fi
    # -j 1: semgrep-core segfaults (-11) under internal parallelism on some inputs; we already
    # parallelize across the 3 tools, so single-job semgrep is both stabler and no slower here.
    ( timeout "$TO" semgrep "${cfg[@]}" --json -o "$OUT/semgrep.json" --metrics=off -j 1 "${sgt[@]}" \
        >"$OUT/semgrep.log" 2>&1
      echo $? > "$OUT/.semgrep.rc"
    ) & pids+=($!); names+=("semgrep")
  else echo "missing" > "$OUT/.semgrep.rc"; fi

  say "${c_dim}running ${#pids[@]} scanners in parallel...${c_rst}"
  local i=0
  for pid in "${pids[@]}"; do wait "$pid"; local nm="${names[$i]}"
    local rc; rc="$(cat "$OUT/.$nm.rc" 2>/dev/null)"
    if [ ! -s "$OUT/$nm.json" ]; then
      say "  ${c_yel}⚠ $nm : aucun JSON (rc=$rc) — voir $nm.log${c_rst}"
    elif [ "$nm" = semgrep ] && [ "${rc:-0}" -ge 2 ] 2>/dev/null; then
      say "  ${c_yel}⚠ semgrep partiel (rc=$rc, crash semgrep-core ?) — résultats incomplets, voir $nm.log${c_rst}"
    else
      say "  ${c_grn}✓ $nm${c_rst} (rc=$rc)"
    fi
    i=$((i+1))
  done

  # --- fuse (EVM) ---
  fuse_and_report "$OUT" "$TARGET" evm
}

# ------------------------------------------------------------------ diff mode
# nuke diff <base>[..<head>] — barrage focalisé sur le code changé (post-audit drift).
# Les analyseurs compilent tout le projet (obligé), mais le triage est filtré aux lignes du patch.
diff_mode(){
  local RANGE="${1:-}"; [ $# -gt 0 ] && shift
  [ -z "$RANGE" ] && { say "usage: nuke diff <base>[..<head>] [repo-path] [--quick] [--window N]"; exit 2; }
  local REPO="."   # optional explicit repo path (else = cwd, the normal git UX)
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then REPO="$1"; shift; fi
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { say "${c_red}pas un dépôt git ($REPO) — le mode diff exige git.${c_rst}"; exit 2; }
  local ROOT; ROOT="$(git -C "$REPO" rev-parse --show-toplevel)"

  local WIN=0; local pass=()   # git --unified=0 gives the EXACT changed lines; --window N hedges scanner anchor drift
  while [ $# -gt 0 ]; do case "$1" in
    --window) WIN="$2"; shift 2;;
    *) pass+=("$1"); shift;;
  esac; done

  local TS OUT; TS="$(date +%Y%m%d-%H%M%S)"; OUT="$ROOT/.nuke/diff-$TS"; mkdir -p "$OUT"

  hdr "NUKE diff — $RANGE"
  say "repo: $ROOT   fenêtre de contexte: ±${WIN} lignes"
  python3 "$SCRIPT_DIR/gitdiff.py" "$ROOT" "$RANGE" > "$OUT/changed_lines.json" 2>"$OUT/gitdiff.log" \
    || { say "${c_red}git diff a échoué (range invalide ?) — voir $OUT/gitdiff.log${c_rst}"; exit 2; }

  local NCH; NCH="$(jq -r '.files | length' "$OUT/changed_lines.json" 2>/dev/null || echo 0)"
  say "fichiers .sol changés (A/C/M/R) : ${c_grn}$NCH${c_rst}"
  if [ "$NCH" -eq 0 ]; then
    say "${c_yel}aucun .sol dans le diff — rien à barrager.${c_rst}"; exit 0; fi
  jq -r '.files[]' "$OUT/changed_lines.json" | sed 's/^/  · /'
  case "$RANGE" in *..*) say "${c_dim}note: le filtrage par ligne suppose que l'arbre de travail correspond au côté HEAD du range (sinon: git checkout <head> d'abord, ou utilise 'nuke diff <base>' seul = base vs arbre de travail).${c_rst}";; esac

  # scope semgrep to changed files, hand the diff-map to the aggregator
  NUKE_SEMGREP_FILES=(); local rel
  while IFS= read -r rel; do [ -n "$rel" ] && NUKE_SEMGREP_FILES+=("$ROOT/$rel"); done < <(jq -r '.files[]' "$OUT/changed_lines.json")
  NUKE_DIFF_MAP="$OUT/changed_lines.json"; NUKE_DIFF_WINDOW="$WIN"

  local rs=("$ROOT" --out "$OUT"); [ ${#pass[@]} -gt 0 ] && rs+=("${pass[@]}")
  run_scan "${rs[@]}"
}

# ------------------------------------------------------------------ selftest
selftest(){
  local FIX="$NUKE_HOME/selftest"
  [ -f "$FIX/evm/Vuln.sol" ] || { say "${c_red}selftest fixture missing${c_rst}"; exit 2; }
  hdr "NUKE selftest — vulnerable fixture"
  local OUT; OUT="$(run_scan "$FIX/evm" --quick --no-build | tail -1)"
  hdr "selftest assertions"
  local ok=1
  for t in slither aderyn semgrep; do
    if [ -s "$OUT/$t.json" ]; then say "  ${c_grn}✓ $t fired${c_rst}"; else say "  ${c_red}✗ $t silent${c_rst}"; ok=0; fi
  done
  if grep -qi reentran "$OUT/signals.md" 2>/dev/null; then say "  ${c_grn}✓ reentrancy signal present${c_rst}"
  else say "  ${c_yel}⚠ no reentrancy signal (check parsers)${c_rst}"; fi

  hdr "selftest — cartes d'espace négatif non-EVM (rendu, sans outils)"
  local tmpd; tmpd="$(mktemp -d)"
  for eco in cosmwasm cosmos-go solana; do
    local w="$tmpd/$eco"; mkdir -p "$w"
    python3 "$SCRIPT_DIR/aggregate.py" --workdir "$w" --target "selftest-$eco" --ecosystem "$eco" >/dev/null 2>&1
    local n; n="$(python3 -c "import json;print(len((json.load(open('$w/signals.json')).get('silent_detail')) or []))" 2>/dev/null || echo 0)"
    if [ "${n:-0}" -ge 15 ] && grep -q "classes de VOL" "$w/signals.md" 2>/dev/null; then
      say "  ${c_grn}✓ $eco : $n classes de vol curées rendues${c_rst}"
    else say "  ${c_red}✗ $eco : worklist non rendue (n=$n)${c_rst}"; ok=0; fi
  done
  rm -rf "$tmpd"

  hdr "selftest — barrage RÉEL non-EVM (rust-generic → fusion SARIF)"
  if have cargo && [ -f "$NUKE_HOME/selftest/rust/Cargo.toml" ]; then
    local ro; ro="$(run_scan "$NUKE_HOME/selftest/rust" --quick | tail -1)"
    [ -s "$ro/clippy.sarif" ] && say "  ${c_grn}✓ clippy → SARIF produit${c_rst}" || say "  ${c_yel}⚠ clippy.sarif vide (toolchain ?)${c_rst}"
    if [ -s "$ro/signals.md" ]; then say "  ${c_grn}✓ fusion SARIF OK — signals.md rendu (pas de crash rust-generic)${c_rst}"
    else say "  ${c_red}✗ signals.md absent — la fusion a crashé${c_rst}"; ok=0; fi
    [ -f "$ro/overflow-checks.WARN" ] && say "  ${c_grn}✓ overflow-checks finding émis${c_rst}" || say "  ${c_yel}⚠ overflow-checks WARN absent${c_rst}"
    rm -rf "$NUKE_HOME/selftest/rust/.nuke" "$NUKE_HOME/selftest/rust/target" 2>/dev/null
  else say "  ${c_dim}rust barrage skip (cargo absent)${c_rst}"; fi

  [ "$ok" = 1 ] && say "\n${c_grn}SELFTEST PASS — le barrage tire à balles réelles (EVM + barrage rust + cartes non-EVM).${c_rst}" \
                || say "\n${c_red}SELFTEST PARTIAL — voir logs dans $OUT${c_rst}"
}

# ------------------------------------------------------------------ digest (pont intake)
digest_cmd(){
  local a="${1:-.}" sig=""; [ $# -gt 0 ] && shift   # rest ($@) = optional --fork/--shape for saturation enrichment
  if [ -f "$a" ]; then sig="$a"
  elif [ -f "$a/signals.json" ]; then sig="$a/signals.json"
  elif [ -d "$a/.nuke" ]; then sig="$(ls -dt "$a"/.nuke/*/signals.json 2>/dev/null | head -1)"
  fi
  [ -z "$sig" ] && { say "${c_red}signals.json introuvable pour '$a' — lance 'nuke <target>' d'abord${c_rst}"; exit 2; }
  python3 "$SCRIPT_DIR/digest.py" --signals "$sig" "$@"
  say "→ $(dirname "$sig")/nuke-digest.md  (à lire par /intake)"
}

# ------------------------------------------------------------------ saturation (filtre de dé-priorisation par veine)
saturation_cmd(){
  local a="${1:-.}" sig=""; [ $# -gt 0 ] && shift
  if [ -f "$a" ]; then sig="$a"
  elif [ -f "$a/signals.json" ]; then sig="$a/signals.json"
  elif [ -d "$a/.nuke" ]; then sig="$(ls -dt "$a"/.nuke/*/signals.json 2>/dev/null | head -1)"
  fi
  [ -z "$sig" ] && { say "${c_red}signals.json introuvable pour '$a' — lance 'nuke <target>' d'abord${c_rst}"; exit 2; }
  python3 "$SCRIPT_DIR/saturation.py" --signals "$sig" "$@"
  say "→ $(dirname "$sig")/saturation.md  (VIERGE = creuse · LABOURÉE = déprioris)"
}

# ------------------------------------------------------------------ dispatch
case "${1:-}" in
  ""|-h|--help) say "usage:
  nuke <target> [--out DIR] [--quick] [--online-rules] [--no-build]   barrage complet
  nuke diff <base>[..<head>] [repo] [--quick] [--window N]           barrage focalisé sur le patch
  nuke digest [workdir|target] [--fork <n[,n]> --shape S]            pré-remplissage intake (+ VEINES VIERGES si --fork)
  nuke saturation [workdir|target] --fork <name[,name]> [--shape S]  tague chaque veine VIERGE/LABOURÉE via le corpus
  nuke env | selftest";;
  env) print_env;;
  selftest) selftest;;
  diff) shift; diff_mode "$@";;
  digest) shift; digest_cmd "$@";;
  saturation) shift; saturation_cmd "$@";;
  *) run_scan "$@";;
esac
