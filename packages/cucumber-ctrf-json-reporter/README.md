# cucumber-ctrf-json-reporter

A [cucumber-js](https://github.com/cucumber/cucumber-js) formatter that
emits [CTRF](https://ctrf.io) JSON.

Fills the gap in the CTRF ecosystem — there are native reporters for
Jest, Mocha, Playwright, Cypress, Vitest, Jasmine, WebdriverIO, but none
for cucumber-js. With this you get real `retries` / `flaky` fields
(tracked across cucumber's `--retry` attempts) instead of the lossy path
through `junit-to-ctrf`.

## Install

```
npm install --save-dev cucumber-ctrf-json-reporter
```

## Use

Via `cucumber.yaml`:

```yaml
default:
  format:
    - "summary"
    - "cucumber-ctrf-json-reporter:reports/ctrf.json"
```

Or CLI:

```
cucumber-js --format 'cucumber-ctrf-json-reporter:reports/ctrf.json'
```

Output is a CTRF report with `retries`, `flaky`, `retryAttempts` populated
per scenario based on cucumber-js's attempt counter. Run it alongside
`ctrf-io/github-test-reporter` in CI for rich PR-level flakiness reports.

## What it maps

| Cucumber concept | CTRF field |
|------------------|------------|
| Pickle (scenario) | `test` |
| Pickle name | `test.name` |
| Pickle tags | `test.tags` |
| Pickle URI | `test.filePath` |
| TestCaseStarted attempt count | `test.retries` |
| Final-attempt status rolled up from step results | `test.status` |
| passed after retries | `test.flaky = true` |
| Earlier attempts | `test.retryAttempts[]` |
| TestStepResult.message / exception.stackTrace | `test.message` / `test.trace` |

## Status rollup

Cucumber step statuses map via priority: `FAILED > AMBIGUOUS > UNDEFINED
> PENDING > SKIPPED > PASSED > UNKNOWN`. The winning step's status
becomes the scenario status.
