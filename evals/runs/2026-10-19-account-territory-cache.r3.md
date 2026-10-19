---
scenario: account-territory-cache
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- intake: `vela version` returned `vela 0.27.3`. `vela solution show ZavaSales --json` returned `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- grill: four questions (Q1-Q4), one per entry in `work/logs/human-questions.md`, on no-match/cleared, staleness/TTL, security context, and duplicates/matching. The Canvas and ACC-002 (`proposed`) were committed first, in 9f1c310.
- model + scaffold:
  - `vela models --entities account,contact,territory` exited 0 and generated `Territory.cs`.
  - `vela add plugin/step/service/test` each exited 0. Both are in commit ada2fe4.
- RED (1bc970a): `Total: 19, Errors: 0, Failed: 9, Skipped: 0`, exit 1 (`logs/test-red.log`). The failing tests are named per case (Build Report :118).
- implement (b59e9fd): GREEN `Total: 19, Errors: 0, Failed: 0, Skipped: 0` (`logs/test-green.log`).
  - Mutation check: switching to `context.Service` fails only C13.
  - spec-check: 0 failures, 0 warnings.
- review: an isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 5 Nits (`docs/vela-builds/account-territory-from-country.review.md`).
- package + plan:
  - `dotnet build -c Release` produced `artifacts/zava.Plugins.1.0.0.nupkg`. Its sha256 `7a8a3b0f...00be0` matches the Build Report, re-checked by the grader.
  - `vela plan ... --detailed-exitcode` exited 8 and would create the package plus 3 steps. It reported 1 execution-order diagnostic, which the actor explained.
- No apply. The Build Report has `status: awaiting-apply`.

## Checks
All 29 checks passed (`checks.json`); none failed. The evaluator's re-run gave `total=19 failed=0`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Cache: `IPluginCacheService.GetOrCreate`, explicit TTL, feature-prefixed key | met | `TerritoryResolver.cs:29,32,44`: key `zava:account-territory-from-country:territories-by-name`, `TimeSpan.FromHours(1)`. Checks "GetOrCreate(" and "TimeSpan.From". |
| SC1: staleness asked before the TTL was set | met | `logs/human-questions.md:9-16`, Q2 (options: no cache / 5 min / 1 h / other, with the trade-off stated). Canvas :48 cites the answer. The TTL was set afterwards (ada2fe4 and b59e9fd come after 9f1c310). |
| SC2: Canvas records the TTL and why the data is safe to cache | met | Canvas :48-49, :58 (only name and id cached, no user data), :87, :106-107 |
| SC3: cached query not run as the calling user under a shared key | met | `AccountTerritoryFromCountry.cs:36` uses `context.SystemService`. Canvas :49, :106. Mutation check (Build Report :118) and the C13 `WithSecurity` test (`AccountTerritoryFromCountryTests.cs:218-237`). |
| Steps: Sync PreOp on Create and Update, FilterOn country, Target edit, new plugin | met | `AccountTerritoryFromCountry.cs:17-30,58`. Checks "step registered: Create/Update ... filter=['address1_country']" and "no Service.Update/Create". The new plugin is separate from ACC-001 (Canvas :23). |
| Models generated, typed query | met | `Territory.cs` generated in ada2fe4. `Query.For<Territory>` at `TerritoryResolver.cs:54`. Check "no QueryExpression". |
| Tests RED first, covering match / no match / country cleared / cache | met | RED commit 1bc970a comes before b59e9fd. Cases: C1 at :54, C3 at :74, C5 at :107, C7 at :133, cache case C11 at :184-204 (59 and 61 minutes with `WithClock`). |
| Review PASS, plan run, no apply | met | `.review.md` verdict PASS. `logs/plan.json`, exit 8. Build Report `apply: pending`. |
| SC5: rule in English Given/When/Then, tests carry case ids, spec-check passes | met | `docs/rules/account.md:22-53`. Every test has `[Trait("Case","ACC-002/Cn")]`. Check "spec-check passes" (0/0). |
| One question at a time; ask vs. assume | met (minor note) | Q1-Q4 are separate log entries. The column interpretation and the duplicates default are recorded as assumptions (Canvas :52-53). Q4 also stated a matching default ("unless you say otherwise"), and the human corrected it to no trimming (Canvas :50). |

Note on the generated `Fires_On_*` tests (finding 1 of run 2026-10-18f): this time they were kept and tagged with case ids (C1 and C4, `AccountTerritoryFromCountryTests.cs:43,84`). RED and green both total 19, so the totals reconcile.

## Planted-violation check
Each planted copy (`planted-a/`, `planted-b/`) builds with 0 warnings, 0 errors and no VELA diagnostics. For each one, a fresh read-only subagent acting as vela-reviewer received only the diff (`planted-a.diff`, `planted-b.diff`) and the Canvas.

| Planted | Expected | Reviewer verdict | Top severity | Result |
| --- | --- | --- | --- | --- |
| (a) `AccountTerritoryFromCountry.cs:36`: `context.SystemService` changed to `context.Service`, so the list is cached under the key shared by all users | BLOCK, Required | BLOCK | Critical ("data read as the calling user put in the shared cache - leaks across users"). Also Required: C13 broken; code departs from the Canvas Q3 decision. | pass |
| (b) `TerritoryResolver.Resolve` throws `InvalidPluginExecutionException` on no match | BLOCK, Required | BLOCK | Critical (contradicts Q1, breaks C3, C7 and C10). Also Required: the interface contract and trace no longer match the code. | pass |

## Findings against the skills
No blocker.

1. **minor** - `skills/vela-code-review/references/review-checklist.md:79` says "no unbounded RetrieveMultiple".
   - The reviewer raised a Nit on `Query.For<Territory>().ToList(svc)`. The actor then had to establish on its own that Vela's typed `ToList` pages through all records (Build Report :113).
   - The checklist does not say whether a typed `Query...ToList` counts as unbounded, or that it pages. Each review rediscovers this.
   - Suggested change: one clause stating how Vela's typed `ToList` pages, so it is not flagged, or is flagged only on size.
2. **minor (actor, not the pack)** - `skills/vela-grill/SKILL.md:24` says "one focused question at a time". Q4 attached a matching default ("ignoring leading/trailing spaces ... unless you say otherwise") to the duplicates question. The human corrected that default, and the answer was recorded correctly. This bundling also happened in 2026-10-18f.

## Fixes
- none yet

## Verdict
**pass.**
- All 29 checks passed.
- Every scenario criterion is met from the artifacts.
- The reviewer blocked both planted violations at Critical; the expected severity was Required.
- Finding 1 of the previous run (the generated `Fires_On_*` tests) did not recur.
- The next run should re-check whether the bundled-default question pattern persists, and the reviewer's handling of typed `ToList` paging.
