#!/usr/bin/env bash
# Tests for the bilingo-insights SessionStart hook.
# Runs the hook with several INSIGHTS_LANG values and checks the emitted JSON.
# Uses node only to validate JSON; the hook itself stays dependency-free.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../plugins/bilingo-insights/hooks-handlers/session-start.sh"

fail=0
check() {
  if [ "$2" = "1" ]; then
    printf 'ok   - %s\n' "$1"
  else
    printf 'FAIL - %s\n' "$1"
    fail=1
  fi
}
valid_json() {
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{JSON.parse(s);process.exit(0)}catch(e){process.exit(1)}})'
}
has() { case "$1" in *"$2"*) echo 1 ;; *) echo 0 ;; esac; }
lacks() { case "$1" in *"$2"*) echo 0 ;; *) echo 1 ;; esac; }

out="$(unset INSIGHTS_LANG; bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "default: valid JSON" "$j"
check "default: lists English then German" "$(has "$out" 'in order: English, German')"
check "default: has German translation box" "$(has "$out" 'translated into German')"
check "default: has English insight box" "$(has "$out" '★ Insight')"

out="$(INSIGHTS_LANG=fr bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "fr: valid JSON" "$j"
check "fr: single non-English box" "$(has "$out" 'Write each insight in')"
check "fr: targets French" "$(has "$out" 'in French')"
check "fr: no translation box" "$(lacks "$out" 'translated into')"

out="$(INSIGHTS_LANG=de bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "de: valid JSON" "$j"
check "de: single non-English box" "$(has "$out" 'Write each insight in')"
check "de: targets German" "$(has "$out" 'in German')"
check "de: no English box" "$(lacks "$out" 'English')"
check "de: no translation box" "$(lacks "$out" 'translated into')"

out="$(INSIGHTS_LANG=en,de,fr bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "three langs: valid JSON" "$j"
check "three langs: lists all three in order" "$(has "$out" 'in order: English, German, French')"
check "three langs: German translation box" "$(has "$out" 'translated into German')"
check "three langs: French translation box" "$(has "$out" 'translated into French')"

out="$(INSIGHTS_LANG='en, de' bash "$HOOK")"
check "spaces around comma: trims to English, German" "$(has "$out" 'in order: English, German')"

out="$(INSIGHTS_LANG='de,de' bash "$HOOK")"
check "duplicates: collapse to single box" "$(has "$out" 'Write each insight in')"
check "duplicates: targets German" "$(has "$out" 'in German')"
check "duplicates: no translation box" "$(lacks "$out" 'translated into')"

out="$(INSIGHTS_LANG='' bash "$HOOK")"
check "empty: falls back to English, German" "$(has "$out" 'in order: English, German')"

out="$(INSIGHTS_LANG='de"; rm -rf /' bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "injection: stays valid JSON" "$j"

out="$(INSIGHTS_LANG=en bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "english: valid JSON" "$j"
check "english: has insight box" "$(has "$out" '★ Insight')"
check "english: no translation box" "$(lacks "$out" 'translated into')"

exit "$fail"
