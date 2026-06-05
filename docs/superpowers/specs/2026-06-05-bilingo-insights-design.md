# bilingo-insights design

**Date:** 2026-06-05
**Author:** Artem Iagovdik (artyom.yagovdik@gmail.com)
**Status:** Implemented, updated for v2.0.0 (multilingual list)

## Summary

`bilingo-insights` is a standalone Claude Code plugin. It recreates the
explanatory output style, but each insight is rendered once per language in an
ordered list. `INSIGHTS_LANG` holds that list (default `en,de`, English then
German). One language gives a single box, three give three.

The plugin ships nothing executable beyond a single `SessionStart` hook. The
hook injects an instruction into the system prompt. The model writes every
language inline. There is no translation API and no parsing of model output.

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

- Env var `INSIGHTS_LANG` is an ordered, comma-separated list of languages.
  Default: `en,de`. The first entry is the canonical box; the rest translate it.
- Each entry is a code or a name (`de`, `German`, `fr`, `français`). Codes map to
  names via a small table; unknown values pass through, and the model handles
  either form.
- One entry gives a single box. Two or more give one box each, in list order.
- Set it in a shell profile, or in the `env` block of Claude Code
  `settings.json`, which is more reliable across shells.
- The hook splits on commas, trims and sanitizes each entry to `[A-Za-z0-9 _-]`,
  drops empties, and drops repeats (case-insensitive, first wins). If nothing
  valid survives, it falls back to `en,de`. A malformed variable cannot break
  the emitted JSON.

### Output format

One stacked box per language, in list order. Each non-English header is
localized.

```
★ Insight ─────────────────────────────
- <2-3 codebase-specific points in the first language>
────────────────────────────────────────
★ Einblick ────────────────────────────
- <the same points, faithfully translated>
────────────────────────────────────────
★ Aperçu ──────────────────────────────
- <the same points again, in the third language>
────────────────────────────────────────
```

Rules the instruction enforces:

- The first box is the canonical insight. Every later box mirrors the same
  points. It does not add, drop, or invent content.
- Each box header uses the word for "Insight" in its language (`Insight`,
  `Einblick` for German, `Aperçu` for French, and so on). The model supplies the
  localized words.
- 2-3 points, codebase-specific, before and after writing code, the same cadence
  as the original explanatory style.
- A single-language list emits one box with no translation rule. If that
  language is English, the output matches the original explanatory style.

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
│           └── session-start.sh   # builds and injects the multilingual instruction
├── docs/
│   └── superpowers/specs/         # this design doc
├── README.md
└── LICENSE                        # MIT, Artem Iagovdik
```

## Hook internals

`session-start.sh`:

1. Read `INSIGHTS_LANG`, default `en,de`.
2. Split on commas. Trim and sanitize each entry to `[A-Za-z0-9 _-]`, resolve
   codes to names, drop empties and repeats. Empty list → `en,de`.
3. Build the instruction. One language uses a single-box template (placeholder
   swap for the name). Two or more build the box block in a loop, one box per
   language. The whole string is then JSON-escaped in pure bash, so JSON stays
   valid with no `jq` or `python` dependency.
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
  keywords (insights, multilingual, bilingual, i18n, explanatory, translation,
  learning).
- `plugin.json`: name `bilingo-insights`, version `2.0.0`, author Artem
  Iagovdik (artyom.yagovdik@gmail.com), description covering the multilingual
  explanatory behavior and the `INSIGHTS_LANG` list.

## README

- What it does and how it works (the `SessionStart` hook pattern).
- The two use cases from Positioning: read insights in your mother tongue, or
  learn a language through the code you already read.
- Install via marketplace, then enable the plugin.
- Configure `INSIGHTS_LANG` (shell profile and `settings.json` `env` examples).
- Sample output showing the stacked boxes.
- Token-cost note: each language adds a copy of the insight, so two roughly
  doubles output and three roughly triples it. Translated text often runs longer
  than English (German especially). Same warning the official plugin carries.
- Branding is the author's own. No association with any language-learning
  product.

## Out of scope

- No translation API or network calls.
- No per-message language switching; the language list is set per session via
  the env var.
