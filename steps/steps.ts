import { Given, When, Then } from "@cucumber/cucumber";
import assert from "node:assert/strict";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const chaos = () => {
  const failRate = Math.random() * 0.85;
  const lo = Math.floor(Math.random() * 500);
  const hi = lo + Math.floor(Math.random() * 2000);
  const errors: (() => never)[] = [
    () => { throw new Error("ECONNRESET"); },
    () => { throw new Error("ETIMEDOUT"); },
    () => { throw new Error("socket hang up"); },
    () => { throw new Error("ECONNREFUSED 127.0.0.1:5432"); },
    () => { throw new TypeError("Cannot read properties of null (reading 'id')"); },
    () => { throw new SyntaxError("Unexpected token '<' in JSON at position 0"); },
    () => { throw new RangeError("Maximum call stack size exceeded"); },
    () => assert.fail("expected 200, got 503"),
    () => assert.equal("ready", "pending"),
    () => { throw new Error("deadlock detected"); },
    () => { throw new Error("OOMKilled"); },
    () => { throw new Error("certificate has expired"); },
    () => { throw new Error("kafka: broker not available"); },
    () => { throw new Error("redis LOADING dataset in memory"); },
    () => { throw new Error("connection pool exhausted"); },
  ];
  return async () => {
    const spike = Math.random() < 0.15 ? Math.floor(Math.random() * 5000) : 0;
    await sleep(lo + Math.floor(Math.random() * (hi - lo)) + spike);
    if (Math.random() < failRate)
      errors[Math.floor(Math.random() * errors.length)]();
  };
};

Given("a service", async () => await sleep(Math.floor(Math.random() * 30)));

When("the login flow runs",        chaos());
When("a search runs",              chaos());
When("checkout runs",              chaos());
When("a file upload runs",         chaos());
When("report generation runs",     chaos());
When("notification dispatch runs", chaos());
When("data sync runs",             chaos());
When("cache warmup runs",          chaos());

Then("it completes", () => {});
