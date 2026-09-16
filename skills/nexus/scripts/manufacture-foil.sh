#!/usr/bin/env bash
# manufacture-foil.sh — générateur de WORKLIST pour les deux foils TOUJOURS disponibles
# (temporel = commit-audité↔HEAD ; interne/mirror = sœur-gardée↔sœur-non-gardée), plus
# une détection du type pour pointer le foil CANONIQUE.
#
#   Ce script ne trouve AUCUN bug et n'émet AUCUN verdict. Il RANGE des candidats-divergence
#   que tu dois ensuite DÉPENSER par exécution (fork / cast / disconfirmer). Une divergence
#   non exécutée n'est PAS traitée (cf. nexus SKILL.md § CONSOMMER LE FOIL).
#
# Usage:
#   manufacture-foil.sh [REPO_DIR] [--audit-ref <git-ref>]
#     REPO_DIR       racine du code (défaut: .)
#     --audit-ref R  le commit/tag béni par l'audit (active le FOIL TEMPOREL)
#
# Sortie: 3 sections — A) foil temporel  B) foil interne/mirror  C) pointeur foil canonique.
set -uo pipefail

REPO="."; AUDIT_REF=""
while [ $# -gt 0 ]; do
  case "$1" in
    --audit-ref) AUDIT_REF="${2:-}"; shift 2 ;;
    --audit-ref=*) AUDIT_REF="${1#--audit-ref=}"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    -*) echo "arg inconnu: $1 (voir --help)"; exit 1 ;;
    *) REPO="$1"; shift ;;
  esac
done
[ -d "$REPO" ] || { echo "FATAL: repo introuvable: $REPO"; exit 1; }
cd "$REPO"

hr(){ printf '%s\n' "────────────────────────────────────────────────────────────────────────"; }
CODE_GLOBS=(--include='*.sol' --include='*.rs' --include='*.go' --include='*.move' --include='*.cairo' --include='*.vy' --include='*.ts' --include='*.js')

echo "# MANUFACTURE-FOIL — worklist (PAS un verdict)"
echo "# repo: $(pwd)   audit-ref: ${AUDIT_REF:-<aucun>}"
echo

# ─────────────────────────────────────────────────────────────────────────────
# A) FOIL TEMPOREL — l'audit est l'oracle ; tout après le commit béni est non-béni.
# ─────────────────────────────────────────────────────────────────────────────
echo "## A) FOIL TEMPOREL (commit-audité ↔ HEAD)"
hr
if [ -z "$AUDIT_REF" ]; then
  echo "Pas de --audit-ref fourni. Pour l'activer, trouve le commit béni :"
  echo "  - git tag / git log --oneline autour de la DATE de l'audit (page du programme, README, CHANGELOG)"
  echo "  - le hash cité dans le rapport C4/Sherlock/Cantina/firme"
  echo "  puis relance :  manufacture-foil.sh $REPO --audit-ref <hash>"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    echo; echo "Tags disponibles (candidats commit-audité) :"
    git tag --sort=-creatordate 2>/dev/null | head -15 | sed 's/^/  /' || true
    echo "Derniers commits :"
    git log --oneline -8 2>/dev/null | sed 's/^/  /' || true
  fi
elif ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "⚠ pas un dépôt git — foil temporel indisponible ici."
elif ! git rev-parse --verify "$AUDIT_REF^{commit}" >/dev/null 2>&1; then
  echo "⚠ ref introuvable: $AUDIT_REF"
