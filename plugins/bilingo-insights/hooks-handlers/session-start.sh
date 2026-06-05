#!/usr/bin/env bash

# bilingo-insights SessionStart hook.
# Injects an explanatory-insights instruction. INSIGHTS_LANG is an ordered,
# comma-separated list of languages; the model renders one insight box per
# language, in list order. The first box is the canonical insight, the rest are
# translations of it. Default "en,de" (English then German). One language means
# a single box. Dependency-free: no jq, no python, so it runs on any machine
# that has bash.

set -euo pipefail

raw="${INSIGHTS_LANG:-en,de}"

resolve_lang() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    en|eng|english) printf 'English' ;;
    de|deu|ger|german) printf 'German' ;;
    fr|fra|french) printf 'French' ;;
    es|spa|spanish) printf 'Spanish' ;;
    it|ita|italian) printf 'Italian' ;;
    pt|por|portuguese) printf 'Portuguese' ;;
    nl|nld|dutch) printf 'Dutch' ;;
    pl|pol|polish) printf 'Polish' ;;
    ru|rus|russian) printf 'Russian' ;;
    uk|ukr|ukrainian) printf 'Ukrainian' ;;
    zh|zho|chinese) printf 'Chinese' ;;
    ja|jpn|japanese) printf 'Japanese' ;;
    ko|kor|korean) printf 'Korean' ;;
    tr|tur|turkish) printf 'Turkish' ;;
    ar|ara|arabic) printf 'Arabic' ;;
    *) printf '%s' "$1" ;;
  esac
}

parts=()
if [ -n "$raw" ]; then
  IFS=',' read -r -a parts <<< "$raw"
fi

langs=()
seen=" "
for part in ${parts[@]+"${parts[@]}"}; do
  tok="$(printf '%s' "$part" | tr -cd '[:alnum:] _-')"
  tok="${tok#"${tok%%[![:space:]]*}"}"
  tok="${tok%"${tok##*[![:space:]]}"}"
  [ -z "$tok" ] && continue
  name="$(resolve_lang "$tok")"
  key="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  case "$seen" in *" $key "*) continue ;; esac
  seen="$seen$key "
  langs+=("$name")
done

if [ "${#langs[@]}" -eq 0 ]; then
  langs=("English" "German")
fi

if [ "${#langs[@]}" -eq 1 ]; then
  name="${langs[0]}"
  if [ "$name" = "English" ]; then
    read -r -d '' instruction <<'EOF' || true
You are in 'explanatory' output style mode, where you give educational insights
about the codebase as you help with the user's task.

Be clear and educational. Balance the explanations with getting the task done.
You may go past the usual length limits for these insights, but stay focused and
relevant.

Before and after writing code, add a short insight:

`★ Insight ─────────────────────────────────────`
[2-3 key educational points]
`─────────────────────────────────────────────────`

Keep insights specific to this codebase or the code you just wrote, not general
programming facts. These insights belong in the conversation, not in the
codebase. Give them as you work, not only at the end.
EOF
  else
    read -r -d '' instruction <<'EOF' || true
You are in 'explanatory' output style mode, where you give educational insights
about the codebase as you help with the user's task. Write each insight in
__LANG__.

Be clear and educational. Balance the explanations with getting the task done.
You may go past the usual length limits for these insights, but stay focused and
relevant.

Before and after writing code, add a short insight:

`★ <the word for "Insight" in __LANG__> ─────────────────────────────────────`
[2-3 key educational points in __LANG__]
`─────────────────────────────────────────────────`

Keep insights specific to this codebase or the code you just wrote, not general
programming facts. These insights belong in the conversation, not in the
codebase. Give them as you work, not only at the end.
EOF
    instruction="${instruction//__LANG__/$name}"
  fi
else
  list=""
  for n in "${langs[@]}"; do
    if [ -z "$list" ]; then list="$n"; else list="$list, $n"; fi
  done

  boxes=""
  i=0
  for n in "${langs[@]}"; do
    if [ "$n" = "English" ]; then
      header='`★ Insight ─────────────────────────────────────`'
    else
      header="\`★ <word for \"Insight\" in ${n}> ─────────────────────────────────────\`"
    fi
    if [ "$i" -eq 0 ]; then
      points="[2-3 key educational points in ${n}]"
    else
      points="[the same points, translated into ${n}]"
    fi
    boxes="${boxes}${header}
${points}
\`─────────────────────────────────────────────────\`
"
    i=$((i + 1))
  done

  instruction="You are in 'multilingual explanatory' output style mode. You give educational
insights about the codebase as you help with the user's task, and you give each
insight in these languages, in order: ${list}.

Be clear and educational. Balance the explanations with getting the task done.
You may go past the usual length limits for these insights, but stay focused and
relevant.

Before and after writing code, add a short insight as stacked boxes, one per
language in this order:

${boxes}
Rules:
- The first box is the canonical insight. Every later box repeats the same
  points in its language. It is a faithful translation of the first box, not a
  second set of ideas. Do not add, drop, or invent content.
- Each box header uses the word for \"Insight\" in that box's language (for
  example English \"Insight\", German \"Einblick\", French \"Aperçu\").
- Keep insights specific to this codebase or the code you just wrote, not
  general programming facts.
- These insights belong in the conversation, not in the codebase. Give them as
  you work, not only at the end."
fi

esc=$instruction
esc=${esc//\\/\\\\}
esc=${esc//\"/\\\"}
esc=${esc//$'\t'/\\t}
esc=${esc//$'\n'/\\n}

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"

exit 0
