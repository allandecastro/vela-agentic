---
scenario: account-multi-step
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
vela_cli: 0.21.0
framework: 0.29.3
model: claude-opus-5-5
runner: "campaign actor + separate grader"
---

Re-grade against the corrected scenario (placeholder/VELA001 criterion corrected 2026-09-30: seeing
VELA001 is no longer required). The earlier grading is kept in `run-record.superseded.md`; its verdict was
not reused.

## Check summary
`checks.json`: **17/17 passed**, `pass: true`. No failed checks. Notable: both steps probe as
`account` PreOperation/Synchronous filter `['name']` (Create + Update), exactly 2 authored steps, `HandleUpdate`
and `OnExecute` both present, no `UserService.Update/Create` write-back, tests use `PluginPipeline`, 13 tests
re-run green.

## Loop outcome
- Canvas committed first (767a66d), `reuse: add-step:AccountDefaultDescription`.
- `vela add step AccountDefaultDescription --entity Account --message Update` exit 0; scaffold aligned to the
  Canvas (PostOperation -> PreOperation, `IUpdatePostContext` -> `IUpdatePreContext`, placeholder -> `e => e.Name`,
  pre-image added, class `partial`).
- Models: skipped (no org); labelled `// STAND-IN for vela-models (no org)` AccountNumber property (f07820a), as
  sanctioned by `skills/vela-plugin-authoring/SKILL.md` step 2.
- RED (12 tests, 4 failed) -> GREEN 12/12 -> new case-only-rename case RED (13, 1 failed) -> GREEN 13/13.
- `dotnet build -c Release`: 0 warnings / 0 errors; isolated vela-reviewer PASS (0 Critical / 0 Required / 5 Nits).
- Package built, sha256 recorded; `vela plan` skipped (no org) with the exact command; stopped at the apply gate.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse via `vela add step AccountDefaultDescription --entity Account --message Update` (no new plugin, no hand-written step) | met | Canvas `docs/vela-builds/account-number-uppercase.md:22` (`reuse: add-step:...`), `:101` + run trace row 2 (exit 0); check "exactly 2 authored step(s)" |
| Generated handler `HandleUpdate` kept, `OnExecute` kept for Create | met | `src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs:20,28,31,55`; checks "src contains /HandleUpdate/", "/OnExecute/" |
| Placeholder `FilterOn(e => e.Id /* TODO */)` replaced with `e => e.Name` | met | `AccountDefaultDescription.cs:25`; Canvas `:103`; check "step registered: Update ... filter=['name']" |
| Stage PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:23,35,51` (`target.AccountNumber = upper`); check "no write-back"; tests assert `crm.GetAll` empty |
| Harness: every test states its trigger; Create tests updated and green | met | `tests/.../AccountDefaultDescriptionTests.cs`: Create `Run` uses `.OnCreate().Stage(PluginStages.PreOperation)`, Update uses `.OnUpdate().Stage(PluginStages.PreOperation)`; pipeline tests dispatch by message |
| SC1 Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas `:18-22`, O section `:76-82` |
| SC2 placeholder replaced; build green, no VELA00x in authored code | met | checks "build succeeds", "no VELA diagnostics"; Canvas `:112` |
| SC3 RED then green: name changed -> uppercased; name unchanged/filter -> not run; Create still passes | met | Canvas `:114-119` (RED `Total: 12, Failed: 4`, GREEN `Total: 13, Failed: 0`); tests `Name_changed_account_number_not_sent_is_uppercased_from_pre_image`, `Name_sent_with_same_value_leaves_account_number_untouched`, `Pipeline_step_does_not_fire_when_name_not_sent`, 3 Create tests; check "tests re-run green (>= 5)" 13/0. Grader corroboration: in a copy (`r1/red-check/`) with `HandleUpdate` stubbed to `return;`, the suite goes `Total: 13, Failed: 5` (the 4 original RED cases + case-only rename), so the tests are not vacuous. Tests and implementation share commit 1a49eb7, so RED is proven by the recorded runner output + this corroboration, not by git history. |
| SC4 `vela-code-review` PASS | met | Canvas `:124-129` (isolated reviewer, PASS, 0 Critical/0 Required, 5 Nits); reviewed diff at `r1/review-diff.txt` |
| Human answer: a null account number stays null | met | tests `Name_changed_account_number_null_is_not_added_to_target`, `Name_changed_account_number_cleared_stays_null` |
| Stop before apply | met | Canvas `apply: pending`, Gate section `:153-160`; no `vela apply` run |

## Planted-violation results
The scenario has no "Planted-violation check" section; none applied.

## Findings against the skills
1. minor - the pack says nothing about the semantics of `ctx.HasChanged` (no hit for `HasChanged` under
   `skills/` or `references/`). The actor's first GREEN used `ctx.HasChanged`, and only its own extra acceptance
   case (`Name_changed_only_in_case_counts_as_a_change`, Canvas `:117`) revealed that the framework treats a
   case-only difference as "not changed". A "Name changes" story is exactly where this matters; add it to
   `references/dataverse-gotchas.md` / `references/plugin-authoring-api.md` (and have `vela-plan-review` prompt
   for "is a case-only change a change?").
2. minor (observation, baseline fixture) - the baseline's Create step carries `FilterOn(e => e.Name)`
   (`AccountDefaultDescription.cs:18`); filtering attributes only apply to Update in Dataverse, so it is inert.
   Not introduced by this run and the reviewer did not flag it; `review-checklist.md` could name "FilterOn on a
   Create step is ignored" as a Nit.

## Verdict
pass - 17/17 deterministic checks and every scenario criterion met; no planted violations defined. Next run
should re-check that the RED evidence stays attributable (tests committed before the implementation would make
it provable from history).
