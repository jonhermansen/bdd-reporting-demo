# Render a CTRF report as a Mermaid-rich markdown report. Each section
# is wrapped in <details> so the full thing fits compactly in step
# summary; expand only what you're investigating.
#
# Inputs (via --slurpfile): $report — one-element array wrapping CTRF
# Inputs (via --arg): $title, $server_url, $repo, $sha

# ── helpers ────────────────────────────────────────────────────────────────

def status_emoji:
  if . == "passed" then "✅"
  elif . == "failed" then "❌"
  elif . == "skipped" then "⏭"
  elif . == "pending" then "⏸"
  else "❓"
  end;

def status_color:
  if . == "passed" then "#22c55e"
  elif . == "failed" then "#ef4444"
  elif . == "skipped" then "#6b7280"
  elif . == "pending" then "#a78bfa"
  else "#facc15"
  end;

# Strip Mermaid-meaningful chars from arbitrary text. Different diagram
# types have slightly different parsers but stripping all of these is
# safe across every chart we use.
def mermaid_safe:
  tostring
  | gsub("[\":|()<>#\\[\\]{}]"; " ")
  | gsub("\\s+"; " ")
  | sub("^ "; "")
  | sub(" $"; "");

def truncate($n):
  tostring | if length > $n then .[0:$n - 1] + "…" else . end;

def ms_to_str:
  if . == null then "—"
  elif . < 1000 then "\(.)ms"
  else "\((. / 1000) | tostring)s"
  end;

# ── 1. Health: pie chart of statuses ──────────────────────────────────────

