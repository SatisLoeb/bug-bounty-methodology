#!/usr/bin/env bash
# HALMOS runner — durcit une propriété en preuve BORNÉE, dans ton format Foundry.
# Lance halmos en JSON, classe chaque check_ (PROUVÉ / CONTRE-EXEMPLE / VACUITÉ / INDÉCIS),
# et REFUSE d'appeler « prouvé » un vert vacuous. Ne remplace pas ton jugement : il l'outille.
#
# Usage:
#   prove.sh [repo] [--function RE] [--contract C] [--loop N] [--array-lengths SPEC] [-- <halmos args>]
#   prove.sh env        # état de l'outil + cheatcodes dans le projet courant
#   prove.sh selftest   # prouve que le runner classe correctement les 4 cas (proven/ce/vacuité×2)
set -uo pipefail
_SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$_SELF")" && pwd)"
HALMOS_HOME="$(dirname "$SCRIPT_DIR")"
c_red=$'\e[31m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_blu=$'\e[34m'; c_dim=$'\e[2m'; c_rst=$'\e[0m'
say(){ printf '%s\n' "$*"; }
hdr(){ printf '\n%s== %s ==%s\n' "$c_blu" "$*" "$c_rst"; }
have(){ command -v "$1" >/dev/null 2>&1; }

print_env(){
  hdr "HALMOS tool matrix"
  if have halmos; then say "  ${c_grn}halmos${c_rst}  $(halmos --version 2>&1|head -1)"
  else say "  ${c_red}halmos manquant${c_rst} — lance scripts/setup.sh"; fi
  have forge && say "  ${c_grn}forge${c_rst}   $(forge --version 2>&1|head -1)"
  if [ -f foundry.toml ]; then
    say "  ${c_grn}foundry.toml${c_rst} présent"
    if forge remappings 2>/dev/null | grep -qi 'halmos-cheatcodes/'; then
      say "  ${c_grn}halmos-cheatcodes${c_rst} remappé"
    else
      say "  ${c_yel}halmos-cheatcodes absent${c_rst} → forge install a16z/halmos-cheatcodes"
    fi
  else say "  ${c_dim}(pas dans un projet Foundry ici)${c_rst}"; fi
}

run_prove(){
  local REPO="."
  if [ $# -gt 0 ] && [ -d "$1" ]; then REPO="$1"; shift; fi
  cd "$REPO" || { say "${c_red}repo introuvable${c_rst}"; exit 2; }
  [ -f foundry.toml ] || { say "${c_red}pas un projet Foundry (foundry.toml absent) dans $REPO${c_rst}"; exit 2; }
  have halmos || { say "${c_red}halmos manquant — lance $HALMOS_HOME/scripts/setup.sh${c_rst}"; exit 2; }

  if ! forge remappings 2>/dev/null | grep -qi 'halmos-cheatcodes/'; then
    say "${c_yel}⚠ halmos-cheatcodes non remappé — les tests SymTest ne compileront pas.${c_rst}"
    say "${c_yel}  → forge install a16z/halmos-cheatcodes${c_rst}"
  fi

  # --canary <fn> : garde de vacuité partielle (délègue puis sort)
  local CANARY_FN="" ; local -a passargs=() ; local -a raw=("$@")
  for ((k=0; k<${#raw[@]}; k++)); do
    if [ "${raw[$k]}" = "--canary" ]; then CANARY_FN="${raw[$((k+1))]:-}"; k=$((k+1)); continue; fi
    passargs+=("${raw[$k]}")
  done
  if [ -n "$CANARY_FN" ]; then run_canary "$CANARY_FN" "${passargs[@]}"; return $?; fi

  # note the bound (the hypothesis to record next to the result)
  local LOOP="2" ARRAYS="0,65,1024"
  local a; local -a args=("$@")
  for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
      --loop) LOOP="${args[$((i+1))]:-2}";;
      --array-lengths) ARRAYS="${args[$((i+1))]:-$ARRAYS}";;
      --default-array-lengths) ARRAYS="${args[$((i+1))]:-$ARRAYS}";;
    esac
  done

  local TS OUT; TS="$(date +%Y%m%d-%H%M%S)"; OUT=".halmos/$TS"; mkdir -p "$OUT"
  hdr "HALMOS — $REPO"
  say "borne: --loop $LOOP · arrays $ARRAYS   (l'hypothèse à noter avec le résultat)"
  say "${c_dim}halmos ${args[*]:-} --json-output $OUT/halmos.json${c_rst}"

  halmos "${args[@]}" --json-output "$OUT/halmos.json" 2>&1 | tee "$OUT/halmos.log"
  # (halmos exit code is in PIPESTATUS[0] but we drive verdicts from the JSON, more precise)

  if [ ! -s "$OUT/halmos.json" ]; then
    say "\n${c_red}Aucun JSON produit — build/compile échoué. Regarde $OUT/halmos.log${c_rst}"
    grep -Ei 'not found|Compiler run failed|Error|Unable to resolve' "$OUT/halmos.log" | head -6
    exit 2
  fi

  python3 "$SCRIPT_DIR/parse_halmos.py" --json "$OUT/halmos.json" --log "$OUT/halmos.log" \
    --loop "$LOOP" --arrays "$ARRAYS" --out "$OUT/proof.md"
  local rc=$?

  hdr "HALMOS done"
  say "  preuve : $OUT/proof.md"
  say "  brut   : $OUT/{halmos.json,halmos.log}"
  say ""
  say "${c_yel}Lecture (substance, pas théâtre) :${c_rst}"
  say "  • CONTRE-EXEMPLE = candidat finding → rejoue les valeurs en forge test concret, puis /report-nerve."
  say "  • VACUITÉ = faux vert : desserre les vm.assume / cible qui ne revert pas toujours, puis relance."
  say "  • PROUVÉ = borné : note --loop/$ARRAYS à côté ; ce n'est pas ∀n. Doute d'un PASS à 1 chemin (canary)."
  say "  • INDÉCIS = mur SMT (x*y=k, sqrt, intérêt composé) → --solver-timeout-assertion, ou reste sur le fuzz."
  return $rc
}

# canary : le site d'assertion de <fn> est-il atteignable par un chemin de succès ?
# (assert(P) -> assert(false) dans fn ; si Halmos l'atteint = PASS réel, sinon = faux vert)
run_canary(){
  local FN="$1"; shift
  local OUT; OUT=".halmos/canary-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$OUT"
  hdr "HALMOS canary — $FN"
  say "question: un chemin de succès ATTEINT-il l'assertion de $FN ? (garde de vacuité partielle)"
  local file
  file="$(grep -rEl "function[[:space:]]+$FN[[:space:]]*\(" test 2>/dev/null | head -1)"
  [ -z "$file" ] && file="$(grep -rEl "function[[:space:]]+$FN" test src 2>/dev/null | head -1)"
  [ -z "$file" ] && { say "${c_red}fonction $FN introuvable sous test/${c_rst}"; return 2; }
  say "fichier: $file"
  # nettoie tout résidu de canary (source + artefact compilé) pour ne pas polluer les runs suivants
  rm -f test/_NukeCanary_*.t.sol 2>/dev/null; rm -rf out/_NukeCanary_*.t.sol 2>/dev/null
  local cfile="test/_NukeCanary_${FN}.t.sol" newc
  newc="$(python3 "$SCRIPT_DIR/canary.py" "$file" "$FN" "$cfile" 2>"$OUT/canary.err")" \
    || { say "${c_red}transform échoué :${c_rst} $(cat "$OUT/canary.err")"; rm -f "$cfile"; return 2; }
  say "contrat canary: $newc   ${c_dim}(assert(P) → assert(false) dans $FN)${c_rst}"
  halmos --contract "$newc" --function "$FN" "$@" --json-output "$OUT/canary.json" >"$OUT/canary.log" 2>&1
  rm -f "$cfile"; rm -rf out/_NukeCanary_*.t.sol 2>/dev/null   # remove temp source AND its stale artifact
  local res
  res="$(python3 - "$OUT/canary.json" "$OUT/canary.log" "$FN" <<'PY'
import json,sys,re
jf,lf,fn=sys.argv[1:4]
try: d=json.load(open(jf))
except Exception: print("ERRJSON"); sys.exit()
row=None
for _,rs in d.get('test_results',{}).items():
    for r in rs:
        if re.search(r'\b'+re.escape(fn)+r'\b', r['name']): row=r
if not row: print("MISSING"); sys.exit()
ex,nm=row.get('exitcode',1),row.get('num_models',0)
raw=re.sub(r'\x1b\[[0-9;]*m','',open(lf).read()) if lf else ''
if (nm and nm>0) or ex==1: print("REACHABLE")
elif ex==0: print("UNREACHABLE")
elif ex==4 or 'all paths have been reverted' in raw: print("UNREACHABLE")
else: print("INDETERMINATE")
PY
)"
  echo
  case "$res" in
    REACHABLE)   say "${c_grn}✓ SITE ATTEIGNABLE — ton PASS est RÉEL${c_rst} : un chemin de succès traverse l'assertion de $FN.";;
    UNREACHABLE) say "${c_red}⨯ SITE JAMAIS ATTEINT — PASS VACUOUS (faux vert)${c_rst} : aucun chemin de succès n'atteint l'assertion. Desserre les vm.assume / la garde conditionnelle, puis re-prouve.";;
    INDETERMINATE) say "${c_yel}? indécis (mur SMT) — --solver-timeout-assertion, ou juge à la main via -vvvvv${c_rst}";;
    MISSING|ERRJSON|*) say "${c_yel}canary inconcluant (build ?) — voir $OUT/canary.log${c_rst}";;
  esac
  [ "$res" = "REACHABLE" ] && return 0 || return 1
}

