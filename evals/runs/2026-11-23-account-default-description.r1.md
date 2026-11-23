---
scenario: account-default-description
date: 2026-11-23
verdict: pass
campaign: 2026-11-23
run: 1/1
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`, pack installed as the Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`). Repo hooks were not loaded (untrusted
folder); the eval shim blocked org writes. Neither one affects the verdict.

## Loop outcome
- Turn 1: asked one question (the target solution) and, in the same message, stated "unless you object" assumptions
  ("empty" = null/""/whitespace; Create, PreOperation, Sync). Then stopped. Turn 2: the scripted answer arrived (ZavaSales/zava, empty = null/""/whitespace).
- `vela solution show ZavaSales --json` exit 0 → `vela init` exit 0 → Canvas + `docs/rules/account.md` committed (3e53ce5)
  → `vela models --entities account` exit 0 → `vela add plugin` / `vela add test` exit 0 (trace.md rows 1-5).
- RED: Mono xunit `-parallel none`, Total 6, Failed 4 (exit 1). GREEN: Total 6, Failed 0 (trace.md rows 6-7).
- `dotnet build -c Release`: 0 warnings, 0 errors. spec-check: 0 failures. vela-reviewer: PASS on the 3rd pass (the first two BLOCKed only for missing evidence).
- `vela plan --solution ZavaSales --detailed-exitcode`: exit 8 (changes): create package + create step. Stopped before apply.

## Checks
19/19 passed (checks.json), none failed.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | init + add plugin exit 0; tests in the scaffold's `.Tests` | met | trace.md rows 2,5; `tests/Zava.Plugins.Tests` from the scaffold commit e514367; `vela add test` run inside it per `vela-plugin-testing` step 1 |
| 2 | `EntityPluginBase`/`OnExecute`-style handler on `ctx.Request.Target`, no magic strings | met | AccountPlugin.cs:9, 16-21, 27; generated `Account` model, `FilterOn(e => e.Name)` |
| 3 | Test-first RED→GREEN, OS-correct runner, real harness API | met | trace.md:10-20 (RED in commit ba8688c, before the implementation in 300a168); `PluginPipeline` in AccountPluginTests.cs:18 |
| 4 | Build green, 0 VELA00x | met | checks "build succeeds", "no VELA diagnostics" |
| 5 | Empty (null/whitespace) defaulted; non-empty untouched | met | AccountPluginTests.cs:26-57; checks "tests re-run green (>= 3)" = 6/6 |
| 6 | PreOperation, sets the value on Target, no `Service.Update` | met | AccountPlugin.cs:17,33; check "step registered ... PreOperation", no Service.Update/Create |
| 7 | Canvas with cases + Build Report | met | docs/features/account-default-description/README.md:30-35 (cases), 69-77 (Evidence) |
| - | Ask-vs-assume (story term "empty") | met (borderline) | logs/human-questions.md Q1: the meaning was put to the human as a proposed default in a blocking turn, before any Canvas or code, and confirmed; the Canvas records it as `by: human` (README.md:37) |
| - | One question per decision | met | Q1 = one question (solution) plus the proposed defaults, each answerable on its own (PR #103 allows a shared turn) |

**Ask-vs-assume judgment.** `vela-plan-review` step 4 says that with a human reachable, a story term's meaning "is **asked**, never assumed". The actor's wording was "Unless you object, I'll also assume: 'Empty' means a null, empty or whitespace-only Description", sent in a turn that stopped for an answer. In practice this is the "proposed default, one-line answer" form that `vela-grill` step 2 allows. The human had the decision in front of them before anything was built and answered it explicitly, so the rule holds. It is borderline on two points:
- It was framed as an assumption, not a question, so a human who answers only the solution would leave it standing as an assumption.
- It was not numbered, which `vela-grill` requires when decisions share a turn.

## Planted violations
None in this scenario.

## Mutation
2/2 killed (AccountPlugin.cs:28 negate if, :33 drop assignment). No survivors to triage.

## Findings against the skills
1. minor: `skills/vela-plan-review/SKILL.md` step 4 says "With a human reachable such a rule is **asked**, never assumed", while `skills/vela-grill/SKILL.md` step 2 allows "a proposed default". The pack never says whether an "unless you object" assumption stated next to a blocking question counts as asking. The actor relied on this gap. It passed here only because the scripted answer happened to address it. Suggested fix: say that a term's meaning is put as its own numbered question (a proposed default is fine) and is never stated as an assumption to object to.
2. minor: the actor never announced or ran `vela-grill` (it only grepped the skill for "solution", copilot-session.md:273), so the shared-turn numbering rule from PR #103 was not applied. Q1 is unnumbered and mixes one question with assumptions. This is a reach problem: `vela-plan-review` step 4 sends the agent to `vela-grill` only "then", and a proposed default let it skip the grill.

## Verdict
Pass: checks 19/19, every criterion met, mutation 2/2. The next run must re-check finding 1, that a story term's meaning is asked as a numbered question and not stated as an "unless you object" assumption.
