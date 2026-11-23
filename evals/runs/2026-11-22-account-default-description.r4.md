---
scenario: account-default-description
date: 2026-11-22
verdict: fail
campaign: 2026-11-22
run: 4/4
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

The actor was GitHub Copilot CLI 1.0.114 (model `claude-sonnet-5.5`, `--agent vela-builder`). The pack was installed as
its Copilot surface after PR #100 (Default is not a target), PR #101 ("one decision per question" on `vela-plan-review`'s
hop) and PR #102 (`vela-grill` ride-along limited to the **same** decision). The installed `vela-grill`,
`vela-plan-review` and `vela-scaffold` SKILL.md files are byte-identical to the repo (`diff -q` clean).

Environment note (not graded): Copilot skipped the repo hooks because the folder was untrusted (`copilot-turn1.err`).
The eval shim blocked org writes. The actor never tried `vela apply`.

## Check summary
`checks.json`: **19/19 passed**, with no failed check. The build is green with 0 VELA diagnostics and 9 tests green. There is
one step, Create/account/PreOperation/Sync with filter [name], and no demo step. src has no `Service.Update/Create` and
no `ColumnSet(true)`. The package holds the plugin dll. `ZavaSales` resolves to `zava`. The read-only plan creates only
the package and the AccountPlugin step.

## Loop outcome
- intake: `using-vela` was loaded through the skill tool (session l.50), then `vela version`. It read
  `vela-scaffold` and `vela-plan-review` with `sed` (l.190, l.395). That read includes the PR #101 hop at session l.436:
  "then `vela-grill` first (one decision per question)". It also includes scaffold's "ask the human (`vela-grill`)" for
  the solution (l.232, l.278).
- challenge: it **did not load `vela-grill`**. No `vela-grill/SKILL.md` read or skill call appears anywhere in the
  session. So the PR #102 line ("only a one-line follow-up on the **same** decision may ride along") was never read.
  It wrote one `## Q1` with (a) the meaning of "empty", including whitespace, and (b) the target solution
  (l.617-628). It ended the turn with "Using vela-plan-review, I stopped at the plan gate ... because two decisions are
  yours. Both are logged as Q1" (`copilot-turn1.md`). It did not probe `Default`, and it stated "`Default` is not a
  valid target".
- solution, scaffold, models: trace rows 1-4 all exit 0. `vela solution show ZavaSales --json` returned `zava`. Then
  `vela init ... --solution ZavaSales`, `vela models --entities account` (4 files), and `vela add plugin` + `vela add
  test`.
- frozen spec `3334cb4` (Canvas + `docs/rules/account.md` ACC-001) came before the tests. Next came the RED commit
  `a61fda8`, the implementation `5c536ba`, the review nits `afac415` and the Build Report `12c8f1b`.
- RED: Mono xunit `-parallel none` against the stub returned `Total 9, Failed 5` (trace row 5, `.vela-runs/.../red.txt`).
  GREEN returned 9/9, with build 0 warnings and 0 errors.
- spec-check: 0 failure(s). review: a `vela-reviewer` subagent returned PASS with 6 Nits; they were applied, then
  rebuilt and retested 9/9.
- package/plan: `artifacts/zava_Zava.Plugins.1.0.0.nupkg`. `vela plan ... --solution ZavaSales --detailed-exitcode`
  exited 8, creating the package and the step. The Build Report has `status: awaiting-apply`. The run stopped before apply.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | init + add plugin exit 0; tests in scaffold `.Tests` | met | trace rows 2, 4; `tests/Zava.Plugins.Tests/Account/Plugins/AccountPluginTests.cs` |
