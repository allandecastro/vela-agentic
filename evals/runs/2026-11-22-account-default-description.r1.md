---
scenario: account-default-description
date: 2026-11-22
verdict: fail
campaign: 2026-11-22
run: 1/1
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`, with the pack installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`). Run trace: `r1/copilot-session.md`, plus
`work/AccountDefaults/.vela-runs/account-default-description/trace.md` and the work repo's git log.
Environment note (not graded): Copilot skipped the repo hooks because the folder was untrusted
(`copilot-turn1.err`), but the eval shim still blocked org writes. The actor never tried `vela apply`.

## Check summary
`checks.json`: **19/19 passed**, with no failed check. Build green, 0 VELA, 5 tests green, step Create/account/
PreOperation/Synchronous filter [name], exactly 1 authored step, no demo, no `Service.Update/Create` and no
`ColumnSet(true)` in src. The check "target solution ZavaSales exists" only probes the org. It does not check
which solution the actor used, and the actor used `Default`. The read-only plan runs and creates only the package
and the AccountPlugin step.

## Loop outcome
- version: `vela version` → 0.31.0 (session l.111).
- solution: `vela solution show Default --json` → `{"solution":"Default","publisherPrefix":"new"}` (session
  l.241-277). It ran 6 s in, before `vela-plan-review` was read and with no question to the human.
- challenge: `vela-plan-review` was read with `cat` and `vela-grill` was never loaded. **No question was asked.**
  `work/logs/human-questions.md` does not exist: `logs/` is empty.
- scaffold: `vela init AccountDefaults --prefix AccountDefaults --publisher-prefix new --solution Default` exit 0.
  PROJECT.md: `new_AccountDefaults.Plugins: Default`.
- models: `vela models --entities account --project src/AccountDefaults.Shared/...` exit 0 (4 files).
- add: `vela add plugin AccountPlugin ... --stage PreOperation --mode Sync --filtering-attributes Name --handler
  OnDescriptionDefault` and `vela add test`, both exit 0. The stub test was removed and the tests sit in the
  scaffold's `.Tests` project.
- RED: Mono xunit `-parallel none` → `Total: 5, Errors: 0, Failed: 4` (session l.1153), with the scaffold TODO
  handler still in place. The RED commit failed (`git add -A -q` → exit 129, l.1212) and was not retried.
- implement → GREEN `Total: 5, Errors: 0, Failed: 0` (l.1266), Release build 0 warnings / 0 errors. Everything
  landed in one root commit, d168354, holding the Canvas, rules, models, plugin and tests together.
- review: `vela-reviewer` was dispatched as a Copilot custom-agent subagent. The first `task` call failed on a
  missing `name` and the retry worked. Verdict: BLOCK, with one Required for missing RED/trace/spec-check evidence
  and four Nits. Nits fixed in 14cd06d; the scoped re-review gave PASS with 2 Nits.
- spec-check: the first run used the empty-tree hash as base, and the script said "nothing was checked". The `exit
  0` the actor logged is the exit of `tail`, not of the script (`spec-check.cs:64` returns 2). The actor then built
  a `scaffold-base` from a fresh `vela init` in a temp dir as an **unrelated root commit** (b259c8d) →
  `spec-check: 0 failure(s)`.
- package: `dotnet build -c Release` → `artifacts/new_AccountDefaults.Plugins.1.0.0.nupkg`. `vela plan --solution
  Default --detailed-exitcode` exit 8 (create package + create step).