else
  echo "Code NÉ APRÈS la bénédiction = ton espace de recherche ENTIER (delta minuscule)."
  echo "Il hérite rarement des gardes posés sur ses parents (post-audit periphery drift → xseam / q9)."
  echo
  echo "Fichiers de code modifiés depuis $AUDIT_REF :"
  git diff --stat "$AUDIT_REF"..HEAD -- "*.sol" "*.rs" "*.go" "*.move" "*.cairo" "*.vy" 2>/dev/null | sed 's/^/  /' || echo "  (aucun / diff vide)"
  echo
  echo "Fonctions AJOUTÉES depuis $AUDIT_REF (siblings sans lignage d'audit) :"
  git diff "$AUDIT_REF"..HEAD -- "*.sol" "*.rs" "*.move" "*.vy" 2>/dev/null \
    | grep -E '^\+' | grep -Ev '^\+\+\+' \
    | grep -oE '(function|fn|def|public fun|entry fun) +[A-Za-z0-9_]+' \
    | sort -u | head -40 | sed 's/^/  + /' || echo "  (aucune)"
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# B) FOIL INTERNE / MIRROR — la sœur gardée est l'oracle de la sœur non-gardée.
# ─────────────────────────────────────────────────────────────────────────────
echo "## B) FOIL INTERNE / MIRROR (sœur gardée ↔ sœur non-gardée)"
hr
# cible = code de PROD uniquement : exclut test/script/mock/vendor/lib + fichiers d'interface (I*.sol)
SOL_FILES="$(find . -name '*.sol' -not -path '*/node_modules/*' -not -path '*/lib/*' 2>/dev/null \
  | grep -vE '/(test|tests|script|scripts|mock|mocks|vendor|interfaces|certora|formal-verification|harness|harnesses|mutation|mutants|helpers|specs)/|\.t\.sol$|\.s\.sol$|/I[A-Z][A-Za-z0-9_]*\.sol$|/(Mock|Dummy|Mint)[A-Za-z0-9_]*\.sol$' \
  | head -400 || true)"
if [ -z "$SOL_FILES" ]; then
  echo "Aucun .sol. Le scan de guard-asymétrie est câblé pour Solidity."
  echo "Pour Rust/Go/Move/Cairo : applique le principe à la main (grep le guard-idiom du langage —"
  echo "  require!(ctx.accounts.signer ...) / assert_eq!(caller ...) / has_one / #[access_control]) et"
  echo "  liste les fonctions-sœurs mutatrices qui ne le portent PAS → veine power / xseam."
