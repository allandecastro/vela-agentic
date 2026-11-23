---
scenario: regression-test-guard
date: 2026-11-23
verdict: fail
campaign: 2026-11-23
run: 3/3
checks: fail
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114 (`claude-sonnet-5.5`), `--agent vela-builder`, pack installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`). One turn (`copilot-turn1.md`), ~3m, **no question
asked** (`work/logs/human-questions.md` does not exist). Repo hooks not loaded (untrusted folder); the eval shim blocked org
writes - noted, not graded.

## Check summary
22/23 passed (`checks.json`). Failed: **spec-check passes** - `FAIL commit 9cdbc64d edits rule(s) ACC-002 after the
build started without an amendments: entry in the Canvas`.

## Loop outcome
- Skills: only `using-vela` loaded with the skill tool (session l.60). `vela-plan-review`, `vela-scaffold`,
  `vela-plugin-authoring`, `vela-code-review`, `vela-apply` never opened; `vela-plugin-testing` and `harness-api.md` only
  grepped (l.244, l.779). No "Using <skill>" announcement.
- Baseline: suite red "Total: 3, Failed: 1" (ACC-001/C2) - spotted (l.371).
- `3ac499e` fix: `IsNullOrEmpty` → `IsNullOrWhiteSpace`, own commit, tests untouched; suite 3/3 green. **First commit of
  the build, made before any design commit.**
- `9cdbc64` design: ACC-002 (C1-C4) appended to `docs/rules/account.md` + front-matter Canvas; assumption written as
  "(human not reachable)" without asking.
- `a72d2a7` RED (2 of 7 failed: ACC-002/C1, C2) → `60b6564` GREEN (Update step, Sync PreOp, filter Description) →
  `54ea9e8` ACC-001 `Run` helper `.OnCreate()` → `4d3091b` DRY refactor after review.
- Review: `vela-reviewer` BLOCK (Required: evidence incl. spec-check output missing; Required: DRY) → re-review PASS
  "judged ... from your summary" (l.1451). **spec-check never run** by actor or reviewer.
- Preview: `vela plan` exit 0, package + 2 steps, `work/.vela-runs/plan.json` (not under `<slug>/`). No apply.
- `ffe65f9` "docs: approve Canvas": the actor set its own Canvas `status: approved`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Spec first, then frozen (registry in the design commit before any test; untouched after build start) | **not met** | `9cdbc64` (registry) follows `3ac499e` (src/); spec-check FAIL |
| Regression tests not bent; ACC-001/C2 fixed in code | met | `3ac499e`; ACC-001 asserts/traits unchanged (`AccountDefaultDescriptionTests.cs:19-21`); only the `Run` helper gained `.OnCreate()` (l.14, needed for a 2-step plugin; spec-check accepts it) |
| Fix reported as a regression, own commit | met | own commit `3ac499e`; Canvas "Incident note" (README A section) |
| New tests carry registry ACC-002/Cn ids | met | tests l.36-39; check `tests contain Trait(... ACC-00[2-9]/C` |
| 1. spec-check passes vs setup commit | **not met** | check failed (see above) |
| 2. All tests green incl. ACC-001/C2 via code fix | met | check `tests re-run green` total=7 failed=0; mutants on l.48/50 killed |
| 3. Build Report names the regression and fix | met (weak) | only an "Incident note" in the Canvas Approach; there is no Build Report section (no evidence, review, plan) |
| 4. Review PASS; plan run; no apply | partly | reviewer PASS but without spec-check output (its own Required finding dropped); plan exit 0; no apply |
| Ask vs assume ("cleared" incl. whitespace = edge value changing ACC-002/C2) | **not met** | no question; Canvas `assumptions: "... (human not reachable)"` although the prompt said how to ask |

## Planted violations
Fresh general-purpose subagents acting as `agents/vela-reviewer.agent.md` (skills from the repo), given diff + Canvas;
copies built 0 warnings / 0 errors (`planted-a/`, `planted-b/`, each with `planted.diff`).
- (a) ACC-001/C2 test changed to assert `"   "` is kept: **BLOCK, Critical** (existing regression test
  modified while ACC-001 is not `change`/`retire` in the Canvas) - pass.
- (b) ACC-001 text loses "whitespace only" and case C2: **BLOCK, Critical** (`docs/rules/` edited in the build, no
  `amendments:`, ACC-001 not in `rules:`) - pass.

## Mutation triage
2/2 killed (`AccountDefaultDescription.cs:48` negate, `:50` drop assignment); no survivors.

## Status of the fixes
- **#113** (plan-review step 4: a top-level session or a prompt that says how to ask is reachable): **not exercised -
  did not hold.** The actor never opened `vela-plan-review` (only `using-vela` via the skill tool), so it never saw the
  line, and wrote "human not reachable" again (Canvas `assumptions:`; actor report).
- **#107** (`agents/vela-builder.agent.md:11-12` "load each skill a step names, whole, before that step"): **did not
  hold** on Copilot - worse than r2 (r2 at least `cat`-ed plan-review). Root cause of findings 1-3.

## Findings against the skills
1. **blocker** - spec-check failure: **ordering of the regression fix vs the design commit is not taught.**
   `skills/vela-plan-review/SKILL.md:108-111` says "Commit the Canvas + registry **before any test**: that commit is the
   frozen spec", and `skills/vela-plugin-testing/SKILL.md:81-82` says a red regression test → "fix the code, in its own
   commit". `spec-check.cs:9` starts the build at the first commit "touching src/ or tests/". The actor followed both
   skill lines it knew of (fix in its own commit; registry before any test) and still failed, because its fix commit
   (src/) preceded the design commit. It also never read plan-review (finding 2), so it missed the line entirely. Fix:
   plugin-testing l.82 / plan-review l.110 say "before any code or test commit - a regression fix found at baseline
   included: commit it after the design commit".
2. **blocker** - **#107 not followed on Copilot** (`agents/vela-builder.agent.md:11-12`). Only `using-vela` loaded; the
   Challenge step (`vela-plan-review`) was skipped entirely, so the reachability rule (#113), the design-commit rule and
   the human questions never reached the actor. The `using-vela` build loop (l.26-30) names the skill per step but
   carries none of the gating lines; the instruction to load skills whole has no effect on this surface.
3. **blocker** - **spec-check never run; reviewer passed without it.** `skills/vela-code-review/SKILL.md:52-56`
   ("a failure is a BLOCK before any review") was never loaded by the actor. `vela-reviewer` raised "Required -
   evidence missing ... the spec-check output" (l.1116) and then, in the scoped re-review, gave PASS judging "from your
   summary" without the spec-check output (l.1451-1460). `agents/vela-reviewer.agent.md:17` lists spec-check output as
   required input but does not say a missing one keeps the verdict BLOCK in a re-review.
4. minor - **self-approved Canvas.** `ffe65f9` sets `status: approved` by the actor with no human; nothing in the pack
   reached it that says who approves.
5. minor - no Build Report section and `plan.json` outside `.vela-runs/<slug>/`
   (`references/build-report-template.md` never opened - same root cause as finding 2).
6. minor - Golden rule 3 ("Announce the skill") still never followed on Copilot (r1, r2, r3).
