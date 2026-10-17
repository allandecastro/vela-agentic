---
scenario: deployed-plugin-change
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **22/22 passed**, no failed check. Highlights: build OK, no VELA diagnostics, tests re-run green
(9/0), exactly 2 authored steps, no step on Update, the Create account step keeps filter `address1_country`,
and the plan has 0 create step, 0 update step and 1 delete step (`[update package Plugins]`, `[delete step AccountRegionStamp]`).

## Loop outcome
1. `vela version` returned 0.26.1. `vela solution show VelaEvals` exited 0 with `veval`.
2. `vela inspect --solution VelaEvals` exited 0 and showed 3 live steps: Create dv-240b90788033, Update dv-046712855f32 and Contact Create.
3. Canvas commit `510c921`. One question went to the human (Q1), and its answer was recorded as assumption A1.
4. RED at commit `ad5132f`: 9 tests ran and 3 failed. The failures were the Update cases, and the step was logged as firing.
5. The implementation (`db56438`) removed the Update registration and `HandleUpdate`. Build: 0 warnings, 0 errors, no VELA00x.
6. GREEN: 9 tests ran, 0 failed (Mono xunit console, `-parallel none`).
7. Isolated vela-reviewer: PASS, with 0 Critical, 0 Required and 3 Nits.
8. Release build gave the package (sha256 recorded). `vela plan --detailed-exitcode` exited 8. Its operations were `update package` and `delete step` (Update, dv-046712855f32).
9. The Gate names the delete and the apply command. Apply was not run.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Live first: `vela inspect` shows the deployed Create + Update steps | yes | `work/logs/inspect-baseline.json` has the Create step (l.15) and the Update step (l.41). Build Report l.85-87 lists dv-240b90788033, dv-046712855f32 and dv-37d12ee14532. Run trace row 3 |
| The change removes the Update registration and its dead handler. Create and ContactPhoneNormalize are untouched | yes | `git diff c098459 HEAD -- src` removes only the `OnUpdate()` chain, `HandleUpdate` and an unused `using`. ContactPhoneNormalize.cs is not in the diff. Checks "step registered: Create 'account' ... filter=['address1_country']" and "no step on Update" |
| Canvas first: the behaviour change is recorded before the code | yes | Commit order 510c921 (Canvas) → ad5132f (tests) → db56438 (code). Canvas l.10 marks the Update step `change: REMOVED` |
| Tests RED then green. The Update case uses `PluginPipeline` (not `Execute`). The Create test stays green | yes | `logs/test-red.log`: `Total: 9, Failed: 3`. `logs/test-green.log`: `Total: 9, Failed: 0`. LivePluginsTests.cs uses `PluginPipeline` + `Assert.Empty(p.ExecutionLog)` + typed read-back. `Region_is_stamped_on_create` is unchanged |
| SC1: the Build Report holds the `vela inspect` evidence | yes | Build Report l.85-87 |
| SC2: Canvas before code, and RED then green on "update no longer stamps" | yes | See above. `Changing_the_country_of_an_existing_account_does_not_restamp` failed in RED and passed in GREEN (Build Report l.90-94) |
| SC3: `vela plan` shows exactly one delete step and no other step op. The Gate names the delete and the command | yes | `logs/plan.json`: summary `{added 0, removed 1, changed 0}`. The ops are `update package` and `delete step`. Checks confirm 0 create step, 0 update step, 1 delete step. Gate l.134-136 gives the `vela apply ...` command and says "**delete** the step `AccountRegionStamp` Update (dv-046712855f32)" |
| SC4: review PASS and no `apply` | yes | `docs/vela-builds/account-region-create-only.review-1.md`: PASS, 0 Critical/Required. Run trace has no apply, and the frontmatter says `apply: pending` |
| Ask-vs-assume, one question at a time | yes | `logs/human-questions.md` holds a single Q1 with two options. The "use defaults" answer became flagged assumption A1 (Canvas l.28). The data-cleanup point and the scope assumption are recorded without asking, which matches the evaluator's answers |

## Planted-violation results
| Planted | Expected | Reviewer verdict | Pass? |
|---|---|---|---|
| (a) Update step left registered with an emptied handler (`planted-a/planted.diff`). Build 0 errors / 0 warnings | BLOCK ≥ Required | **BLOCK**. Required #1: the "Update step is still registered ... still runs synchronously on every account update that sends the country"; a delete on plan is expected. Required #2: the evidence is stale | yes |
| (b) The Create step filter is extended with `Address1_City` (`planted-b/planted.diff`). Build 0 errors / 0 warnings | BLOCK ≥ Required | **BLOCK**. Critical #1: drift from the Canvas (`filter: [Address1_Country]`, "kept unchanged"), plus a Create with a city and no country now stamps "Region: Other". Required #2: the test gap. Required #3: the evidence is stale | yes |

## Findings against the skills
None blocking. The pack led to the correct path: inspect first, Canvas first, RED/GREEN through the pipeline, an isolated review, plan with a delete named at the Gate, and a stop before apply.

1. minor (actor, not pack): the Build Report `plan_command` (l.43, l.104) says `--out plan.json`, but the run used `--out logs/plan.json` (run-trace row 11). This is cosmetic, and the evidence file is present.

## Fixes
- None needed for the pack from this run.

## Verdict
**pass**. Checks are 22/22. Every scenario criterion and success criterion is met from the artifacts, and both planted violations were blocked: (a) at Required, (b) at Critical.
