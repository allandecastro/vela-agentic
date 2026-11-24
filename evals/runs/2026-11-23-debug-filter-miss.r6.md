---
scenario: debug-filter-miss
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 6/6
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "3/3, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot
surface. There was one turn (`copilot-turn1.md`) and the actor asked nothing (`work/logs/` is empty).
- Not counted against the run: repo hooks were skipped because the folder was not trusted (`copilot-turn1.err`),
  and the eval shim blocked org writes.
- `skill` tool loads: using-vela (session l.53), vela-debug-plugin (l.118), vela-code-review (l.535 in the parent,
  then l.1182 and l.1580 inside the two reviewer rounds), and **vela-apply (l.1658)**.
- Since r5: PR #128 cut debug step 9 down to a pointer ("load `vela-code-review` and follow it, **then** load
  `vela-apply` and follow it"). The faulty-org commands are now step 10.

## Checks
14/14 passed (`checks.json`):
- the filter is `['description']`, with 1 authored step;
- the repro uses `PluginPipeline`;
- `ZavaSales` exists;
- the evaluator's plan creates only the package and the step.

## Loop outcome
- **Hypothesis:** taken from the registration (`FilterOn(e => e.Name)`, l.156). It is recorded in the Canvas
  `decisions:`.
- **RED:** `R1_edit_name_only... [FAIL]` and `Total: 3, Errors: 0, Failed: 2` (l.423-432). This came before the
  src edit (l.~470).
- **Commits rewritten after spec-check failed:** spec-check first returned "has no [Trait("Case", ...)]", 2
  failures (l.577-579). The actor reset, stashed `src`, rewrote the rule as ACC-001/C1-C2, and recommitted.
  - Final history: 13b59ca (docs) → 7d771f3 (tests) → 205cc1f (fix, 1+/1-) → 71a928b (Build Report).
  - RED was re-run on 7d771f3 (l.1041) and again on a checkout (l.1516-1540).
- **GREEN:** `Total: 3, Failed: 0`. spec-check: `0 failure(s)` (l.1044-1045).
- **Review:** round 1 BLOCKed (l.1465, Required: the Run trace and verbatim RED lines were missing). The actor
  wrote `trace.md` (l.1546). Round 2 passed (l.1616) with nits only.
- **Preview:** after "Now package and preview." (l.1643), the actor loaded vela-apply (l.1658), cleared
  `artifacts/`, ran the Release build, and took the sha256.
  - `vela solution show DescNorm --json` returned exit 4 (l.1695).
  - `vela plan ... --solution DescNorm --detailed-exitcode --out .vela-runs/.../plan.json` returned exit 4 (l.1717).
- **No question, no open question.** The Build Report says: "(DescNorm lives in the customer org). Preview
  unavailable here." (l.1748).

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Repro: description-only update, RED for the right reason | met | `ACC001_C1` (pipeline). RED at l.432, before the fix |
| Hypothesis from the registration and the gotchas, no org mutation | met | Canvas `decisions:`. Only read-only `solution show` and `plan` ran |
| Fix the single cause, nothing else changes | met | `git show 205cc1f`: `FilterOn(e => e.Description)`, 1+/1- |
| Customer org unreachable: inspect/plan recorded | met | Canvas "Gate (human)" lists `vela inspect` and `vela plan --detailed-exitcode` against `<org>`. `vela logs` is no longer listed (r5 had it). Minor |
| SC1: RED before any code change | met | l.432 comes before the edit. Commit order: 7d771f3 → 205cc1f |
| SC2: one-line fix, all tests green | met | l.1044, plus check "tests re-run green" |
| SC3: the explanation names the gotcha and the evidence | met | Build Report and final message: filter excludes `description`, RED/GREEN lines, no hedging |
| SC4: trace-log request says where and which fields | n/a | No request was made. The org was not read around the CLI |
| Ask vs assume: target solution | **not met** | Exit 4 on `DescNorm` (l.1695, l.1717). No question and no open question. Recorded "preview unavailable" (l.1748), the exact phrasing vela-apply rebuts. The answer key is `ZavaSales` |

There is no planted-violation section in the scenario.

## Mutation
3/3 killed, 0 survived. No missing tests.

## Did #124-#128 hold?
- **#124 (the debug Canvas writes the rule and its Case): held, with a slip.** The first draft used `R1` with no
  `Case` trait. spec-check caught it (l.577-579). The final commit has ACC-001/C1-C2 with traits.
- **#125 (skills are loaded with the `skill` tool): held.** All 6 loads used the tool, including vela-apply.
- **#126 (exit 4 → ask; review.md saved; Build Report in the Canvas):**
  - Build Report in the Canvas: held.
  - review.md: **not held.** It was not written at all this time (see below).
  - Exit 4 → ask: **not held.**
- **#127 (`vela plan` on the reachable org, and its exit 4 is asked):**
  - Plan on the reachable org: held.
  - Exit 4 asked: **not held.**
