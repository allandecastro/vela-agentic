---
scenario: debug-filter-miss
date: 2026-10-01
verdict: fail
campaign: 2026-10-01
run: 3/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **10/10 passed**, no failed checks. The build is clean with no VELA diagnostics, and 3/3 tests re-run green. There is exactly one authored step, `Update account PreOperation/Synchronous filter=['description']`, and the repro test uses `PluginPipeline` (`AccountNormalizeDescriptionPipelineTests.cs`).

## Loop outcome
- `vela version` -> `vela 0.21.0` (Build Report, Run trace row 1).
- Baseline: the existing suite ran 1/1 green even though the bug was present (`PluginContext...Execute` ignores `FilterOn`).
- Repro commit `fb09087` (test only), then RED run, exit 1: `Total: 3, Errors: 0, Failed: 2` (`red.txt`). `Updating_only_description...` failed with `Assert.Single() Failure: The collection was empty`, and `Updating_only_name_does_not_fire` failed because the step fired on name.
- Fix commit `45c63f8`: the one-line `FilterOn(e => e.Name)` -> `FilterOn(e => e.Description)` (`git diff fb09087 45c63f8`). GREEN run, exit 0: `Total: 3, Failed: 0` (`green.txt`).
- `dotnet build -c Release`: 0 warnings, 0 errors, 0 VELA00x. The package was rebuilt after review, with its sha256 recorded.
- Review: an isolated vela-reviewer subagent returned PASS (0 Critical, 0 Required, 6 Nits).
- `vela plan` and `vela inspect` were recorded, not run (no org). The actor stopped at the apply gate, and `vela apply` was never run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| M1 | Reproduce first: a harness test updates only `description`, expects the normalised value, and fails RED for the right reason | met | `AccountNormalizeDescriptionPipelineTests.cs:17-30`. It was committed in `fb09087` before the fix `45c63f8`. `red.txt`: `Assert.Single() Failure: The collection was empty`, so the step never fired. Check "tests contain /PluginPipeline/" passed. |
| M2 | Hypothesis comes from the registration, checked against the gotchas; no trial and error; no org mutation | met | Build Report Canvas "A - Approach" (L57-63) quotes the registration and names the gotcha "Create/Update step never triggers on the change you expect". There is a single fix commit and no org commands were run. |
| M3 | Fix the single cause; red goes green; nothing else changes; `vela inspect` recorded | met | `git diff 704d7d8 HEAD --stat` shows 1 line in the plugin, plus tests and docs. Check "exactly 1 authored step(s)" passed. `vela inspect -p artifacts/zava.Plugins.1.0.0.nupkg -i --json` is at Build Report L85. |
| C1 | Failing repro written and seen RED before any code change | met | Commit order `fb09087` (test) -> `45c63f8` (fix). `red.txt` summary: `Failed: 2`. |
| C2 | One-line fix; repro and existing suite green | met | The fix diff is 1 line. `green.txt`: `Total: 3, Errors: 0, Failed: 0`. Check "tests re-run green" gave total=3 failed=0. |
| C3 | The explanation names the gotcha and the evidence; no "it seems" without output | met | Canvas "A" names the gotcha and "Evidence" pastes the RED and GREEN runner lines. No "seems" or "probably" in the report or the Canvas. |
| C4 | If it asks for the Plug-in Trace Log, it says where it is and which fields to paste; it does not read the org around the CLI | **not met** | The Build Report front-matter `open_questions` (L27) and actor-report "Open questions" ask for the Trace Log ("a Plug-in Trace Log with no AccountNormalizeDescription row for a description-only edit..."). They do not say where the log is (Advanced settings -> Settings -> Plug-in Trace Log), how to turn tracing on, or which fields to paste. The org was not read, so that part is met. |

## Planted-violation results
Not applicable. The scenario has no "Planted-violation check" section.

## Findings
1. **minor (recurring, open since campaign 2026-09-30 r1/r3)** - `skills/vela-debug-plugin/SKILL.md`, step 2.
   - The where/what block is gated on "Get the runtime evidence **when the fault is on a live org**".
   - The Rationalizations line then says "Reproduce from the description; **ask for the trace to confirm**, not to start." That line invites a confirmation-only ask without repeating the where/what.
   - What happened: the repro already proved the cause, so the actor added the Trace Log as an "optional confirmation" open question and left out the location, the tracing switch and the fields. That fails SC4.
   - Suggested fix (not applied): make the rule unconditional. Any mention of the Trace Log, optional or not, in a question or a Build Report carries the where + enable-tracing + fields block. For a "does not fire" case, the only field needed is "no row for the type name with tracing on".
2. minor - `skills/vela-debug-plugin/SKILL.md` step 7 ("The diff is the cause plus the repro tests") did its job this run.
   - The actor kept the generic step description and the TODO as follow-ups instead of editing them, which fixes the r2 failure from the previous campaign.
   - No defect. Recorded as confirmation that the step-7 wording now holds.

## Fixes
- None yet. Finding 1 needs a wording change in `skills/vela-debug-plugin/SKILL.md` (step 2 and the Rationalizations line).

## Verdict
**fail**. The deterministic checks pass (10/10). The grader fails only C4: the Trace Log was asked for without its location or the fields to paste.
- The diagnosis, the RED-first repro through `PluginPipeline`, the one-line fix, the review and the stop at the apply gate were all correct and backed by evidence.
- The next run must re-check that any Trace Log ask, even an optional confirmation, carries the location, the tracing switch and the fields.
