---
scenario: account-default-description
date: 2026-11-22
verdict: fail
campaign: 2026-11-22
run: 2/2
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

The actor was GitHub Copilot CLI 1.0.114 (`--agent vela-builder`). The pack was installed as its Copilot surface
(`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`), after PR #100 ("Default is not a target
solution"). Run trace: `r2/copilot-session.md`, `r2/copilot-turn1.md` (the question), `r2/copilot-turn2.md`,
`work/ZavaSales/.vela-runs/account-default-description/trace.md`, and the work repo's git log.

Environment note (not graded): Copilot skipped the repo hooks because the folder was untrusted
(`copilot-turn1.err`, `copilot-turn2.err`). The eval shim still blocked org writes. The actor never tried
`vela apply`.

## Check summary
`checks.json`: **19/19 passed**, with no failed check:
- build green, 0 VELA diagnostics, 8 tests green
- step Create/account/PreOperation/Synchronous, filter [name]; exactly 1 authored step; no demo
- no `Service.Update/Create` and no `ColumnSet(true)` in src
- package `artifacts/zava_Zava.Plugins.1.0.0.nupkg`; the read-only plan creates only the package and the
  AccountPlugin step

This time the package itself carries the `zava` prefix, which proves the actor used the right solution.

## Loop outcome
- intake: `using-vela` was loaded through the skill tool (session l.57-64). It read `vela-scaffold`, `vela-models`
  and `vela version` → `vela 0.31.0` (l.112, l.290). It ran `vela solution --help` only; there was **no**
  `vela solution show Default` probe.
- challenge: it read `vela-plan-review` with `cat ... | head -120` (l.416). `vela-grill` appears only in the
  directory listing (l.92) and was never loaded. At 18 s, **before any scaffold**, it wrote `logs/human-questions.md`
  Q1 and ended the turn with `QUESTION FOR THE HUMAN:` (`copilot-turn1.md`). That one question held two
  independent decisions: (1) is whitespace-only "empty", and (2) which target solution, noting "`Default` isn't a
  valid target … Without a name I scaffold with publisher prefix `tbd`". The answer was appended under Q1.
- solution: `vela solution show ZavaSales --json --url <org>` exit 0 → `{"solution":"ZavaSales","publisherPrefix":"zava"}`
  (l.617-626; trace row 1).
- scaffold/models/add: `vela init ZavaSales --prefix Zava --publisher-prefix zava --solution ZavaSales` exit 0.
  `vela models --entities account --project src/Zava.Shared/...` exit 0 (4 files). `vela add plugin AccountPlugin ...
  --stage PreOperation --mode Sync --filtering-attributes Name --handler OnDescriptionDefault` and `vela add test`
  both exit 0 (trace rows 2-4). PROJECT.md: `zava_Zava.Plugins: ZavaSales`.
- frozen spec: `88d8816` "Canvas and rules for ACC-001" (Canvas + `docs/rules/account.md`) was committed before any
  test.
- RED: `d4e64de` holds the tests and the scaffold TODO handler. Mono xunit `-parallel none` → `Total: 8, Errors: 0,
  Failed: 5` (l.1548). The 5 failures are C1, C2×2 and C3×2; C4 and C5 are "leave alone" cases and were green.
- implement → `fd5aaba`. GREEN `Total: 8, Errors: 0, Failed: 0` and build 0 warnings / 0 errors (l.1590-1592).
- spec-check `--base main` → `spec-check: 0 failure(s)`, exit 0 (l.1730-1731). This time the base is a real one
  (the scaffold commit on `main`).
- review: `vela-reviewer` was dispatched as a Copilot `task` subagent (l.1922). Verdict PASS, with 5 Nits and no
  Critical/Required. Nits 1-3 were fixed in `20f3dea`, followed by a rebuild and retest (GREEN 8/0, l.2322).
- package/plan: `dotnet build -c Release` → `zava_Zava.Plugins.1.0.0.nupkg`. `vela plan -p ... --solution ZavaSales
  --detailed-exitcode --out .vela-runs/.../plan.json` → exit 8, creating the package and the step (l.2341-2350).