selftest(){
  have halmos || { say "${c_red}halmos manquant — setup.sh d'abord${c_rst}"; exit 2; }
  have forge  || { say "${c_red}forge manquant${c_rst}"; exit 2; }
  local W; W="$(mktemp -d /tmp/halmos-selftest.XXXX)"
  hdr "HALMOS selftest — 4 cas (proven / counterexample / vacuité ×2)"
  say "${c_dim}scaffolding projet Foundry jetable dans $W ...${c_rst}"
  ( cd "$W"
    forge init --force . >/dev/null 2>&1
    forge install a16z/halmos-cheatcodes >/dev/null 2>&1
    rm -f src/Counter.sol test/Counter.t.sol script/*.s.sol 2>/dev/null
    grep -q 'halmos-cheatcodes/=' remappings.txt 2>/dev/null || echo 'halmos-cheatcodes/=lib/halmos-cheatcodes/src/' >> remappings.txt
    cp "$HALMOS_HOME/selftest/src/Adder.sol"  src/Adder.sol
    cp "$HALMOS_HOME/selftest/test/Adder.t.sol" test/Adder.t.sol )

  halmos --root "$W" --json-output "$W/res.json" >"$W/res.log" 2>&1
  python3 "$SCRIPT_DIR/parse_halmos.py" --json "$W/res.json" --log "$W/res.log" || true

  hdr "assertions selftest"
  local ok=1
  chk(){ python3 - "$W/res.json" "$W/res.log" "$1" "$2" <<'PY'
import json,sys,re
jf,lf,name,want=sys.argv[1:5]
d=json.load(open(jf)); raw=open(lf).read()
raw=re.sub(r'\x1b\[[0-9;]*m','',raw)
def base(s):
    m=re.search(r'(check_\w+)',s); return m.group(1) if m else s
row=None
for suite,rs in d['test_results'].items():
    for r in rs:
        if base(r['name'])==name: row=r
if not row: print("MISSING"); sys.exit(3)
ex,nm=row['exitcode'],row['num_models']
ra=any('all paths have been reverted' in l and name in l for l in raw.splitlines())
if ex==0: got="PROVEN"
elif nm>0: got="COUNTEREXAMPLE"
elif ra or ex==4: got="VACUOUS"
else: got="INDETERMINATE"
print(got); sys.exit(0 if got==want else 1)
PY
  }
  for pair in "check_add_commutative:PROVEN" "check_badMax:COUNTEREXAMPLE" \
              "check_vacuous_assume:VACUOUS" "check_vacuous_revert:VACUOUS"; do
    local fn="${pair%%:*}" want="${pair##*:}" got
    got="$(chk "$fn" "$want")"
    if [ "$got" = "$want" ]; then say "  ${c_grn}✓ $fn → $got${c_rst}"
    else say "  ${c_red}✗ $fn → $got (attendu $want)${c_rst}"; ok=0; fi
  done
  rm -rf "$W"
  [ "$ok" = 1 ] && say "\n${c_grn}SELFTEST PASS — le garde classe correctement (et refuse la vacuité).${c_rst}" \
                || { say "\n${c_red}SELFTEST FAIL${c_rst}"; exit 1; }
}

case "${1:-}" in
  ""|-h|--help) say "usage:
  prove.sh [repo] [--function RE] [--contract C] [--loop N] [--array-lengths SPEC]
  prove.sh [repo] --canary check_xxx [--loop N]   garde de vacuité : le site d'assertion est-il atteignable ?
  prove.sh env | selftest | scaffold <ContractPath> [FnName]";;
  env) print_env;;
  selftest) selftest;;
  scaffold) shift; bash "$SCRIPT_DIR/scaffold.sh" "$@";;
  *) run_prove "$@";;
esac
