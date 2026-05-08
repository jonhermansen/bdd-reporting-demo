## 🔄 Migration result — pre-upgrade vs post-upgrade

| Metric | Pre-upgrade | Post-upgrade | Δ |
|---|---|---|---|
| Tests 📝 | 6 | 6 | +0 |
| Passed ✅ | 4 | 4 | +0 |
| Failed ❌ | 1 | 1 | +0 |
| Skipped ⏭️ | 1 | 1 | +0 |
| Flaky 🍂 | 0 | 0 | +0 |
| Duration ⏱️ | 5s | 4.5s | -0.5s |

🔴 **1 regressed**   🟢 **1 recovered**

### 🔴 Regressed (passed → failed)

| Test | Pre | Post |
|---|---|---|
| becomes_regressed | ✅ 100ms | ❌ AssertionError: schema column type changed unexpectedly |

### 🟢 Recovered (failed → passed)

| Test | Pre | Post |
|---|---|---|
| becomes_recovered | ❌ old issue: index missing | ✅ 35ms |
