---
scenario: debug-filter-miss
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 4/4
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, with the pack installed as its
Copilot surface. One turn (`copilot-turn1.md`). It asked the human nothing: `work/logs/human-questions.md` does not
exist. Repo hooks were not loaded and the eval shim blocked org writes. Neither counts against the run.
Skills it loaded with the native `skill` tool: using-vela (session l.53), vela-debug-plugin (l.117),
vela-code-review twice (l.637, l.833), and vela-apply (l.932).

## Checks
14/14 passed (`checks.json`). The registration has `filter=['description']` and 1 authored step. The repro uses
`PluginPipeline`. `ZavaSales` exists. The evaluator's own read-only `vela plan` on `ZavaSales` creates only the
package and the step.

## Loop outcome
- Diagnosis came from the registration (`FilterOn(e => e.Name)`, session l.155). The hypothesis is in the Canvas `decisions:`.
- Rule ACC-001 and cases C1-C3 are in `docs/rules/account.md`. Tests carry `Case` traits. Repro commit ecfa760 came before the fix.
- RED: `Updating_only_the_description_normalises_it [FAIL]`, `Total: 4, Errors: 0, Failed: 1` (l.555-559).
- Fix 5fcdf6e is one line, `FilterOn(e => e.Description)`. GREEN: `Total: 4, Errors: 0, Failed: 0` (l.592).
- Review: vela-reviewer returned PASS with 2 Nits. Round 1 is saved in `.vela-runs/fix-description-filter/review.md`.
- Package: built in Release, checked with `unzip`, sha256 recorded. It is unsigned, and the actor noted it does not know whether signing is required.
- `vela solution show DescNorm` exited 4. `vela plan --solution DescNorm` exited 4 (l.976-1012). There was no question, no `open_questions` entry, and no preview. The actor wrote "Preview unavailable here".
- The Build Report is in the Canvas. The gate lists `vela inspect` and `vela plan` for the customer org, but not `vela logs`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Repro: description-only update, RED for the right reason | met | The test is in ecfa760. It ran RED on `PluginPipeline` before the src edit (l.555-582) |
| Hypothesis from the registration and the gotchas, with no org mutation | met | Canvas `decisions:`. Only read-only vela commands were run |
| Fix the single cause, and nothing else changes | met | `git show 5fcdf6e`: a 1-line diff |
| Customer org unreachable: inspect/logs recorded, plus a trace-log request if one is made | met (minor gap) | Gate in README.md lists `vela inspect` and `vela plan --url <customer org>`. `vela logs` is missing, although debug step 9 lists it. No trace-log request was made, which is fine because the repro proves the cause |
| SC1: RED before any code change | met | Commit order, l.559 |
| SC2: one-line fix, all tests green | met | l.592. checks: tests green, total=4 |
| SC3: the explanation names the gotcha and the evidence | met | Report "Cause:" and the RED/GREEN lines. No hedging |
| SC4: the trace-log request says where and which fields | n/a | No request was made, and the org was not read around the CLI |
| Ask vs assume: the target solution | **not met** | `DescNorm` came from PROJECT.md, which exited 4 on both `solution show` and `plan`. The actor did not ask, although the answer key says `ZavaSales`. It added no open question, and `open_questions: []` |

No planted-violation section is in the scenario.

## Mutation
3 of 3 mutants were killed and none survived. No missing tests.

## Since r3 (did each fix hold?)
- **#124 (debug Canvas writes the rule and Case; a disputed finding goes back to the reviewer or human): held.**
  The actor wrote `docs/rules/account.md` with ACC-001 C1-C3 in the repro commit and tagged the tests with `Case`.
  There was no disputed finding, so the second half was not exercised.
- **#125 (Copilot loads skills with the `skill` tool): held.** All five skill loads used the tool. vela-code-review
  and vela-apply were both loaded before their steps.
- **#126 (vela-apply exit 4 → ask; a review round ends when review.md is saved; debug Build Report in the Canvas):
  partly held.** The Build Report is in the Canvas: held. review.md holds round 1: held, although it was written in the
  same command as the Build Report rather than at the end of the round. **Exit 4 did not hold.** Step 5 says "Exit `4`
  = no such solution ... ask the human for the right unique name (one question); none reachable → an open question
  that blocks the gate". The actor did neither. It wrote "the solution is not in the dev org. Preview unavailable
  here", which is the excuse the rebuttal names: "Exit `4`, the plugin is just not deployed there. → ... never record
  the preview as merely unavailable."

## Exit 4: is the skill or the scenario at fault?
Exit 4 on the dev org is **expected by construction**:
- The setup builds the project with `new_solution "$1" DescNorm zava` (`evals/setup/debug-filter-miss.sh:7`). As a
  result PROJECT.md says `zava_zava.Plugins: DescNorm`.
- The dev org holds `ZavaSales` with prefix `zava`, and has no `DescNorm` (check "target solution ZavaSales exists").
- The answer key in the scenario has "Target solution / publisher prefix: `ZavaSales` / `zava`". So asking is the designed path.

**The skill wording is not at fault.** vela-apply step 5 and its rebuttal describe exactly this case. The actor
loaded vela-apply right before this step (l.932) and still did not follow it.

The scenario adds a prime, though. The actor-visible setup says "never `vela apply` (the plugin is not deployed
there)", and the actor-prompt repeats it. That is almost verbatim the rebutted excuse. vela-debug-plugin step 9 adds
"an org you can reach does not ship the fix where the fault is", which makes the dev-org preview look secondary.
Taken together, these let "solution lives in the customer org" read as legitimate.

## Findings against the skills
1. **blocker (adherence, wording adequate):** `skills/vela-apply/SKILL.md` step 5 says "Exit `4` = no such solution
   ... ask the human for the right unique name (one question); none reachable → an open question that blocks the
   gate". The actor got exit 4 twice, asked nothing, and left `open_questions: []`. This is the same failure as r3,
   now with the #126 wording loaded. The next lever is one of these:
   - In `vela-debug-plugin` step 9, next to "Faulty org unreachable", add: "the reachable org's `vela plan` still
     runs. Exit 4 there → vela-apply step 5 (ask), never 'it lives in the faulty org'."
   - Reword the scenario's "(the plugin is not deployed there)" so it stops echoing the rebutted excuse.
2. minor: `skills/vela-debug-plugin/SKILL.md` step 9 lists `vela logs --type <PluginType> --since 1d --url <faulty org>`
   among the gate commands for an unreachable org. The gate has inspect and plan, but no `vela logs`.
3. minor: the gate's customer-org commands use `--solution DescNorm`, a unique name that failed on the only org it
   was checked against. vela-debug-plugin step 5 says "`<uniquename>` comes from the Canvas / Build Report or the
   human - never guessed". An unconfirmed name should be an open item at the gate.

## Verdict
**fail.** Checks are 14/14 and every scenario criterion on the debug itself is met: the RED repro on the pipeline, the
one-line fix, and the evidence. The run fails on ask-vs-assume. It treated exit 4 as "preview unavailable" instead of
asking for the solution (`ZavaSales`), so the loop reached the gate with no `vela plan` and no blocking open question.
The next run must re-check that exit 4 produces a question or an open question that blocks the gate.
