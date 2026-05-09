# Render CTRF + history as Mermaid step summary.
# --slurpfile report / history   --arg title / server_url / repo / sha

def safe: tostring | gsub("[\":|()<>#\\[\\]{}]"; " ") | gsub("\\s+"; " ") | sub("^ ";"") | sub(" $";"");
def trunc($n): if length > $n then .[0:$n-1] + "…" else . end;
def ms_fmt: if . < 1000 then "\(.)ms" else "\(. / 1000 * 10 | floor / 10)s" end;

def test_link:
  if $repo != "" then
    "<a href=\"\($server_url)/\($repo)/blob/\($sha)/\(.filePath // "")#L\(.line // 1)\" target=\"_blank\">\(.name | safe | trunc(40))</a>"
  else .name | safe | trunc(40) end;

def status_icon:
  if .flaky then "🔄" elif .status == "failed" then "❌" elif .status == "skipped" then "⏭" else "✅" end;

# ── gantt ─────────────────────────────────────────────────────────────

def gantt($tests):
  if ($tests | length) < 2 then "" else
  ($tests | map(.start // 0) | min) as $o
  | "<details open><summary>⏱ <b>Parallel execution</b></summary>\n\n"
  + "```mermaid\ngantt\n  dateFormat x\n  axisFormat %S.%L\n  title Workers\n"
  + ($tests | group_by(.threadId // "0") | sort_by(.[0].threadId // "")
    | map(
      (.[0].threadId // "0") as $wid
      | "  section W\($wid)\n"
      + (sort_by(.start) | map(
          (if .status == "failed" then "crit, " elif .flaky then "active, " elif .status == "passed" then "done, " else "" end) as $tag
          | "  \(.name | safe | trunc(30)) :\($tag)\((.start // 0) - $o), \((.stop // 0) - $o)\n"
        ) | join(""))
    ) | join(""))
  + "```\n</details>\n\n"
  end;

# ── results table ─────────────────────────────────────────────────────

def results($tests):
  "<details open><summary>📋 <b>Results</b></summary>\n\n"
  + "| Test | | Retries | Duration |\n|---|---|---|---|\n"
  + ($tests | sort_by(if .status == "failed" then 0 elif .flaky then 1 elif .status == "skipped" then 3 else 2 end)
    | map("| \(test_link) | \(status_icon) | \(.retries) | \(.duration | ms_fmt) |")
    | join("\n"))
  + "\n\n</details>\n\n";

# ── history ───────────────────────────────────────────────────────────

def history($h):
  if ($h | length) < 2 then "" else
  "<details><summary>📈 <b>History</b> (\($h | length) runs)</summary>\n\n"
  + "| Run | Date | Tests | Passed | Failed | Flaky |\n|---|---|---|---|---|---|\n"
  + ($h | map("| \(.run) | \(.date) | \(.tests) | \(.passed) | \(.failed) | \(.flaky) |") | join("\n"))
  + "\n\n</details>\n\n"
  end;

# ── compose ───────────────────────────────────────────────────────────

$report[0].results as $r | ($r.tests // []) as $tests | ($history[0] // []) as $h
| ($r.summary // {}) as $s
| "## \($title)\n\n"
+ "\($s.tests // 0) tests · \($s.passed // 0) passed · \($s.failed // 0) failed · \($s.flaky // 0) flaky · \(($s.stop // 0) - ($s.start // 0) | ms_fmt)\n\n"
+ gantt($tests) + results($tests) + history($h)