else
  echo "Fonctions external/public MUTATRICES sans modificateur-garde dans l'en-tête = candidats sibling"
  echo "non-gardé. Compare chacune à sa SŒUR gardée (même famille) : l'asymétrie = oversight, pas design (Rule 8)."
  echo
  echo "— Histogramme des gardes présents (ce que le dev CRAINT ; cherche la sœur qui les SAUTE) :"
  grep -rhoE '\b(onlyOwner|onlyRole|onlyGovernance|onlyAdmin|onlyManager|onlyOperator|nonReentrant|whenNotPaused|requiresAuth|restricted|auth)\b' --include='*.sol' . 2>/dev/null \
    | sort | uniq -c | sort -rn | head -15 | sed 's/^/    /' || echo "    (aucun modificateur-garde repéré)"
  echo
  echo "— Candidats (external/public, non-view/pure, en-tête sans garde) :"
  # awk: accumule l'en-tête d'une fonction jusqu'au '{' ou ';', puis classe.
  printf '%s\n' "$SOL_FILES" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    awk -v FN="$f" '
      function flush(   guarded, mutating, external) {
        if (hdr=="") return
        external = (hdr ~ /(external|public)/)
        mutating = (hdr !~ /(view|pure)/)
        guarded  = (hdr ~ /(only[A-Z][A-Za-z0-9_]*|nonReentrant|whenNotPaused|requiresAuth|restricted|[^A-Za-z]auth[^A-Za-z])/)
        name = hdr; sub(/^.*function[ \t]+/,"",name); sub(/[ \t]*\(.*/,"",name)
        if (external && mutating && !guarded && hasbody && name!="" && name!="constructor")
          printf "    %-28s  %s\n", name, FN
        hdr=""
      }
      {
        line=$0
        if (acc==0 && line ~ /function[ \t]+[A-Za-z0-9_]+[ \t]*\(/) { acc=1; hdr=line }
        else if (acc==1) { hdr=hdr " " line }
        # terminateur : accolade = a un CORPS (candidat reel) ; point-virgule = decl interface (ignoree)
        if (acc==1 && line ~ /\{/)      { acc=0; hasbody=1; flush() }
        else if (acc==1 && line ~ /;/)  { acc=0; hasbody=0; flush() }
      }
    ' "$f" 2>/dev/null
  done | sort -u | head -40 || true
  CAND_N="$(printf '%s\n' "$SOL_FILES" | while IFS= read -r f; do [ -f "$f" ] && awk '/function[ \t]+[A-Za-z0-9_]+[ \t]*\(/{c++} END{print c+0}' "$f"; done | paste -sd+ 2>/dev/null | bc 2>/dev/null || echo "?")"
  echo
  echo "  (heuristique en-tête ; les gardes multi-lignes ou en-corps require(msg.sender) peuvent manquer —"
  echo "   VÉRIFIE chaque candidat en lisant la fonction. Total fonctions scannées ≈ ${CAND_N}. Cap affichage: 40.)"
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# C) FOIL CANONIQUE — détecter le type pour pointer la référence + la veine.
# ─────────────────────────────────────────────────────────────────────────────
echo "## C) POINTEUR FOIL CANONIQUE (type détecté → référence à diff → veine)"
hr
detect(){ grep -rIlE "$1" . "${CODE_GLOBS[@]}" --exclude-dir={node_modules,target,dist,build,.git,vendor,out,cache,lib,deps} 2>/dev/null | head -1; }
hit=0
if [ -n "$(detect 'IERC4626|ERC4626|totalAssets\(|convertToShares|previewRedeem')" ]; then
  echo "  • ERC-4626 (vault) → réf: la forme canonique OZ ERC4626 ; diff arrondi dépôt(Down)/retrait(Up)."
  echo "    veine: darkside Door C (déviation) + extract (mirror arrondi) + mirror V_in/V_out."; hit=1; fi
if [ -n "$(detect 'IERC20|\bERC20\b|allowance\[|safeTransferFrom\(')" ]; then
  echo "  • ERC-20 → réf: EIP-20 + OZ ; diff hooks/fee-on-transfer/return-bool/approve-race."
  echo "    veine: darkside Door C."; hit=1; fi
if [ -n "$(detect 'getReserves|swapExactTokens|UniswapV2|constant.?product|reserve0|kLast')" ]; then
  echo "  • AMM x*y=k → réf: UniswapV2 canonique ; diff invariant k, fee, skim/sync."
  echo "    veine: extract (math-extractible) + invfuzz si math ré-implémentée."; hit=1; fi
if [ -n "$(detect 'nBits|powLimit|proof.?of.?work|header.?chain|CompactTarget|difficulty.?retarget')" ]; then
  echo "  • header-chain / retarget de difficulté → réf: rust-bitcoin / Bitcoin Core."
  echo "    veine: invfuzz (harness différentiel + gate reachability) — le cas canonique."; hit=1; fi
if [ -n "$(detect '_domainSeparator|EIP712|_hashTypedData|permit\(|DOMAIN_SEPARATOR')" ]; then
  echo "  • EIP-712 / permit → réf: EIP-712 + OZ ; diff domain-separator, replay, chainId, nonce."
  echo "    veine: darkside Door C + power (authz de la signature)."; hit=1; fi
if [ -n "$(detect 'anchor_lang|declare_id!|#\[program\]|derive\(Accounts\)')" ]; then
  echo "  • Solana/Anchor → réf: l'IDL on-chain vs la source ; has_one/signer/owner par instruction."
  echo "    veine: power (authz) + solfork si closed-source + xseam (sibling non-gardé)."; hit=1; fi
[ "$hit" = 0 ] && echo "  (aucun type standard fingerprinté — recrute le foil-jumeau ou le foil interne ci-dessus.)"
echo
hr
echo "RAPPEL: ceci est une WORKLIST, pas un verdict. Range les candidats par chaînabilité-à-un-impact"
echo "payable, DÉPENSE depuis le haut avec un artefact EXÉCUTÉ par ligne, et ne conclus JAMAIS \"null\""
echo "sans avoir nommé le foil ET montré le registre d'exécution (nexus SKILL.md § LE VRAI PIÈGE)."
