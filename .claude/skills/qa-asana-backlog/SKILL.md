---
name: qa-asana-backlog
description: Pulls a batch of completed bug tickets from an Asana project and QA-verifies each one as a dynamic multi-agent workflow, producing ExUnit regression tests and a pass/fail summary. Use when the user asks to "verify recent bug fixes", "QA the backlog", "pull bug tickets from Asana and check them", or similar batch verification. For a single known ticket, use qa-asana-ticket instead.
---

# QA the Asana Backlog

Batch-verify completed bug tickets from Asana against the current application,
orchestrated as a dynamic workflow that scales with the number of tickets.

**REQUIRED SUB-SKILL:** qa-asana-ticket — every ticket is verified by a
sub-agent running that skill. Do not restate or improvise its per-ticket steps
here; if its behavior needs to change, change that skill.

## Instructions

### Step 1: Gather preconditions

Use `AskUserQuestion` to collect, before doing anything else:

1. **Asana project** — recall previous choices from memory and present them as
   pre-selected defaults; offer to search by name
   (`mcp__claude_ai_Asana__asana_typeahead_search`) for anything else
2. **Environment** — local in the main worktree | local on another branch in
   its own worktree | dev-green | dev-orange | staging
3. **Scope** — how many tickets, from what time frame (offer 1 week, 1 month,
   3 months, 6 months, 1 year, custom)

If the chosen environment is deployed (dev-green / dev-orange / staging),
ensure an authenticated session exists NOW, while the session is still
interactive: REQUIRED SUB-SKILL — qa-capture-auth-session for that env. It
reuses a still-valid saved session or pauses for the user to log in once.
Skipping this guarantees every dispatched agent reports blocked at the
Keycloak wall and silently degrades to local-checkout verification.

### Step 2: Pull tickets

Use `mcp__claude_ai_Asana__asana_search_tasks` scoped to the chosen project:
completed tasks, completion date within the time frame. Bug tickets typically
have a bug, caterpillar, or similar emoji (🐛 🪲 🐞 …) in the title — filter on
that, newest first, up to the requested count. If too few match, say so and
show what you found rather than padding with non-bug tickets.

### Step 3: Confirm with the user

Present the candidate tickets with their Asana links and one-line summaries,
then use `AskUserQuestion` to get explicit approval or swaps. Do NOT proceed
without confirmation. (Interactive questions cannot happen inside the workflow,
so all asking ends here.)

### Step 4: Run the verification workflow

Run the batch via the `Workflow` tool, passing the confirmed tickets and
environment as `args` (actual JSON, not a string). Adapt this canonical script
rather than inventing a new shape:

