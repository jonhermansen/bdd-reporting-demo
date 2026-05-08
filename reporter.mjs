import { Formatter } from "@cucumber/cucumber";
import { randomUUID } from "node:crypto";

const ms = (t) => (t ? t.seconds * 1000 + Math.round(t.nanos / 1e6) : 0);

export default class Reporter extends Formatter {
  constructor(options) {
    super(options);
    this.pickles = new Map();
    this.tcToPickle = new Map();
    this.started = new Map();
    this.stepResults = new Map();
    this.acc = new Map();
    this.astLines = new Map();
    this.t0 = 0;
    options.eventBroadcaster.on("envelope", (e) => this.handle(e));
  }

  handle(e) {
    if (e.testRunStarted) this.t0 = ms(e.testRunStarted.timestamp);
    if (e.pickle) this.pickles.set(e.pickle.id, e.pickle);
    if (e.testCase) this.tcToPickle.set(e.testCase.id, e.testCase.pickleId);

    if (e.gherkinDocument?.feature)
      for (const c of e.gherkinDocument.feature.children) {
        const sc = c.scenario;
        if (!sc) continue;
        if (sc.location) this.astLines.set(sc.id, sc.location.line);
        for (const ex of sc.examples || [])
          for (const row of ex.tableBody || [])
            if (row.location) this.astLines.set(row.id, row.location.line);
      }

    if (e.testCaseStarted) {
      const s = e.testCaseStarted;
      this.started.set(s.id, {
        tcId: s.testCaseId, attempt: s.attempt,
        start: ms(s.timestamp), worker: s.workerId,
      });
    }

    if (e.testStepFinished) {
      const id = e.testStepFinished.testCaseStartedId;
      const arr = this.stepResults.get(id) || [];
      arr.push(e.testStepFinished);
      this.stepResults.set(id, arr);
    }

    if (e.testCaseFinished) {
      const info = this.started.get(e.testCaseFinished.testCaseStartedId);
      if (!info) return;
      const pid = this.tcToPickle.get(info.tcId);
      const pickle = pid && this.pickles.get(pid);
      if (!pickle) return;

      const steps = this.stepResults.get(e.testCaseFinished.testCaseStartedId) || [];
      let status = "passed", message, trace;
      for (const s of steps) {
        const r = s.testStepResult;
        if (r.status === "FAILED") {
          status = "failed"; message = r.message; trace = r.exception?.stackTrace;
        } else if (r.status !== "PASSED" && status === "passed") {
          status = { SKIPPED: "skipped", PENDING: "pending" }[r.status] || "other";
        }
      }

      const a = this.acc.get(pid) || { pickle, attempts: [] };
      a.attempts.push({
        attempt: info.attempt, start: info.start,
        stop: ms(e.testCaseFinished.timestamp),
        status, message, trace, worker: info.worker,
      });
      this.acc.set(pid, a);
    }

    if (e.testRunFinished) this.flush(ms(e.testRunFinished.timestamp));
  }

  flush(t1) {
    const tests = [...this.acc.values()].map(({ pickle, attempts }) => {
      const sorted = attempts.sort((a, b) => a.attempt - b.attempt);
      const last = sorted.at(-1);
      const retries = sorted.length - 1;
      const lineId = pickle.astNodeIds.at(-1);
      const t = {
        name: pickle.name,
        status: last.status,
        duration: last.stop - last.start,
        start: last.start,
        stop: last.stop,
        retries,
        flaky: last.status === "passed" && retries > 0,
        filePath: pickle.uri,
        line: lineId ? this.astLines.get(lineId) : undefined,
        tags: pickle.tags.map((t) => t.name),
      };
      if (last.worker != null) t.threadId = last.worker;
      if (last.status === "failed" && last.message) t.message = last.message;
      if (last.status === "failed" && last.trace) t.trace = last.trace;
      if (retries > 0)
        t.retryAttempts = sorted.slice(0, -1).map((a) => ({
          status: a.status, duration: a.stop - a.start,
          start: a.start, stop: a.stop,
        }));
      return t;
    }).sort((a, b) => a.start - b.start);

    const c = (s) => tests.filter((t) => t.status === s).length;
    this.log(JSON.stringify({
      reportFormat: "CTRF", specVersion: "0.0.0",
      reportId: randomUUID(), timestamp: new Date().toISOString(),
      generatedBy: "flaky-finder",
      results: {
        tool: { name: "cucumber-js" },
        summary: {
          tests: tests.length, passed: c("passed"), failed: c("failed"),
          skipped: c("skipped"), pending: c("pending"), other: c("other"),
          flaky: tests.filter((t) => t.flaky).length,
          start: this.t0, stop: t1,
        },
        tests,
      },
    }, null, 2) + "\n");
  }
}
