---
scenario: bulk-update-multiple
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.6
runner: "campaign actor + separate grader"
---

## Loop outcome
- `vela version` -> vela 0.21.0 (Canvas Run trace #1).
- Plan review + grill: Canvas drafted (`work/canvas-draft.md`), human answers recorded (scope A, whitespace-only -> null, ZavaSales/zava).
- `vela init ZavaSales --prefix zava --no-integrations --no-console -o .` exit 0 (Vela.Plugins 0.29.6); demos removed.
- `vela add plugin AccountTrimNamePlugin --entity Account --message UpdateMultiple --filtering-attributes Name` exit 0; PostOperation -> PreOperation as vela-scaffold says.
- `vela models` skipped (no org), command recorded; Account.Name already in scaffold model, no stand-in.
- Tests written first (commit 3d44152): RED 11 total / 6 failed. **Grader re-ran RED independently** by checking out 3d44152 in a clone: `Total: 11, Errors: 0, Failed: 6` - the same 6 behaviour tests failed.
- Implement (ce2990a) -> GREEN 11/11; build 0 warnings / 0 errors.
- Isolated vela-reviewer: PASS, 0 Critical / 0 Required / 7 Nits (recorded in the Build Report; diff in `review/diff.txt`).
- Package `artifacts/zava.Plugins.1.0.0.nupkg`; `vela plan` skipped (no org), command recorded; stopped at the apply gate.

## Deterministic checks
15/15 passed (`checks.json`, pass: true). No failed checks. Includes: build succeeds, no VELA diagnostics, tests re-run green (11/0), exactly 1 step `UpdateMultiple account PreOperation/Synchronous filter=['name']`, no step on Update, no `UserService.Update/Create` in src, tests contain `WithTargets`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Message choice: Canvas decides UpdateMultiple vs Update and records why; not both | met | Build Report `docs/vela-builds/account-trim-name-updatemultiple.md` L44 (assumption: merged pipelines), L74-81 (Approach: "registered on UpdateMultiple only, not also on Update ... registering both would run the logic twice"), L109; checks "exactly 1 authored step(s)", "no step on Update" |
| Bulk surface: iterates the batch, edits each target in PreOperation, no per-record Update | met | `src/zava.Plugins/Account/Plugins/AccountTrimNamePlugin.cs` L23-24 (`OnUpdateMultiple().PreOperation()`), L34 (`foreach ... ctx.Request.Targets.Entities`), L43-47 (in-place edit via shared attribute collection); check "src must not contain UserService.(Update|Create)"; test L45 `Assert.Empty(crm.GetAll("account"))` |
| Tests: batch supplied via WithTargets (+ OnMessage where needed); cases several-with-spaces, no-name, mixed | met | Tests L22-30 `PluginContext.For<Account>().WithTargets(targets)` (single-step plugin: trigger derived, per `references/harness-api.md` L73-75); L33-46 several padded, L59-68 Name not sent, L106-120 mixed batch; L123-145 pipeline `UpdateMultipleRequest` asserts `run.Message == "UpdateMultiple"` |
| Human answer: whitespace-only Name -> null | met | Plugin L63-64; test L94-103, L119, L142 |
| Human answer: solution/prefix ZavaSales/zava | met | Canvas L24-25; apply command L200 `--solution ZavaSales` |
| SC1: Canvas records the message decision with its reason | met | Canvas L74-81 |
| SC2: RED then GREEN on the batch cases; no per-record write in handler | met | RED: Canvas L130-136, commit 3d44152 has TODO handler; grader reproduction 11/6 failed incl. Batch_PaddedNames, MixedBatch, WhitespaceOnly, Pipeline_UpdateMultiple. GREEN: check "tests re-run green" total=11 failed=0 |
| SC3: build clean of VELA00x; vela-code-review PASS | met | checks "build succeeds", "no VELA diagnostics"; Canvas L150-158 reviewer PASS 0 Crit / 0 Req (raw reviewer output not saved as a separate file; the diff given to it is in `review/diff.txt`) |
| Stop before apply | met | Canvas `apply: pending`, Gate section L190-203; no apply in the Run trace |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Findings against the skills
1. minor - `skills/vela-plugin-authoring/SKILL.md` step 2 says "do not fall back to a magic string" and covers only the no-org *property* stand-in. It gives no typed way to ask "did the target send this column?" when the scaffold's minimal model has no field-name constants. The actor declared `private const string NameColumn = "name"` (plugin L19) and wrote `entity.Contains(NameColumn)`, and recorded the exception in Norms. That was a reasonable call, but the skill should name the sanctioned idiom for presence checks (e.g. generated `Fields` constants after `vela models`, or a labelled stand-in constant in the no-org case).
2. minor - `vela-code-review` / `agents/vela-reviewer.agent.md` do not require the dispatcher to save the reviewer's raw findings as an artifact. Only the diff (`review/diff.txt`) and the actor's summary in the Build Report survive, so the "Reviewed" claim cannot be checked independently against the reviewer's own words.

## Verdict
pass. All 15 checks passed and every criterion is met from the artifacts. The grader reproduced RED independently. Next run must re-check: the RED evidence still comes from a test-only commit before the implementation, and the Canvas still states the Update-vs-UpdateMultiple reason.
