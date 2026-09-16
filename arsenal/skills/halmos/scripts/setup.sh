#!/usr/bin/env bash
# HALMOS setup — idempotent. Installe halmos (uv) globalement, et — dans un projet Foundry —
# les cheatcodes + le remapping. Réexécutable sans dégât.
set -uo pipefail
have(){ command -v "$1" >/dev/null 2>&1; }
echo "== HALMOS setup =="

# 1) halmos via uv (isolé, solveurs z3+yices bundlés)
if ! have halmos; then
  if have uv; then
    echo "[halmos] uv tool install --python 3.12 halmos"
    uv tool install --python 3.12 halmos >/dev/null 2>&1 || uv tool install halmos >/dev/null 2>&1
  else
    echo "[uv] absent → installe uv puis halmos"
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
    export PATH="$HOME/.local/bin:$PATH"
    uv tool install --python 3.12 halmos >/dev/null 2>&1
  fi
fi
export PATH="$HOME/.local/bin:$PATH"
have halmos && echo "[halmos] $(halmos --version 2>&1|head -1)" || echo "[halmos] ÉCHEC (voir uv)"

# 2) cheatcodes + remapping — seulement si on est dans un projet Foundry
if [ -f foundry.toml ]; then
  if ! forge remappings 2>/dev/null | grep -qi 'halmos-cheatcodes/'; then
    echo "[cheatcodes] forge install a16z/halmos-cheatcodes"
    git add -A >/dev/null 2>&1 && git commit -qm 'wip: pre-halmos' >/dev/null 2>&1 || true
    forge install a16z/halmos-cheatcodes >/dev/null 2>&1 || echo "[cheatcodes] échec forge install (repo git ?)"
    grep -q 'halmos-cheatcodes/=' remappings.txt 2>/dev/null || echo 'halmos-cheatcodes/=lib/halmos-cheatcodes/src/' >> remappings.txt
  fi
  forge remappings 2>/dev/null | grep -qi 'halmos-cheatcodes/' && echo "[cheatcodes] remappé ✓" || echo "[cheatcodes] non remappé"
else
  echo "[cheatcodes] (pas dans un projet Foundry — lance depuis la cible: forge install a16z/halmos-cheatcodes)"
fi
echo "== done — vérifie:  prove.sh selftest  =="
