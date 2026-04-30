# Render a CTRF report as nested HTML tables with <details> drill-down.
# Each row at every level: [Name] [Status] [Duration]. The Name cell
# wraps a <details>; expanding it reveals the next level's table inline.
# Steps are leaf rows (no <details>), with a Feature link column.
# Each name (file, scenario, step) is itself a link to its source.
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

def htmlesc:
  tostring
  | gsub("&"; "&amp;")
  | gsub("<"; "&lt;")
  | gsub(">"; "&gt;");

# Wrap arbitrary text in an HTML link to a github blob URL. $line may be
# null (file-level link) or a number. Falls back to plain text when any
# required GitHub env var is missing.
def link_to($uri; $line; $text):
  if ($server_url != "" and $repo != "" and $sha != "" and $uri != null and $uri != "") then
    if $line != null then
      "<a href=\"\($server_url)/\($repo)/blob/\($sha)/\($uri)#L\($line)\">\($text)</a>"
    else
      "<a href=\"\($server_url)/\($repo)/blob/\($sha)/\($uri)\">\($text)</a>"
    end
  else
    $text
  end;

# Render a "uri:line" code-span link for the leaf step row's Feature cell.
def feature_link($uri; $line):
  link_to($uri; $line; "<code>\(($uri // "" | htmlesc)):\(($line // "—") | tostring)</code>");

def rollup_status:
  if any(.[]; . == "failed") then "failed"
  elif any(.[]; . == "passed") then "passed"
  elif all(.[]; . == "skipped") then "skipped"
  else "other"
  end;

# A leaf step row: 4 columns (Step | Status | Duration | Feature). The
# step name itself is a link to its step-definition .ts source.
def step_row:
  . as $s
  | $s.extra as $e
  | "<tr>"
  + "<td>\(link_to($e.definition.uri // null; $e.definition.line // null; ($s.name | htmlesc)))</td>"
  + "<td>\($s.status | status_emoji)</td>"
  + "<td>\(($e.duration // 0) | ms_to_str)</td>"
  + "<td>\(feature_link($e.feature.uri; $e.feature.line))</td>"
  + "</tr>";

# Failure detail spans the full width with a <pre> message under the
# failed step inside the same scenario table.
def failure_row($t):
  ($t.steps // [] | map(select(.status == "failed"))[0]) as $f
  | if $f then
      "<tr><td colspan=\"4\"><pre>\(($f.extra.message // $t.message // "no message") | htmlesc)</pre></td></tr>"
    else "" end;

# A scenario row: name cell wraps a <details> whose body is the steps
# table. The summary text is itself a link to the scenario's .feature
# line.
def scenario_row:
  . as $t
  | ($t.name | htmlesc) as $name
  | "<tr><td>"
    + (if (($t.steps // []) | length) > 0 then
        "<details><summary>\(link_to($t.filePath; $t.line; $name))"
        + (if ($t.retries // 0) > 0 then " <sub>(\($t.retries) retries)</sub>" else "" end)
        + "</summary>"
        + "<table>"
        + "<thead><tr><th>Step</th><th>Status</th><th>Duration</th><th>Feature</th></tr></thead>"
        + "<tbody>"
        + ($t.steps | map(step_row) | join(""))
        + failure_row($t)
        + "</tbody></table>"
        + "</details>"
      else
        link_to($t.filePath; $t.line; $name)
      end)
    + "</td>"
    + "<td>\($t.status | status_emoji)</td>"
    + "<td>\(($t.duration // 0) | ms_to_str)</td>"
    + "</tr>";

# A file row: name cell wraps a <details> whose body is the scenarios
# table. The summary text is itself a link to the .feature file.
def file_row:
  . as $f
  | "<tr><td>"
    + "<details><summary>📂 \(link_to($f.filePath; null; "<code>\($f.filePath | htmlesc)</code>"))</summary>"
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
