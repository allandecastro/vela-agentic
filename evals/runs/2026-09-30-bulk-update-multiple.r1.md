---
scenario: bulk-update-multiple
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.6
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, no failed checks. The checks cover: the Canvas exists, the build succeeds,
there are no VELA diagnostics, 12/12 tests re-run green, exactly one authored step
(UpdateMultiple/account/PreOperation/Sync, filter `name`), no Update step, no demo registered, the package
holds the dll, `src` has no `Service.Update/Create`, and the tests use `WithTargets`.

## Loop outcome
- `vela version` gave 0.21.0. `vela init --name ZavaSales --prefix zava --output . --no-integrations --no-console` exited 0 (Vela.Plugins 0.29.6), and the demos were removed (commit fa10dee).
- The Canvas was committed (c91bf38) before the scaffold. `vela add plugin AccountTrimName --entity Account --message UpdateMultiple --filtering-attributes Name` and `vela add test` both exited 0 (a12fe8a).
- The RED tests were committed (e7ddc45) with the TODO handler. **The grader re-ran it independently** on a clone at e7ddc45 (Mono xunit.console, `-parallel none`): `Total: 12, Errors: 0, Failed: 8, Skipped: 0`. The failing tests were AC1, AC2, AC4, AC6, AC7, AC8, AC10 and AC12, matching the Build Report.
- GREEN (2c12c14): checks.json re-ran 12/12 with 0 failed. The build had 0 errors, 0 warnings and no VELA00x.
- Review by an isolated vela-reviewer: PASS with 0 Critical, 0 Required and 2 Nits (Build Report lines 116-119). The diff the reviewer got is at `work/review1/diff.txt`.
- `vela plan` was skipped because there is no org. The exact command is recorded. `vela apply` was not run, and the Gate section hands it to a human.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Message choice is decided and the reason recorded; UpdateMultiple and Update are not both registered | met | Canvas `account-trim-name-bulk.md:36`: "UpdateMultiple and Update pipelines are merged ... so no Update step is registered (it would run twice)". Also `:70-72` (Approach), `:93` "never register both Update and UpdateMultiple", `:30` (human scope decision). Checks "exactly 1 authored step" and "no step on Update" |
| Bulk surface: iterates the batch, edits each target in PreOperation, no per-record Update | met | `AccountTrimName.cs:19-22` (OnUpdateMultiple/PreOperation/Sync/FilterOn Name), `:33-56` (foreach over `ctx.Request.Targets.Entities`, edits in place, no service calls). Check "src must not contain Service.Update/Create" |
| Tests supply the batch as Targets (WithTargets / the UpdateMultiple message) | met | `AccountTrimNameTests.cs:23-26` `PluginContext.For<Account>().WithTargets(targets)`. For a single-step plugin, `references/harness-api.md:73-76` says WithTargets alone derives the trigger, so `.OnMessage("UpdateMultiple")` is not needed. The pipeline test also sends `UpdateMultipleRequest` (`:126`) |
| Case: several records with spaces | met | AC1 `:33-44` (3 padded targets) and AC7 `:113-132` |
| Case: a record without a name | met | AC5 `:77-87` (Name null), AC6 `:92` (Name not sent), AC4 (whitespace-only becomes null, per the hidden human answer) |
| Case: a mixed batch | met | AC6 `:90-100` (not-sent plus padded), AC7 (padded plus whitespace-only) |
| Whitespace-only Name becomes null (hidden answer) | met | `AccountTrimName.cs:45-49`, AC4 and AC7 |
| Single Updates are acceptable (merged pipeline) | met | AC8 `:135-145`, Canvas `:30`, `:72` |
| SC1: the Canvas records the message decision with its reason | met | Canvas `:36`, `:70-72` |
| SC2: RED then GREEN on the batch cases; no per-record write | met | RED reproduced by the grader (8/12 failing at e7ddc45). GREEN 12/12 (checks.json). The RED run fails on AC1 and AC7. `RunBatch` asserts that the org is empty (`:29`) |
| SC3: build clean of VELA00x; vela-code-review PASS | met | checks "build succeeds" and "no VELA diagnostics". Build Report `:116` "PASS, 0 Critical, 0 Required, 2 Nits" |
| Solution/prefix ZavaSales / zava | met | Canvas `:14-15`, `ZavaSales.sln`, `zava.Plugins.csproj` |
| Stop before apply | met | Canvas `:54` `apply: pending`, and the Gate section `:148-155` |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Findings against the skills
None blocking.
1. minor (evidence, not a behaviour defect) - the reviewer's raw output was not persisted. Only the actor's transcription in the Build Report (`:116-119`) and the input diff (`work/review1/diff.txt`) exist. `AGENTS.md` asks for "the `vela-code-review` findings list", and the Build Report does contain that list, so the criterion is met. Persisting the reviewer's verbatim verdict would make it independently checkable.

## Fixes
- n/a

## Verdict
**pass**: checks pass (15/15) and the grader passes, with every criterion met. RED was verified independently.
The next run must re-check two things:
- The Canvas still records the merged-pipeline reason for picking UpdateMultiple over Update.
- The scaffolded `WithTarget` test is still replaced by `WithTargets`.
