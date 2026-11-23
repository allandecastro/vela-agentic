---
scenario: debug-filter-miss
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 1/1
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`, pack installed as `.github/skills`, `.github/agents`,
`.github/copilot-instructions.md`. First Copilot run of this scenario. One turn (`copilot-turn1.md`), 56 s, no
question asked (`work/logs/` empty). Repo hooks were not loaded ("folder ... is not trusted",
`copilot-turn1.err`); the eval shim blocked org writes. Neither is counted against the run. Grader model: claude-opus-5-5.

## Check summary
`checks.json`: **14/14 passed**, 0 failed. Build, no VELA diagnostics, tests green (total=2), step Update/account/
PreOperation/Sync filter=['description'], exactly 1 authored step, repro uses PluginPipeline, ZavaSales exists,
read-only plan runs, no demo op, plan creates only authored steps.

## Skills read (from `copilot-session.md`)
| File | How |
| --- | --- |
| `using-vela/SKILL.md` | whole (skill tool, 5s) |
| `vela-debug-plugin/SKILL.md` | whole (skill tool, 7s) |
| `vela-plugin-testing/SKILL.md` | partial: `grep -B2 -A12 "mono\|xunit.console"`, about l.69-117 (17s) |
| `vela-plugin-testing/references/harness-api.md` | partial: grep "mono", l.6-14 and l.85-87 (21s) |
| `vela-code-review/references/harness-api.md` | partial: grep "xunit.console", l.166-177 (21s) |
| `vela-builder.agent.md` | loaded as the agent profile via `--agent` (not observable) |
| Not opened | `dataverse-gotchas.md`, `cli-surface.md`, `vela-plan-review`, `vela-code-review/SKILL.md`, `vela-apply/SKILL.md`, `build-report-template.md` |

## Loop outcome
- Read `PROJECT.md` (`zava_zava.Plugins: DescNorm`), the plugin (`FilterOn(e => e.Name)`) and the one `Execute` test. `ls docs`: none.
- Triage done silently: "no docs/rules/ exists ... -> bug, not change request" (`actor-report.md`). No question to the human.
- Added `Updating_only_the_description_normalises_it` (PluginPipeline, Create then Update description only).
- RED: mono xunit `-parallel none`: `Total: 2, Errors: 0, Failed: 1` (Expected "Hello world", Actual "  Hello   world  ").
- Fix `FilterOn(e => e.Name)` -> `FilterOn(e => e.Description)`. GREEN: `Total: 2, Errors: 0, Failed: 0`; build 0 warnings / 0 errors.
- `vela plan --packages-dir artifacts --solution DescNorm --url <dev> 2>&1 | tail -15; echo exit=$?` -> "Solution not found: DescNorm", `exit=0`. That is the exit code of `tail`, not of `vela`. The actor called the result "expected".
- Test and fix were committed together in one commit, 13de837. No Canvas, no `.vela-runs/`, no review, no Build Report.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reproduce first: description-only update through the harness, RED for the right reason | met | `AccountNormalizeDescriptionTests.cs:11-20` (PluginPipeline); session 24s RED output before the fix edit at 29s. Git does not prove the order: the test and the fix are in the same commit, 13de837. |
| Hypothesis from the registration, checked against `dataverse-gotchas.md`; no trial and error, no org mutation | met (weak) | The cause was read directly from `RegisterPluginSteps` (session 10s). The gotcha is the one listed in `vela-debug-plugin` step 5. `dataverse-gotchas.md` was never opened. Only read-only `plan` touched the org. |
| Fix the single cause, red -> green, nothing else changes | met | `git show 13de837`: plugin 1+/1-, plus the repro test; GREEN 2/2; check "exactly 1 authored step(s)" |
| Customer org unreachable: `vela inspect` / `vela logs` recorded as confirming commands; the trace-log request says where and what | **not met** | `actor-report.md`: "Run `vela inspect` and `vela plan --solution DescNorm` against it". There is no connection flag and no package, so it is not an exact command. There is no `vela logs` and no Plug-in Trace Log request. The solution name is unverified: it is the one that just returned "Solution not found". |
| SC1 Failing repro written and seen RED before any code change | met | session 16s (test edit) -> 24s RED -> 29s fix |
| SC2 One-line fix; repro and existing suite green | met | 13de837; `Total: 2, Failed: 0`; check "tests re-run green" |
| SC3 Explanation names the gotcha and the evidence; no "it seems" | met | `actor-report.md` "Root cause ... FilterOn(e => e.Name) ... Execute ... ignores filters"; quotes RED/GREEN lines |
| SC4 If the trace log is requested: where + fields; no org reads around the CLI | met (vacuous) | No request was made; only `vela` touched the org |

Process deviations from the pack, outside the scenario criteria but relevant to the findings:
- No Canvas, although `vela-debug-plugin` step 3 requires one "**before** the fix".
- The RED test was not committed alone (`vela-plugin-testing`).
- No `vela-reviewer` dispatch, although the actor prompt asks for one.
- `vela solution show` was not run, `--detailed-exitcode` was not passed, and the plan's exit code was lost.
- No Build Report or apply gate. The final message told the human to "apply the rebuilt ... nupkg".

## Planted-violation results
The scenario has no "Planted-violation check" section, so none was applied.

## Mutation triage
3/3 killed (`AccountNormalizeDescription.cs:29` negate-if and flip-comparison, `:31` drop-assignment). No survivors.

## Findings against the skills
1. **blocker** - `skills/vela-debug-plugin/SKILL.md` ends at step 8 "**Regression-test.**" and has no hand-off back
   to the loop's Review -> Package & preview -> Apply gate. `agents/vela-builder.agent.md:69`
   "Something misbehaves: `vela-debug-plugin`" routes there but never brings the agent back. Copilot treated step 8 as
   the end of the task. It skipped `vela-code-review`, `vela-apply` and the Build Report, and its final message
   tells the human to apply. The debug skill needs a final numbered step: "9. Continue the build loop at
   Review (`vela-code-review`) -> `vela-apply` preview -> Build Report; the gate targets the faulty org".
2. **blocker** - `skills/vela-debug-plugin/SKILL.md:59-61`: the Canvas requirement sits mid-paragraph in step 3:
   "Write a small-story Canvas (`using-vela`: front matter + cases; record the symptom and hypothesis in
   `decisions:`) **before** the fix." Copilot skipped it and reported "No Canvas written (small fix, no docs tree)".
   This is the same failure as PR #119: a mandatory artifact in prose is skipped on Copilot. Make it its own numbered
   step with an observable output (`docs/features/<slug>/README.md` committed with the RED test).
3. minor - `skills/vela-debug-plugin/SKILL.md:36-39` step 0: "No rule covers it -> ask the human which it is." Copilot
   decided "bug" by itself from the plugin's name. The human's answer would have agreed, so there was no harm.
   On a legacy project with no `docs/rules/`, every debug run hits this branch. The skill could say that the
   question is mandatory even when the intent looks obvious, or say what counts as evidence of intent.
4. minor - `skills/vela-debug-plugin/SKILL.md:68-69` "`<uniquename>` comes from the Canvas / Build Report or the human"
   conflicts with `vela-apply/SKILL.md:48` ("the package's solution from `PROJECT.md`"). Copilot took `DescNorm`
   from `PROJECT.md`, got "Solution not found", and called it "expected". `vela-apply` step 5 says that exit `4`
   "blocks the gate", but Copilot never opened `vela-apply`. Align the two skills on one source, and add
   "Solution not found = ask, never 'expected'" to the debug skill's step 8.
5. minor - `skills/vela-debug-plugin/SKILL.md:75-77` "record the exact `vela inspect` / `vela plan` / `vela logs`
   commands against **that** org". Copilot recorded `vela inspect` with no `--url`/`-p`/`--solution` and dropped
   `vela logs`. Step 2's trace-log request (where + fields) is gated on "when the fault is on a live org", and
   Copilot did not apply it although the fault is on the customer's org. Spell out a template for the unreachable
   case (`vela inspect -p <pkg> --solution <name> --url <customer-org>`, `vela logs --type <PluginType> ...`, plus the
   trace-log path and fields).
6. minor - evidence discipline: `AGENTS.md` asks for "the `vela plan --solution` output **and exit code**". Copilot
   piped the plan through `tail` and reported `exit=0`, which is the exit code of `tail`. `vela-apply` covers this
   with `--detailed-exitcode`, but the debug path never reaches `vela-apply` (see finding 1).

## Verdict
fail. Checks pass 14/14, and the core debug, a PluginPipeline RED -> one-line fix -> GREEN, was clean and fast.
The unreachable-org item is not met: the commands are not exact, there is no `vela logs`, there is no trace-log
request, and the solution name is unverified. Copilot also stopped at the debug skill's last step, with no Canvas,
review, preview or Build Report.

The next run should re-check four things after findings 1-2 are fixed:
- a Canvas is committed with the RED test;
- the reviewer is dispatched;
- `vela-apply` preview runs with the exit code captured;
- the gate commands are exact and aimed at the customer org.
