// All step implementations are synthesized — no real services involved.
// This component exists to validate the CTRF reporter pipeline, so the
// "test results" are deliberately fabricated to give the reporter a
// rich, varied dataset (durations, retries, skips, failures).
import { Before, Given, When, Then } from "@cucumber/cucumber";
import assert from "node:assert/strict";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const jitter = (lo: number, hi: number) => lo + Math.floor(Math.random() * (hi - lo));

// Mark @wip scenarios as skipped so they surface in the reporter's Skipped
// section rather than being filtered out entirely.
Before({ tags: "@wip" }, function () {
  return "skipped";
});

// ── "Backend" mocks — fast, always-passing ────────────────────────────────

Given("the backend is reachable", async function () {
  await sleep(jitter(5, 30));
});

Then("the health endpoint returns ok", async function () {
  await sleep(jitter(5, 30));
});

When("I POST an item named {string}", async function (_name: string) {
  await sleep(jitter(20, 80));
});

Then("GET \\/api\\/items includes {string}", async function (_name: string) {
  await sleep(jitter(15, 60));
});

// ── "UI" mocks — slightly slower; one occasional failure for Failed-Tests ─

When("I open the UI", async function () {
  await sleep(jitter(80, 250));
});

When("I add an item named {string} via the UI", async function (_name: string) {
  await sleep(jitter(60, 200));
  // ~5% deterministic-looking failure so the reporter has a Failed Test row
  // to render on most runs (still varies enough to exercise fail-rate trend).
  if (Math.random() < 0.05) {
    assert.fail("simulated UI flake: add button did not register click");
  }
});

Then("the item {string} appears in the list", async function (_name: string) {
  await sleep(jitter(40, 150));
});

Then("the heading {string} eventually appears", async function (_text: string) {
  // Flaky timing: occasionally takes long enough to "fail" — paired with
  // @flaky tag this becomes a passes-on-retry row in the Flaky section.
  if (Math.random() < 0.3) {
    await sleep(jitter(800, 1400));
    throw new Error("simulated render timeout");
  }
  await sleep(jitter(80, 250));
});

// ── Showcase steps — drive Slowest / Flaky-rate / Skipped sections ────────

When("a {word} workload runs", async function (size: string) {
  // Bucketed durations so Slowest p95 has a visible spread across runs.
  const range: Record<string, [number, number]> = {
    fast: [20, 120],
    medium: [200, 600],
    slow: [800, 1500],
    glacial: [1800, 2800],
  };
  const [lo, hi] = range[size] ?? [50, 150];
  await sleep(jitter(lo, hi));
});

Then("it returns within budget", function () {
  assert.ok(true);
});

When("a request is sent with intermittent network jitter", async function () {
  await sleep(jitter(40, 220));
  if (Math.random() < 0.2) throw new Error("simulated transient network blip");
});

Then("the response is eventually successful", function () {
  assert.ok(true);
});

// ── Migration-diff steps — phase-conditional outcomes ─────────────────────

When("a migration-sensitive operation runs", async function () {
  await sleep(jitter(50, 200));
  if (process.env.CTRF_SUITE === "post-upgrade") {
    assert.fail("post-upgrade regression: schema column type changed unexpectedly");
  }
});

When("a previously-broken operation runs", async function (this: any) {
  this.log("running migration-aware operation against current schema");
  await sleep(jitter(50, 200));
  this.log(process.env.CTRF_SUITE === "post-upgrade" ? "schema check passed" : "schema check FAILED");
  if (process.env.CTRF_SUITE !== "post-upgrade") {
    assert.fail("known pre-upgrade issue: index missing on legacy schema");
  }
});

// ── Auth feature steps ────────────────────────────────────────────────────

Given("a fresh test environment", async function () {
  await sleep(jitter(40, 80));
});

Given("the auth service is reachable", async function () {
  await sleep(jitter(20, 50));
});

When("the user logs in with {string} credentials", async function (this: any, kind: string) {
  this.log(`POST /auth/login (kind=${kind})`);
  await sleep(jitter(80, 200));
  this.log(kind === "valid" ? "auth token issued" : "credentials rejected");
  this.loginKind = kind;
});

Then("login is {string}", function (this: any, expected: string) {
  const actual = this.loginKind === "valid" ? "successful" : "rejected";
  assert.equal(actual, expected);
});

When("a new user signs up with email {string}", async function (_email: string) {
  await sleep(jitter(200, 400));
});

Then("a verification email is sent", async function () {
  await sleep(jitter(50, 100));
});

When("the user requests a password reset for {string}", async function (_email: string) {
  await sleep(jitter(150, 300));
});

Then("a reset link is sent", async function () {
  await sleep(jitter(30, 80));
});

Given("an authenticated session", async function () {
  await sleep(jitter(50, 100));
});

When("the user logs out", async function () {
  await sleep(jitter(40, 80));
});

Then("the session is invalidated", async function () {
  await sleep(jitter(20, 60));
});

// ── Cart feature steps ────────────────────────────────────────────────────

Given("a logged-in user", async function () {
  await sleep(jitter(60, 120));
});

When(
  "the user adds {int} {string} to the cart",
  async function (this: any, count: number, item: string) {
    this.log(`POST /cart/items {item: "${item}", count: ${count}}`);
    await sleep(jitter(40, 120));
    this.cartCount = (this.cartCount ?? 0) + count;
    this.log(`cart now has ${this.cartCount} items`);
  }
);

When(
  "the user adds {int} {string} to the cart with {int}ms latency",
  async function (this: any, count: number, _item: string, latency: number) {
    await sleep(latency);
    this.cartCount = (this.cartCount ?? 0) + count;
  }
);

When("the user applies discount code {string}", async function (_code: string) {
  await sleep(jitter(30, 90));
});

Then("the cart contains {int} items", function (this: any, expected: number) {
  assert.equal(this.cartCount ?? 0, expected);
});

Then("the cart total reflects the discount", async function () {
  await sleep(jitter(20, 60));
});
