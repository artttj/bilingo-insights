# bilingo-insights implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Claude Code plugin that prints each explanatory insight in English and in a second language chosen with `INSIGHTS_LANG` (default German).

**Architecture:** A single `SessionStart` hook injects an `additionalContext` instruction into the system prompt. The model writes both languages inline. No code runs against the user's project, and there is no translation service. Same mechanism as the official `explanatory-output-style` plugin, with a bilingual instruction and a language selector.

**Tech Stack:** Bash (dependency-free hook: no `jq`, no `python`). Marketplace + plugin manifests as JSON. Tests in bash, using `node` only at test time to validate JSON.

---

## File structure

```
bilingo-insights/
├── .claude-plugin/
│   └── marketplace.json                 # marketplace listing → ./plugins/bilingo-insights
├── plugins/
│   └── bilingo-insights/
│       ├── .claude-plugin/plugin.json    # plugin manifest
│       ├── hooks/hooks.json              # SessionStart → session-start.sh
│       └── hooks-handlers/session-start.sh  # builds + injects the bilingual instruction
├── test/
│   └── session-start.test.sh             # runs the hook, checks emitted JSON
├── docs/superpowers/                     # spec + this plan (already committed)
├── README.md
├── LICENSE                               # MIT, Artem Iagovdik
└── .gitignore
```

Responsibilities: the hook is the only logic. Manifests are static config. The test exercises the hook's branches (default, code, name, empty, injection, English fallback).

---

## Task 1: Plugin and marketplace manifests

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/bilingo-insights/.claude-plugin/plugin.json`

- [ ] **Step 1: Write `.claude-plugin/marketplace.json`**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
  "name": "bilingo-insights",
  "owner": {
    "name": "Artem Iagovdik",
    "url": "https://github.com/artttj"
  },
  "metadata": {
    "description": "Bilingual explanatory insights for Claude Code. English plus a language you choose.",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "bilingo-insights",
      "source": "./plugins/bilingo-insights",
      "description": "Recreates the explanatory output style, but every insight appears in English and in a second language set by INSIGHTS_LANG (default German). Read insights in your mother tongue, or learn a language through the code you already read.",
      "version": "1.0.0",
      "author": {
        "name": "Artem Iagovdik",
        "url": "https://github.com/artttj"
      },
      "homepage": "https://github.com/artttj/bilingo-insights",
      "license": "MIT",
      "category": "productivity",
      "keywords": ["insights", "bilingual", "i18n", "explanatory", "translation", "learning"]
    }
  ]
}
```

- [ ] **Step 2: Write `plugins/bilingo-insights/.claude-plugin/plugin.json`**

```json
{
  "name": "bilingo-insights",
  "version": "1.0.0",
  "description": "Bilingual explanatory insights. Each insight appears in English and in a second language set by INSIGHTS_LANG (default German).",
  "author": {
    "name": "Artem Iagovdik",
    "email": "artyom.yagovdik@gmail.com",
    "url": "https://github.com/artttj"
  }
}
```