```javascript
export const meta = {
  name: 'qa-asana-backlog',
  description: 'Verify completed Asana bug tickets and challenge surprising verdicts',
  phases: [
    { title: 'Verify', detail: 'one verify agent per ticket' },
    { title: 'Challenge', detail: 'skeptic re-check of still-present verdicts' },
  ],
}
// args: { tickets: [{ gid, name, url }], env: 'dev-green', mode: 'write-test' }
// args may arrive as a JSON string instead of a parsed object — always shim:
const A = typeof args === 'string' ? JSON.parse(args) : args
const VERDICT = {
  type: 'object',
  required: ['ticket_gid', 'verdict', 'criteria'],
  properties: {
    ticket_gid: { type: 'string' },
    verdict: { enum: ['pass', 'fail', 'conditional_pass', 'blocked'] },
    criteria: { type: 'array', items: { type: 'object', properties: {
      name: { type: 'string' },
      result: { enum: ['pass', 'fail', 'conditional_pass', 'blocked'] },
      note: { type: 'string' } } } },
    test_file: { type: ['string', 'null'] },
    test_result: { type: ['string', 'null'] },
    report_path: { type: ['string', 'null'] },
    notes: { type: 'string' },
  },
}
// The workflow runtime cannot resolve project-level .claude/agents/ types, so use
// general-purpose agents and inline the persona + hard constraints in every prompt:
const guardrails = 'You are an expert QA engineer for the MBTA Alerts UI. HARD CONSTRAINTS: ' +
  'Asana is READ-ONLY (never create/update/delete tasks). Any alert create/edit/duplicate URL ' +
  'must contain /mono/. Never modify data on dev-green/dev-orange/staging; local test data is OK. ' +
  'No root-cause analysis — demonstrating the bug is the deliverable. '
const browserRule = 'Drive the browser by writing your own throwaway headless Playwright ' +
  'script and running it with Bash (toolkit: .claude/skills/qa-asana-ticket/scripts/, adapt ' +
  'example-verify.mjs) — a private browser per script, NEVER the shared MCP browser. ' +
  'Deployed envs: example-verify.mjs auto-loads the saved auth session ' +
  '(scripts/.auth/<env>-state.json) so your context starts signed in; if a page still ' +
  'bounces to a Keycloak login, the session expired — report blocked, never attempt to log in. '

const results = await pipeline(
  A.tickets,
  t => agent(
    guardrails + `Invoke the qa-asana-ticket skill with args "ticket=${t.gid} env=${A.env} mode=${A.mode}" ` +
    `and follow it exactly. ${browserRule} Write your test in its own file under ` +
    `test/alerts_ui_web/tickets/ — never a shared file. Do NOT append to the cumulative ` +
    `summary file; the orchestrator does that. Ticket: "${t.name}" (${t.url})`,
    { label: `verify:${t.gid}`, phase: 'Verify', schema: VERDICT,
      agentType: 'general-purpose' }
  ),
  // Challenge surprising outcomes: a "fail" verdict sends devs hunting,
  // so it must survive an independent refutation attempt before we report it.
  (r, t) => !r || r.verdict !== 'fail' ? r :
    agent(
      guardrails + `A QA agent claims Asana ticket "${t.name}" (${t.url}, gid ${t.gid}) FAILS verification ` +
      `(bug still present / criteria unmet) on env ${A.env}. Adversarially re-check: invoke ` +
      `the qa-asana-ticket skill with args "ticket=${t.gid} env=${A.env} mode=verify-only" ` +
      `and try to REFUTE the claim (drifted UI? wrong selector? missing test data you may ` +
      `create locally?). ${browserRule}`,
      { label: `challenge:${t.gid}`, phase: 'Challenge', schema: VERDICT,
        agentType: 'general-purpose' }
    ).then(c => ({ ...r, challenge: c,
      verdict: c.verdict === 'fail' ? 'fail' : 'disputed' }))
)
const out = results.filter(Boolean)
log(`${out.length}/${A.tickets.length} tickets verified; ` +
  `${out.filter(r => r.verdict === 'pass').length} pass, ` +
  `${out.filter(r => r.verdict === 'fail').length} fail, ` +
  `${out.filter(r => r.verdict === 'conditional_pass').length} conditional, ` +
  `${out.filter(r => r.verdict === 'disputed').length} disputed, ` +
  `${out.filter(r => r.verdict === 'blocked').length} blocked`)
return { results: out, skipped: A.tickets.length - out.length }
```

Scaling notes:

- `pipeline`, not `parallel`: a ticket's Challenge runs while other tickets are
  still in Verify — no barrier
- Scripted private browsers (see qa-asana-ticket's browser rule) eliminate
  cross-agent browser contention entirely; the remaining throughput limits are
  the dev server and concurrent `mix test` compile locks
- A `null` result means the agent was skipped or errored — report it as
  skipped, never silently drop it
- **Fallback:** if the `Workflow` tool is unavailable in this context, dispatch
  the same prompts as parallel `Agent` calls in one message
  (`subagent_type: qa-verification-engineer` — the Agent tool, unlike the
  workflow runtime, does resolve project-level agents) and run Challenge
  prompts for any fail verdicts afterwards.

### Step 5: Aggregate and report

Summarize in a table: ticket (linked) | verdict | criteria passed | test file |
test result. Call out failing, **disputed** (verify and challenge disagreed —
needs a human look), conditional-pass, blocked, and skipped tickets explicitly.
Per-ticket reports and evidence live under the **active checkout's**
`qa/` (never a hardcoded path — worktree-isolated sessions can't
write outside their checkout). Finally, append one line per ticket (date,
ticket, verdict, report path) to the cumulative summary
`qa/summary.md` — the orchestrator does this once; per-ticket
agents must not.

The header of the file should be amended to be a general summary of the health
of the ticket-related test suite: Passes, Fails, Blocked, Total, notable places
where failures occur and/or reasons why, and any other notes that might be
relevant to someone viewing an overview of the health of these tests.

## Constraints

- The constraints in qa-asana-ticket bind every sub-agent — notably the
  `/mono/` URL rule for alert create/edit/duplicate, and read-only treatment of
  dev-green / dev-orange / staging
- One ticket per Verify agent; don't fan out beyond the confirmed list

## Troubleshooting

**Sub-agent says it can't invoke the skill:** The `qa-verification-engineer`
agent definition (`.claude/agents/qa-verification-engineer.md`) must include
`Skill` in its tools list.

**Workflow agents can't reach Asana/Playwright tools:** Workflow subagents load
MCP schemas via ToolSearch on demand; if the connector itself is disconnected
(common in headless runs), reconnect it or fall back to `Agent` dispatch.

**Asana search returns nothing:** Check the project GID, and widen the time
frame before concluding there are no bug tickets.
