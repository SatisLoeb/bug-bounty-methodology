#!/usr/bin/env bash
# pr-watch.sh — surveillance générique multi-target des repos GitHub (HEAD + PR heads),
# généralisation de sky-pas-watch.sh à toute la watchlist.
#
# Config : drift-watch/pr-watchlist.tsv (TSV, lignes # ignorées)
#   id <TAB> remotes(,) <TAB> mode <TAB> globs(,) <TAB> trigger_regex <TAB> dossier
#   - mode  : "pr" = HEAD + refs/pull/*/head (repos de gouvernance/spells, pré-merge) ;
#             "head" = HEAD seulement (gros repos protocole ; le drift-watch classique garde la baseline de verdict)
#   - globs : pathspecs pour restreindre le grep (évite le bruit des archives/tests) ; vide = tout *.sol *.rs *.clar *.go *.ts
#   - trigger_regex : motifs re-arm (extended regex, git grep -E)
#   - dossier : chemin du dossier d'engagement (info pour l'analyste, non utilisé par le script)
#
# État : drift-watch/state/<id>.refs — "déjà vu" AUTO-AVANÇANT (≠ baseline de verdict de watchlist.tsv,
# qui reste gelée). Premier run d'une target = baseline silencieuse.
#
# Usage : tools/pr-watch.sh [id-filter]
# Exit  : 0 = rien ; 2 = erreurs réseau uniquement ; 10 = changements (détails sur stdout)
# Réseau : git protocol sur repos publics uniquement (passe le proxy egress).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$ROOT/drift-watch/pr-watchlist.tsv"
STATE_DIR="$ROOT/drift-watch/state"
FILTER="${1:-}"
mkdir -p "$STATE_DIR"
WORKDIR="$(mktemp -d)"; trap 'rm -rf "$WORKDIR"' EXIT

DEFAULT_EXT=':*.sol :*.rs :*.clar :*.go :*.ts :*.move :*.vy'
ANY_CHANGE=0; ANY_ERR=0

while IFS=$'\t' read -r id remotes mode globs regex dossier; do
  [[ -z "${id:-}" || "$id" == \#* ]] && continue
  [[ -n "$FILTER" && "$id" != *"$FILTER"* ]] && continue

  new="$WORKDIR/$id.new"; : > "$new"
  ok_net=0
  for entry in ${remotes//,/ }; do
    remote="${entry%%@*}"
    refspec="HEAD"; [[ "$entry" == *@* ]] && refspec="refs/heads/${entry#*@}"
    [[ "$mode" == "pr" ]] && refspec="$refspec refs/pull/*/head"
    # shellcheck disable=SC2086
    if git ls-remote "https://github.com/${remote}" $refspec 2>/dev/null \
        | awk -v r="$remote" '{print r" "$2" "$1}' >> "$new"; then ok_net=1; fi
  done
  sort -o "$new" "$new"
  if [[ ! -s "$new" ]]; then
    echo "FETCHERR  [$id] ls-remote vide (réseau ?) — état non modifié"; ANY_ERR=1; continue
  fi

  state="$STATE_DIR/$id.refs"
  if [[ ! -s "$state" ]]; then
    cp "$new" "$state"
    echo "BASELINE  [$id] $(wc -l < "$state") refs enregistrées (aucune analyse au premier run)"
    continue
  fi

  changed="$(comm -13 "$state" "$new" || true)"
  [[ -z "$changed" ]] && continue
  ANY_CHANGE=1
  echo "=== [$id] CHANGEMENTS ($(echo "$changed" | wc -l) refs) — dossier: ${dossier:-aucun} ==="
  echo "$changed"

  # pathspecs de grep
  spec="$DEFAULT_EXT"
  if [[ -n "${globs:-}" ]]; then
    spec=""; for g in ${globs//,/ }; do spec+=" ${g%/}/*"; done
  fi

  dir="$WORKDIR/clone_$id"
  while read -r remote ref sha; do
    [[ -z "${remote:-}" ]] && continue
    [[ ! -d "$dir/.git" ]] && { git init -q "$dir"; }
    git -C "$dir" remote remove origin 2>/dev/null; git -C "$dir" remote add origin "https://github.com/${remote}"
    if git -C "$dir" fetch -q --depth 2 origin "$sha" 2>/dev/null; then
      # shellcheck disable=SC2086
      hits="$(git -C "$dir" grep -nIE "$regex" "$sha" -- $spec 2>/dev/null | grep -viE '/(test|tests|archive|mocks?)/' | head -25 || true)"
      if [[ -n "$hits" ]]; then
        echo "--- TRIGGER-HITS $remote $ref ($sha) ---"; echo "$hits"
      else
        echo "--- $remote $ref (${sha:0:9}) : aucun trigger hors tests/archives ---"
      fi
    else
      echo "--- $remote $ref (${sha:0:9}) : fetch impossible (ref supprimée ?) ---"
    fi
  done <<< "$changed"

  cp "$new" "$state"
  echo
done < "$CONF"

if (( ANY_CHANGE )); then echo "ÉTAT mis à jour dans $STATE_DIR (à committer)"; exit 10; fi
(( ANY_ERR )) && exit 2
echo "OK: aucune target n'a bougé"
exit 0