- gate: Build Report `945fbdf`, `status: awaiting-apply`, `apply: pending`. The run stopped and `vela apply` was not
  run. `.vela-runs/` is untracked: `.gitignore` gets `/.vela-runs/` on its own line, and `git ls-files` shows no
  trace or plan.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` exit 0 per vela-scaffold; tests in the scaffold's `.Tests` project | met | trace rows 2 and 4 (exit 0); `tests/Zava.Plugins.Tests/Account/Plugins/AccountPluginTests.cs`. `vela add test` was run inside the test project, which the rubric note tolerates |
| 2 | Handler per vela-plugin-authoring; no magic strings where a model exists | met | `AccountPlugin.cs:9` `EntityPluginBase<Account>`; `:16-21` `RegisterStep().OnCreate().PreOperation().Sync().FilterOn(e => e.Name)...Handle(OnDescriptionDefault)`; `:28` `ctx.Request.Target`; typed `target.Description`, `const DefaultDescription` |
| 3 | Test-first: RED seen and then green, with the OS-correct runner and the real harness API | met | `d4e64de` (tests + TODO stub) before `fd5aaba`; session l.1548 RED `Failed: 5`, l.1592 GREEN; Mono `xunit.console.exe -parallel none`; `PluginPipeline.Empty().Register<AccountPlugin>()` |
| 4 | `dotnet build` green, no VELA00x | met | l.1590-1591 and l.2320-2321 "0 Warning(s) 0 Error(s)"; checks "build succeeds", "no VELA diagnostics" |
| 5 | null / whitespace → defaulted; non-empty → untouched | met | tests C1 (absent), C2 (`""`, null), C3 (`"   "`, `"\t \r\n"`), C4 (`"Existing text"`, `"  padded  "`); checks total=8 failed=0; both mutants killed |
| 6 | PreOperation; default set on `ctx.Request.Target`; no `ctx.Service.Update` | met | `AccountPlugin.cs:17,28-36`; checks "step registered ... PreOperation/Synchronous" and "src must not contain Service.Update/Create" |
| 7 | Canvas (acceptance cases) + Build Report (harness pass, analyzers clean, cases checklist) per template | met | `docs/features/account-default-description/README.md`: `acceptance_cases` C1-C5, `harness: pass`, `analyzers: clean`, `review: pass`, `plan_preview: changes` with the command, Evidence section, Gate. Minor gap: the trace has no review/package/plan rows and `review.md` was not saved to `.vela-runs/` (both actor slips) |
| - | Models note: `account` generated with `vela models`, no stand-in; Create `FilterOn` | met | trace row 3; `src/Zava.Shared/Models/Generated/Account.cs` tracked; `FilterOn(e => e.Name)` |
| - | Known findings closed (harness API, Mono runner, authoring surface, Create FilterOn, target.Id) do not recur | met | correct surfaces used the first time, with no rediscovery in the session |
| - | Ask vs assume (r1 blocker: target solution guessed) | **met: the PR #100 fix held** | The actor asked for the target solution **before** scaffolding and never probed `Default`. `copilot-turn1.md`: "`Default` isn't a valid target. Without a name I scaffold with publisher prefix `tbd`". It also asked what "empty" means instead of assuming. Canvas `decisions:` records both answers `{by: human}`. Platform facts (FilterOn Name, Create only, calling user) are under `assumptions:` |
| - | One question at a time | **not met** | `logs/human-questions.md` has a single `## Q1` that holds two independent business decisions (whitespace = empty, target solution) plus a list of plan assumptions. `vela-grill` SKILL.md:26-31 says "Ask **one focused question at a time** ... a one-line edge follow-up may ride along, never two independent decisions". The actor prompt also asked for "one `## Q<n>` section per question". `vela-grill` was never loaded (only listed at session l.92). There was no harm to the deliverable, because both answers arrived in one turn |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Mutation triage
`mutation.json`: 2 sites, 2 killed, 0 survived, 0 invalid (score 1.0). No survivor to triage.

## Findings against the skills
1. minor: the one-question rule is reachable only through a hop that this host skipped. `vela-plan-review`
   SKILL.md:111-114 says "unless a branch is a business decision only the human can make ...: then `vela-grill`
   first and resume with the answers". `agents/vela-builder.agent.md` step 3 says "Only the human can resolve it?
   `vela-grill`". The rule that shapes *how* to ask lives only in `vela-grill` SKILL.md:26-31 ("one focused question
   at a time ... never two independent decisions").

   On Copilot, the actor read `vela-plan-review` with `cat` and asked inline from it. It never loaded `vela-grill`
   (it did not load it in r1 either), so it batched two independent decisions into one turn. The PR #100 wording
   ("`Default` is the system solution ... asked") worked because it sits on the path the actor actually reads
   (`vela-scaffold` and `vela-builder`).

   Correct path: load `vela-grill` before the first question. A lean fix makes the hop carry the rule, for example
   in `vela-plan-review` step 4: "then `vela-grill` first (one decision per question) and resume with the answers".
   That fix stays on one host-neutral line.

Observations, not pack defects:
- The `.gitignore` gap from r1 (no trailing newline, which produced `*.pfx/.vela-runs/`) did not recur. The actor
  inserted `/.vela-runs/` above the signing block. The scaffold's `.gitignore` still ends with `*.pfx` and no
  newline, which is a Vela CLI gap to relay.
- Actor slips that don't fail any criterion: the trace has 7 rows and stops at spec-check, so it has no
  review/package/plan rows; `review.md` was not saved under `.vela-runs/`; reviewer Nit 4 (verbatim RED test names
  in the trace) was left. The Canvas Evidence section does list the RED test names.
- Copilot specifics that worked: the `vela-reviewer` custom-agent dispatch (first try this time), the Mono runner,
  the frozen-spec commit before the tests, a separate RED commit, spec-check on a real base, and the stop at the
  apply gate.

## Verdict
**fail** (grader). Checks 19/19, criteria 1-7, the models note and the known findings are all met, and mutation
killed 2/2.

**The r1 blocker is fixed.** The target solution was asked before scaffolding rather than guessed, and the
package, PROJECT.md and plan all target `ZavaSales`/`zava`.

The only unmet criterion is one question at a time: two independent decisions were bundled into a single Q1
because `vela-grill` was never loaded. The next Copilot run must re-check that the builder asks one decision per
turn, either by loading `vela-grill` or through the rule carried on the plan-review hop.
