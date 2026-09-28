---
scenario: debug-filter-miss
date: 2026-09-30
verdict: fail
campaign: 2026-09-30
run: 2/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **10/10 passed**, no failed checks. The checks were: solution found, build succeeds, no VELA diagnostics,
tests re-run green (total=5, failed=0), plugin dll built, registration probe runs, the step registered as Update account
PreOperation/Synchronous with filter=['description'], exactly 1 authored step, no dotted Custom API names, and the tests
contain `PluginPipeline`.

## Loop outcome
- `vela version` returned `vela 0.21.0` (exit 0), recorded in the Build Report Run trace row 1.
- The actor read `RegisterPluginSteps()` and formed its hypothesis from the gotcha (filter excludes the changed column).
- Commit `a8c840b` added the Canvas. Commit `e8bd16d` added 4 `PluginPipeline` tests (tests only).
- Commit `30c160c` made the fix. Commits `acc8a8d` and `f45ae75` updated the Canvas and Build Report.
- **Grader re-run of RED:** I cloned the repo at `e8bd16d`, built it (0 errors) and ran Mono xunit with `-parallel none`.
  - Result: `Total: 5, Errors: 0, Failed: 4`.
  - The description-only test fails with `Assert.Single() Failure: The collection was empty`, which is the right reason: the step never fired.
  - The name-only test fails with `Assert.Empty() Failure: Collection was not empty`.
- GREEN after the fix is confirmed by the `tests re-run green` check (5/5).
- Package: `artifacts/zava.Plugins.1.0.0.nupkg`. `vela plan` and `vela inspect` were recorded, not run (no org). `vela apply` was never run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Reproduce first: a harness test that updates only `description`, expects the normalised value and fails RED for the right reason | met | `AccountNormalizeDescriptionTests.cs` `Description_only_update_fires_and_saves_normalised_value` uses `PluginPipeline` and updates only Description. Commit `e8bd16d` (test) comes before `30c160c` (fix). The grader re-run at `e8bd16d` shows `Assert.Single() Failure: The collection was empty`, so the step did not fire. |
| S2 | Hypothesis from the registration, checked against the gotchas; no trial and error; no org mutation | met | Build Report Canvas "A - Approach" and "Root cause" (lines 53-57, 76-80) name the filtering-attribute gotcha. There is one fix commit and no intermediate edits. No org command was run (Run trace rows 9 and following are recorded only). |
| S3 | Fix the single cause, red goes green, **nothing else changes**; `vela inspect` recorded | **not met** | `review-diff.patch` and commit `30c160c` show **2 lines** changed in the plugin (`AccountNormalizeDescription.cs`, 2 insertions and 2 deletions). Besides `FilterOn(e => e.Name)` → `FilterOn(e => e.Description)`, the actor also rewrote `.WithDescription("Update Account handler.")` → `"Normalise account description (trim, collapse spaces) on update."`. That is a second change to the registered step: the Build Report line 103 itself expects `vela plan` to show "filtering attributes `name` -> `description`, **description text**". The `vela inspect` command is recorded (Build Report line 104). |
| C1 | Failing repro test written and seen RED before any code change | met | Commit order `e8bd16d` → `30c160c`. The actor's RED output (`Total: 5, Failed: 4`) was independently reproduced by the grader. |
| C2 | One-line fix; the repro and the existing suite are green | **not met** | The suite is green (check `tests re-run green`: total=5, failed=0), but the fix is not one line: the plugin diff is 2 lines, one of them unrelated to the cause (step description text). |
| C3 | The explanation names the gotcha and the evidence; no "it seems" without output | met | Build Report "Root cause" and "Evidence" (lines 76-104) quote the RED and GREEN runner lines and the ExecutionLog entry for the name-only update. There is no unsupported hedging. |
| C4 | Trace Log request says where it is and which fields to paste; no org read around the CLI | met | Build Report line 129: Settings → Customization → Enable logging = All; Settings → Plug-in Trace Log. It lists type name, message, entity, stage/mode, depth, correlation id, exception, message block. There were no Web API calls. |

## Planted-violation results
Not applicable. This scenario has no "Planted-violation check" section. Its planted bug (`FilterOn(e => e.Name)`) is
the subject of the run, and the actor found and fixed it.

## Findings against the skills
1. **blocker** - In `skills/vela-debug-plugin/SKILL.md` step 7, the text "**Fix** the single most-likely cause with evidence." does not say to leave out incidental edits.
   - The actor fixed the cause but also rewrote the step's `WithDescription(...)` text in the same commit. That adds a second registration change to the `apply`.
   - Nothing in the debug skill tells the actor to limit the diff to the cause.
   - The actor's Canvas "N - Norms" (via `vela-plan-review`) recorded "Step description updated to say what the step does" as a norm. The Canvas step therefore made the incidental change look intended.
   - The isolated `vela-reviewer` returned PASS without flagging the extra registration change. `references/review-checklist.md` has no "debug fix must be minimal" axis.
   - Fix: add to step 7 "change only what the cause requires; cosmetic or unrelated edits (step descriptions, TODOs, renames) go in a separate change or are recorded as follow-ups". Add a matching review-checklist item for debug diffs.
2. minor - `skills/vela-debug-plugin/SKILL.md` step 4 conflicts with `skills/vela-test-harness/SKILL.md` step 3.
   - Step 4 says "A debug run adds the repro plus any directly related regression case - not the full coverage set of a new build."
   - The harness step says "Write the full **Coverage** set above (not just the happy path)" (`## Coverage (mandatory - no happy-path-only)`).
   - The actor followed the harness skill and added 4 pipeline cases (repro, name-only, cleared, already-normal). The cleared and already-normal cases go beyond "directly related".
   - Fix: add a debug-run exception to the harness Coverage section, pointing back to vela-debug-plugin step 4.
3. minor - The debug flow pulled in the full build loop: vela-plan-review Canvas, vela-apply packaging, and an open question about the solution name blocking apply.
   - `skills/vela-debug-plugin/SKILL.md` does not say which build-loop artifacts a debug fix needs.
   - The result was heavier than the fix and is where the incidental Norms edit came from (finding 1).
   - Fix: state the minimum artifact set for a debug fix. For example: repro test, fix, Build Report with Root cause, Evidence and recorded `inspect`/`plan`.

## Verdict
**fail**. The deterministic checks pass (10/10). The grader fails the run on criteria S3 and C2: the fix is not a one-line change and something else did change (the registered step description). The diagnosis, test-first discipline, evidence and trace-log request were all correct. The next run must re-check that the plugin diff is limited to the `FilterOn` line once finding 1 is fixed in the skill.
