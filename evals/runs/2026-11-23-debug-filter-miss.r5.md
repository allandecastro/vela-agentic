---
scenario: debug-filter-miss
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 5/5
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot
surface. One turn (`copilot-turn1.md`). It asked the human nothing (`work/logs/` is empty). Repo hooks were skipped
(folder not trusted, `copilot-turn1.err`) and the eval shim blocked org writes. Neither counts against the run.
Skills loaded with the `skill` tool: using-vela (session l.53), vela-debug-plugin (l.127), vela-code-review (l.782,
parent), vela-code-review (l.953, inside the vela-reviewer task). **vela-apply was never loaded.**

## Checks
14/14 passed (`checks.json`): filter=['description'], 1 authored step, the repro uses `PluginPipeline`, `ZavaSales`
exists, the evaluator's read-only plan creates only the package and the step.

## Loop outcome
- Hypothesis from the registration before any run: "the likely cause is `FilterOn(e => e.Name)`" (l.234).
- Repro (`PluginPipeline`, `Case=ACC-001/C1`) RED: `Updating_only_the_description_normalises_it [FAIL]`,
  `Total: 2, Errors: 0, Failed: 1` (l.378-390). The src edit came later (l.652).
- The first commit swallowed the fix (edit and commit ran in parallel). The actor noticed it and split the commits
  (l.732-755). Final history: bc3b039 (rule + Canvas + repro) → 9a8c125 (a 1-line fix) → f8156b1 (Build Report).
- Release build: 0 warnings, 0 errors. GREEN: `Total: 2, Errors: 0, Failed: 0` (l.681). spec-check: 0 failure(s) (l.803).
- vela-reviewer: PASS with 4 Nits (l.1071-1105).
- `vela solution show` was never run. `vela plan ... --solution DescNorm --url <dev>` returned exit 4, `Solution not
  found: DescNorm` (l.1115-1121). There was no question and no `open_questions`. The Build Report reads "(the
  solution is not in the dev org; the fault is in the customer org)".
- The Build Report is in the Canvas. The gate lists `vela inspect`, `vela plan --detailed-exitcode` and `vela logs`
  against the customer org, all with the unconfirmed `--solution DescNorm`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Repro: description-only update, RED for the right reason | met | Test `AccountNormalizeDescriptionTests.cs` (pipeline). RED at l.378-390, before the src edit at l.652 |
| Hypothesis from the registration and the gotchas, with no org mutation | met | l.234. Canvas `decisions:`. Only a read-only `vela plan` was run |
| Fix the single cause, and nothing else changes | met | `git show 9a8c125`: `FilterOn(e => e.Description)`, 1+/1- |
| Customer org unreachable: inspect/logs recorded | met | Gate line in the Canvas README lists inspect, plan and logs `--url <customer org>` (the r4 gap is closed) |
| SC1: RED before any code change | met | l.390 comes before l.652. The split commits restore the order |
| SC2: one-line fix, all tests green | met | l.681. checks: tests green |
| SC3: the explanation names the gotcha and the evidence | met | Build Report "Root cause" plus the RED/GREEN lines. No hedging |
| SC4: the trace-log request says where and which fields | n/a | No request was made. The org was not read around the CLI |
| Ask vs assume: the target solution | **not met** | Exit 4 on `DescNorm` (l.1121). The actor asked nothing and added no open question. The answer key is `ZavaSales` |

No planted-violation section is in the scenario.

## Mutation
3 of 3 killed, 0 survived. No missing tests.

## Since r4 (did each fix hold?)
- **#124 (debug Canvas writes the rule and Case): held.** ACC-001/C1 was in `docs/rules/account.md` with a
  `Case` trait, in the repro commit.
- **#125 (Copilot loads skills with the `skill` tool): partly held.** Every load used the tool, but vela-apply was
  skipped (see below).
- **#126 (vela-apply exit 4 → ask; review.md saved; Build Report in Canvas): partly held.** The Build Report is in
  the Canvas. review.md was again written in the Build Report command (l.1130), after the plan rather than at the
  end of the round. Exit 4: **not held**. The step 5 text was never loaded, so it could not hold.
