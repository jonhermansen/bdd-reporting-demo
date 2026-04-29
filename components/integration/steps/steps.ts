import { Before, Given, When, Then } from "@cucumber/cucumber";
import assert from "node:assert/strict";
import type { StackWorld } from "./world.js";

// Mark @wip scenarios as skipped so they surface in the reporter's Skipped
// section rather than being filtered out entirely.
Before({ tags: "@wip" }, function () {
  return "skipped";
});

const BACKEND = process.env.BACKEND_URL ?? "http://localhost:8080";
const UI = process.env.UI_URL ?? "http://localhost:5173";

Given("the backend is reachable", async function () {
  const r = await fetch(`${BACKEND}/health`);
  assert.ok(r.ok);
});

Then("the health endpoint returns ok", async function () {
  const r = await fetch(`${BACKEND}/health`);
  assert.equal(await r.text(), "ok");
});

When("I POST an item named {string}", async function (name: string) {
  const r = await fetch(`${BACKEND}/api/items`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  assert.equal(r.status, 201);
});

Then("GET \\/api\\/items includes {string}", async function (name: string) {
  const r = await fetch(`${BACKEND}/api/items`);
  const items = (await r.json()) as { name: string }[];
  assert.ok(items.some((i) => i.name === name));
});

When("I open the UI", async function (this: StackWorld) {
  await this.page!.goto(UI);
});

When("I add an item named {string} via the UI", async function (this: StackWorld, name: string) {
  await this.page!.getByTestId("new-item").fill(name);
  await this.page!.getByTestId("add").click();
});

Then("the item {string} appears in the list", async function (this: StackWorld, name: string) {
  await this.page!.getByText(name).waitFor();
});

Then("the heading {string} eventually appears", async function (this: StackWorld, text: string) {
  // Slight flake: UI is usually up but occasionally not ready
  if (Math.random() < 0.3) await new Promise((r) => setTimeout(r, 3500));
  await this.page!.getByRole("heading", { name: text }).waitFor({ timeout: 3000 });
});

// ── Showcase steps: drive the reporter's Slowest / Flaky / Skipped sections ──

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const jitter = (lo: number, hi: number) => lo + Math.floor(Math.random() * (hi - lo));

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

Then("it returns within budget", async function () {
  // Always passes — the value is in the durations, not the assertions.
  assert.ok(true);
});

When("a request is sent with intermittent network jitter", async function () {
  // Variable duration + ~20% failure rate. With cucumber's @flaky retry tag
  // this surfaces as flaky (passed-after-retry) most runs.
  await sleep(jitter(40, 220));
  if (Math.random() < 0.2) throw new Error("simulated transient network blip");
});

Then("the response is eventually successful", function () {
  assert.ok(true);
});
