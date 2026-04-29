# Render a migration-test markdown summary comparing two CTRF reports.
# Inputs (via --slurpfile): $pre, $post — each is a one-element array
# wrapping the CTRF JSON.
#
# Null-safe: missing summary fields fall back to 0, missing baseline
# test lookups fall back to "—".

def signed: tostring | (if startswith("-") then . else "+" + . end);
def safe: tostring | gsub("\n"; "<br>") | gsub("\\|"; "\\\\|");
def n(x): x // 0;

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
    + "| Test | Pre | Post |\n|---|---|---|\n"
    + ($regressed | map(
        ($by_name[.name] // {}) as $base
        | "| \(.name | safe) | ✅ \($base.duration // "—")ms | ❌ \(.message // "no message" | safe) |"
      ) | join("\n"))
    + "\n\n"
  else "" end)

+ (if ($recovered | length) > 0 then
    "### 🟢 Recovered (failed → passed)\n\n"
    + "| Test | Pre | Post |\n|---|---|---|\n"
    + ($recovered | map(
        ($by_name[.name] // {}) as $base
        | "| \(.name | safe) | ❌ \($base.message // "fail" | safe) | ✅ \(.duration // "—")ms |"
      ) | join("\n"))
    + "\n\n"
  else "" end)
