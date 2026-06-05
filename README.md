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
