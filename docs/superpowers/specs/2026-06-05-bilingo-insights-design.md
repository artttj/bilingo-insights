# bilingo-insights design

**Date:** 2026-06-05
**Author:** Artem Iagovdik (artyom.yagovdik@gmail.com)
**Status:** Approved for planning

## Summary

`bilingo-insights` is a standalone Claude Code plugin. It recreates the
explanatory output style, but every insight is shown twice: once in English,
then the same points translated into a configured language. German is the
default.

The plugin ships nothing executable beyond a single `SessionStart` hook. The
hook injects an instruction into the system prompt. The model writes both
languages inline. There is no translation API and no parsing of model output.

## Positioning

The same feature works in two directions, depending on which language you set:

- **Understand faster in your mother tongue.** Code and its explanations are
  almost always in English. Set `INSIGHTS_LANG` to your native language and a
  complex concept lands in the language you actually think in, right next to
  the English the rest of the field uses.
- **Learn a language while you code.** Set `INSIGHTS_LANG` to a language you
  are learning. You already read code for hours, so now every insight comes
  with its translation. You pick up real technical vocabulary in context,
  session after session, without leaving your editor.

English is always present, so you never lose the canonical version. The second
language is the one you choose for whichever goal you have.

## Why this approach

The official `explanatory-output-style` plugin is a `SessionStart` hook that
injects an `additionalContext` string telling Claude to emit `★ Insight`
blocks. That is the whole plugin, just prompt injection. `bilingo-insights`
uses the same mechanism with a bilingual instruction plus a language selector.

Alternatives considered and rejected:

- **Translation API in the hook (DeepL, etc.).** The insights do not exist at
  `SessionStart`, so the hook has nothing to translate. It would need to
  intercept model output, which this hook stage cannot do. Adds API keys,
  latency, and failure modes for no benefit.
- **Subagent / output style.** Insights happen inline during normal
  development. A `SessionStart` hook fits that. A subagent swaps the whole
  system prompt, which is not wanted here.

## Behavior

### Language selection

- Env var `INSIGHTS_LANG` picks the second language. Default: `de`.
- Accepts a code or a name (`de`, `German`, `fr`, `français`). The value is
  passed through to the instruction as the target language; the model handles
  either form.
- Set it in a shell profile, or in the `env` block of Claude Code
  `settings.json`, which is more reliable across shells.
- The hook sanitizes the value to `[A-Za-z0-9 _-]` before injecting, so a
  malformed variable cannot break the emitted JSON. An empty result falls back
  to `de`.

### Output format

Two stacked boxes per insight. The second box header is localized to the target
language.

```
★ Insight ─────────────────────────────
- <2-3 codebase-specific points in English>
────────────────────────────────────────
★ Einblick ────────────────────────────
- <the same points, faithfully translated>
────────────────────────────────────────
```

Rules the instruction enforces:

- The translated box mirrors the same points. It does not add, drop, or invent
  content.
- The second header uses the word for "Insight" in the target language
  (`Einblick` for German, `Aperçu` for French, and so on). The model supplies
  this.
- 2-3 points, codebase-specific, before and after writing code, the same
  cadence as the original explanatory style.
- If the target language resolves to English, emit a single English box. No
  pointless duplicate.

## Repository layout

Follows the rapid-stack pattern: a marketplace at the repo root pointing at a
plugin in `plugins/`.

```
bilingo-insights/
├── .claude-plugin/
│   └── marketplace.json          # marketplace listing → ./plugins/bilingo-insights
├── plugins/
│   └── bilingo-insights/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── hooks/
│       │   └── hooks.json         # SessionStart → session-start.sh
│       └── hooks-handlers/
│           └── session-start.sh   # builds and injects the bilingual instruction
├── docs/
│   └── superpowers/specs/         # this design doc
├── README.md
└── LICENSE                        # MIT, Artem Iagovdik
```

## Hook internals

`session-start.sh`:

1. Read `INSIGHTS_LANG`, default `de`.
2. Sanitize to `[A-Za-z0-9 _-]`; empty → `de`.
3. Substitute the language into a pre-escaped instruction string (placeholder
   swap). The static instruction is stored already JSON-escaped, so only the
   sanitized language token is interpolated. JSON stays valid with no `jq` or
   `python` dependency.
4. Print the `hookSpecificOutput` JSON, the same shape as the official
   `session-start.sh`:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<bilingual instruction with target language>"
  }
}
```

Dependency-free bash matters: `SessionStart` runs on every session on whatever
machine installed the plugin. A missing `jq`/`python` would silently break
insights for some users.

## Manifests

- `marketplace.json`: name `bilingo-insights`, owner Artem Iagovdik, one plugin
  entry with `source: ./plugins/bilingo-insights`, category `productivity`,
  keywords (insights, bilingual, i18n, explanatory, translation, learning).
- `plugin.json`: name `bilingo-insights`, version `1.0.0`, author Artem
  Iagovdik (artyom.yagovdik@gmail.com), description covering the bilingual
  explanatory behavior and the `INSIGHTS_LANG` variable.

## README

- What it does and how it works (the `SessionStart` hook pattern).
- The two use cases from Positioning: read insights in your mother tongue, or
  learn a language through the code you already read.
- Install via marketplace, then enable the plugin.
- Configure `INSIGHTS_LANG` (shell profile and `settings.json` `env` examples).
- Sample output showing the two boxes.
- Token-cost note: this roughly doubles insight output, and the translated text
  often runs longer than English (German especially). Same warning the official
  plugin carries.
- Branding is the author's own. No association with any language-learning
  product.

## Out of scope

- No translation API or network calls.
- No more than two languages at once (English + one target).
- No per-message language switching; the language is set per session via the
  env var.
