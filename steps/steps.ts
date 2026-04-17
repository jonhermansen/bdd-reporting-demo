import { Given, When, Then } from "@cucumber/cucumber";
import assert from "node:assert/strict";

const retryCounters = new Map<string, number>();

Given("the demo is set up", function () {});

Given("I have the number {int}", function (n: number) {
  (this as { n?: number }).n = n;
});

Then("it should be positive", function () {
  const n = (this as { n?: number }).n;
  assert.ok(n !== undefined && n > 0, `expected positive, got ${n}`);
});

When("I wait {int} ms", async function (ms: number) {
  await new Promise((r) => setTimeout(r, ms));
});

Then("the test passes", function () {
  assert.ok(true);
});

Then("this step never runs", function () {
  throw new Error("unreachable under the default tag filter");
});

Then("I assert that {int} equals {int}", function (a: number, b: number) {
  assert.equal(a, b);
});

When("I hit a pending step", function () {
  return "pending";
});

When("I increment the retry counter {string}", function (name: string) {
  retryCounters.set(name, (retryCounters.get(name) ?? 0) + 1);
});

Then("the counter {string} must be at least {int}", function (name: string, target: number) {
  const v = retryCounters.get(name) ?? 0;
  assert.ok(v >= target, `counter ${name} is ${v}, need >= ${target}`);
});

Then("I randomly fail {int} percent of the time", function (pct: number) {
  if (Math.random() * 100 < pct) {
    throw new Error(`random flake triggered (threshold ${pct}%)`);
  }
});

When("I log {string}", function (msg: string) {
  this.log(msg);
});

When("I attach text {string}", function (payload: string) {
  this.attach(payload, "text/plain");
});
