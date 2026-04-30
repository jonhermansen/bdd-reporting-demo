# Render a CTRF report as nested HTML tables with <details> drill-down.
# Each row at every level: [Name] [Status] [Duration]. The Name cell
# wraps a <details>; expanding it reveals the next level's table inline.
# Steps are leaf rows (no <details>), with extra Feature / Definition
# link columns.
#
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

# HTML-escape (minimal — name fields don't typically contain special chars
# but we hedge against pipes / angle brackets just in case).
def htmlesc:
  tostring
  | gsub("&"; "&amp;")
  | gsub("<"; "&lt;")
  | gsub(">"; "&gt;");

# Build an HTML <a> tag link, or plain text fallback.
def html_link($uri; $line):
  if ($server_url != "" and $repo != "" and $sha != "" and $uri != null and $uri != "" and $line != null) then
    "<a href=\"\($server_url)/\($repo)/blob/\($sha)/\($uri)#L\($line)\"><code>\($uri | htmlesc):\($line | tostring)</code></a>"
  elif $uri != null and $uri != "" then
    "<code>\($uri | htmlesc):\($line | tostring)</code>"
  else
    "—"
  end;

def rollup_status:
  if any(.[]; . == "failed") then "failed"
  elif any(.[]; . == "passed") then "passed"
  elif all(.[]; . == "skipped") then "skipped"
  else "other"
  end;

# A leaf step row: 5 columns (Step | Status | Duration | Feature | Definition).
def step_row:
  . as $s
  | $s.extra as $e
  | "<tr>"
  + "<td>\($s.name | htmlesc)</td>"
  + "<td>\($s.status | status_emoji)</td>"
  + "<td>\(($e.duration // 0) | ms_to_str)</td>"
  + "<td>\(html_link($e.feature.uri; $e.feature.line))</td>"
  + "<td>\(html_link($e.definition.uri // null; $e.definition.line // null))</td>"
  + "</tr>";

# A failure-detail row spans the full width with a <pre> message.
def failure_row($t):
  ($t.steps // [] | map(select(.status == "failed"))[0]) as $f
  | if $f then
      "<tr><td colspan=\"5\"><pre>\(($f.extra.message // $t.message // "no message") | htmlesc)</pre></td></tr>"
    else "" end;

# A scenario row: name cell wraps a <details> whose body is the steps table.
# Status + duration columns sit alongside, always visible.
def scenario_row:
  . as $t
  | "<tr><td>"
    + (if (($t.steps // []) | length) > 0 then
        "<details><summary>\($t.name | htmlesc)"
        + (if ($t.retries // 0) > 0 then " <sub>(\($t.retries) retries)</sub>" else "" end)
        + "</summary>"
        + "<table>"
        + "<thead><tr><th>Step</th><th>Status</th><th>Duration</th><th>Feature</th><th>Definition</th></tr></thead>"
        + "<tbody>"
        + ($t.steps | map(step_row) | join(""))
        + failure_row($t)
        + "</tbody></table>"
        + "</details>"
      else
        ($t.name | htmlesc)
      end)
    + "</td>"
    + "<td>\($t.status | status_emoji)</td>"
    + "<td>\(($t.duration // 0) | ms_to_str)</td>"
    + "</tr>";

# A file row: name cell wraps a <details> whose body is the scenarios table.
def file_row:
  . as $f
  | "<tr><td>"
    + "<details><summary>📂 <code>\($f.filePath | htmlesc)</code></summary>"
    + "<table>"
    + "<thead><tr><th>Scenario</th><th>Status</th><th>Duration</th></tr></thead>"
    + "<tbody>"
    + ($f.tests | map(scenario_row) | join(""))
    + "</tbody></table>"
    + "</details></td>"
    + "<td>\($f.status | status_emoji)</td>"
    + "<td>\($f.duration | ms_to_str)</td>"
    + "</tr>";

$report[0].results as $r
| ($r.tests // []) as $tests
| ($tests | group_by(.filePath // "unknown") | map({
    filePath: (.[0].filePath // "unknown"),
    tests: .,
    duration: (map(.duration // 0) | add),
    status: (map(.status // "other") | rollup_status)
  })) as $files

| "## \($title)\n\n"
+ "<table>"
+ "<thead><tr><th>File / Scenario / Step</th><th>Status</th><th>Duration</th></tr></thead>"
+ "<tbody>"
+ ($files | map(file_row) | join(""))
+ "</tbody></table>\n\n"
