# Playwright tests

## What should be a Playwright test vs an ExUnit test?
There are two types of tests that are better suited for Playwright:
1. Tests that are very dependent on specific user or JS interaction. 
    1. For example, the copy button so we can inspect the clipboard, or some modal logic, since our ExUnit tests have a hard time figuring out if a modal is visible or not.
2. True E2E, smoke-test like tests

We currently only really have Playwright tests of type 1, as we haven't discussed what automated smoke testing might look like. We would probably base it off of [this manual QA doc](https://github.com/mbta/alerts_ui/blob/9b25cfb446eaa6941d2e4ec7e86303c07458a0d6/docs/regression-testing.md) though, and run it against one of our dev environments. For example, perhaps against staging whenever we have a release candidate ready.

## Developing
Some docs on tools that are really useful for developing Playwright tests:
- [UI Mode](https://playwright.dev/docs/test-ui-mode) lets you step through a step and see what it is doing in a 'browser'. There is also a handy button that lets you click on an element and it'll tell you how to hit that element via a selector.
- [VS Code extension](https://playwright.dev/docs/getting-started-vscode) lets you run individual tests from within VS Code. You can also use it to find selectors, and even record yourself clicking through your site and it will generate selectors to use.

## In CI
If a Playwright test fails in CI, it will upload an artifact under the task "Upload playwright report". The task will give you an "Artifact download URL" which is a zip file. You can download this file, then open the `index.html` and see where your test went wrong.

You can even view a trace for a failed tests, which is essentially a visual replay of what happened in the test. 

## Caveats
Currently, we are hitting the real MBTA API in our Playwright tests, which isn't ideal. Not only because we are hitting an external API, but also because the API data itself changes at least each rating. So we try to write our tests to not be trip ID specific, or to use Subway data which is more stable.

More investigation is needed to see if we can mock out our API calls. Playwright offers great support for mocking client side HTTP calls, but since these calls are all made on the server side (and there are a lot of them), it is more difficult.