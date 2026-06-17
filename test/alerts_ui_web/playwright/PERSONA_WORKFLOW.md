# Three-persona evaluation workflow

Each proving-slice spec is shaped by a three-persona evaluation, run from the
**main Claude session** via the `Workflow` tool (it needs `Workflow`, which
subagents don't have). For a test case, run the script below with that case's
`caseName`, the relevant `docs/regression-testing.md` excerpt, the target `url`,
and `env: 'local'`.

Personas inspect the **live app** with throwaway headless Playwright `.mjs`
scripts (toolkit: `.claude/skills/qa-asana-ticket/scripts/`, adapt
`example-verify.mjs`) — never the shared MCP browser, and never submitting data
on a `*.mbtace.com` env. The reconcile step returns `{ encode, reportBugs }`:

- `encode` — deterministic assertions to bake into the spec (as checks +
  `// consensus:` comments). Flaky/timing-fragile ideas are dropped.
- `reportBugs` — suspected real app bugs or doc discrepancies, surfaced to the
  user, **not** silently encoded as passing assertions.

```javascript
export const meta = {
  name: 'e2e-persona-eval',
  description: 'Evaluate one regression test case via three personas and reconcile a consensus',
  phases: [{ title: 'Personas' }, { title: 'Reconcile' }],
}
// args: { caseName, docExcerpt, url, env: 'local' }
const A = typeof args === 'string' ? JSON.parse(args) : args
const browserRule = 'Inspect the LIVE app by writing a throwaway headless Playwright .mjs ' +
  'script (toolkit: .claude/skills/qa-asana-ticket/scripts/, adapt example-verify.mjs) and ' +
  'running it with Bash. Alert create/edit/duplicate URLs MUST contain /mono/. Drive controls ' +
  'like a human (.click()/press/type) — never set .checked/.value with synthetic events. ' +
  'Do NOT submit/create data on any *.mbtace.com env.'
const FINDINGS = { type: 'object', required: ['assertions', 'suspectedBugs'], properties: {
  assertions: { type: 'array', items: { type: 'string' } },
  suspectedBugs: { type: 'array', items: { type: 'object', properties: {
    title: { type: 'string' }, evidence: { type: 'string' } } } },
  fuzzInputs: { type: 'array', items: { type: 'string' } } } }

const personas = [
  ['qa', 'a senior QA engineer maximizing edge/corner coverage'],
  ['skeptic', 'a skeptic trying to PROVE the app has real bugs that must be fixed'],
  ['fuzzer', 'an adversary generating random/hostile inputs to break things'],
]
const found = await parallel(personas.map(([key, role]) => () =>
  agent(`You are ${role}. Test case: "${A.caseName}". Target ${A.url} on env ${A.env}. ` +
    `Regression doc excerpt:\n${A.docExcerpt}\n\n${browserRule} Return concrete Playwright-style ` +
    `assertions to encode, any suspected real bugs with evidence, and fuzz inputs you tried.`,
    { label: `persona:${key}`, phase: 'Personas', schema: FINDINGS })))
const valid = found.filter(Boolean)
const consensus = await agent(
  `Reconcile these three persona reports for test case "${A.caseName}" into a single consensus: ` +
  `the deduped set of assertions worth encoding (stable, deterministic ones only — drop flaky/ ` +
  `timing-fragile ideas), and a separate list of suspected real app bugs to report to the user ` +
  `(NOT to encode as passing assertions). Reports:\n${JSON.stringify(valid)}`,
  { phase: 'Reconcile', schema: { type: 'object', required: ['encode', 'reportBugs'], properties: {
    encode: { type: 'array', items: { type: 'string' } },
    reportBugs: { type: 'array', items: { type: 'object', properties: {
      title: { type: 'string' }, evidence: { type: 'string' } } } } } } })
return consensus
```