def health_section($r):
  ($r.summary // {}) as $s
  | "<details open><summary>🩺 <b>Health</b> · "
  + "\($s.tests // 0) tests · "
  + "\($s.passed // 0) ✅ · "
  + "\($s.failed // 0) ❌ · "
  + "\($s.skipped // 0) ⏭ · "
  + "\((($s.stop // 0) - ($s.start // 0)) | ms_to_str)"
  + "</summary>\n\n"
  + "```mermaid\n"
  + "pie title Run health\n"
  + (if ($s.passed // 0) > 0 then "    \"Passed\" : \($s.passed)\n" else "" end)
  + (if ($s.failed // 0) > 0 then "    \"Failed\" : \($s.failed)\n" else "" end)
  + (if ($s.skipped // 0) > 0 then "    \"Skipped\" : \($s.skipped)\n" else "" end)
  + (if ($s.flaky // 0) > 0 then "    \"Flaky\" : \($s.flaky)\n" else "" end)
  + (if ($s.other // 0) > 0 then "    \"Other\" : \($s.other)\n" else "" end)
  + "```\n\n"
  + "</details>\n\n";

# ── 2. Slowest scenarios: horizontal bar chart ────────────────────────────

def slowest_section($tests):
  ($tests | sort_by(-(.duration // 0)) | .[0:10]) as $top
  | if ($top | length) == 0 then ""
    else
      "<details><summary>🐌 <b>Slowest scenarios</b></summary>\n\n"
      + "```mermaid\n"
      + "xychart-beta horizontal\n"
      + "    title \"Top \($top | length) slowest (ms)\"\n"
      + "    x-axis [\($top | map("\"\(.name | mermaid_safe | truncate(28))\"") | join(", "))]\n"
      + "    y-axis \"ms\" 0 --> \(($top[0].duration // 1) + 100)\n"
      + "    bar [\($top | map((.duration // 0) | tostring) | join(", "))]\n"
      + "```\n\n"
      + "</details>\n\n"
    end;

# ── 3. Time budget: treemap of where time went, grouped by file ───────────

def treemap_section($tests):
  if ($tests | length) == 0 then ""
  else
    "<details><summary>🗺 <b>Time budget</b> — where wall-clock went</summary>\n\n"
    + "```mermaid\n"
    + "treemap-beta\n"
    + "\"Test execution\"\n"
    + (
        $tests
        | group_by(.filePath // "unknown")
        | map(
            ((.[0].filePath // "unknown") | split("/") | last) as $shortname
            | "    \"\($shortname | mermaid_safe)\"\n"
            + (. | sort_by(-(.duration // 0)) | map(
                "        \"\(.name | mermaid_safe | truncate(40))\": \((.duration // 0))\n"
              ) | join(""))
          )
        | join("")
      )
    + "```\n\n"
    + "</details>\n\n"
  end;

# ── 4. Parallel execution: gantt with worker swim lanes ───────────────────

def gantt_safe:
  tostring | gsub("[:|<>#\"`]"; " ") | gsub("\\s+"; " ");

def gantt_section($tests):
  if ($tests | length) == 0 then ""
  else
    ($tests | map(.start // 0) | min) as $origin
    | "<details><summary>⏱ <b>Parallel execution</b> — workers as lanes</summary>\n\n"
    + "```mermaid\n"
    + "gantt\n"
    + "    dateFormat x\n"
    + "    axisFormat %S.%L\n"
    + "    title Scenarios by worker\n"
    + (
        $tests
        | group_by(.threadId // "single")
        | sort_by(.[0].threadId // "")
        | map(
            "    section Worker \((.[0].threadId // "single") | tostring)\n"
            + (
                . | sort_by(.start // 0) | map(
                  ((.start // 0) - $origin) as $start_rel
                  | ((.stop // .start // 0) - $origin) as $stop_rel
                  | (if .status == "failed" then "crit, "
                     elif .status == "passed" then "done, "
                     else "" end) as $tag
                  | "    \(.name | gantt_safe | truncate(40)) : \($tag)\($start_rel), \($stop_rel)\n"
                ) | join("")
              )
          )
        | join("")
      )
    + "```\n\n"
    + "</details>\n\n"
  end;

# ── 5. Suite hierarchy: mindmap of features and scenarios ─────────────────

def mindmap_section($tests):
  if ($tests | length) == 0 then ""
  else
    "<details><summary>🌳 <b>Suite structure</b></summary>\n\n"
    + "```mermaid\n"
    + "mindmap\n"
    + "    root((Run))\n"
    + (
        $tests
        | group_by(.filePath // "unknown")
        | map(
            ((.[0].filePath // "unknown") | split("/") | last | mermaid_safe) as $shortname
            | "        \($shortname)\n"
            + (. | map("            \(.name | mermaid_safe | truncate(40))\n") | join(""))
          )
        | join("")
      )
    + "```\n\n"
    + "</details>\n\n"
  end;

# ── 6. Failed scenarios: per-test step flowchart ──────────────────────────

def status_fill:
  if . == "passed" then "#22c55e"
  elif . == "failed" then "#ef4444"
  elif . == "skipped" then "#6b7280"
  else "#facc15"
  end;

def flowchart_for_test($t):
  ($t.steps // []) as $steps
  | if ($steps | length) == 0 then "_(no step data captured for this scenario)_\n\n"
    else
      "```mermaid\n"
      + "flowchart LR\n"
      + ($steps | to_entries | map(
          .key as $i
          | "    n\($i)[\"\(.value.name | mermaid_safe | truncate(48))<br/>\(.value.status | status_emoji) \((.value.extra.duration // 0) | ms_to_str)\"]\n"
        ) | join(""))
      + ($steps | to_entries | map(
          .key as $i
          | if $i == 0 then "" else "    n\($i - 1) --> n\($i)\n" end
        ) | join(""))
      + ($steps | to_entries | map(
          .key as $i
          | "    style n\($i) fill:\(.value.status | status_fill),color:#fff,stroke:#0f172a\n"
        ) | join(""))
      + "```\n\n"
    end;

def failed_section($tests):
  ($tests | map(select(.status == "failed"))) as $failed
  | if ($failed | length) == 0 then
      "<details><summary>🚨 <b>Failures</b> — none</summary>\n\nNo failures in this run. ✨\n\n</details>\n\n"
    else
      "<details open><summary>🚨 <b>Failed scenarios</b> (\($failed | length))</summary>\n\n"
      + ($failed | map(
          "#### \(.name | mermaid_safe)\n\n"
          + flowchart_for_test(.)
        ) | join(""))
      + "</details>\n\n"
    end;

# ── compose ────────────────────────────────────────────────────────────────

$report[0].results as $r
| ($r.tests // []) as $tests

| "## \($title)\n\n"
+ health_section($r)
+ failed_section($tests)
+ slowest_section($tests)
+ treemap_section($tests)
+ gantt_section($tests)
+ mindmap_section($tests)
