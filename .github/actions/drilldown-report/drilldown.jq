# Render a CTRF report as a nested <details> drilldown.
# Inputs (via --slurpfile): $report (one-element array wrapping the CTRF JSON)
# Inputs (via --arg): $title, $server_url, $repo, $sha

def ms_to_str:
  if . == null then "—"
  elif . < 1000 then "\(.)ms"
  else "\((. / 1000) | tostring)s"
  end;

def status_emoji:
  if . == "passed" then "✅"
  elif . == "failed" then "❌"
  elif . == "skipped" then "⏭️"
  elif . == "pending" then "⏸️"
  else "❓"
  end;

def safe: tostring | gsub("\n"; "<br>") | gsub("\\|"; "\\\\|");

# Build a markdown link from uri + line, falling back to plain text.
def link($uri; $line):
  if ($server_url != "" and $repo != "" and $sha != "" and $uri != null and $uri != "" and $line != null) then
    "[\($uri | tostring):\($line | tostring)](\($server_url)/\($repo)/blob/\($sha)/\($uri | tostring)#L\($line | tostring))"
  elif $uri != null and $uri != "" then
    "\($uri | tostring):\($line | tostring)"
  else
    "—"
  end;

# Roll a list of test statuses into a single status by precedence.
def rollup_status:
  if any(.[]; . == "failed") then "failed"
  elif any(.[]; . == "passed") then "passed"
  elif all(.[]; . == "skipped") then "skipped"
  else "other"
  end;

# Aggregate tests by file path → { filePath, status, duration, tests[] }
def by_file:
  group_by(.filePath // "unknown")
  | map({
      filePath: (.[0].filePath // "unknown"),
      tests: .,
      duration: (map(.duration // 0) | add),
      status: (map(.status // "other") | rollup_status)
    });

$report[0].results as $r
| ($r.tests // []) as $tests

| "## \($title)\n\n"
+ "<details><summary>📋 \(($r.summary.tests // 0)) tests · "
+ "\(($r.summary.passed // 0) | tostring) ✅ · "
+ "\(($r.summary.failed // 0) | tostring) ❌ · "
+ "\(($r.summary.skipped // 0) | tostring) ⏭️ · "
+ "\((($r.summary.stop // 0) - ($r.summary.start // 0)) | ms_to_str)</summary>\n\n"

# For each feature file:
+ ($tests | by_file | map(
    "<details><summary>\(.status | status_emoji) <code>\(.filePath | safe)</code> · "
    + "\(.tests | length) scenarios · \(.duration | ms_to_str)</summary>\n\n"

    # For each scenario in that file:
    + (.tests | map(
        . as $t
        | "<details><summary>\($t.status | status_emoji) \($t.name | safe) · \(($t.duration // 0) | ms_to_str)"
        + (if ($t.retries // 0) > 0 then " · \(.retries) retries" else "" end)
        + "</summary>\n\n"

        # Steps table (if we have step data)
        + (if ($t.steps // []) | length > 0 then
            "| Step | Status | Duration | Feature | Definition |\n"
            + "|---|---|---|---|---|\n"
            + ($t.steps | map(
                . as $s
                | $s.extra as $e
                | "| \($s.name | safe) "
                + "| \($s.status | status_emoji) "
                + "| \(($e.duration // 0) | ms_to_str) "
                + "| \(link($e.feature.uri; $e.feature.line)) "
                + "| \(link($e.definition.uri // null; $e.definition.line // null)) |"
              ) | join("\n"))
            + "\n\n"
          else "" end)

        # Failure detail (if any step failed)
        + (if ($t.steps // []) | any(.[]; .status == "failed") then
            ($t.steps | map(select(.status == "failed"))[0]) as $fail
            | "<details><summary>Failure detail</summary>\n\n"
            + "```text\n\($fail.extra.message // $t.message // "no message")\n```\n\n"
            + "</details>\n\n"
          else "" end)

        + "</details>\n\n"
      ) | join(""))

    + "</details>\n\n"
  ) | join(""))

+ "</details>\n\n"
