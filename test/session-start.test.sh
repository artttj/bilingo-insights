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

out="$(unset INSIGHTS_LANG; bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "default: valid JSON" "$j"
check "default: targets German" "$(has "$out" 'then German')"
check "default: has translation box" "$(has "$out" 'translated into German')"

out="$(INSIGHTS_LANG=fr bash "$HOOK")"
check "fr code: targets French" "$(has "$out" 'then French')"

out="$(INSIGHTS_LANG=French bash "$HOOK")"
check "French name: targets French" "$(has "$out" 'then French')"

out="$(INSIGHTS_LANG='' bash "$HOOK")"
check "empty: defaults to German" "$(has "$out" 'then German')"

out="$(INSIGHTS_LANG='de"; rm -rf /' bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "injection: stays valid JSON" "$j"

out="$(INSIGHTS_LANG=en bash "$HOOK")"
printf '%s' "$out" | valid_json && j=1 || j=0
check "english: valid JSON" "$j"
check "english: has insight box" "$(has "$out" '★ Insight')"
if [ "$(has "$out" 'translated into')" = "0" ]; then
  check "english: no translation box" 1
else
  check "english: no translation box" 0
fi

exit "$fail"
