import { Given, When, Then } from "@cucumber/cucumber";
import assert from "node:assert/strict";
import type { StackWorld } from "./world.js";

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
