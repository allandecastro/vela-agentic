---
scenario: bulk-update-multiple
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- version: `vela version` -> vela 0.25.0 (Canvas Run trace #1).
- challenge: vela-plan-review + vela-grill; one human question (target solution -> ZavaSales); `vela solution show ZavaSales --json` -> prefix zava (exit 0).
- scaffold: `vela init --name ZavaSales --prefix Zava --publisher-prefix zava` (0); `vela models --entities account` (0, 4 files); `vela add plugin AccountTrimNameBulk --message UpdateMultiple --stage PreOperation --mode Sync --filtering-attributes name` (0); `vela add test ... --message UpdateMultiple` (0).
- RED: commit c55a3eb (tests only; handler still the scaffold TODO) -> `Total: 14, Failed: 9`.
- GREEN: commit bcce7ee -> `Total: 14, Failed: 0` (mono xunit 2.9.2, `-parallel none`).
- verify: `dotnet build -c Release --no-incremental` 0 warnings / 0 errors.
- review: self-review fallback (subagent dispatch refused by the concurrent-subagent limit, labelled in the Build Report) -> PASS, 1 Nit (Canvas wording) fixed in fd2c1af.
- preview: `dotnet build -c Release` -> artifacts/Zava.Plugins.1.0.0.nupkg (dll inside); `vela plan ... --detailed-exitcode` exit 8: create package + 1 step (UpdateMultiple/account/20/Sync/filter name). Stopped at the apply gate.

## Checks (evals/checks/check.py)
19/19 passed. No failed check. Notably: step registered UpdateMultiple/account/PreOperation/Sync filter [name]; exactly 1 authored step; no step on Update; no `Service.Update/Create` in src; tests contain `WithTargets`; read-only `vela plan` runs and creates only authored steps.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| Message choice: Canvas decides UpdateMultiple vs Update and records why; not both | met | Canvas `docs/vela-builds/account-trim-name-bulk.md` L33 (assumption: merged pipelines, UpdateMultiple only "avoids running twice"), L69-71 (Approach: one execution per batch, "never both"); check "no step on Update", "exactly 1 authored step(s)" |
| Bulk surface: iterates the batch, edits each target in PreOperation, never `Update` per record | met | `src/Zava.Plugins/Account/Plugins/AccountTrimNameBulk.cs` L17-19 (`OnUpdateMultiple().PreOperation().Sync()`), L28-43 (`foreach row in ctx.Request.Targets.Entities`, sets `target.Name`); check "src must not contain Service.(Update|Create)" ok |
| Tests supply the batch as Targets (`WithTargets` / `UpdateMultiple`) | met | Tests L21-24 + L36/60/77/114 (`UpdateMultipleRequest` through `PluginPipeline`), L98-101 `PluginContext.For<Account>().WithTargets(...)`. No `.OnMessage("UpdateMultiple")`, but `harness-api.md` L71-73 says `WithTargets` alone is enough for a single-step plugin |
| Case: several records with spaces | met | Theory L45-64 (8 values) + mixed batch L67-90 (3 trimmed rows) |
| Case: a record without a name | met | L81/89 (row without Name left alone), L92-105 (Name not added), L107-118 (Name not sent -> does not fire), L120-131 (Name cleared -> null) |
| Case: mixed batch | met | `Mixed_Batch_Trims_Each_Target_Once_Per_Batch` L67-90 (single ExecutionLog entry, trimmed / untouched / not-sent rows) |
| SC1 Canvas records the message decision with its reason | met | as above (Canvas L33, L67-71) |
| SC2 RED then GREEN on the batch cases; no per-record write | met | git: c55a3eb (tests only, handler = scaffold TODO) before bcce7ee; Build Report L106-108 RED 9 failed / GREEN 14/14; checks "tests re-run green" total=14 failed=0; no `Service.Update` |
| SC3 build clean of VELA00x; vela-code-review PASS | met | check "no VELA diagnostics", "build succeeds"; Build Report L113-115 self-review PASS (labelled fallback, allowed by the evaluator note) |
| Human answers: logic may also run for single Updates | consistent | Built and tested (L133-145), flagged as open question (Canvas L40) |
| Human answers: whitespace-only Name becomes null | partly | Built as `''` (Canvas L26/L36, test L52) and left as an open question blocking apply rather than asked. Dataverse persists an empty string as null, so the saved result matches; the test `SavedName(...) ?? string.Empty` (L63) cannot tell the two apart. Not a scenario success criterion; noted, not failed |
| Stop before apply | met | Canvas `apply: pending`, Gate section; no apply in the Run trace |

Self-review quality: adequate for this small diff - spec and standards points match what an isolated reviewer would check (bulk iteration, no write-back, FilterOn, not-sent vs cleared). It missed the Nit that the whitespace-only test's `?? string.Empty` hides the `''`/null distinction its own open question is about.

## Planted-violation results
None: the scenario has no "Planted-violation check" section.

## Findings against the skills
1. minor - `skills/vela-grill/SKILL.md` lists "Trigger: ... Do **other events** reach the same outcome (delete, re-parent, bulk) - are they in scope?" and "Data: ... where do defaults/edge cases go?", and its red flag is "Ending the interview with a branch still unresolved". `skills/vela-plan-review/SKILL.md` step 4 says to continue on an assumption unless the branch is "a business decision only the human can make". With a human reachable, the actor started vela-grill but asked only for the solution. It then pushed two acceptance-changing business decisions (does it apply to single Updates; what happens to a whitespace-only Name) to "open questions that block apply". The two skills disagree on whether an edge-value rule ("whitespace-only means empty", which plan-review itself gives as an assumption example at L88-89) is a business decision to ask once grill is running. Suggested fix: when vela-grill is already in progress with a reachable human, have it ask the behaviour-changing edge cases in the same interview, as one-line follow-ups, instead of deferring them to the apply gate.

## Verdict
pass - checks 19/19 and every scenario criterion met from the artifacts. There is no planted violation to test. Next run should re-check: whether the whitespace-only case is asked (expected answer: null) and whether its test separates `''` from null.
