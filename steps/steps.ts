import {
  BeforeAll, AfterAll, Given, When, Then, setDefaultTimeout,
} from "@cucumber/cucumber";

setDefaultTimeout(15000);
import { createServer, type Server } from "node:http";
import assert from "node:assert/strict";

let server: Server;
let base: string;

BeforeAll(async () => {
  server = createServer((req, res) => {
    const path = req.url || "/";
    const r = Math.random();

    // Path-based behavior: some endpoints are slow, some are fast, some are cursed
    const slow = /batch|report|sync/.test(path);
    const cursed = /checkout|upload/.test(path);
    const quick = /health|probe/.test(path);

    // Failure modes — weighted by endpoint personality
    const failChance = cursed ? 0.55 : slow ? 0.35 : quick ? 0.20 : 0.30;

    if (r < failChance) {
      const mode = Math.random();
      if (mode < 0.20) { req.socket.destroy(); return; }
      if (mode < 0.35) return; // never respond → timeout
      if (mode < 0.50) { res.writeHead(503); res.end(); return; }
      if (mode < 0.60) { res.writeHead(502); res.end(); return; }
      if (mode < 0.68) { res.writeHead(429); res.end(); return; }
      if (mode < 0.80) { res.end("{bad"); return; }
      // partial write then kill
      res.writeHead(200, { "content-type": "application/json" });
      res.write('{"ok":');
      setTimeout(() => req.socket.destroy(), 50);
      return;
    }

    // Success path — variable latency by endpoint type
    const delay = slow
      ? 3000 + Math.floor(Math.random() * 12000)
      : quick
        ? 50 + Math.floor(Math.random() * 300)
        : 200 + Math.floor(Math.random() * 3000);

    setTimeout(() => {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true }));
    }, delay);
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
});

AfterAll(() => server?.close());

const hit = async (path: string) => {
  const res = await fetch(`${base}${path}`, {
    signal: AbortSignal.timeout(10000),
  });
  assert.ok(res.ok, `HTTP ${res.status}`);
  await res.json();
};

Given("a service", async () => {
  await new Promise((r) => setTimeout(r, Math.floor(Math.random() * 30)));
});

When("the login flow runs",        () => hit("/auth/login"));
When("a search runs",              () => hit("/api/search"));
When("checkout runs",              () => hit("/api/checkout"));
When("a file upload runs",         () => hit("/api/upload"));
When("report generation runs",     () => hit("/api/reports"));
When("notification dispatch runs", () => hit("/api/notify"));
When("data sync runs",             () => hit("/api/sync"));
When("cache warmup runs",          () => hit("/api/cache/warm"));
When("batch {word} runs",          (id: string) => hit(`/batch/${id}`));
When("health probe hits {word}",   (t: string) => hit(`/health/${t}`));

Then("it completes", () => {});
