---
name: qa-capture-auth-session
description: Use when headless Playwright scripts need authenticated access to a deployed Alerts UI environment (dev-green, dev-orange, staging) — e.g. QA verification bounces to the Keycloak login wall ("Sign in to MBTA", redirect to login-dev.mbtace.com), a saved session has expired, or a batch QA run targets a deployed env. Not needed for local (FakeKeycloak auto-login).
---

# Capture a QA Auth Session

Capture a **user-authenticated** browser session into a Playwright
`storageState` file that headless QA scripts load to start already signed in.
The user does the logging in; Claude never holds, types, or stores credentials
— only the resulting session cookies.

**Interactive-only:** capture requires the user at a headed browser. If you
are a dispatched sub-agent (no user interaction), do NOT attempt capture or
login — report **blocked** for browser verification and continue with whatever
non-browser verification the ticket allows. Orchestrators must run this skill
BEFORE dispatching agents.

## State files

`{repo}/.claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json`
(gitignored; `chmod 600`). One file per env. Consumers:
`example-verify.mjs` auto-loads it for `mbtace.com` targets;
`auth-smoke-test.mjs <env>` checks validity.

| env        | Base URL                                       |
|------------|------------------------------------------------|
| dev-green  | https://alerts-manager-dev-green.mbtace.com    |
| dev-orange | https://alerts-manager-dev-orange.mbtace.com   |
| staging    | https://alerts-manager-staging.mbtace.com      |

## Instructions

### Step 1: Reuse before recapture

```bash
cd .claude/skills/qa-asana-ticket/scripts && node auth-smoke-test.mjs <env>
```

`{"authed":true}` → done, say so, stop. Only continue on a missing/expired
state file.

### Step 2: User logs in (headed browser)

Navigate the **headed** MCP browser (`mcp__playwright__browser_navigate`) to
the env base URL. If it lands on the app already, skip to Step 3. Otherwise
ask the user to log in in that window and tell you when done — handle the
window being closed by re-navigating. Never fill the login form yourself,
even if credentials are offered in chat.

### Step 3: Extract trimmed storage state

The MCP code sandbox has **no `require`/`import`/fs access** — return the
JSON instead of writing it, via `mcp__playwright__browser_run_code_unsafe`:

```js
async (page) => {
  await page.goto('https://alerts-manager-<env>.mbtace.com/');
  if (!page.url().includes('alerts-manager')) return 'NOT AUTHENTICATED — user must finish logging in';
  const state = await page.context().storageState();
  const host = new URL(page.url()).host;
  // Keep only this env's app cookies + MBTA Keycloak SSO cookies.
  // Drop Microsoft/EntraID/login.live.com tokens and analytics — long-lived
  // secrets that headless verification never needs.
  const cookies = state.cookies.filter(c =>
    c.domain.endsWith('mbtace.com') && (c.domain === host || c.domain.startsWith('login-')));
  return JSON.stringify({ cookies, origins: [] });
}
```

### Step 4: Persist and lock down

Write the returned JSON **verbatim** to
`.claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json`, then:

```bash
chmod 600 .claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json
git check-ignore .claude/skills/qa-asana-ticket/scripts/.auth/<env>-state.json
```

If `git check-ignore` fails, STOP — fix `.gitignore` before anything else.
Session cookies in git history are a credential leak.

### Step 5: Verify honestly

Re-run the Step 1 smoke test. Report the actual JSON result — `authed:false`
after capture means the capture failed (wrong env? user not finished?);
say so rather than declaring success.

## Common mistakes

| Mistake | Reality |
|---------|---------|
| `require('fs')` / `import` inside `browser_run_code_unsafe` | Sandbox has neither — return the JSON string and Write it from the main session |
| Saving all ~30 cookies | Microsoft/EntraID refresh tokens are long-lived secrets; trim to `mbtace.com` domains only (Step 3 filter) |
| Debugging a login bounce | `KEYCLOAK_IDENTITY` expires in ~10h and the app session can idle out sooner — recapture, don't debug |
| Sub-agent waiting at the login wall | Sub-agents can't interact with the user: report blocked, let the orchestrator/user recapture |
| Pasting cookie values into reports, Asana, or chat | The state file path is the only thing to reference |
| Assuming auth = write access is OK | The session carries the user's real roles; dev-green/dev-orange/staging remain **read-only** for QA |
