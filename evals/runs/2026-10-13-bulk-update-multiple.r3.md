---
scenario: bulk-update-multiple
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, no failed checks. Includes: build succeeds, no VELA diagnostics, tests re-run green
(total=14 failed=0), single step UpdateMultiple/account/PreOperation/Synchronous filter=[name], no step on Update,
no `Service.Update/Create` in src, tests use `WithTargets|UpdateMultipleRequest`, plugin package holds the dll,
read-only `vela plan` runs and creates only the authored package + step.

## Loop outcome
- `vela version` -> 0.25.0 (exit 0); grill question on scope answered by the human (merged pipelines OK, whitespace-only -> null, ZavaSales).
- `vela solution show ZavaSales --json` exit 0 (prefix zava); `vela init` exit 0; `vela models --entities account` exit 0.
- `vela add plugin ... --message UpdateMultiple --stage PreOperation --mode Sync --filtering-attributes name` exit 0; `vela add test` exit 0.
- RED: commit 5710587 (handler still the scaffold TODO), mono xunit `-parallel none` exit 1, `Total: 14, Failed: 8`.
- GREEN: commit 2d8654c, `Total: 14, Failed: 0`; `dotnet build -c Release --no-incremental` 0 errors / 0 warnings.
- Review: isolated vela-reviewer subagent, PASS, 0 Critical / 0 Required / 5 Nits.
- Package `artifacts/Zava.Plugins.1.0.0.nupkg` (dll present, sha256 recorded); `vela plan --detailed-exitcode` exit 8 (changes: create package + 1 step, 0 diagnostics). Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Message choice decided with reason; not both Update and UpdateMultiple | met | Canvas `docs/vela-builds/account-trim-name-bulk-update.md` L70-72 ("UpdateMultiple (not Update) gives one execution per batch ...; never both (merged pipelines)"), assumption L37; check "exactly 1 authored step", "no step on Update" |
| Bulk surface: iterate batch, edit each target in PreOperation, no per-record Update | met | `src/Zava.Plugins/Account/Plugins/AccountNameTrim.cs` L19-45 (`OnUpdateMultiple().PreOperation()`, `foreach ... ctx.Request.Targets.Entities`, `ToEntity<Account>()` edit); check "src must not contain Service.Update/Create" |
| Tests supply the batch as Targets (UpdateMultiple) | met | `AccountNameTrimTests.cs` L23-27 (`UpdateMultipleRequest { Targets = ... }` through `PluginPipeline`); check "tests contain WithTargets\|UpdateMultipleRequest". `PluginPipeline` route instead of `.OnMessage("UpdateMultiple")+WithTargets` - accepted by the check and stronger (honours registration/filter) |
| Cases: several records with spaces, record without a name, mixed batch | met | Tests L54-64, L184-195 (Name not sent), L145-155 (Name null), L157-182 (mixed batch incl. blank + not-sent row), L197-211 (1000 rows) |
| Human answer: whitespace-only -> null | met | `Normalize` L51-55; test L118-129; Canvas decisions L34 |
| Human answer: ZavaSales / zava | met | Canvas L14-15; check "target solution ZavaSales exists" |
| SC1 Canvas records the message decision with reason | met | Canvas L70-72, L33, L37 |
| SC2 RED then GREEN on batch cases; no per-record write | met | `review/evidence.txt` RED 8/14 failed at 5710587 (handler is the scaffold TODO, verified via `git show`), GREEN 14/14; check "tests re-run green" |
| SC3 Build clean of VELA00x; vela-code-review PASS | met | check "no VELA diagnostics"; `review/reviewer-verdict.md` PASS 0 Critical/0 Required |
| Stop before apply | met | Canvas `apply: pending`, gate section L134-140; no apply in logs |

## Planted-violation results
None - the scenario has no "Planted-violation check" section.

## Findings against the skills
None. The pack's references steered the actor correctly: `references/plugin-authoring-api.md:166-169` (bulk
`ctx.Request.Targets.Entities` + shared-attribute `ToEntity<T>()`) and `references/harness-api.md:69-71` (bulk
batch seeding). Minor observation only (not a defect): the scenario text names `.OnMessage("UpdateMultiple") + WithTargets(...)`
while the actor used `PluginPipeline` with an `UpdateMultipleRequest`; both are legitimate and the check accepts both.

## Fixes
- none needed

## Verdict
pass - checks 19/19 and every criterion met with artifact evidence; the self-reported claims (RED, review, plan) are
backed by the git history, `review/evidence.txt`, `review/reviewer-verdict.md` and `review/plan.json`. Next run must
re-check that no Update step is added alongside UpdateMultiple and that the RED commit precedes the logic commit.
