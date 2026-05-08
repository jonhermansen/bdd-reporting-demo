#!/usr/bin/env node
// CTRF charts: read a CTRF JSON, render a directory of PNG charts plus
// an index.md aggregating them. Self-contained — only @resvg/resvg-js
// for SVG → PNG. Each chart is a focused renderer below; add more by
// dropping a new function in the CHARTS array.

import { Resvg } from "@resvg/resvg-js";
import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";

// ── helpers ────────────────────────────────────────────────────────────────

const COLORS = {
  passed: "#22c55e",
  failed: "#ef4444",
  skipped: "#6b7280",
  pending: "#a78bfa",
  other: "#facc15",
};
const BG = "#0d1117";
const FG_DIM = "#6b7280";
const FG = "#9ca3af";
const GRID = "#374151";

const escape = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));

const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));

// ── timeline: workers as columns, time as Y axis ──────────────────────────

function renderTimeline(tests) {
  if (tests.length === 0) return null;

  const origin = Math.min(...tests.map((t) => t.start ?? 0));
  const totalMs = Math.max(1, Math.max(...tests.map((t) => (t.stop ?? 0) - origin)));
  const workers = [...new Set(tests.map((t) => String(t.threadId ?? "0")))]
    .sort((a, b) => (Number(a) || 0) - (Number(b) || 0));

  // Adaptive sizing — keep chart under ~1200px wide regardless of worker count.
  const COL_W = clamp(Math.floor(1150 / Math.max(1, workers.length)), 10, 40);
  const LEFT = 50;
  const HEADER = 24;
  const W = LEFT + workers.length * COL_W;
  // Height auto-scales so total stays under ~3000px even for long runs.
  const Y_SCALE = Math.min(0.5, 2800 / totalMs);
  const H = HEADER + totalMs * Y_SCALE + 20;

  const headers = workers
    .map((w, i) =>
      `<text x="${LEFT + i * COL_W + COL_W / 2}" y="14" text-anchor="middle" font-size="9" fill="${FG}" font-family="monospace">w${escape(w)}</text>`
    )
    .join("");

  // Gridlines + labels every second (or every 5s if the run is long).
  const gridStep = totalMs > 30000 ? 5000 : 1000;
  const gridLabel = gridStep === 5000 ? (s) => `${s * 5}s` : (s) => `${s}s`;
  const grid = [];
  for (let s = 0; s * gridStep <= totalMs; s++) {
    const y = HEADER + s * gridStep * Y_SCALE;
    grid.push(`<line x1="${LEFT - 4}" y1="${y}" x2="${W}" y2="${y}" stroke="${GRID}" stroke-width="0.5"/>`);
    grid.push(`<text x="${LEFT - 6}" y="${y + 3}" text-anchor="end" font-size="8" fill="${FG_DIM}" font-family="monospace">${gridLabel(s)}</text>`);
  }

  const bars = tests
    .map((t) => {
      const colIdx = workers.indexOf(String(t.threadId ?? "0"));
      if (colIdx < 0) return "";
      const x = LEFT + colIdx * COL_W + 1;
      const y = HEADER + ((t.start ?? 0) - origin) * Y_SCALE;
      const h = Math.max(2, ((t.stop ?? 0) - (t.start ?? 0)) * Y_SCALE);
      const fill = COLORS[t.status] ?? COLORS.other;
      return `<rect x="${x}" y="${y}" width="${COL_W - 2}" height="${h}" fill="${fill}" rx="2"><title>${escape(t.name)} — ${t.duration}ms (${t.status})</title></rect>`;
    })
    .join("");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" style="background:${BG}">
<rect width="${W}" height="${H}" fill="${BG}"/>
${grid.join("")}
${headers}
${bars}
</svg>`;
}

// ── Add more renderers here. Each takes (tests) and returns SVG string or null.
// ── Suggested next: flamechart, waterfall, failure-bar, duration-histogram.

const CHARTS = [
  { id: "timeline", title: "Parallel execution timeline", render: renderTimeline },
];

// ── main ──────────────────────────────────────────────────────────────────

const { values } = parseArgs({
  options: {
    input: { type: "string" },
    output: { type: "string" },
  },
});

if (!values.input || !values.output) {
  console.error("usage: charts.mjs --input <ctrf.json> --output <dir>");
  process.exit(1);
}

const ctrf = JSON.parse(fs.readFileSync(values.input, "utf8"));
const tests = ctrf?.results?.tests ?? [];

fs.mkdirSync(values.output, { recursive: true });

const indexLines = ["# 📊 Charts", ""];

for (const chart of CHARTS) {
  const svg = chart.render(tests);
  if (!svg) {
    console.error(`skipped: ${chart.id} (renderer returned null)`);
    continue;
  }
  const png = new Resvg(svg, { background: BG }).render().asPng();
  fs.writeFileSync(path.join(values.output, `${chart.id}.png`), png);
  fs.writeFileSync(path.join(values.output, `${chart.id}.svg`), svg);
  indexLines.push(`## ${chart.title}`, "", `![${chart.id}](./${chart.id}.png)`, "");
  console.error(`rendered: ${chart.id} (${png.byteLength} bytes)`);
}

fs.writeFileSync(path.join(values.output, "index.md"), indexLines.join("\n"));
console.error(`wrote ${CHARTS.length} chart(s) to ${values.output}`);
