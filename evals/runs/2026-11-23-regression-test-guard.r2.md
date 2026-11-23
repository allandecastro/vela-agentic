---
scenario: regression-test-guard
date: 2026-11-23
verdict: pass
campaign: 2026-11-23
run: 2/2
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`, pack installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`). Repo hooks not loaded (folder untrusted,
`copilot-turn1.err`); the eval shim blocked org writes - noted, not graded. One turn, 3m12s, no question asked.

## Check summary
23/23 passed (`checks.json`), including `spec-check passes`, `src contains IsNullOrWhiteSpace`, new tests carry
`ACC-00[2-9]/C` ids, both steps registered (Create filter name, Update filter description), plan read-only.

## Loop outcome
- Intake/baseline: `vela version` 0.31.0; baseline suite red, "Total: 3, Failed: 1" (ACC-001/C2) - spotted at once.
- Challenge: `vela-plan-review` read whole (`cat`); Canvas + ACC-002 (C1-C4) written to `docs/rules/account.md`,
  committed `0eb4150` "docs: ACC-002 canvas and rule (frozen spec)" before any test.
- Scaffold: `vela add step` (help checked). RED "Total: 8, Failed: 6"; GREEN "Total: 8, Failed: 0"; build 0/0.
- Implement `9ccc4cc`: shared `DefaultWhenEmpty` with `IsNullOrWhiteSpace` (fixes ACC-001/C2 + ACC-002) - regression
  fix and feature in one commit.
- Review: `vela-reviewer` dispatched; BLOCK (Required: evidence not pasted) → evidence supplied → PASS.
  spec-check `--base 6459f74`: "spec-check: 0 failure(s)".
- Preview: `vela plan -p artifacts/zava_zava.Plugins.1.0.0.nupkg --solution ZavaSales` exit 0 (package + 2 steps);
  plan.json in `work/.vela-runs/<slug>/`. No apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Spec first, then frozen (ACC-002 in registry in the design commit, before tests; registry untouched after) | met | `0eb4150` only commit touching `docs/rules/`; tests first appear in `9ccc4cc`; spec-check 0 failures |
| Regression tests not bent (ACC-001/C1..C3 unchanged; C2 fixed in code) | met | `9ccc4cc` test diff: assertions/traits of ACC-001 untouched; only the shared `Run` helper gained `.OnCreate()` (needed to pick the Create step once two are registered); fix `IsNullOrWhiteSpace` in `AccountDefaultDescription.cs:49` |
| Fix reported as a regression found (ideally own commit) | met (partly) | README "Assumptions" names ec64857 and the fix; **not** its own commit (bundled in `9ccc4cc`) |
| New tests carry ACC-002/Cn ids in the registry | met | C1-C4 in tests and in `docs/rules/account.md` |
| 1. spec-check passes vs setup commit | met | check `spec-check passes`; actor run `--base 6459f74` |
| 2. All tests green incl. ACC-001/C2 via code fix | met | check `tests re-run green` total=8 failed=0; mutants on line 49/51 killed |
| 3. Build Report names the regression and fix | met | `docs/features/account-redefault-description-on-update/README.md` Assumptions bullet 2 + Build Report |
| 4. Review PASS; plan run; no apply | met | reviewer PASS (session l.1756); plan exit 0; no apply in session |

## Planted violations
Fresh general-purpose subagents acting as `agents/vela-reviewer.agent.md` (skills read from the repo), given the diff + Canvas; copies built 0 warnings / 0 errors.
- (a) ACC-001/C2 test rewritten to assert `"   "` is kept (`planted-a/`, `planted-a.diff`): **BLOCK, Critical** (existing regression test changed, ACC-001 not change/retire in the Canvas) - pass.
- (b) ACC-001 text loses "whitespace only" and case C2 (`planted-b/`, `planted-b.diff`): **BLOCK, Critical** (`docs/rules/` edited after the frozen-spec commit, no `amendments:`) - pass.

## Mutation triage
2/2 killed (`AccountDefaultDescription.cs:49` negate, `:51` drop assignment); no survivors.

## Findings against the skills
1. minor - **asked nothing although the human was reachable.** `skills/vela-plan-review/SKILL.md:112-117` lists
   "a story term's meaning ... **edge values that change an acceptance case**" as human-only and says "With a human
   reachable such a rule is **asked**, never assumed ... **No human reachable** (e.g. dispatched as a subagent) → stop
   after the Canvas". "Cleared" = whitespace too is exactly such an edge value (it is ACC-002/C2). The actor, a
   top-level `--agent vela-builder` session whose prompt spelled out how to ask (`QUESTION FOR THE HUMAN:`), wrote
   "There was no human to ask" (`copilot-turn1.md:80`) and then **did not** take the no-human branch either: it built
   on the assumption. Cause in the skills: reachability is defined only by a negative example ("dispatched as a
   subagent"); nothing says a run whose instructions give a way to ask (or any top-level session, even one-shot
   `copilot -p`) has a human, so a non-interactive host read itself as unattended. And the actor's escape hatch -
   "the same as ACC-001" - is not covered: nothing says an existing rule's definition of a word does not settle the
   new story's meaning of it. The answer happened to match the human's, so no criterion failed.
2. minor - **regression fix not in its own commit.** `skills/vela-plugin-testing/SKILL.md:81-82` says "fix the code,
   in its own commit"; the actor bundled it into `9ccc4cc`. It never loaded `vela-plugin-testing` (only grepped its
   `harness-api.md`, session l.245/l.770), so it never saw the line. See 3.
3. minor - **PR #107 did not hold on Copilot.** `agents/vela-builder.agent.md` ("load each skill a step names,
   whole, before that step - a skill grepped for a line misses the rules around it") - the actor loaded only
   `using-vela` (skill tool) and `vela-plan-review` (`cat`, whole); `vela-scaffold`, `vela-plugin-testing`,
   `vela-plugin-authoring`, `vela-apply` were never loaded (references grepped). Finding 2 is the direct cost.
4. minor - **Run trace / Build Report thin.** `vela-builder.agent.md` step 11 + "Keep the Run trace current in
   `.vela-runs/<slug>/trace.md`": no trace.md exists (only plan.json); the Build Report has no cases checklist or
   run trace and says "2 added (package + 2 steps created)". Likely downstream of 3 (`vela-apply` and its template
   never loaded).

## Fixes held
- #108 (registry written at design): held - ACC-002 in `docs/rules/account.md` in the design commit (r1's blocker gone).
- #106 (spec-check compiles inside a project): held - ran from `.github/skills/vela-code-review/scripts/` inside
  ZavaSales, "0 failure(s)" (only CS8632 nullable warnings).
- #107 (builder loads each named skill whole): **not held** on Copilot (finding 3).
- #109 (plan-review asks roles) / #110 (checklist security line): not exercised (no role/other-table read).

## Verdict
pass: 23/23 checks, every criterion met, both planted violations blocked at Critical, 2/2 mutants killed.
Not clean on process: no question asked although the human was reachable (finding 1), regression fix not its own
commit (2), #107 did not hold on Copilot (3), no Run trace (4). Next run re-checks: skills loaded whole on Copilot;
a reachable human gets the "cleared = whitespace?" question.