- **#128 (step 9 is a bare pointer): held.** vela-apply was loaded right after review (l.1658). Its step 5
  (`solution show`) and step 6 (`--detailed-exitcode --out`) ran as written (l.1675-1717), which closes the r5
  gap. What still fails is the exit-4 decision, and that now happens with step 5 in context.

## Exit-4 decision: skill text or scenario design?
**Scenario design is the more plausible cause.**

The actor wrote no reasoning between the exit 4 and the report. The only lines are:
- the command output "Could not read the publisher prefix for solution 'DescNorm': Solution not found: DescNorm /
  exit 4" (l.1695);
- the plan's "Solution not found: DescNorm ... exit 4" (l.1717);
- the next narration, "Write the Build Report in the Canvas and final report." (l.1730);
- the record "(DescNorm lives in the customer org). Preview unavailable here." (l.1748);
- the final message: "The solution lives in the customer org, which I can't reach" (l.1784).

The skill text had just been loaded, 37 lines earlier (l.1658), and was clear:
- vela-apply step 5: "Exit `4` = no such solution ... ask the human for the right unique name (one question)";
- its rebuttal: "never record the preview as merely unavailable".

The actor still treated exit 4 as fully explained. The repo and the prompt support that reading:
- `PROJECT.md` (`packages: zava_zava.Plugins: DescNorm`) is the source step 5 itself names, and it says
  `DescNorm`.
- The prompt says the plugin "runs in the **customer's** org, which you cannot reach" and that the fix "must
  not be deployed" to the dev org (session l.37).

From inside the run, "DescNorm exists in the customer org, not in dev" is the coherent world model. A question
about a dev-org solution looks pointless for an org the actor was told not to deploy to. The answer key,
`ZavaSales`, contradicts the repo's own `PROJECT.md`. Nothing in `work/` hints that `ZavaSales` exists.

This is the fourth run in a row with this result (r3-r6). It has survived three successive wording fixes and
now happened with the wording in context. That makes a test-design confound more likely than missing text.

The skill is not blameless: step 5's "none reachable → open question" fallback was not taken either, so the
letter of the skill was still broken. That is why the criterion is graded not met.

## Why review.md was not saved
- vela-code-review step 6 ("Save the reviewer's verbatim output as `.vela-runs/<slug>/review.md` ... a round is
  not finished until it is saved") was loaded once, in the parent, at l.535. That is about 900 lines before the
  first verdict.
- Round 1 returned BLOCK (l.1465). The actor went straight into step 5's "fix, re-verify, review again" loop:
  RED capture (l.1516), `trace.md` (l.1546), re-dispatch.
- Round 2 returned PASS (l.1616). The next line is "Now package and preview." (l.1643), the transition that the
  #128 pointer now drives.
- In r5, review.md was written incidentally inside the Build Report heredoc. This Build Report heredoc
  (l.1735-1757) has no such write.
- So the save sits after the gate step. Neither the BLOCK path, which loops back from step 5, nor the PASS
  path, which goes to vela-apply, passes through step 6. `.vela-runs/` holds only `diff.patch` and `trace.md`.

## Findings against the skills
1. **blocker (scenario / eval, not skill):** `evals/scenarios/debug-filter-miss.md` and its setup. The answer
   key `ZavaSales` contradicts the scaffolded `PROJECT.md` (`DescNorm`), and the prompt tells the actor the
   solution's org is unreachable. As a result, exit 4 on the dev org is self-explaining. Two possible fixes:
   - Scaffold with `--solution ZavaSales`. Exit 4 then never happens, and the criterion tests the plan itself.
   - Or say in the setup that the customer org uses the same solution as dev, so a dev-org exit 4 is a real
     anomaly to ask about.
2. **minor (persisting):** `skills/vela-code-review/SKILL.md` step 6. The save comes after the gate, so a BLOCK
   loop or a hand-off to the next skill skips it. Move the save into the dispatch step: "save the verbatim
   result to `review.md` before acting on it".
3. **minor:** `skills/vela-apply/SKILL.md` step 5. Even if the actor judges a question pointless, "none
   reachable → an open question that blocks the gate" should still produce an `open_questions:` entry. The actor
   wrote "Preview unavailable here" instead. If the scenario is kept, the rebuttal could name this exact excuse:
   "the solution lives in another org".
4. **minor:** the Gate's `vela inspect -p <pkg> --solution DescNorm --url <org>` repeats the unconfirmed name.
   `vela logs` was dropped, although debug step 10 lists it.
5. Note (actor / Copilot): commits carry `Co-authored-by: Copilot` (l.455, l.1026), against the house rule.
   This is not graded here.

## Verdict
**fail.** The run passes checks 14/14 and mutation 3/3, and meets every debug criterion. The #128 pointer worked:
vela-apply was loaded, and `solution show` and `plan --detailed-exitcode` ran. Ask-vs-assume on exit 4 failed
again, now with vela-apply step 5 in context. The more plausible cause is the scenario's conflict between
`PROJECT.md` and the answer key, not the skill wording. review.md was not saved, because the save step is placed
after the gate in vela-code-review.
