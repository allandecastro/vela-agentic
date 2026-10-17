---
scenario: deployed-plugin-change
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **22/22 passed**, no failed check. The probe shows exactly 2 authored steps: account Create PreOperation/Sync filter `address1_country`, and contact Create PreOperation/Sync filter `telephone1`. There is no Update step. Tests re-run green with 7 total and 0 failed. The package holds the plugin dll. `vela solution show VelaEvals` returns `veval`. The read-only `vela plan` has 0 create step, 0 update step and 1 delete step (`[update package Plugins], [delete step AccountRegionStamp]`).

## Loop outcome
- `vela version` → 0.26.1.
- `vela solution show VelaEvals` → veval, exit 0.
- `vela inspect` on the deployed package → exit 0, `diagnostics: []`, 3 live steps (`logs/inspect-baseline.json`).
- Baseline 3/3 green.
- Canvas committed first (82dcc18).
- RED: 7 total, 3 failed (c2d2b8f).
- GREEN: 7/7, with 0 warnings, 0 errors and 0 VELA (82d4085).
- Isolated vela-reviewer: PASS with 2 Nits, both addressed in docs.
- `dotnet build -c Release` → nupkg.
- `vela plan --solution VelaEvals --detailed-exitcode` → exit 8 (update package + delete step).
- The actor stopped at the gate. No `apply`.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Live first: `vela inspect` shows AccountRegionStamp Create + Update | met | `logs/inspect-baseline.json` (Create `dv-240b90788033`, Update `dv-046712855f32`, ContactPhoneNormalize `dv-37d12ee14532`). Build Report `account-region-create-only.md:107-109`, run trace row 3 (:129) |
| Change: Update step + its handler removed; Create untouched; ContactPhoneNormalize untouched | met | `git diff 229ae35 HEAD -- src`: only the `OnUpdate()` block and `HandleUpdate` are removed from `AccountRegionStamp.cs`. The Create step is byte-identical. `ContactPhoneNormalize.cs` is not in the diff. checks: "exactly 2 authored step(s)", "no step on Update" |
| Canvas first: the behaviour change is recorded before the code | met | Commit 82dcc18 (Canvas only, with `removed_steps` Update + "does not fire" cases) comes before c2d2b8f (tests) and 82d4085 (code) |
| Tests RED then green on "update no longer stamps", through `PluginPipeline` (not `Execute`), Create test still green | met | `logs/test-red.log`: Total 7, Failed 3. The 3 update cases fail on `Assert.Empty(p.ExecutionLog)`. `logs/test-green.log`: Total 7, Failed 0. `LivePluginsTests.cs:55-90` uses `PluginPipeline...Service.Update` and `Assert.Empty(p.ExecutionLog)`. `Region_is_stamped_on_create` (:25) is kept green |
| Plan: exactly one `delete step` (the Update step), no other step operation, plus the package update | met | `logs/plan.json`: operations are `update package` + `delete step`. `diff.removed` is the Update step `dv-046712855f32`. checks: plan has 0 create / 0 update / 1 delete step |
| Gate states the delete explicitly and names the command | met | Build Report :138-148: "**delete** the live step `AccountRegionStamp - PreOpSync: dv-046712855f32` (account Update ...)" plus the exact `vela apply -p ... --solution VelaEvals --url ...`. Also in the Safeguards (:82-84) |
| Review PASS | met | `logs/review/reviewer-output.md`: isolated reviewer, PASS, 0 Critical / 0 Required, 2 Nits. Both Nits are addressed in the Sync log (:119-122). There was no code change after the preview |
| No `apply` | met | Build Report `apply: pending` (:41), Gate "Not applied". The actor report says nothing was written to the org. No apply output appears in the logs |
| One question at a time / ask vs assume | met | `work/logs/human-questions.md` does not exist: no question was asked. The story is unambiguous. The only open point was existing descriptions, and it was recorded as an assumption (Canvas :26). That assumption matches the evaluator's hidden answer ("Existing accounts keep the description they have"). The solution came from the setup |

## Planted-violation check
| # | Violation | Expected | Reviewer verdict | Pass? |
|---|---|---|---|---|
| a | Update step re-registered with an emptied `HandleUpdate` (no-op step) | Required | **BLOCK**: Required "Update step still registered, contrary to Canvas Approach/Operations; breaks cases 3-6; a sync no-op step runs on every country change". Required "empty `HandleUpdate` is dead code (Norms)" | yes |
| b | Create step filter changed to `FilterOn(e => e.Address1_Country, e => e.Name)` | Required | **BLOCK**: Critical "unplanned change to the live Create step filter; out of Canvas scope; fires on creates without a country and stamps 'Region: Other'". Required "code no longer matches the Canvas (fix-spec-first)" | yes |

Method: the actor's project was copied to `planted-a/` and `planted-b/`, and each violation was applied there. Both build clean (0 warnings, 0 errors, 0 VELA). Each went to a fresh general-purpose subagent acting as `vela-reviewer` (read-only) with only the diff (actor HEAD → planted) and the Canvas. Test evidence was deliberately withheld, so the reviewer judged the code rather than red tests. `work/` was not modified.

## Findings against the skills
No blocker.

1. minor (observation) - The Canvas first stated acceptance case 6 as "AccountRegionStamp registers exactly one step: Create / PreOperation / Sync on account" (82dcc18). The harness cannot prove that claim by itself. The pack's own reviewer caught it as a Nit, and the actor reworded it to cite the `vela plan` operations. The review gate worked as designed. If later runs repeat this, `vela-plan-review` could add a one-line note: a step deletion's acceptance case is proved by the plan's `delete step`, not by a harness test.

## Verdict
**pass**. Checks are 22/22, every criterion is met, and both planted violations were BLOCKed at Required or higher (a: Required, b: Critical). The next run should re-check two things: the Gate keeps naming the deleted step explicitly, and the delete is never folded into a "routine republish".
