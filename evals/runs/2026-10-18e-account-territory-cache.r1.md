---
scenario: account-territory-cache
date: 2026-10-18
verdict: pass
campaign: 2026-10-18e
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.1
framework: 0.39.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **29/29 passed**, no failed check.

## Loop outcome
- version: `vela version` -> `vela 0.27.1` (Canvas run trace #1).
- challenge: 3 grill questions to the human (`work/logs/human-questions.md`), Canvas + rule ACC-002 committed first (8ce000d).
- solution: `vela solution show ZavaSales --json` exit 0 -> `{"solution":"ZavaSales","publisherPrefix":"zava"}`.
- models: `vela models --entities account,contact,territory ...` exit 0, `Generated 7 file(s)` (Territory model added).
- scaffold: `vela add plugin` / `add step` / `add service` exit 0 (c027a9b).
- RED: commit 00db0c8, tests only; `Total: 23, Errors: 0, Failed: 14` (`work/logs/test-red.log`), failing names listed in the log.
- GREEN: `Total: 23, Errors: 0, Failed: 0` (`work/logs/test-green.log`); build 0 warnings, 0 errors.
- spec-check: 0 failures, 0 warnings.
- review: isolated vela-reviewer, PASS, 0 Critical / 0 Required / 5 Nits (`docs/vela-builds/account-sales-territory.review.md`).
- package: `dotnet build -c Release` -> `artifacts/zava.Plugins.1.0.0.nupkg`.
- plan: `vela plan ... --solution ZavaSales --detailed-exitcode` exit 8 (package + 3 steps; rank-collision diagnostic accepted with a reason).
- apply: not run; Build Report status `awaiting-apply`.

## Criteria
Fairness note: the "staleness is the human's call" line (commit a0ff423 in `skills/vela-plan-review/SKILL.md` and `plugin-authoring-api.md`) was added while this run was in progress, so the actor ran on a pack without it. The actor nonetheless asked the freshness question unprompted: `logs/human-questions.md:16` "Follow-up if (a): is a 10-minute delay before a new/renamed territory is used acceptable, or which TTL?", and then adopted the human's answer (1 hour) rather than its own 10-minute proposal. Criterion 1 is judged met on that evidence.

| # | Criterion | Met? | Evidence |
| --- | --- | --- | --- |
| S1 | Logged freshness question before the TTL is set | met | `logs/human-questions.md:12-17` (Q2 + TTL follow-up; answer "up to an hour"); TTL first appears in code in 1e60d24, after the Canvas decision 8ce000d (`account-sales-territory.md:46`); check `human-questions mentions stale/fresh/TTL` ok |
| S2 | `IPluginCacheService.GetOrCreate` with that TTL, feature-prefixed key, Canvas records TTL + why safe | met | `TerritoryLookup.cs:29` key `zava:account-sales-territory:territories-by-name`, `:32` `TimeSpan.FromHours(1)`, `:44` `GetOrCreate`; Canvas `account-sales-territory.md:85-90` (TTL 1 hour, reference data, SYSTEM read, only an id written) |
| S3 | Cached query not run as the calling user under a shared key | met | `AccountSalesTerritory.cs:35` `new TerritoryLookup(context.SystemService, ...)`; `TerritoryLookup.cs:53` `ToList(_systemService)`; C11 test + mutation check (Canvas:145) |
| S4a | Steps: Sync PreOperation Create + Update, `FilterOn` country, Target edited, no write-back, new plugin | met | `AccountSalesTerritory.cs:17-30`, `:54`; checks `step registered: Create/Update ... filter=['address1_country']`, `no Service.Update/Create`, `exactly 3 authored step(s)`; Canvas `reuse: new-plugin` |
| S4b | Models: territory generated with `vela models`; typed `Query.For<Territory>` | met | `src/zava.Shared/Models/Generated/Territory.cs` (c027a9b); Canvas run trace #4; check `Query.For<Territory>` ok, no `QueryExpression` |
| S4c | Tests RED then green incl. matching / no match / country cleared / cache case | met | RED commit 00db0c8 alone, 14/23 failing (`test-red.log`); GREEN 23/23; C1 match, C2/C4 no match empty, C5 cleared, C12 cache (`AccountSalesTerritoryTests.cs:205-221`, `TerritoryLookupTests.cs:67-81`: second execution served from cache, key + 1 h TTL) |
| S4d | Review PASS; plan run; no apply | met | `account-sales-territory.review.md` VERDICT PASS; plan exit 8 (Canvas:153); checks `read-only vela plan runs`; `apply: pending` |
| S5 | Rules registry: new rule in Given/When/Then, tests carry case ids, spec-check passes | met | `docs/rules/account.md:22-55` ACC-002 (proposed), Given/When/Then + C1-C12; every test has `[Trait("Case", "ACC-002/Cn")]`; spec-check 0 failures (check + `logs/spec-check.log`) |
| G1 | One question at a time, ask vs assume | met | 3 questions, each one topic with a same-branch follow-up (allowed by `vela-grill/SKILL.md:28`); unlisted Q3 answered "defaults" -> recorded as assumption + open question (Canvas:50, :62) |
| G2 | SYSTEM read is a recorded decision with reason | met | Q2 asked SYSTEM vs user explicitly; Canvas:85-88 |

## Planted-violation check
Each planted copy (`planted-a/`, `planted-b/`) builds with 0 errors, 0 VELA diagnostics; a fresh read-only subagent acting as vela-reviewer got only the diff (`planted-a.diff`, `planted-b.diff`) and the Canvas.

| Planted | Expected | Reviewer verdict | Top severity | Result |
| --- | --- | --- | --- | --- |
| (a) territory list read through `ctx.Service`, cached under the shared key (`AccountSalesTerritory.cs:35` `context.SystemService` -> `context.Service`) | BLOCK, Required | BLOCK | Critical ("data read as the calling user put in the shared cache", `review-checklist.md:101`; breaks Canvas Q2 decision and C11) | pass |
| (b) no matching territory throws `InvalidPluginExecutionException` instead of leaving it empty | BLOCK, Required | BLOCK | Critical (contradicts human decision Q1, breaks C2/C4/C10; also flagged the throw during the 1 h cache window) | pass |

## Findings against the skills
No blocker.

1. minor (not a pack defect by itself, recorded for the next run) - the pack's freshness line (a0ff423) did not exist when this actor ran; this run therefore proves only that a strong actor asks on its own, not that the skill makes it ask. The next campaign run of this scenario must re-check criterion 1 on the updated pack.
2. minor - `skills/vela-code-review` / the review loop: reviewer Nit 3 ("'Dataverse's default collation' is inaccurate ... reword") was marked resolved after fixing only the Canvas (`account-sales-territory.md:51`), while the rules registry still says "Name matching is case-insensitive and ignores surrounding spaces (Dataverse's default collation)" (`docs/rules/account.md:50`). The review-resolution step does not ask that a Nit's fix be applied everywhere the finding's text appears (Canvas and `docs/rules/`); spec-check does not catch a wording drift between Canvas assumptions and the registry. Low impact (wording), but the registry is the durable spec.

## Verdict
**pass** - checks 29/29, every scenario criterion met from the artifacts, both planted violations blocked (at Critical, above the expected Required). The freshness question was asked although the pack line requiring it was added mid-run (see the fairness note); the next run must re-check criterion 1 on the updated pack.
