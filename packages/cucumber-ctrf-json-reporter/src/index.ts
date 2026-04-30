import { Formatter, IFormatterOptions } from "@cucumber/cucumber";
import { PickleStepType, TestStepResultStatus } from "@cucumber/messages";
import type {
  Envelope,
  FeatureChild,
  GherkinDocument,
  Pickle,
  StepDefinition,
  TestCase,
  TestStep,
  TestStepFinished,
  Timestamp,
} from "@cucumber/messages";
import type { CTRFReport, Step, Test, TestStatus } from "ctrf";
import { randomUUID } from "node:crypto";

// ---- helpers ----------------------------------------------------------------

const tsToMs = (t: Timestamp | undefined): number =>
  t ? t.seconds * 1000 + Math.round(t.nanos / 1_000_000) : 0;

const durToMs = tsToMs;

// cucumber status -> CTRF status (cucumber is noisier)
const mapStatus = (s: TestStepResultStatus | undefined): TestStatus => {
  switch (s) {
    case TestStepResultStatus.PASSED:
      return "passed";
    case TestStepResultStatus.FAILED:
      return "failed";
    case TestStepResultStatus.SKIPPED:
      return "skipped";
    case TestStepResultStatus.PENDING:
      return "pending";
    default:
      return "other";
  }
};

// Priority when summarising many step statuses into one scenario status.
// Anything worse than PASSED wins; FAILED trumps all.
const STATUS_PRIORITY: TestStepResultStatus[] = [
  TestStepResultStatus.FAILED,
  TestStepResultStatus.AMBIGUOUS,
  TestStepResultStatus.UNDEFINED,
  TestStepResultStatus.PENDING,
  TestStepResultStatus.SKIPPED,
  TestStepResultStatus.PASSED,
  TestStepResultStatus.UNKNOWN,
];

function rollUpStatus(
  steps: TestStepFinished[]
): { status: TestStepResultStatus; message?: string; trace?: string } {
  if (steps.length === 0) return { status: TestStepResultStatus.UNKNOWN };
  let winner: TestStepResultStatus = TestStepResultStatus.PASSED;
  let winnerIdx = STATUS_PRIORITY.indexOf(TestStepResultStatus.PASSED);
  let message: string | undefined;
  let trace: string | undefined;
  for (const s of steps) {
    const idx = STATUS_PRIORITY.indexOf(s.testStepResult.status);
    if (idx < winnerIdx) {
      winner = s.testStepResult.status;
      winnerIdx = idx;
      message = s.testStepResult.message;
      trace = s.testStepResult.exception?.stackTrace;
    }
  }
  return { status: winner, message, trace };
}

// ---- the formatter ----------------------------------------------------------

interface AttemptRecord {
  attempt: number;
  startMs: number;
  stopMs: number;
  steps: TestStepFinished[];
  testCaseId: string;
}

interface PickleAccumulator {
  pickle: Pickle;
  attempts: AttemptRecord[];
}

export default class CtrfFormatter extends Formatter {
  private readonly pickles = new Map<string, Pickle>(); // pickleId → Pickle
  private readonly testCaseToPickle = new Map<string, string>(); // testCaseId → pickleId
  private readonly startedToTestCase = new Map<
    string,
    { testCaseId: string; attempt: number; startMs: number }
  >(); // testCaseStartedId → info
  private readonly stepsByStarted = new Map<string, TestStepFinished[]>(); // testCaseStartedId → steps
  private readonly accumulators = new Map<string, PickleAccumulator>(); // pickleId → accumulator
  private readonly astLines = new Map<string, number>(); // gherkin AST node id → line
  private readonly stepDefs = new Map<string, { uri: string; line: number }>(); // stepDefId → location
  private readonly testCases = new Map<string, TestCase>(); // testCaseId → TestCase (for testSteps[])
  private runStart = 0;
  private runStop = 0;

  constructor(options: IFormatterOptions) {
    super(options);
    options.eventBroadcaster.on("envelope", (e: Envelope) => this.onEnvelope(e));
  }

