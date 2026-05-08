# Render a migration-test markdown summary comparing two CTRF reports.
# Inputs (via --slurpfile): $pre, $post — each is a one-element array
# wrapping the CTRF JSON.
# Inputs (via --arg): $server_url, $repo, $sha — used to build clickable
# blob URLs for test names. Empty strings disable linking.
#
# Null-safe: missing summary fields fall back to 0, missing baseline
# test lookups fall back to "—".

def signed: tostring | (if startswith("-") then . else "+" + . end);
def safe: tostring | gsub("\n"; "<br>") | gsub("\\|"; "\\\\|");
def n(x): x // 0;

# Build a markdown link from a test's filePath + line, falling back to
# the bare name if any required piece is missing.
def link_name($t):
  if ($server_url != "" and $repo != "" and $sha != "" and ($t.filePath // "") != "" and ($t.line // null) != null) then
    "[\($t.name | safe)](\($server_url)/\($repo)/blob/\($sha)/\($t.filePath)#L\($t.line))"
  else
    ($t.name | safe)
  end;

# Compact "(N retries)" annotation when a test ultimately passed but
# needed retries. Empty when not flaky.
def retry_note($t):
  if ($t.retries // 0) > 0 then
    " <sub>(\($t.retries) \(if $t.retries == 1 then "retry" else "retries" end))</sub>"
  else ""
  end;

($pre[0].results // {}) as $p
| ($post[0].results // {}) as $q
| ($p.summary // {}) as $ps
| ($q.summary // {}) as $qs
| ($p.tests // []) as $ptests
| ($q.tests // []) as $qtests
| ($ptests | INDEX(.name)) as $by_name

| ($qtests | map(select(.status == "failed" and (($by_name[.name] // {}).status == "passed")))) as $regressed
| ($qtests | map(select(.status == "passed" and (($by_name[.name] // {}).status == "failed")))) as $recovered
| ($ptests | map(select(.flaky == true)) | length) as $pflaky
| ($qtests | map(select(.flaky == true)) | length) as $qflaky
| (n($ps.stop) - n($ps.start)) as $pdur
| (n($qs.stop) - n($qs.start)) as $qdur

| "## 🔄 Migration result — pre-upgrade vs post-upgrade\n\n"
+ "| Metric | Pre-upgrade | Post-upgrade | Δ |\n"
+ "|---|---|---|---|\n"
+ "| Tests 📝 | \(n($ps.tests)) | \(n($qs.tests)) | \((n($qs.tests) - n($ps.tests)) | signed) |\n"
+ "| Passed ✅ | \(n($ps.passed)) | \(n($qs.passed)) | \((n($qs.passed) - n($ps.passed)) | signed) |\n"
+ "| Failed ❌ | \(n($ps.failed)) | \(n($qs.failed)) | \((n($qs.failed) - n($ps.failed)) | signed) |\n"
+ "| Skipped ⏭️ | \(n($ps.skipped)) | \(n($qs.skipped)) | \((n($qs.skipped) - n($ps.skipped)) | signed) |\n"
+ "| Flaky 🍂 | \($pflaky) | \($qflaky) | \(($qflaky - $pflaky) | signed) |\n"
+ "| Duration ⏱️ | \($pdur / 1000)s | \($qdur / 1000)s | \((($qdur - $pdur) / 1000) | signed)s |\n"
+ "\n"
+ "🔴 **\($regressed | length) regressed**   🟢 **\($recovered | length) recovered**\n\n"

+ (if ($regressed | length) > 0 then
    "### 🔴 Regressed (passed → failed)\n\n"
    + "| Test | Pre status | Post status | Duration |\n|---|---|---|---|\n"
    + ($regressed | map(
        ($by_name[.name] // {}) as $base
        | "| \(link_name(.))\(retry_note(.)) | ✅ pass | ❌ \(.message // "no message" | safe) | \($base.duration // "—")ms → \(.duration // "—")ms |"
      ) | join("\n"))
    + "\n\n"
  else "" end)

+ (if ($recovered | length) > 0 then
    "### 🟢 Recovered (failed → passed)\n\n"
    + "| Test | Pre status | Post status | Duration |\n|---|---|---|---|\n"
    + ($recovered | map(
        ($by_name[.name] // {}) as $base
        | "| \(link_name(.))\(retry_note(.)) | ❌ \($base.message // "fail" | safe) | ✅ pass | \($base.duration // "—")ms → \(.duration // "—")ms |"
      ) | join("\n"))
    + "\n\n"
  else "" end)

# Surface flaky tests too — anything that needed retries in either phase.
| . as $rendered
| (
    ($qtests + $ptests)
    | map(select((.retries // 0) > 0))
    | unique_by(.name)
    | sort_by(-(.retries // 0))
  ) as $flaky_tests
| if ($flaky_tests | length) > 0 then
    $rendered
    + "### 🍂 Tests that needed retries\n\n"
    + "| Test | Pre attempts | Post attempts |\n|---|---|---|\n"
    + ($flaky_tests | map(
        . as $t
        | (($by_name[.name] // {}).retries // 0) as $pre_retries
        | (($qtests | map(select(.name == $t.name))[0] // {}).retries // 0) as $post_retries
        | "| \(link_name($t)) | \(if $pre_retries > 0 then "\($pre_retries + 1) attempts" else "1 attempt" end) | \(if $post_retries > 0 then "\($post_retries + 1) attempts" else "1 attempt" end) |"
      ) | join("\n"))
    + "\n\n"
  else $rendered end
