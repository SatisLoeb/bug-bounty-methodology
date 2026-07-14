#!/usr/bin/env bash
# NUKE — idempotent installer for the local static-analysis arsenal.
# Safe to re-run. Installs only what is missing. No sudo required (user-writable prefixes).
set -uo pipefail
NUKE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEC="$NUKE/vendor/semgrep-smart-contracts"
mkdir -p "$NUKE/vendor/bin"
echo "== NUKE setup ($NUKE) =="

need(){ command -v "$1" >/dev/null 2>&1; }

# aderyn (prebuilt via npm; falls back to cargo)
if ! need aderyn; then
  echo "[aderyn] npm i -g @cyfrin/aderyn"; npm i -g @cyfrin/aderyn >/dev/null 2>&1 \
    || { echo "[aderyn] cargo fallback"; cargo install aderyn >/dev/null 2>&1; }
fi
need aderyn && echo "[aderyn] $(aderyn --version 2>&1 | head -1)" || echo "[aderyn] MISSING"

# semgrep (isolated via pipx)
if ! need semgrep; then echo "[semgrep] pipx install semgrep"; pipx install semgrep >/dev/null 2>&1; fi
need semgrep && echo "[semgrep] $(semgrep --version 2>&1 | head -1)" || echo "[semgrep] MISSING"

# Decurity rules (real-exploit-derived Solidity/Cairo/Rust ruleset)
if [ ! -d "$DEC/.git" ]; then
  git clone --depth 1 https://github.com/Decurity/semgrep-smart-contracts "$DEC" >/dev/null 2>&1
else ( cd "$DEC" && git pull --ff-only >/dev/null 2>&1 ); fi
[ -d "$DEC/solidity/security" ] && echo "[decurity] $(find "$DEC/solidity/security" -name '*.yaml' | wc -l | tr -d ' ') security rules" || echo "[decurity] MISSING"

# medusa fuzzer (optional)
if ! need medusa && [ ! -x "$NUKE/vendor/bin/medusa" ]; then
  for a in medusa-linux-x64.tar.gz medusa-linux-amd64.tar.gz; do
    curl -fsSL "https://github.com/crytic/medusa/releases/latest/download/$a" -o /tmp/medusa.tgz 2>/dev/null \
      && tar xzf /tmp/medusa.tgz -C "$NUKE/vendor/bin" 2>/dev/null && chmod +x "$NUKE/vendor/bin/medusa" 2>/dev/null && break
  done
fi
{ need medusa || [ -x "$NUKE/vendor/bin/medusa" ]; } && echo "[medusa] ok" || echo "[medusa] skipped (optional)"

# Pashov agent-hunt skills (LLM fan-out layer NUKE can PROPOSE)
if [ ! -d "$NUKE/vendor/pashov-skills/.git" ]; then
  git clone --depth 1 https://github.com/pashov/skills "$NUKE/vendor/pashov-skills" >/dev/null 2>&1
fi
for s in solidity-auditor x-ray fizz; do
  [ -d "$NUKE/vendor/pashov-skills/$s" ] && [ ! -e "$HOME/.claude/skills/$s" ] \
    && cp -r "$NUKE/vendor/pashov-skills/$s" "$HOME/.claude/skills/$s" && echo "[pashov] +/$s"
done

# ---------------------------------------------------------------- non-EVM arsenal (Rust/CosmWasm/Solana + Go/Cosmos)
# All best-effort, no sudo. Rust barrages need cargo; Go barrages need go. Skipped cleanly if absent.
if need cargo; then
  echo "== non-EVM: Rust suite (cargo-*) =="
  need rustup && rustup component add clippy >/dev/null 2>&1
  for c in cargo-audit cargo-deny cargo-geiger clippy-sarif sarif-fmt cargo-dylint dylint-link; do
    command -v "$c" >/dev/null 2>&1 || { echo "[rust] cargo install $c"; cargo install "$c" --locked >/dev/null 2>&1 || echo "[rust] $c skipped"; }
  done
  # prime the RustSec advisory-db so `cargo audit --no-fetch` works fully offline (OPSEC default)
  if [ ! -d "$HOME/.cargo/advisory-db/.git" ]; then
    echo "[rust] cloning advisory-db (one-time, for --no-fetch)"
    git clone --depth 1 https://github.com/rustsec/advisory-db "$HOME/.cargo/advisory-db" >/dev/null 2>&1 || echo "[rust] advisory-db skipped"
  fi
else echo "[non-EVM] cargo absent — Rust/CosmWasm/Solana barrage unavailable"; fi

if need go; then
  echo "== non-EVM: Go/Cosmos suite =="
  # golangci-lint fuses gosec+staticcheck+errcheck+govet; the rest are separate SARIF streams
  for pkg in \
    "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest" \
    "golang.org/x/vuln/cmd/govulncheck@latest" \
    "go.uber.org/nilaway/cmd/nilaway@latest" \
    "github.com/gitleaks/gitleaks/v8@latest" \
    "github.com/google/osv-scanner/v2/cmd/osv-scanner@latest"; do
    b="$(basename "${pkg%@*}")"; command -v "$b" >/dev/null 2>&1 || { echo "[go] go install $b"; go install "$pkg" >/dev/null 2>&1 || echo "[go] $b skipped"; }
  done
  # ToB semgrep-rules (Go concurrency/nil/race ~ consensus-non-determinism proxy; host for custom Cosmos rules)
  if [ ! -d "$NUKE/vendor/semgrep-rules/.git" ]; then
    git clone --depth 1 https://github.com/trailofbits/semgrep-rules "$NUKE/vendor/semgrep-rules" >/dev/null 2>&1 || echo "[go] tob semgrep-rules skipped"
  fi
  [ -d "$NUKE/vendor/semgrep-rules/go" ] && echo "[go] ToB go rules: $(find "$NUKE/vendor/semgrep-rules/go" -name '*.yaml' | wc -l | tr -d ' ')" || echo "[go] ToB go rules MISSING"
else echo "[non-EVM] go absent — Cosmos-SDK barrage unavailable"; fi

# OpenGrep (preferred over semgrep: free intra-file taint, no telemetry). Best-effort static binary.
if ! need opengrep && ! need semgrep; then
  echo "[opengrep] install (rule engine for Rust/Go/Cairo/Move rulesets)"
  curl -fsSL https://raw.githubusercontent.com/opengrep/opengrep/main/install.sh 2>/dev/null | bash >/dev/null 2>&1 || echo "[opengrep] skipped — pipx install semgrep as fallback"
fi

# Solana deep scanners (sec3 X-Ray / Radar) are Docker + image pull (network) -> OPT-IN, not installed here.
echo "[solana] sec3 X-Ray / Radar = opt-in Docker (NUKE_SEC3=1 at scan time); not pulled (OPSEC)."
# CodeQL (only cosmos-semantic non-determinism SAST) is a large manual install; see references/routing.md.
need codeql && echo "[go] codeql present (enable per-scan with NUKE_CODEQL=1)" || echo "[go] codeql absent — manual install; the only cosmos non-determinism SAST"

# convenience launcher on PATH (best effort)
for BIN in "$HOME/.local/bin" "$(npm config get prefix 2>/dev/null)/bin"; do
  if [ -d "$BIN" ] && [ -w "$BIN" ]; then ln -sf "$NUKE/scripts/nuke.sh" "$BIN/nuke" && echo "[launcher] $BIN/nuke -> nuke.sh" && break; fi
done

echo "== done — run:  nuke selftest  =="