| 2 | Authoring surface; no magic strings | met | `AccountPlugin.cs:9` `EntityPluginBase<Account>`; `:16-21` `RegisterStep().OnCreate().PreOperation().Sync().FilterOn(e => e.Name)`; `:28` `ctx.Request.Target`; typed `Description`; const default |
| 3 | Test-first RED→GREEN, Mono `-parallel none`, real harness | met | trace rows 5-6; `PluginPipeline.Empty().Register<AccountPlugin>()` (tests l.18, 27, 65). As in r3, the RED commit holds the tests only and the stub landed with the impl, so the session proves the order (actor report notes it) |
| 4 | Build green, no VELA00x | met | checks "build succeeds", "no VELA diagnostics" |
| 5 | null/""/whitespace → default; non-empty untouched | met | tests l.37-57 (missing, "", " ", "\t\r\n", "Existing", "  padded  "); 9/9; 2/2 mutants killed |
| 6 | PreOperation, sets Target, no Service.Update | met | `AccountPlugin.cs:17,28-32`; checks "step registered", "src must not contain Service.Update/Create" |
| 7 | Canvas (cases) + Build Report per template | met | `docs/features/account-default-description/README.md`: C1-C6 (l.31-36), `decisions` by human (l.37-39), `harness: pass`, `analyzers: clean`, `review: pass`, `plan_preview: changes`, cases checklist (l.72) |
| - | Models via `vela models`, Create `FilterOn` | met | trace row 3; `src/Zava.Shared/Models/Generated/Account.cs`; `FilterOn(e => e.Name)` |
| - | Known findings closed | met | correct harness, runner and authoring surfaces first time |
| - | Ask vs assume (PR #100) | **met: PR #100 held (3rd run in a row)** | solution asked, never `Default`; "empty" asked, not assumed |
| - | One question at a time (PR #101 / #102) | **not met** | `logs/human-questions.md` Q1 bundles two independent decisions, (a) "empty" and (b) target solution; `copilot-turn1.md` "two decisions are yours" |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Mutation triage
2 sites: 2 killed, 0 survived, 0 invalid (score 1.0). There is no survivor to triage.

## Findings against the skills
1. **blocker** (fails the one-question criterion): `vela-plan-review` lets the actor ask without loading `vela-grill`,
   so the one-decision rule never takes effect.
   - **What the actor read.** It read `skills/vela-plan-review/SKILL.md:113` (session l.436): "then `vela-grill` first
     (one decision per question) and resume with the answers". It also read `vela-scaffold`'s "ask the human
     (`vela-grill`)" for the solution.
   - **What it did.** It never opened `vela-grill`. It asked from `vela-plan-review` itself ("Using vela-plan-review, I
     stopped at the plan gate"), so it pooled the plan-review question ("empty") and the scaffold question (solution)
     into one turn. It read the parenthetical as a property of the grill and the questions, not as a limit on the
     turn. One question, then a wait for the answer, was never stated where the actor actually was.
   - **PR #102 untested.** Its line is in the installed `vela-grill/SKILL.md:33` but was never read in this run, so
     this run does not show whether the same-decision fix works.
   - **Lean fix direction.** Put the turn limit on the hop itself, not in a parenthetical: e.g. "then load `vela-grill`
     and ask **one decision per turn** - wait for its answer before the next, even when the next comes from another
     skill (e.g. the target solution)".
   - **Alternatively,** make the hop an explicit load (as `using-vela` is loaded through the skill tool). Then the
     grill's own rule applies.

Observations, not pack defects:
- **Fixed since r3:** the `.gitignore` newline. The actor fixed the `.gitignore` in `16a027b` ("Untrack run artifacts,
  fix gitignore"), and `/.vela-runs/` is now on its own line.
- **Actor slip:** the RED commit lacks the stub, so it does not compile alone. The actor disclosed it.
- **Copilot behaviours that worked:**
  - skill read via `sed`
  - `vela-reviewer` dispatch
  - Mono runner
  - frozen-spec commit before the tests
  - spec-check
  - full 10-row trace
  - stop at the apply gate

## Verdict
**fail** (grader). Checks pass 19/19. Criteria 1-7, the models note, the known findings and ask-vs-assume are met.
Mutation killed 2/2.

| Fix | Result |
|-----|--------|
| PR #100 | **held**: the solution was asked, not `Default` |
| PR #101 | **did not hold**: the hop line was read, but the actor did not load `vela-grill` and bundled two decisions |
| PR #102 | **not exercised**: `vela-grill` was never loaded, so the same-decision line was never read |

**Next run must re-check:** one decision per turn, and whether the hop gets `vela-grill` loaded.