- **#127 (debug step 9: plan on the reachable org, exit 4 is asked; scenario prime removed): not held.** The
  plan on the reachable org did run (held). Exit 4 was again treated as "the fault is in the customer org", even with
  the prime gone ("the fix must not be deployed there", session l.37).

## Why vela-apply was not loaded this time (line-level)
1. **Packaging was already done before review.** The l.667 command, "Fix, build, test, commit", ran
   `dotnet build DescNorm.sln -c Release`, the tests, and `ls artifacts` → `zava_zava.Plugins.1.0.0.nupkg`. By the
   time review ended, the only vela-apply work left was one command.
2. **Step 9 inlines that command.** The installed `vela-debug-plugin/SKILL.md` l.79-80 says "**then** `vela-apply`
   (Release build after the last change, `vela plan` on the org you can reach, its exit code - exit `4` is a
   solution to ask about, its step 5, not "not deployed here")". The parenthetical is a complete recipe: build, plan,
   exit code. It also points at "its step 5" without quoting what step 5 does.
3. **There was no narration turn between review and plan.** The reviewer task returns at l.1105. The next event is
   the parent's `bash` "vela plan preview (read-only)" at l.1109-1111. There is no Copilot message and no `skill`
   call in between. (In r4 the actor wrote a transition and loaded vela-apply at l.932.) The actor ran the recipe
   from the step 9 parenthetical and skipped the skill whose step 5 holds the ask. That also explains why
   `vela solution show` (vela-apply step 5) and `--detailed-exitcode` (vela-apply step 6) are both missing from l.1115.
4. With step 5's text ("ask the human for the right unique name (one question)") and the rebuttal ("never record
   the preview as merely unavailable") out of context, the actor fell back on step 9's closing clause: "an org you
   can reach does not ship the fix where the fault is". Its Build Report repeats that clause almost word for word:
   "the fault is in the customer org".

## Findings against the skills
1. **blocker:** `skills/vela-debug-plugin/SKILL.md` step 9, "**then** `vela-apply` (Release build after the last
   change, `vela plan` on the org you can reach, its exit code - exit `4` is a solution to ask about, its step 5, ...)".
   The inline recipe replaced loading vela-apply. The actor ran `vela plan` straight after review (l.1111) and did
   not run `vela solution show`. On exit 4 it did not ask. There are two possible levers:
   - Cut the recipe down to a pointer: "load `vela-apply` and run its steps 5-6".
   - Put the action itself inline: "exit `4` → ask the human for the solution's unique name (one question), or
     add a blocking open question".

   The current half-pointer, "its step 5", is the worst of both.
2. **blocker (persisting):** `skills/vela-debug-plugin/SKILL.md` step 9 says "an org you can reach does not ship the
   fix where the fault is". Unprimed by the scenario, this clause still licensed "the fault is in the customer org"
   as the explanation for exit 4 (Canvas Build Report "Preview" line). The clause needs to be scoped to the gate
   commands only, for example "...so the gate also names the faulty org", so it cannot be read as an excuse for exit 4.
3. minor (persisting from r4 #3): the gate's customer-org commands use `--solution DescNorm`, which is
   unconfirmed and failed on the only org it was tried on. Debug step 5 says "never guessed".
4. minor (persisting): `review.md` was written together with the Build Report (l.1130), after `vela plan`, not when
   the review round closed.

## Verdict
**fail.** Checks are 14/14, mutation is 3/3, and the debug criteria are all met: the pipeline RED repro before the
fix, the 1-line fix, the evidence, and the gate commands (now including `vela logs`). The run fails on ask-vs-assume
for the third run in a row. Exit 4 on `DescNorm` got no question and no blocking open question. This time
vela-apply was never loaded, because debug step 9 inlines enough of its recipe to run `vela plan` without it.
Next run: re-check that vela-apply is loaded after review in a debug flow, that `vela solution show` runs, and that
exit 4 produces a question.
