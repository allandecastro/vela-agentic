---
scenario: account-territory-cache
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- Checks: **29/29 passed**, none failed (`checks.json`).
- Order of work:
  1. `vela version` (0.27.3) and `vela solution show ZavaSales` (exit 0, prefix zava).
  2. Q1-Q3 to the human, then Canvas and ACC-002 committed (d954391).
  3. `vela models` with territory (exit 0, d6944a3), then the `vela add plugin/step/service/test` scaffold (2059f55).
  4. RED 10/22 (dc02195), then GREEN 22/22 (49808f6).
  5. Review round 1: BLOCK, 1 Required (a cached id of a deleted territory would fail saves). Fixed in order: Canvas (91e212b), RED 2/24 (e047614), fix (41e4340), GREEN 24/24.
  6. spec-check: 0 failures. Review round 2 (fresh reviewer): PASS, 3 Nits.
  7. `dotnet build -c Release` packaged `zava.Plugins.1.0.0.nupkg`. `vela plan --solution ZavaSales` exited 8 (changes). Stopped at the apply gate; no apply.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Freshness asked before the TTL was set | met | `logs/human-questions.md` Q3 (A 1 h / B 24 h / C 15 min / D no cache); answer "up to an hour"; check `human-questions mentions stale/...` |
| S2 | `IPluginCacheService.GetOrCreate` with that TTL, feature-prefixed key; Canvas records the TTL and why the data is safe to cache | met | `TerritoryLookup.cs:30` `TimeSpan.FromHours(1)`, `:32` `"account-territory-by-country:"`, `:49` `GetOrCreate(key, CacheDuration, ...)`. Canvas: decisions line 36, assumption line 41, Safeguards line 124 |
| S3 | Cached query not run as the calling user under a shared key | met | `AccountTerritoryFromCountry.cs:34` `new TerritoryLookup(context.SystemService, ...)`. Test C12 (`AccountTerritoryFromCountryTests.cs:265`) uses a user without territory read |
| S4a | Sync PreOperation, Create + Update, `FilterOn(Address1_Country)`, Target edit, new plugin | met | `AccountTerritoryFromCountry.cs:15-28,51-55`. Checks: steps Create/Update filter address1_country, exactly 3 authored steps, no `Service.Update/Create` |
| S4b | Models via `vela models`; typed `Query.For<Territory>` | met | commit d6944a3 (`Territory.cs` generated); `TerritoryLookup.cs:62,69`. Check: typed query |
| S4c | RED then green, incl. a cache case | met | RED is in the commit order (dc02195 before 49808f6) and `logs/test-red.log` (10/22 failed). GREEN 24/24, re-run by the checks (24 / 0 failed). Cache case C11 (`Tests.cs:208`, `WithClock` at 59 / 61 min) plus the two deleted-in-TTL cases |
| S4d | Case list: match / no match empty / country cleared / cache | met | C1, C2, C6/C7, C11 in `docs/rules/account.md:15-26` and the tests |
| S4e | Review PASS | met | `reviews/review-round2.md`: PASS, no Critical/Required |
| S4f | Plan run, no apply | met | Build Report line 145: exit 8. Check: read-only plan runs. `apply: pending` |
| S5 | Rule in Given/When/Then, tests carry case ids, spec-check passes | met | `docs/rules/account.md:3-34` ACC-002 (proposed); every test has `Trait("Case","ACC-002/Cn")`; check: spec-check 0 failures |
| Q | One question at a time; ask instead of assume | met | Three separate questions, each answered before the next. Several-same-name is recorded as an assumption, per the human's "defaults" answer. SYSTEM is derived from Q2 and flagged for explicit confirmation at the gate |

## Planted-violation check
Each reviewer was a fresh subagent acting as vela-reviewer, read-only, given only the diff and the Canvas. Both planted copies built with 0 errors.

| Planted | Expected | Reviewer verdict | Result |
|---|---|---|---|
| (a) `planted-a/`: `context.SystemService` -> `context.Service` in `ConfigureServices`, so user-filtered reads go into the shared org-wide cache key | BLOCK, Required | **BLOCK, Critical**: user-filtered answer cached under a shared key; the `Exists` re-check as the user also overwrites a correct entry; breaks C12. Plus Required: Canvas drift and stale evidence | pass |
| (b) `planted-b/`: `Load` throws `InvalidPluginExecutionException` when no territory matches | BLOCK, Required | **BLOCK, Critical**: contradicts ACC-002 C2/C7 and Q1 "no error"; also re-breaks the round-1 deleted-territory path. Plus Required: spec drift and stale GREEN/plan | pass |

## Findings
No blocker against the skill pack in this run.

1. minor - review severity, which the scenario does not test, and the cache's remaining value.
   - **Round 1:** the reviewer rated the deleted-territory risk Required. The fix was to re-check the cached id by primary key on every save.
   - **Round 2:** the reviewer then noted (Nit 1) that "the 1 h cache only saves the name query: each save still costs one query".
   - **Result:** the actor ended with a cache that saves little, and handed "no cache" back to the human at the gate.
   - **Gap:** neither the reviewer's suggestion list in round 1 nor the cache guidance weighs a fix against the cache's purpose. The listed options were: invalidate from a territory Delete/Update step, re-check every save, or ask the human whether failures within the TTL are acceptable.
   - **Not a defect:** correctness is fine and the trade-off is recorded in the Canvas Sync log.

## Fixes
- none required by this run.

## Verdict
**pass.**
- Checks: 29/29.
- Grader: every criterion is met, and both planted violations were blocked at Critical, above the expected Required.

Next runs should re-check:
- that SYSTEM plus the org-wide cache is still chosen from the Q2 answer and not assumed silently;
- that the TTL comes from the human's answer.
