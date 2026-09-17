#!/usr/bin/env bash
# recall-check.sh — the recall cross-check driver. Emits the periodic worklist for confronting each
# open NO-GO with public reality. There is no clean API for reports.immunefi.com, so this is a
# browser-assisted review, not a scraper: it prints, per recalled target, WHERE to look for a public
# finding that would prove the NO-GO false. A hit -> move the row to "Recall Corpses" in recall-ledger.md,
# classify generation-gap vs gate-error, name the generator/gate it implicates.
# Usage: ./recall-check.sh        (print the worklist from recall-ledger.md)
set -uo pipefail
LEDGER="$(dirname "$0")/recall-ledger.md"
[ -f "$LEDGER" ] || { echo "recall-ledger.md not found next to this script"; exit 1; }

echo "=== RECALL CROSS-CHECK worklist  $(date -u +%Y-%m-%d) ==="
echo "For each recalled target below, scan for a PUBLIC finding since the NO-GO date. A hit = recall-corpse."
echo "Sources: reports.immunefi.com (bug reports) · cantina.xyz/portfolio + /competitions · audits.sherlock.xyz ·"
echo "         code4rena.com/reports · the project's own audits repo · cat-2 disclosures."
echo "Ask on each hit: is the found bug a hypothesis I NEVER generated (generation-gap -> missing generator)"
echo "                 or one I generated and killed wrongly (gate-error -> gate re-calibration)?"
echo

# pull target names (first cell) from the Open NO-GO rows table
awk '
  /^## Open NO-GO rows/ {inrows=1; next}
  /^## Recall Corpses/  {inrows=0}
  inrows && /^\| / && $0 !~ /kill-list/ && $0 !~ /^\|[-: ]*\|/ {
    line=$0; sub(/^\| */,"",line); sub(/ *\|.*/,"",line);
    if (line != "" && line != "target") print line
  }
' "$LEDGER" | while IFS= read -r t; do
  # strip the [[memory]] wikilink for the search term
  term="$(echo "$t" | sed -E 's/ *\(\[\[.*\]\]\)//; s/ +$//')"
  q="$(echo "$term" | sed 's/ /+/g')"
  printf -- "- %s\n    reports:  https://reports.immunefi.com/?search=%s\n    google:   https://www.google.com/search?q=%s+bug+bounty+finding+OR+exploit\n" "$term" "$q" "$q"
done

echo
echo "After the pass: if 0 hits, this is NOT proof the NO-GOs were right (most findings are private) — it is"
echo "one weak recall observation. If >=1 hit, that is a real corpse: record it and mine the generator it names."