  private onEnvelope(e: Envelope): void {
    if (e.testRunStarted) this.runStart = tsToMs(e.testRunStarted.timestamp);
    if (e.gherkinDocument) this.indexGherkinDocument(e.gherkinDocument);
    if (e.pickle) this.pickles.set(e.pickle.id, e.pickle);
    if (e.stepDefinition) this.recordStepDefinition(e.stepDefinition);
    if (e.testCase) this.onTestCase(e.testCase);
    if (e.testCaseStarted) {
      this.startedToTestCase.set(e.testCaseStarted.id, {
        testCaseId: e.testCaseStarted.testCaseId,
        attempt: e.testCaseStarted.attempt,
        startMs: tsToMs(e.testCaseStarted.timestamp),
      });
    }
    if (e.testStepFinished) {
      const list = this.stepsByStarted.get(e.testStepFinished.testCaseStartedId) ?? [];
      list.push(e.testStepFinished);
      this.stepsByStarted.set(e.testStepFinished.testCaseStartedId, list);
    }
    if (e.testCaseFinished) {
      const startedInfo = this.startedToTestCase.get(e.testCaseFinished.testCaseStartedId);
      if (!startedInfo) return;
      const pickleId = this.testCaseToPickle.get(startedInfo.testCaseId);
      if (!pickleId) return;
      const pickle = this.pickles.get(pickleId);
      if (!pickle) return;

      const acc = this.accumulators.get(pickleId) ?? { pickle, attempts: [] };
      acc.attempts.push({
        attempt: startedInfo.attempt,
        startMs: startedInfo.startMs,
        stopMs: tsToMs(e.testCaseFinished.timestamp),
        steps: this.stepsByStarted.get(e.testCaseFinished.testCaseStartedId) ?? [],
        testCaseId: startedInfo.testCaseId,
      });
      this.accumulators.set(pickleId, acc);
    }
    if (e.testRunFinished) {
      this.runStop = tsToMs(e.testRunFinished.timestamp);
      this.writeReport();
    }
  }

  private onTestCase(tc: TestCase): void {
    this.testCaseToPickle.set(tc.id, tc.pickleId);
    this.testCases.set(tc.id, tc);
  }

  private recordStepDefinition(sd: StepDefinition): void {
    const ref = sd.sourceReference;
    if (!ref?.uri || !ref.location) return;
    this.stepDefs.set(sd.id, { uri: ref.uri, line: ref.location.line });
  }

  // Walk the gherkin AST and record line numbers for each scenario, every
  // gherkin step, and (for outlines) each example row. Pickles reference
  // these AST node ids, so we use them to populate test.line and per-step
  // feature-file locations.
  private indexGherkinDocument(doc: GherkinDocument): void {
    if (!doc.feature) return;
    const walk = (children: readonly FeatureChild[]): void => {
      for (const child of children) {
        if (child.scenario) {
          const sc = child.scenario;
          if (sc.location) this.astLines.set(sc.id, sc.location.line);
          for (const step of sc.steps ?? []) {
            if (step.location) this.astLines.set(step.id, step.location.line);
          }
          for (const ex of sc.examples ?? []) {
            for (const row of ex.tableBody ?? []) {
              if (row.location) this.astLines.set(row.id, row.location.line);
            }
          }
        }
        if (child.rule?.children) walk(child.rule.children);
      }
    };
    walk(doc.feature.children);
  }

  // Map cucumber's PickleStepType to gherkin's user-facing keyword.
  // (Cucumber stores Context/Action/Outcome internally; reports want
  // Given/When/Then.)
  private keywordFor(type: PickleStepType | undefined): string {
    switch (type) {
      case PickleStepType.CONTEXT: return "Given";
      case PickleStepType.ACTION: return "When";
      case PickleStepType.OUTCOME: return "Then";
      default: return "";
    }
  }

  private buildTest(pickleId: string, acc: PickleAccumulator): Test {
    // last attempt = authoritative final result
    const sorted = [...acc.attempts].sort((a, b) => a.attempt - b.attempt);
    const finalAttempt = sorted[sorted.length - 1];
    const rollup = rollUpStatus(finalAttempt.steps);
    const finalStatus = mapStatus(rollup.status);
    const retries = sorted.length - 1;

    // CTRF_FILE_PATH_PREFIX lets cucumber's pickle.uri (relative to the
    // cucumber working directory) be promoted to a project-root-relative
    // path so downstream link builders (github blob URLs etc.) can use
    // it directly.
    const pathPrefix = process.env.CTRF_FILE_PATH_PREFIX ?? "";
    const filePath = pathPrefix
      ? `${pathPrefix.replace(/\/+$/, "")}/${acc.pickle.uri}`
      : acc.pickle.uri;

    // Last astNodeId is the most-specific node — scenario id for plain
    // scenarios, table-row id for Scenario Outline examples — so the
    // line lands on the right row of an outline.
    const lastAstId = acc.pickle.astNodeIds[acc.pickle.astNodeIds.length - 1];
    const line = lastAstId ? this.astLines.get(lastAstId) : undefined;

    const test: Test = {
      name: acc.pickle.name,
      status: finalStatus,
      duration: finalAttempt.stopMs - finalAttempt.startMs,
      start: finalAttempt.startMs,
      stop: finalAttempt.stopMs,
      retries,
      flaky: finalStatus === "passed" && retries > 0,
      rawStatus: rollup.status,
      tags: acc.pickle.tags.map((t) => t.name),
      filePath,
    };

    if (line !== undefined) test.line = line;

    // Populate spec-defined `steps[]` with cucumber-rich data in `step.extra`.
    // Step.name carries the keyword + text (spec field, minimal); detail
    // (location, duration, error) goes in extra so flat-scenario consumers
    // can ignore it while drilldown renderers get full fidelity.
    const testCase = this.testCases.get(finalAttempt.testCaseId);
    const steps = this.buildSteps(acc.pickle, finalAttempt, testCase, pathPrefix);
    if (steps.length > 0) test.steps = steps;

    // CTRF_SUITE lets the same scenarios run multiple times in one job
    // (e.g. pre-/post-upgrade) without colliding in the merged report.
    if (process.env.CTRF_SUITE) test.suite = [process.env.CTRF_SUITE];

    if (finalStatus === "failed") {
      if (rollup.message) test.message = rollup.message;
      if (rollup.trace) test.trace = rollup.trace;
    }

    if (retries > 0) {
      test.retryAttempts = sorted.slice(0, -1).map((a) => {
        const r = rollUpStatus(a.steps);
        return {
          attempt: a.attempt + 1, // CTRF is 1-indexed; cucumber is 0-indexed
          status: mapStatus(r.status),
          duration: a.stopMs - a.startMs,
          start: a.startMs,
          stop: a.stopMs,
          message: r.message,
          trace: r.trace,
        };
      });
    }

    return test;
  }