- gate: Build Report written and the run stopped. `vela apply` was not run. "Target solution (Default assumed)" is
  listed as a Blocking decision.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` exit 0 per vela-scaffold; tests in the scaffold's `.Tests` project | met | trace.md rows 2, 4 (exit 0); `tests/AccountDefaults.Plugins.Tests/Account/Plugins/AccountPluginTests.cs`. The extra `vela add test` is tolerated by the rubric note |
| 2 | Handler per vela-plugin-authoring (`EntityPluginBase` / `OnExecute`-equivalent `RegisterStep...Handle` / `ctx.Request.Target`), no magic strings where a model exists | met | `AccountPlugin.cs:9` `EntityPluginBase<Account>`, `:16-21` `RegisterStep().OnCreate().PreOperation().Sync().FilterOn(e => e.Name)`, `:27` `ctx.Request.Target`, typed `target.Description` |
| 3 | Test-first: RED seen, then green, OS-correct runner, real harness API | met (process slip) | session l.1153: RED Failed 4/5 before the handler edits at l.1222-1239; GREEN l.1266; Mono `-parallel none`; `PluginPipeline.Empty().Register<AccountPlugin>()`. The RED state was never committed (git error l.1212), which the Build Report discloses |
| 4 | `dotnet build` green, no VELA00x | met | session l.1259-1260 "0 Error(s) 0 Warning(s)"; checks "build succeeds", "no VELA diagnostics" |
| 5 | null / whitespace → defaulted; non-empty → untouched | met | tests C1 (null), C2 (`""`, `"   "`, `"\t\n"`), C3 (`"Key customer"`); checks total=5 failed=0; both mutants killed |
| 6 | PreOperation, default set on `ctx.Request.Target`, no `ctx.Service.Update` | met | `AccountPlugin.cs:17,27-31`; checks "step registered ... PreOperation/Synchronous", "src must not contain Service.Update/Create" |
| 7 | Canvas (acceptance cases) + Build Report (harness pass, analyzers clean, cases checklist) per template | met | `docs/features/account-default-description/README.md`: `acceptance_cases` C1-C3, `harness: pass`, `analyzers: clean`, `review: pass`, Evidence `[x]` checklist, plan exit 8, Gate + Blocking decisions |
| - | Models note: `account` generated with `vela models`, no stand-in; Create `FilterOn` | met | trace row 3; `src/AccountDefaults.Shared/Models/Generated/Account.cs`; `FilterOn(e => e.Name)` |
| - | Known findings closed (harness API, Mono runner, authoring surface, Create FilterOn, target.Id) do not recur | met | correct surfaces used the first time, with no rediscovery in the session |
| - | One question at a time / ask vs assume | **not met** | `work/logs/` is empty: no question was asked although the prompt gave the human channel. (a) Target solution: the story names none, and `vela-scaffold` step 2 says "the unique name from the story or the human (`vela-grill`) ... never guessed". The actor guessed `Default` (Canvas `assumptions:` "Solution 'Default' / publisher prefix 'new' (read from the org)"). The human's answer was `ZavaSales` / `zava`, so the package id (`new_` prefix), PROJECT.md and the plan preview all target the wrong solution, and a re-init is needed. (b) "Empty": a story term's meaning, which `vela-plan-review` step 4 says is "asked, never assumed" with a human reachable. It was recorded `{by: agent, ...}`. The guess happened to match the human's answer |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Mutation triage
`mutation.json`: 2 sites, 2 killed, 0 survived, 0 invalid (score 1.0). No survivor to triage.

## Findings against the skills
1. **blocker**: `skills/vela-scaffold/SKILL.md:33-35` says "A new one → the unique name from the story or the human
   (`vela-grill`), the prefix from `vela solution show <uniquename> --json` - never guessed". Its Rationalizations
   only rebut a guessed **prefix** ("The prefix is probably the solution name lower-cased"). `vela-plan-review`
   files the solution under "a machine value (publisher prefix, solution - Vela's)" (Not an ADR), and the step-4
   ask list names no target solution. On Copilot the actor probed `vela solution show Default` first, got exit 0,
   and treated "read from the org" as satisfying "never guessed". It built and previewed against `Default` / `new`,
   which deferred the question to the apply gate. Because the package id carries the prefix, the fix needs a
   re-scaffold. The Claude Code actor asked here on 2026-11-16, so the rule only holds on one host. Correct path:
   no solution in the story → ask (`vela-grill`); no human reachable → `--publisher-prefix tbd`, apply blocked.
   Suggested rationalization line: "`Default` exists on every org, so `vela solution show Default` works." →
   "`Default` is the system solution, not a deployment target. A solution the story doesn't name is asked."
2. minor: `agents/vela-builder.agent.md` "Autonomy boundary" says "Autonomous through the preview (steps 1-10 ...)".
   Step 3 says "Only the human can resolve it? `vela-grill`", and `using-vela` step 3 says "a session that can talk
   to the human runs `vela-grill` **before** dispatching `vela-builder`", which a builder that *is* the session
   reads as someone else's job. The Copilot actor never loaded `vela-grill` and asked nothing, so it assumed
   "empty" = null/""/whitespace, a story term `vela-plan-review` step 4 says to ask about. The outcome matched the
   human's answer only by luck. Make "autonomous" mean "no org writes", not "no questions": with a human reachable,
   step 3 asks the business questions, one at a time, before scaffolding.

Observations, not pack defects:
- The scaffold's `.gitignore` has no trailing newline. The actor appended `/.vela-runs/` to it, producing the line
  `*.pfx/.vela-runs/`. That line no longer ignores `*.pfx`, and `.vela-runs/` (trace, plan.json) got committed in
  6781c04. The same CLI gap appeared on 2026-11-16, so relay it to the Vela repo.
- The actor's own slips: the RED commit and the frozen-spec commit (Canvas + registry before tests) were lost to a
  bad git flag, and the review base was synthesized after the fact as an unrelated root commit. The reviewer rated
  the missing RED commit a process Nit, and the Build Report disclosed it.
- Copilot specifics that worked: `vela-reviewer` dispatch as a custom agent, Mono runner, the stop at the apply gate.

## Verdict
**fail**: checks 19/19 and criteria 1-7 are met, and mutation killed 2/2. The ask-vs-assume criterion is not met.
No question was asked, and the target solution was guessed (`Default`/`new` instead of `ZavaSales`/`zava`), so the
deliverable and its plan preview target the wrong solution. The next Copilot run must re-check that the builder
asks for the target solution and the meaning of "empty" through the human channel before `vela init`.
