# 🔄 Migration test dashboard — mockup

A static rendering of what the ideal migration-test report could look like in
GitHub's markdown renderer. Each section probes a different diagram type to
see which actually render in GitHub's pinned Mermaid.

Data is realistic-fake, modeled after a typical run of the integration suite.

---

## Headline

> 🔴 **1 regression**   🟢 **1 recovery**   ⏱ post is **490ms faster**   📐 step coverage: **92% → 88%**

## Pre vs Post summary

| Metric | Pre-upgrade | Post-upgrade | Δ |
|---|---|---|---|
| Tests 📝 | 12 | 12 | 0 |
| Passed ✅ | 10 | 10 | 0 |
| Failed ❌ | 1 | 1 | 0 |
| Skipped ⏭️ | 1 | 1 | 0 |
| Flaky 🍂 | 1 | 2 | +1 |
| Duration ⏱️ | 5.49s | 5.00s | -490ms |

## 🔴 Regressed (passed → failed)

| Test | Pre | Post | Duration |
|---|---|---|---|
| [Schema column type](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/features/items.feature#L57) | ✅ pass | ❌ AssertionError: schema column type changed unexpectedly | 130ms → 66ms |

## 🟢 Recovered (failed → passed)

| Test | Pre | Post | Duration |
|---|---|---|---|
| [Known issue](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/features/items.feature#L61) | ❌ index missing on legacy schema | ✅ pass | 188ms → 179ms |

## 🍂 Tests that needed retries

| Test | Pre attempts | Post attempts |
|---|---|---|
| [Network jitter retries cleanly](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/features/items.feature#L43) | 1 attempt | 3 attempts |
| [Occasionally flaky — UI render timing](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/features/items.feature#L23) | 2 attempts | 1 attempt |

---

## Where did the time go? (Treemap)

```mermaid
treemap-beta
"Test execution"
    "pre-upgrade"
        "Backend health check": 38
        "API create and list": 69
        "UI adds an item end-to-end": 359
        "UI render timing (flaky)": 432
        "Workload fast": 23
        "Workload medium": 344
        "Workload slow": 933
        "Workload glacial": 2300
        "Network jitter": 129
        "Schema column type (REGRESSED)": 130
        "Known issue (RECOVERED)": 188
    "post-upgrade"
        "Backend health check": 42
        "API create and list": 71
        "UI adds an item end-to-end": 220
        "UI render timing (flaky)": 411
        "Workload fast": 28
        "Workload medium": 352
        "Workload slow": 911
        "Workload glacial": 2100
        "Network jitter": 410
        "Schema column type (REGRESSED)": 66
        "Known issue (RECOVERED)": 179
```

(Fallback if treemap doesn't render)

---

## Execution timeline (Gantt)

```mermaid
gantt
    title Test execution timeline (ms)
    dateFormat x
    axisFormat %S.%L
    section Pre-upgrade
    Backend health check     :0, 38
    API create and list      :38, 107
    UI adds an item          :107, 466
    UI render timing         :466, 898
    Workload fast            :898, 921
    Workload medium          :921, 1265
    Workload slow            :1265, 2198
    Workload glacial         :2198, 4498
    Network jitter           :4498, 4627
    Schema column type       :4627, 4757
    Known issue              :4757, 4945
    section Post-upgrade
    Backend health check     :5000, 5042
    API create and list      :5042, 5113
    UI adds an item          :5113, 5333
    UI render timing         :5333, 5744
    Workload fast            :5744, 5772
    Workload medium          :5772, 6124
    Workload slow            :6124, 7035
    Workload glacial         :7035, 9135
    Network jitter           :9135, 9545
    Schema column type       :9545, 9611
    Known issue              :9611, 9790
```

---

## Pass/fail breakdown (Pie)

```mermaid
pie title Post-upgrade outcomes
    "Passed" : 10
    "Failed" : 1
    "Skipped" : 1
```

---

## Phase comparison (xychart-beta)

```mermaid
xychart-beta
    title "Per-test duration: pre vs post (ms)"
    x-axis [Backend, API, UI-add, UI-render, fast, medium, slow, glacial, jitter, schema, known]
    y-axis "Duration (ms)" 0 --> 2500
    bar [38, 69, 359, 432, 23, 344, 933, 2300, 129, 130, 188]
    bar [42, 71, 220, 411, 28, 352, 911, 2100, 410, 66, 179]
```

---

## Test-set diff flow (Sankey-beta)

```mermaid
sankey-beta

Pre passed,Post passed,9
Pre passed,Post failed,1
Pre failed,Post passed,1
Pre skipped,Post skipped,1
```

---

## Drill-down (nested details)

<details>
<summary>📂 components/integration/features/items.feature (post-upgrade)</summary>

<details>
<summary>❌ <b>Schema column type — passes pre, fails post</b> · 66ms</summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| When a migration-sensitive operation runs | ❌ | 66ms | [steps.ts:102](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/steps/steps.ts#L102) |

```text
AssertionError [ERR_ASSERTION]: post-upgrade regression: schema column type changed unexpectedly
    at StackWorld.<anonymous> (steps.ts:78:16)
```

</details>

<details>
<summary>✅ <b>Known issue — fails pre, fixed post</b> · 179ms</summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| When a previously-broken operation runs | ✅ | 179ms | [steps.ts:109](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/steps/steps.ts#L109) |

</details>

<details>
<summary>✅ <b>Backend health check</b> · 42ms</summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| Given the backend is reachable | ✅ | 18ms | [steps.ts:28](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/steps/steps.ts#L28) |
| Then the health endpoint returns ok | ✅ | 24ms | [steps.ts:32](https://github.com/jonhermansen/bdd-reporting-demo/blob/main/components/integration/steps/steps.ts#L32) |

</details>

</details>

---

## Performance tracing experiments

### Inline sparklines using Unicode blocks

| Test | Last 8 runs | p50 | p95 | Trend |
|---|---|---|---|---|
| Backend health check | ▁▁▂▁▁▂▁▁ | 38ms | 52ms | stable |
| UI adds an item | ▂▃▅█▅▃▂▂ | 220ms | 460ms | spike on r4 |
| Workload glacial | ▆▆▇▇▆▇█▇ | 2200ms | 2480ms | drift up |
| Schema column type | ▁▁▁█████ | 100ms | 130ms | hard fail since r4 |
| Network jitter | ▁▂▁▃▂▁█▁ | 130ms | 410ms | retry-noisy |

### Step-level waterfall (Mermaid gantt as substep tracing)

```mermaid
gantt
    title "Schema column type — step-by-step trace"
    dateFormat x
    axisFormat %S.%L
    section Pre-upgrade (130ms total)
    When a migration-sensitive operation runs : 0, 130
    section Post-upgrade (66ms total, FAILED)
    When a migration-sensitive operation runs : 0, 66
```

### Multi-scenario waterfall

```mermaid
gantt
    title "Pre-upgrade run — scenarios + their steps"
    dateFormat x
    axisFormat %S.%L

    section Backend health check (38ms)
    Given the backend is reachable      : 0, 12
    Then the health endpoint returns ok : 12, 38

    section API create and list (69ms)
    When I POST an item                 : 38, 78
    Then GET /api/items includes it     : 78, 107

    section UI adds an item (359ms)
    When I open the UI                  : 107, 232
    And I add an item via the UI        : 232, 384
    Then the item appears in the list   : 384, 466

    section UI render timing (432ms, flaky)
    When I open the UI                  : 466, 580
    Then heading eventually appears     : 580, 898
```

### Hot path / Top-N slowest

```mermaid
xychart-beta horizontal
    title "Top 5 slowest tests in this run (ms)"
    x-axis [Workload-glacial, UI-render, UI-add, Workload-slow, Network-jitter]
    y-axis "Duration (ms)" 0 --> 2500
    bar [2300, 432, 359, 933, 410]
```

### Distribution view (if we had history)

```mermaid
xychart-beta
    title "Network jitter — duration distribution across 100 runs"
    x-axis [50ms, 100ms, 150ms, 200ms, 250ms, 300ms, 400ms, 500ms]
    y-axis "Run count" 0 --> 30
    bar [22, 18, 12, 8, 5, 3, 2, 30]
```

### "Flame" via stacked Mermaid

> ⚠ Mermaid doesn't have a native flamegraph; closest is a stacked horizontal gantt.
> For a real flamegraph we'd render SVG → PNG → embed as data URI. See bottom of file.

---

## Nesting experiments

### Nested expandable rows (Phase → Feature → Scenario → Steps)

This is the layout you described: each level is a clickable summary row;
expanding reveals the next level. Steps are the leaf and render as a table.
Default state is fully collapsed — click into what you care about.

<details>
<summary>📋 <b>pre-upgrade</b> · 5.49s · 12 tests · 10 ✅ · 1 ❌ · 1 ⏭ · 1 🍂</summary>

<blockquote>

<details>
<summary>📂 <b>features/items.feature</b> · 12 scenarios</summary>

<blockquote>

<details>
<summary>✅ Backend health check · 38ms</summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| Given the backend is reachable | ✅ | 12ms | [steps.ts:28](#) |
| Then the health endpoint returns ok | ✅ | 26ms | [steps.ts:32](#) |

</details>

<details>
<summary>✅ API create and list · 69ms</summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| When I POST an item named "thingamajig" | ✅ | 40ms | [steps.ts:36](#) |
| Then GET /api/items includes "thingamajig" | ✅ | 29ms | [steps.ts:40](#) |

</details>

<details>
<summary>🟡 UI render timing — passed on attempt 2 · 432ms total</summary>

**Attempt 1** ❌ (218ms) — `simulated render timeout`
**Attempt 2** ✅ (214ms)

| Step (final attempt) | Status | Duration | Definition |
|---|---|---|---|
| When I open the UI | ✅ | 91ms | [steps.ts:46](#) |
| Then the heading "Items" eventually appears | ✅ | 123ms | [steps.ts:63](#) |

</details>

<details>
<summary>❌ Known issue — fails pre, fixed post · 188ms</summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| When a previously-broken operation runs | ❌ | 188ms | [steps.ts:109](#) |

```text
AssertionError: known pre-upgrade issue: index missing on legacy schema
    at StackWorld.<anonymous> (steps.ts:84:16)
```

</details>

<details>
<summary>⏭ Pending feature — surfaced in Skipped report · 1ms</summary>

Marked `@wip` — Before-hook returned "skipped".

</details>

</blockquote>

</details>

</blockquote>

</details>

<details>
<summary>📋 <b>post-upgrade</b> · 5.00s · 12 tests · 10 ✅ · 1 ❌ · 1 ⏭ · 0 🍂</summary>

<blockquote>

<details>
<summary>📂 <b>features/items.feature</b> · 12 scenarios</summary>

<blockquote>

<details>
<summary>❌ <b>Schema column type — passes pre, fails post</b> · 66ms · <em>REGRESSION</em></summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| When a migration-sensitive operation runs | ❌ | 66ms | [steps.ts:102](#) |

```text
AssertionError: post-upgrade regression: schema column type changed unexpectedly
    at StackWorld.<anonymous> (steps.ts:78:16)
```

> ⚠ This test passed in pre-upgrade (130ms). The upgrade introduced this failure.

</details>

<details>
<summary>✅ <b>Known issue — fails pre, fixed post</b> · 179ms · <em>RECOVERY</em></summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| When a previously-broken operation runs | ✅ | 179ms | [steps.ts:109](#) |

> ✨ This test was failing in pre-upgrade. The upgrade fixed it.

</details>

<details>
<summary>✅ Backend health check · 42ms</summary>

| Step | Status | Duration | Definition |
|---|---|---|---|
| Given the backend is reachable | ✅ | 18ms | [steps.ts:28](#) |
| Then the health endpoint returns ok | ✅ | 24ms | [steps.ts:32](#) |

</details>

</blockquote>

</details>

</blockquote>

</details>

### Indented bullet tree

- 📁 Run 142
  - 📋 pre-upgrade phase
    - 📂 features/items.feature
      - ✅ Backend health check (38ms)
      - ✅ API create and list (69ms)
      - ✅ UI adds an item (359ms)
      - 🟡 UI render timing — flaky, passed on attempt 2 (432ms)
      - ❌ Known issue — fails pre, fixed post (188ms)
      - ⏭ Pending feature (skipped)
  - 📋 post-upgrade phase
    - 📂 features/items.feature
      - ✅ Backend health check (42ms)
      - ❌ Schema column type — passes pre, fails post (66ms)
      - ✅ Known issue — fails pre, fixed post (179ms)

### Mindmap (Mermaid)

```mermaid
mindmap
  root((Migration<br/>test))
    Pre-upgrade
      Backend
        Health check ✅
        API list ✅
      UI
        Add item ✅
        Render timing 🟡
      Migration
        Schema column ✅
        Known issue ❌
    Post-upgrade
      Backend
        Health check ✅
        API list ✅
      UI
        Add item ✅
        Render timing ✅
      Migration
        Schema column ❌
        Known issue ✅
```

### Timeline (Mermaid)

```mermaid
timeline
    title CI runs over time
    section Last week
        Mon: r135 ✅
            : r136 ✅
            : r137 🍂 1 flake
        Tue: r138 ✅
            : r139 ❌ 2 regressions
        Wed: r140 ✅
            : r141 ✅
    section Today
        Now: r142 ❌ 1 regression
```

### Tabular nesting (does GFM allow nested tables?)

| Phase | Detail |
|---|---|
| pre | <table><tr><td>Tests: 12</td><td>Passed: 10</td></tr></table> |
| post | <table><tr><td>Tests: 12</td><td>Passed: 10</td></tr></table> |

(Probably won't render as a true nested table — GitHub usually flattens.)

### Code block as ASCII tree (always renders)

```text
Run 142
├── pre-upgrade  5.49s  ❌ 1 failed  🍂 1 flaky
│   ├── ✅ Backend health check               38ms
│   ├── ✅ API create and list                69ms
│   ├── ✅ UI adds an item                   359ms
│   ├── 🟡 UI render timing (×2)             432ms
│   ├── ⚡ Workload buckets (×4)            3.6s
│   ├── 🟡 Network jitter (×1)               129ms
│   ├── ❌ Known issue                       188ms  ← was failing pre, expected
│   ├── ⏭ Pending feature                     1ms
│   └── ✅ Schema column type                130ms  ← passing pre
└── post-upgrade  5.00s  ❌ 1 failed
    ├── ✅ Backend health check               42ms
    ├── ✅ API create and list                71ms
    ├── ✅ UI adds an item                   220ms
    ├── ✅ UI render timing                  411ms
    ├── ⚡ Workload buckets (×4)            3.4s
    ├── 🟡 Network jitter (×3)               410ms
    ├── ✅ Known issue                       179ms  ← recovered
    ├── ⏭ Pending feature                     1ms
    └── ❌ Schema column type                 66ms  ← REGRESSED
```

---

## Coverage delta

| File | Pre | Post | Δ |
|---|---|---|---|
| `components/integration/features/items.feature` | 92% (24/26 steps) | 88% (23/26 steps) | -4% |
| `components/integration/steps/steps.ts` | 87% | 81% | -6% |

> ⚠ One scenario in post-upgrade exited early due to the schema-column-type regression, leaving its remaining steps unexercised. The drop is expected.

---

## What renders here, what doesn't

After this file is pushed, GitHub will render whatever its pinned Mermaid
version supports and silently swallow / display "Diagram syntax error" for
the rest. The probable order of working → not:

- `pie` ✅ (stable since Mermaid 8.x)
- `gantt` ✅ (stable since Mermaid 8.x)
- `sankey-beta` ✅ (Mermaid 10.x)
- `xychart-beta` ⚠ (Mermaid 10.6+)
- `treemap-beta` ❓ (Mermaid 11.x — depends on GitHub's pinned version)

Anything that doesn't render falls back to a code block — still readable, just not pretty.