  private buildSteps(
    pickle: Pickle,
    attempt: AttemptRecord,
    testCase: TestCase | undefined,
    pathPrefix: string,
  ): Step[] {
    if (!testCase) return [];

    const pickleStepsById = new Map(pickle.steps.map(s => [s.id, s]));
    const testStepsById = new Map<string, TestStep>(
      testCase.testSteps.map(ts => [ts.id, ts]),
    );

    const out: Step[] = [];
    for (const finishedStep of attempt.steps) {
      const testStep = testStepsById.get(finishedStep.testStepId);
      // Skip hooks (testStep with hookId, no pickleStepId)
      if (!testStep?.pickleStepId) continue;
      const pickleStep = pickleStepsById.get(testStep.pickleStepId);
      if (!pickleStep) continue;

      const keyword = this.keywordFor(pickleStep.type);
      const featureLineKey = pickleStep.astNodeIds[pickleStep.astNodeIds.length - 1];
      const featureLine = featureLineKey ? this.astLines.get(featureLineKey) : undefined;
      const featurePath = pathPrefix
        ? `${pathPrefix.replace(/\/+$/, "")}/${pickle.uri}`
        : pickle.uri;

      const stepDefId = testStep.stepDefinitionIds?.[0];
      const def = stepDefId ? this.stepDefs.get(stepDefId) : undefined;
      // Normalize the step-definition uri to repo-root-relative.
      // Cucumber emits either an absolute path (with "file://" prefix) or
      // a path relative to its own working directory.
      let defUri = def?.uri ?? "";
      if (defUri.startsWith("file://")) defUri = defUri.replace(/^file:\/\//, "");
      if (defUri.startsWith("/") && pathPrefix) {
        // Absolute → trim to after the pathPrefix marker
        const marker = `/${pathPrefix.replace(/^\/|\/$/g, "")}/`;
        const idx = defUri.indexOf(marker);
        if (idx >= 0) defUri = defUri.slice(idx + 1);
      } else if (!defUri.startsWith("/") && pathPrefix && !defUri.startsWith(pathPrefix)) {
        // Relative → prepend the pathPrefix
        defUri = `${pathPrefix.replace(/\/+$/, "")}/${defUri}`;
      }

      const result = finishedStep.testStepResult;
      const status = mapStatus(result.status);
      const durationMs = durToMs(result.duration);

      const step: Step = {
        name: keyword ? `${keyword} ${pickleStep.text}` : pickleStep.text,
        status,
        extra: {
          keyword,
          text: pickleStep.text,
          duration: durationMs,
          feature: { uri: featurePath, line: featureLine },
          ...(def ? { definition: { uri: defUri, line: def.line } } : {}),
          ...(result.message ? { message: result.message } : {}),
          ...(result.exception?.stackTrace ? { trace: result.exception.stackTrace } : {}),
        },
      };
      out.push(step);
    }
    return out;
  }

  private writeReport(): void {
    const tests: Test[] = [];
    for (const [pickleId, acc] of this.accumulators) {
      tests.push(this.buildTest(pickleId, acc));
    }

    const summary = {
      tests: tests.length,
      passed: tests.filter((t) => t.status === "passed").length,
      failed: tests.filter((t) => t.status === "failed").length,
      skipped: tests.filter((t) => t.status === "skipped").length,
      pending: tests.filter((t) => t.status === "pending").length,
      other: tests.filter((t) => t.status === "other").length,
      flaky: tests.filter((t) => t.flaky).length,
      start: this.runStart,
      stop: this.runStop,
      duration: this.runStop - this.runStart,
    };

    const report: CTRFReport = {
      reportFormat: "CTRF",
      specVersion: "0.0.0",
      reportId: randomUUID(),
      timestamp: new Date().toISOString(),
      generatedBy: "cucumber-ctrf-json-reporter",
      results: {
        tool: { name: "cucumber-js" },
        summary,
        tests,
      },
    };

    this.log(JSON.stringify(report, null, 2) + "\n");
  }
}
