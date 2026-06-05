#!/usr/bin/env node
// End-to-end test for the bilingo-insights plugin.
// Exercises the real wiring rather than calling the script directly: it reads
// the manifests, pulls the SessionStart command out of hooks.json, runs that
// exact command the way Claude Code would (with CLAUDE_PLUGIN_ROOT set), then
// parses the emitted hook output and checks its shape. node is fine here; only
// the hook itself must stay dependency-free.

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
const pluginRoot = path.join(repoRoot, 'plugins', 'bilingo-insights');

let fail = 0;
function check(name, cond) {
  console.log(`${cond ? 'ok  ' : 'FAIL'} - ${name}`);
  if (!cond) fail = 1;
}
function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

// 1. Manifests parse and agree with each other.
const marketplace = readJson(path.join(repoRoot, '.claude-plugin', 'marketplace.json'));
const plugin = readJson(path.join(pluginRoot, '.claude-plugin', 'plugin.json'));
const hooks = readJson(path.join(pluginRoot, 'hooks', 'hooks.json'));

const entry = (marketplace.plugins || []).find((p) => p.name === plugin.name);
check('marketplace.json parses with a name', !!marketplace.name);
check('plugin.json parses with a name', !!plugin.name);
check('marketplace lists this plugin', !!entry);
check(
  'versions agree (2.0.0)',
  plugin.version === '2.0.0' &&
    marketplace.metadata.version === '2.0.0' &&
    entry &&
    entry.version === '2.0.0'
);

// 2. The marketplace source path resolves to a real plugin directory.
const resolvedSource = entry ? path.resolve(repoRoot, entry.source) : '';
check('marketplace source path exists', !!resolvedSource && fs.existsSync(resolvedSource));
check(
  'source contains plugin.json',
  !!resolvedSource && fs.existsSync(path.join(resolvedSource, '.claude-plugin', 'plugin.json'))
);

// 3. hooks.json declares a SessionStart command pointing at a script that exists.
const sessionStart = hooks.hooks && hooks.hooks.SessionStart;
check('hooks.json declares SessionStart', Array.isArray(sessionStart) && sessionStart.length > 0);
const command = sessionStart && sessionStart[0].hooks[0].command;
check('SessionStart has a command string', typeof command === 'string' && command.length > 0);
const handler = path.join(pluginRoot, 'hooks-handlers', 'session-start.sh');
check('handler script exists', fs.existsSync(handler));

// 4. Run the exact command, with CLAUDE_PLUGIN_ROOT set, across several
//    INSIGHTS_LANG settings, and validate the parsed hook output.
function runHook(insightsLang) {
  const env = { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot };
  if (insightsLang === null) delete env.INSIGHTS_LANG;
  else env.INSIGHTS_LANG = insightsLang;
  try {
    return execSync(command, { env, encoding: 'utf8' });
  } catch (e) {
    return '';
  }
}

function validShape(out, expectContains) {
  let obj;
  try {
    obj = JSON.parse(out);
  } catch (e) {
    return false;
  }
  const h = obj.hookSpecificOutput;
  if (!h || h.hookEventName !== 'SessionStart') return false;
  if (typeof h.additionalContext !== 'string' || h.additionalContext.length === 0) return false;
  if (expectContains && !h.additionalContext.includes(expectContains)) return false;
  return true;
}

const scenarios = [
  { name: 'default (unset) -> English then German', lang: null, contains: 'in order: English, German' },
  { name: 'de -> single German box', lang: 'de', contains: 'Write each insight in' },
  { name: 'en,de,fr -> three languages in order', lang: 'en,de,fr', contains: 'in order: English, German, French' },
  { name: 'en -> single English box', lang: 'en', contains: '★ Insight' },
];
for (const s of scenarios) {
  check(`e2e run: ${s.name}`, validShape(runHook(s.lang), s.contains));
}

// 5. Malformed input passed via the env var still yields parseable hook JSON.
check(
  'e2e run: malformed INSIGHTS_LANG still yields valid hook JSON',
  validShape(runHook('de"; rm -rf /'), null)
);

process.exit(fail);
