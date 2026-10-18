---
scenario: account-territory-cache
date: 2026-10-18
verdict: pass
campaign: 2026-10-18f
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.1
framework: 0.39.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- version `vela version` → 0.27.1 (exit 0); `vela solution show ZavaSales --json` → `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- grill: Q1-Q4 logged in `work/logs/human-questions.md` (country column, no-match behaviour, staleness/TTL, security context); Canvas + ACC-002 (proposed) committed first (d6f7a80).
- `vela models --entities account,contact,territory` (exit 0, Territory.cs generated, d082485); `vela add plugin/step/service/test` (7343ad0).
- RED (5d823fc): `Total: 22, Errors: 0, Failed: 14, Skipped: 0` (exit 1, `logs/test-red.log`).
- implement (5c25af6); first green `Total: 22, Failed: 0` (`logs/test-green.log`, 13:17:11).
- 5bd71fc drops the two generated `Fires_On_*` tests; verify run `Total: 20, Failed: 0` (`logs/test-verify.log`, 13:18:47); spec-check 0/0.
- review: isolated vela-reviewer PASS, 0 Critical / 0 Required, 4 Nits, 1 Gate item.
- `dotnet build -c Release` → `artifacts/zava.Plugins.1.0.0.nupkg`; `vela plan ... --detailed-exitcode` → exit 8 (create package + 3 steps, 1 execution-order diagnostic). No apply; Build Report `status: awaiting-apply`.

## Checks
29/29 passed (`checks.json`), no failed check. The evaluator's re-run: `total=20 failed=0`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Cache: `IPluginCacheService.GetOrCreate`, explicit TTL in Canvas, feature-prefixed key | met | `TerritoryLookup.cs` `GetOrCreate(CacheKey, CacheTtl, ...)`, `CacheKey = "account-territory:territories-by-name"`, `TimeSpan.FromHours(1)`; Canvas :85, :106 |
| Staleness asked before picking the TTL (SC1) | met | `logs/human-questions.md` Q3 (options no-cache / 5 min / 1 h / other, cost stated); Canvas decision :36 cites the answer |
| Never cache user-filtered data: SYSTEM read with Canvas reason (SC3) | met | `AccountTerritoryFromCountry.cs` ConfigureServices `context.SystemService`; Canvas :37, :106; mutation check (Service → C14 fails), Build Report :136 |
| Steps: Sync PreOp Create + Update, FilterOn country, Target edit, new plugin | met | checks "step registered: Create/Update ... filter=['address1_country']", "no Service.Update/Create"; Canvas :8-10, :78 |
| Models generated, typed query | met | checks "Query.For<Territory>", no QueryExpression; `Territory.cs` generated (d082485) |
| Tests RED first, incl. matching / no match / country cleared / cache case (SC4) | met | RED commit 5d823fc before 5c25af6; RED log 14 failures named with case ids (Build Report :128-134); C1, C3, C10, C13 (pipeline + service) green in `logs/test-verify-cases.txt` |
| Review PASS, plan run, no apply (SC4) | met | `account-territory-from-country.review.md` PASS; `logs/plan.json` exit 8; `apply: pending` |
| SC2: Canvas records TTL and why safe to cache | met | Canvas :36-37, :104-107 |
| SC5: rule in English Given/When/Then, tests carry case ids, spec-check passes | met | `docs/rules/account.md` ACC-002; every test `[Trait("Case","ACC-002/Cn")]`; `logs/spec-check.log` 0/0; check "spec-check passes" |
| Ask-vs-assume | met | country column (Q1) relayed as "use defaults" → recorded as assumption + Gate item 1; duplicate names recorded as assumption |

### Why the RED run has 22 tests and the final green run has 20
The two missing tests are `Fires_On_Create_PreOperation` and `Fires_On_Update_PreOperation`. `vela add test` generated them in 7343ad0, and they passed in RED as guard tests. The suite was still 22/22 green after the implementation (`logs/test-green.log`). Commit 5bd71fc then deleted both ("drop the generated Fires_On_* tests (no case id; firing is asserted by C5/C7/C10-C12)"), and the verify, review and Build Report runs show 20. Count: 17 ACC-002 (C1-C4, C5×3, C6-C14, and C13 in the service test) + 3 ACC-001 = 20.

**This is not a defect of the build:**
- No behaviour case was lost.
- No pre-existing (regression) test was touched. Both tests were born on this branch, and spec-check passes.
- Firing is still proven through `PluginPipeline`: C5 asserts `Single(ExecutionLog, Create && HandlerInvoked)`, C10/C11 do the same for Update, and C7/C12 assert non-firing.
- The removal is disclosed in the Build Report (Sync log :161, commit list :119), and the reviewer saw it ("2 generated Fires_On_* added then removed").

The one blemish is in the evidence: Build Report :135 cites only the final 20-test run and does not quote the first 22/22 green. The RED→green delta is therefore explained only in the Sync log. This is a pack gap (finding 1), not a failed criterion.

## Planted-violation check
Each planted copy (`planted-a/`, `planted-b/`) builds with 0 warnings, 0 errors and 0 VELA diagnostics. A fresh read-only subagent acting as vela-reviewer got only the diff (`planted-a.diff`, `planted-b.diff`) and the Canvas.

| Planted | Expected | Reviewer verdict | Top severity | Result |
| --- | --- | --- | --- | --- |
| (a) `AccountTerritoryFromCountry.cs:36` changes `context.SystemService` to `context.Service`, so the list is cached under the shared key | BLOCK, Required | BLOCK | Critical ("data read as the calling user put in the shared cache"); also Required: C14 broken, and code changed ahead of the Canvas | pass |
| (b) `TerritoryLookup.FindByName` throws `InvalidPluginExecutionException` on no match | BLOCK, Required | BLOCK | Critical (contradicts the human decision, breaks C3/C4/C9/C13); also Required: interface contract out of sync | pass |

## Findings against the skills
No blocker.

1. **minor** - `skills/*/references/harness-api.md:35` says "It generates a pipeline `Fires_On_*` test ... un-skip `Does_What_It_Should` and put the acceptance cases there". `skills/vela-test-harness/SKILL.md:69` says "A test without a case id ... is a review finding".
   - The pack never says what happens to the generated, untagged `Fires_On_*` tests. Tag them with a case, keep them, or delete them?
   - The actor deleted them after the first green run (5bd71fc). As a result the RED total (22) and the reported green total (20) differ, which looks like vanished tests unless the reader finds the Sync log.
   - `build-report-template.md:128` asks for the RED summary but has no line requiring the harness evidence to reconcile RED and green totals.
   - Suggested change: one line in vela-test-harness saying either "fold the generated `Fires_On_*` into a case-tagged pipeline test, or delete it before RED", or "when the test count changes between RED and green, say which tests and why in Evidence".
2. **minor (actor, not the pack)** - `vela-grill/SKILL.md:24` says "one focused question at a time". Q2 carried a "ride-along" (case-insensitive match). It was load-bearing and the answer was clear, so this is not counted as a failed criterion, but it bundles two decisions in one question.

## Fixes
- none yet

## Verdict
**pass.** Checks 29/29, every scenario criterion is met from the artifacts, and both planted violations were blocked at Critical (expected Required). The RED 22 → green 20 drop is two scaffold-generated `Fires_On_*` tests deleted after the first green run. Their coverage is retained by the case-tagged pipeline tests, so the drop is not a defect, but the pack should say how to handle them (finding 1). The next run must re-check how the generated `Fires_On_*` tests are handled and whether the RED/green totals are reconciled in Evidence.
