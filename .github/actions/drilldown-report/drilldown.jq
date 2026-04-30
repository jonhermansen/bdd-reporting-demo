# Render a CTRF report as nested HTML tables with <details> drill-down.
# Each row at every level: [Name] [Status] [Duration]. The Name cell
# wraps a <details>; expanding it reveals the next level's table inline.
# Steps are leaf rows (no <details>). Each name (file, scenario, step)
# links to its corresponding line in the .feature file. The .ts step
# definition source is reachable only from clickable stack-trace frames
# inside failure detail.
#
# Inputs (via --slurpfile): $report (one-element array wrapping the CTRF JSON)
# Inputs (via --arg): $title, $server_url, $repo, $sha, $workspace

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

def htmlesc:
  tostring
  | gsub("&"; "&amp;")
  | gsub("<"; "&lt;")
  | gsub(">"; "&gt;");

# Wrap arbitrary text in an HTML link to a github blob URL. $line
# defaults to 1 when null so every link consistently points at a
# specific line (file-level links land on #L1). target=_blank so clicks
# land in a new tab — bypasses the narrow Actions chrome and gives the
# full file viewer width. Falls back to plain text when any required
# GitHub env var is missing.
def link_to($uri; $line; $text):
  if ($server_url != "" and $repo != "" and $sha != "" and $uri != null and $uri != "") then
    "<a href=\"\($server_url)/\($repo)/blob/\($sha)/\($uri)#L\($line // 1)\" target=\"_blank\" rel=\"noopener\">\($text)</a>"
  else
    $text
  end;

# Strip the GITHUB_WORKSPACE prefix from an absolute path so it becomes
# repo-root-relative (suitable for github blob URLs).
def repo_relative($p):
  if ($workspace // "") != "" and ($p | startswith($workspace + "/")) then
    $p | .[($workspace | length) + 1:]
  else
    $p
  end;

# Linkify file:// frames in a stack trace. Each "file:///path:line:col"
# becomes a clickable github link; node-internal frames stay plain text.
def linkify_trace:
  if ($server_url != "" and $repo != "" and $sha != "") then
    gsub("file://(?<path>[^\\s:)]+):(?<line>\\d+)(?::\\d+)?";
      (repo_relative(.path)) as $rel
      | "<a href=\"\($server_url)/\($repo)/blob/\($sha)/\($rel)#L\(.line)\" target=\"_blank\" rel=\"noopener\">\($rel):\(.line)</a>"
    )
  else . end;

def rollup_status:
  if any(.[]; . == "failed") then "failed"
  elif any(.[]; . == "passed") then "passed"
  elif all(.[]; . == "skipped") then "skipped"
  else "other"
  end;

# Sum the durations on each step's extra.duration; consistent rollup so
# the inner step durations always equal the scenario's reported duration.
# (Cucumber's wall-clock test.duration includes hook + IPC overhead and
# can differ slightly; we trade it for math consistency.)
def sum_step_durations:
  ((.steps // []) | map(.extra.duration // 0) | add) // 0;

# A leaf step row: Status | Duration | Step. The step name is a link to
# the matching line in the .feature file.
def step_row:
  . as $s
  | $s.extra as $e
  | "<tr>"
  + "<td>\($s.status | status_emoji)</td>"
  + "<td>\(($e.duration // 0) | ms_to_str)</td>"
  + "<td>\(link_to($e.feature.uri // null; $e.feature.line // null; ($s.name | htmlesc)))</td>"
  + "</tr>";

# Failure detail as a series of "extended" rows beneath the failed step:
# one ⚠ row for the error type+message, then one row per stack frame
# (each frame's file:line is a clickable link). Frames inherit indent
# via leading "↳" so they read as belonging to the failed step.
def failure_row($t):
  ($t.steps // [] | map(select(.status == "failed"))[0]) as $f
  | if $f then
      ($f.extra.message // $t.message // "no message") as $msg
      | ($f.extra.trace // "") as $trace
      | ($msg | split("\n")[0]) as $first_line
      | "<tr><td>⚠</td><td>—</td><td><i>\($first_line | htmlesc)</i></td></tr>"
        + (
            $trace
            | split("\n")
            | map(select(test("\\S")))
            | map("<tr><td></td><td>—</td><td><sub>↳ \(. | htmlesc | linkify_trace)</sub></td></tr>")
            | join("")
          )
    else "" end;

# A scenario row. Name cell wraps a <details> whose body is the steps
# table; summary text links to the .feature scenario line. Optional
# threadId tag and "(N retries)" annotation if applicable.
def scenario_row:
  . as $t
  | ($t.name | htmlesc) as $name
  | ($t | sum_step_durations) as $rolled
  | "<tr>"
    + "<td>\($t.status | status_emoji)</td>"
    + "<td>\($rolled | ms_to_str)</td>"
    + "<td>"
    + (if (($t.steps // []) | length) > 0 then
        "<details><summary>\(link_to($t.filePath; $t.line; $name))"
        + (if ($t.threadId // "") != "" then " <sub><code>w\($t.threadId)</code></sub>" else "" end)
        + (if ($t.retries // 0) > 0 then " <sub>(\($t.retries) retries)</sub>" else "" end)
        + "</summary>"
        + "<table>"
        + "<thead><tr><th>Status</th><th>Duration</th><th>Step</th></tr></thead>"
        + "<tbody>"
        + ($t.steps | map(step_row) | join(""))
        + failure_row($t)
        + "</tbody></table>"
        + "</details>"
      else
        link_to($t.filePath; $t.line; $name)
      end)
    + "</td>"
    + "</tr>";

# A file row: name cell wraps a <details> whose body is the scenarios
# table. Duration rolls up from scenarios' rolled-up step durations so
# arithmetic is consistent at every level.
def file_row:
  . as $f
  | "<tr>"
    + "<td>\($f.status | status_emoji)</td>"
    + "<td>\($f.duration | ms_to_str)</td>"
    + "<td><details><summary>📂 \(link_to($f.filePath; null; "<code>\($f.filePath | htmlesc)</code>"))</summary>"
    + "<table>"
    + "<thead><tr><th>Status</th><th>Duration</th><th>Scenario</th></tr></thead>"
    + "<tbody>"
    + ($f.tests | map(scenario_row) | join(""))
    + "</tbody></table>"
    + "</details></td>"
    + "</tr>";

$report[0].results as $r
| ($r.tests // []) as $tests
| ($tests | group_by(.filePath // "unknown") | map({
    filePath: (.[0].filePath // "unknown"),
    tests: .,
    duration: (map(. | sum_step_durations) | add),
    status: (map(.status // "other") | rollup_status)
  })) as $files

| "## \($title)\n\n"
+ "<table>"
+ "<thead><tr><th>Status</th><th>Duration</th><th>File / Scenario / Step</th></tr></thead>"
+ "<tbody>"
+ ($files | map(file_row) | join(""))
+ "</tbody></table>\n\n"