- [ ] **Step 3: Validate both files parse as JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('.claude-plugin/marketplace.json','utf8'));JSON.parse(require('fs').readFileSync('plugins/bilingo-insights/.claude-plugin/plugin.json','utf8'));console.log('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin plugins/bilingo-insights/.claude-plugin
git commit -m "feat: add marketplace and plugin manifests"
```

---

## Task 2: Hook wiring

**Files:**
- Create: `plugins/bilingo-insights/hooks/hooks.json`

- [ ] **Step 1: Write `plugins/bilingo-insights/hooks/hooks.json`**

```json
{
  "description": "Bilingual explanatory insights hook. Adds English plus chosen-language insight instructions.",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks-handlers/session-start.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate it parses as JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('plugins/bilingo-insights/hooks/hooks.json','utf8'));console.log('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add plugins/bilingo-insights/hooks/hooks.json
git commit -m "feat: wire SessionStart hook"
```

---

## Task 3: The hook script (TDD)

**Files:**
- Create: `test/session-start.test.sh`
- Create: `plugins/bilingo-insights/hooks-handlers/session-start.sh`

- [ ] **Step 1: Write the failing test `test/session-start.test.sh`**

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails (hook does not exist yet)**

Run: `bash test/session-start.test.sh`
Expected: FAIL — the hook file is missing, so the runs error and checks fail.

- [ ] **Step 3: Write `plugins/bilingo-insights/hooks-handlers/session-start.sh`**

```bash
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
```

- [ ] **Step 4: Make the hook executable**

Run: `chmod +x plugins/bilingo-insights/hooks-handlers/session-start.sh`

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash test/session-start.test.sh`
Expected: every line starts with `ok`, exit code 0.

- [ ] **Step 6: Sanity-check the default output by eye**

Run: `bash plugins/bilingo-insights/hooks-handlers/session-start.sh | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>console.log(JSON.parse(s).hookSpecificOutput.additionalContext))"`
Expected: readable instruction text, "English first, then German", and both box headers.

- [ ] **Step 7: Commit**

```bash
git add test/session-start.test.sh plugins/bilingo-insights/hooks-handlers/session-start.sh
git commit -m "feat: add bilingual SessionStart hook with tests"
```

---

## Task 4: README, LICENSE, .gitignore

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.gitignore`

- [ ] **Step 1: Write `README.md`**

````markdown
# bilingo-insights

Bilingual explanatory insights for Claude Code. Every insight shows up twice:
once in English, then the same points in a language you pick. German by default.

It builds on the explanatory output style. The difference is the second box.

## What it looks like

```
★ Insight ─────────────────────────────
- The repository pattern keeps data access out of the business logic.
- Dependency injection here avoids a hard tie to the concrete logger.
────────────────────────────────────────
★ Einblick ────────────────────────────
- Das Repository-Muster hält den Datenzugriff aus der Geschäftslogik heraus.
- Dependency Injection vermeidet hier eine feste Bindung an den Logger.
────────────────────────────────────────
```

## Why you might want it

- Read insights in your mother tongue. Code and its explanations are almost
  always English. Set the second language to your own and the idea lands in the
  language you think in, with the English still right there.
- Learn a language while you code. Set the second language to one you are
  learning. You already read code for hours, so now each insight comes with its
  translation and you pick up real technical vocabulary in context.

## How it works

A SessionStart hook adds an instruction to the session that asks Claude to write
each insight in English and then in your chosen language. Nothing runs against
your code, and there is no translation service. Claude writes both languages
itself. This is the same mechanism as the official explanatory-output-style
plugin, with a bilingual instruction.

## Install

```
/plugin marketplace add artttj/bilingo-insights
/plugin install bilingo-insights@bilingo-insights
```

Restart the session so the hook loads.

## Choose the language

Set `INSIGHTS_LANG` to a language code or name. German is the default.

In your shell profile:

```
export INSIGHTS_LANG=fr
```

Or in Claude Code `settings.json`, which works the same across shells:

```json
{
  "env": {
    "INSIGHTS_LANG": "fr"
  }
}
```

Codes like `de`, `fr`, `es`, `it`, `pt`, `nl`, `pl`, `ru`, `uk`, `zh`, `ja`,
`ko`, `tr`, `ar` map to their language names. Anything else passes straight
through, so `INSIGHTS_LANG=Swedish` also works. Set it to `en` for a single
English box.

## A note on cost

This roughly doubles the length of each insight, and translated text often runs
longer than English (German especially). If token use matters to you, keep that
in mind or use the single-language explanatory plugin instead.

## License

MIT. See [LICENSE](LICENSE).
````

- [ ] **Step 2: Write `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 Artem Iagovdik

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Write `.gitignore`**

```
.DS_Store
```

- [ ] **Step 4: Commit**

```bash
git add README.md LICENSE .gitignore
git commit -m "docs: add README, license, gitignore"
```

---

## Task 5: Publish to a public GitHub repo

**Files:** none (git/remote only)

- [ ] **Step 1: Confirm the test passes and all JSON is valid**

Run: `bash test/session-start.test.sh && node -e "['.claude-plugin/marketplace.json','plugins/bilingo-insights/.claude-plugin/plugin.json','plugins/bilingo-insights/hooks/hooks.json'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8')));console.log('json ok')"`
Expected: all `ok` lines, then `json ok`.

- [ ] **Step 2: Confirm the repo name is free**

Run: `gh repo view artttj/bilingo-insights >/dev/null 2>&1 && echo EXISTS || echo FREE`
Expected: `FREE`. If `EXISTS`, stop and pick a different name.

- [ ] **Step 3: Create the public repo and push**

Run: `gh repo create artttj/bilingo-insights --public --source=. --remote=origin --push --description "Bilingual explanatory insights for Claude Code: English plus a language you choose."`
Expected: repo created, `master` pushed, `origin` set.

- [ ] **Step 4: Verify**

Run: `gh repo view artttj/bilingo-insights --json url,visibility --jq '.url, .visibility'`
Expected: the URL and `PUBLIC`.

---

## Self-review

**Spec coverage:**
- Standalone repo + marketplace → Task 1, Task 5.
- SessionStart hook, prompt injection only → Task 2, Task 3.
- `INSIGHTS_LANG`, default `de`, code or name → Task 3 (case map), README in Task 4.
- Sanitize the value → Task 3 (`tr -cd`), tested by the injection case.
- Two stacked boxes, localized second header → Task 3 instruction, README sample.
- English target falls back to one box → Task 3 `bilingual=0` branch, tested.
- Dependency-free (no jq/python) → Task 3 uses only bash builtins and `tr`/`printf`.
- Token-cost note → README in Task 4.
- Positioning (two use cases) → README "Why you might want it".

**Placeholder scan:** none. `__LANG__` is a real runtime placeholder the script substitutes, not a plan gap.

**Type/name consistency:** marketplace name `bilingo-insights` and plugin name `bilingo-insights` give the install id `bilingo-insights@bilingo-insights`, matching the README. Hook path in `hooks.json` (`hooks-handlers/session-start.sh`) matches the file created in Task 3 and the path the test calls.
