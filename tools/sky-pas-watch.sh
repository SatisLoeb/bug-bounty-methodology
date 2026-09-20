#!/usr/bin/env bash
# sky-pas-watch.sh — détecte les nouveaux commits/PRs dans les repos de spells Sky/Osero/Grove
# et pré-grep les patterns PAS des 4 WATCH conditions du dossier
# memory/-home-malix-Desktop-BUGS/sky-pas-beamstate-immunefi-engagement.md
#
# Usage: tools/sky-pas-watch.sh [state_file]
# Exit:  0 = aucun changement ; 10 = changements détectés (détails sur stdout)
# Réseau: uniquement git protocol sur repos publics (passe le proxy egress; l'API GitHub est bloquée).
set -euo pipefail

REPOS=(
  "sky-ecosystem/spells-mainnet"
  "osero-io/osero-spells"
  "grove-labs/grove-spells"
)

# Patterns PAS à pré-griper dans les refs nouvelles/modifiées (triage, pas verdict) :
# WATCH-1: addInitRateLimits avec maxAmount == type(uint256).max (arme P-01 si slope > 0)
# WATCH-2: addInitRateLimits en slot général address(0) (cross-Star, namespace de clés partagé)
# WATCH-3: addInitControllerActions en slot général address(0)
# WATCH-4: unpause du PAS_TIMELOCK / initLimitsAndControllerData / pairings de cBeam
GREP_PATTERN='addInitRateLimits|addInitControllerActions|initLimitsAndControllerData|setCBeamFor|addCBeam|PAS_TIMELOCK|unpause|PASAuthorizeInPAU|PAS_CONFIGURATOR|BeamState|setUnlimitedRateLimitData|type(uint256).max'

STATE_FILE="${1:-$(dirname "$0")/../memory/-home-malix-Desktop-BUGS/sky-pas-watch-state.txt}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

current_state() {
  for repo in "${REPOS[@]}"; do
    # HEAD de la branche par défaut + toutes les têtes de PR, préfixées par le repo
    git ls-remote "https://github.com/${repo}" HEAD 'refs/pull/*/head' 2>/dev/null \
      | awk -v r="$repo" '{print r" "$2" "$1}'
  done | sort
}

current_state > "$WORKDIR/new_state.txt"

if [[ ! -s "$WORKDIR/new_state.txt" ]]; then
  echo "ERROR: ls-remote returned nothing (network/proxy issue?) — no verdict, not updating state" >&2
  exit 2
fi

# Premier run : enregistrer la baseline sans fetch/grep (des centaines de refs historiques)
if [[ ! -s "$STATE_FILE" ]]; then
  cp "$WORKDIR/new_state.txt" "$STATE_FILE"
  echo "BASELINE créée: $(wc -l < "$STATE_FILE") refs enregistrées dans $STATE_FILE (à committer). Aucune analyse."
  exit 0
fi

# Refs nouvelles ou dont le SHA a changé
CHANGED="$(comm -13 <(sort "$STATE_FILE") "$WORKDIR/new_state.txt" || true)"

if [[ -z "$CHANGED" ]]; then
  echo "OK: aucun changement ($(wc -l < "$STATE_FILE") refs suivies)"
  exit 0
fi

echo "=== CHANGEMENTS DÉTECTÉS ==="
echo "$CHANGED"
echo

# Pré-grep PAS dans chaque ref changée (shallow fetch de la ref seule)
while read -r repo ref sha; do
  [[ -z "${repo:-}" ]] && continue
  dir="$WORKDIR/$(echo "$repo" | tr '/' '_')"
  if [[ ! -d "$dir" ]]; then
    git init -q "$dir" && git -C "$dir" remote add origin "https://github.com/${repo}"
  fi
  if git -C "$dir" fetch -q --depth 2 origin "$sha" 2>/dev/null; then
    hits="$(git -C "$dir" grep -lIE "$GREP_PATTERN" "$sha" -- '*.sol' 2>/dev/null || true)"
    if [[ -n "$hits" ]]; then
      echo "--- $repo $ref ($sha) : fichiers matchant les patterns PAS ---"
      echo "$hits"
      # Contexte: lignes matchantes des 4 conditions dures uniquement
      git -C "$dir" grep -nIE 'addInitRateLimits|addInitControllerActions|initLimitsAndControllerData|unpause' "$sha" -- '*.sol' 2>/dev/null \
        | grep -v '^.*lib/' | head -40 || true
      echo
    else
      echo "--- $repo $ref ($sha) : aucun pattern PAS (changement hors sujet) ---"
    fi
  else
    echo "--- $repo $ref ($sha) : fetch impossible (ref supprimée ?) ---"
  fi
done <<< "$CHANGED"

# Mettre à jour l'état (le commit de l'état est laissé à l'appelant)
cp "$WORKDIR/new_state.txt" "$STATE_FILE"
echo "État mis à jour: $STATE_FILE (à committer)"
exit 10
