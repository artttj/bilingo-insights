#!/usr/bin/env bash

# bilingo-insights SessionStart hook.
# Injects the explanatory-insights instruction in English plus a second
# language chosen with INSIGHTS_LANG (default German). Dependency-free:
# no jq, no python, so it runs on any machine that has bash.

set -euo pipefail

lang_raw="${INSIGHTS_LANG:-de}"
lang="$(printf '%s' "$lang_raw" | tr -cd '[:alnum:] _-')"
[ -z "$lang" ] && lang="de"

lang_lower="$(printf '%s' "$lang" | tr '[:upper:]' '[:lower:]')"

bilingual=1
lang_name="$lang"
case "$lang_lower" in
  en|eng|english) bilingual=0 ;;
  de|deu|ger|german) lang_name="German" ;;
  fr|fra|french) lang_name="French" ;;
  es|spa|spanish) lang_name="Spanish" ;;
  it|ita|italian) lang_name="Italian" ;;
  pt|por|portuguese) lang_name="Portuguese" ;;
  nl|nld|dutch) lang_name="Dutch" ;;
  pl|pol|polish) lang_name="Polish" ;;
  ru|rus|russian) lang_name="Russian" ;;
  uk|ukr|ukrainian) lang_name="Ukrainian" ;;
  zh|zho|chinese) lang_name="Chinese" ;;
  ja|jpn|japanese) lang_name="Japanese" ;;
  ko|kor|korean) lang_name="Korean" ;;
  tr|tur|turkish) lang_name="Turkish" ;;
  ar|ara|arabic) lang_name="Arabic" ;;
esac

if [ "$bilingual" -eq 1 ]; then
  read -r -d '' instruction <<'EOF' || true
You are in 'bilingual explanatory' output style mode. You give educational
insights about the codebase as you help with the user's task, and you give each
insight in two languages: English first, then __LANG__.

Be clear and educational. Balance the explanations with getting the task done.
You may go past the usual length limits for these insights, but stay focused and
relevant.

Before and after writing code, add a short insight as two stacked boxes. First
an English box, then the same points translated into __LANG__:

`★ Insight ─────────────────────────────────────`
[2-3 key educational points in English]
`─────────────────────────────────────────────────`
`★ <the word for "Insight" in __LANG__> ─────────────────`
[the same points, translated into __LANG__]
`─────────────────────────────────────────────────`

Rules:
- The second box repeats the same points in __LANG__. Do not add, drop, or
  invent content. It is a translation of the English box, not a second set of
  ideas.
- The second box header uses the word for "Insight" in __LANG__ (for example
  German "Einblick", French "Aperçu").
- Keep insights specific to this codebase or the code you just wrote, not
  general programming facts.
- These insights belong in the conversation, not in the codebase. Give them as
  you work, not only at the end.
EOF
  instruction="${instruction//__LANG__/$lang_name}"
else
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
fi

esc=$instruction
esc=${esc//\\/\\\\}
esc=${esc//\"/\\\"}
esc=${esc//$'\t'/\\t}
esc=${esc//$'\n'/\\n}

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"

exit 0
