---
scenario: account-default-description
date: 2026-11-22
verdict: fail
campaign: 2026-11-22
run: 3/3
checks: pass
grader: fail
model: claude-sonnet-5.5
vela_cli: 0.31.0
framework: 0.43.0
runner: "copilot-cli actor + separate grader"
mutation: "2/2, 0 missing test(s)"
---

The actor was GitHub Copilot CLI 1.0.114 (model `claude-sonnet-5.5`, `--agent vela-builder`). The pack was installed
as its Copilot surface (`.github/skills`, `.github/agents`, `.github/copilot-instructions.md`) after PR #100 ("Default
is not a target solution") and PR #101 ("(one decision per question)" on `vela-plan-review`'s hop to `vela-grill`).
The installed `vela-grill` and `vela-plan-review` SKILL.md files are byte-identical to the repo (`diff` clean).

Run trace: `r3/copilot-session.md`, `r3/copilot-turn1.md` (the question), `r3/copilot-turn2.md`,
`work/ZavaSales/.vela-runs/account-default-description/trace.md`, and the work repo's git log.

Environment note (not graded): Copilot skipped the repo hooks because the folder was untrusted
(`copilot-turn1.err`, `copilot-turn2.err`). The eval shim blocked org writes. The actor never tried `vela apply`.

## Check summary
`checks.json`: **19/19 passed**, with no failed check:
- build green, 0 VELA diagnostics, 7 tests green
- step Create/account/PreOperation/Synchronous with filter [name]; exactly 1 authored step; no demo
- no `Service.Update/Create` and no `ColumnSet(true)` in src
- package `artifacts/zava_Zava.Plugins.1.0.0.nupkg`; `ZavaSales` → `zava`; the read-only plan creates only the
  package and the AccountPlugin step

## Loop outcome
- intake: `using-vela` was loaded through the skill tool (session l.57-64) and `vela version` returned `vela 0.31.0`
  (l.~80). It read `vela-plan-review` and `vela-scaffold` with `cat` (l.106-351). That read includes the PR #101 hop
  at l.224 ("then `vela-grill` first (one decision per question)") and the PR #100 rationalization at l.327-328.
- challenge: unlike r1 and r2, it **loaded `vela-grill`** (`cat vela-grill/SKILL.md | head -80`, l.377-440). That
  read includes l.411-416: "Ask **one focused question at a time** ... a one-line edge follow-up may ride along,
  never two independent decisions".
- It then wrote a single `## Q1` (l.520-527) holding the target-solution question plus a line labelled "Edge, one
  line:" about whitespace. It ended the turn with "QUESTION FOR THE HUMAN: Using vela-grill, I need two answers
  before I scaffold." (`copilot-turn1.md`). There was no `vela solution show Default` probe. The answer was appended
  under Q1.
- solution: `vela solution show ZavaSales --json --url <org>` exit 0 → `{"solution":"ZavaSales","publisherPrefix":"zava"}`
  (trace row 1).
- scaffold/models/add: `vela init ZavaSales --prefix Zava --publisher-prefix zava --solution ZavaSales` exit 0, then
  `vela models --entities account` exit 0 (4 files), then `vela add plugin AccountPlugin ... --stage PreOperation
  --mode Sync --filtering-attributes Name --handler OnDescriptionDefault` + `vela add test` exit 0 (trace rows 2-4).
  `PROJECT.md` reads `zava_Zava.Plugins: ZavaSales`.
- frozen spec: `4b4fd5a` (Canvas + `docs/rules/account.md`, ACC-001) was committed before the tests.
- RED: the tests ran against the scaffold TODO handler. Mono xunit `-parallel none` → `Total: 7, Errors: 0,
  Failed: 5` (l.1609, at 1m55s). The 5 failures are C1/C5, C2 ×2 and C3 ×2. C4 and C6 are "leave alone" or
  "doesn't fire" guards, so they pass.
- implement: three edits to `AccountPlugin.cs` at 2m4s, made **after** the RED run. A parallel tool call raced them
  into commit `77947c0` "Add generated account models and AccountPlugin scaffold", so there is no separate
  implementation commit ("nothing to commit", l.~1720).
- GREEN: `Total: 7, Errors: 0, Failed: 0, Skipped: 0`, build 0 warnings / 0 errors (l.1700).
- spec-check `--base 8df6603` → `spec-check: 0 failure(s)` (l.~1840).
- review: a `vela-reviewer` task subagent (l.1906) returned PASS with 4 Nits and no Critical/Required. Nit 1 was
  fixed in `2936317`, followed by a rebuild and retest (GREEN 7/0, l.2268).
- package/plan: `dotnet build -c Release` → `zava_Zava.Plugins.1.0.0.nupkg`. `vela plan -p ... --solution ZavaSales
  --detailed-exitcode --out .vela-runs/.../plan.json` → exit 8, creating the package and the step.
- gate: Build Report `a4439bd`, `status: awaiting-apply`, `apply: pending`. The run stopped and `vela apply` was not
  run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `vela init` + `vela add plugin` exit 0 per vela-scaffold; tests in the scaffold's `.Tests` project | met | trace rows 2 and 4 (exit 0); `tests/Zava.Plugins.Tests/Account/Plugins/AccountPluginTests.cs`. `vela add test` targeted the scaffold's test project, which the rubric note tolerates |
| 2 | Handler per vela-plugin-authoring; no magic strings where a model exists | met | `AccountPlugin.cs:9` `EntityPluginBase<Account>`; `:16-21` `RegisterStep().OnCreate().PreOperation().Sync().FilterOn(e => e.Name)...Handle(OnDescriptionDefault)`; `:28` `ctx.Request.Target`; typed `target.Description`; `const DefaultDescription` |
| 3 | Test-first: RED seen and then green, with the OS-correct runner and the real harness API | met | session l.1609 RED `Failed: 5` at 1m55s against the TODO stub (l.1155-1162). Edits came at 2m4s, then GREEN at l.1700. Mono `xunit.console.exe -parallel none`; `PluginPipeline.Empty().Register<AccountPlugin>()`. Git history is muddied: RED commit `37bd654` holds only the tests (it does not compile alone), and the implementation sits in the "scaffold" commit `77947c0`. The session, not git, proves the order |
| 4 | `dotnet build` green, no VELA00x | met | l.1700 and l.2264 "0 Warning(s) 0 Error(s)"; checks "build succeeds", "no VELA diagnostics" |
| 5 | null / whitespace → defaulted; non-empty → untouched | met | tests: C1 (not sent), C2 (`""`, null), C3 (`"   "`, `"\t \r\n"`), C4 (`"  Key customer "` preserved), C6 (Update doesn't fire); checks total=7 failed=0; both mutants killed |
| 6 | PreOperation; default set on `ctx.Request.Target`; no `ctx.Service.Update` | met | `AccountPlugin.cs:17,28-35`; checks "step registered ... PreOperation/Synchronous" and "src must not contain Service.Update/Create" |
| 7 | Canvas (acceptance cases) + Build Report (harness pass, analyzers clean, cases checklist) per template | met | `docs/features/account-default-description/README.md`: `acceptance_cases` C1-C6, `harness: pass`, `analyzers: clean`, `review: pass`, `plan_preview: changes` with `plan_command`, the Evidence checklist (l.76), Gate, and Rollback. The trace has all 10 rows this time (r2 stopped at spec-check). Minor: `review.md` was not saved under `.vela-runs/` (an actor slip, as in r2) |
| - | Models note: `account` generated with `vela models`, no stand-in; Create `FilterOn` | met | trace row 3; `src/Zava.Shared/Models/Generated/Account.cs` tracked; `FilterOn(e => e.Name)` |
| - | Known findings closed (harness API, Mono runner, authoring surface, Create FilterOn, target.Id) do not recur | met | the correct surfaces were used the first time, with no rediscovery |
| - | Ask vs assume (r1 blocker: `Default` guessed) | **met: the PR #100 fix held, for the second run in a row** | The target solution was asked before scaffolding, with no `Default` probe; `copilot-turn1.md` says "It should not be `Default`". "Empty" was also asked rather than assumed. Canvas `decisions:` records both answers `{by: human}`; platform facts are under `assumptions:` |
| - | One question at a time (r2 finding, PR #101) | **not met: the PR #101 fix did not hold** | `logs/human-questions.md` has a single `## Q1` that holds two independent decisions: the target solution, and "Edge, one line: should a Description that is only whitespace count as empty". The turn opens with "I need two answers". See finding 1 for why |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none were run.

## Mutation triage
`mutation.json` has 2 sites: 2 killed, 0 survived, 0 invalid (score 1.0). There is no survivor to triage.

## Findings against the skills
1. **blocker** (it fails the one-question criterion): the ride-along carve-out in `vela-grill` is loose enough to
   license the very bundling it forbids.

   **What the actor read.** PR #101 put the rule on the path, and the actor read it. Session l.224 shows
   `vela-plan-review` "then `vela-grill` first (one decision per question)". For the first time in this campaign it
   also loaded `vela-grill` itself (l.377), including SKILL.md:29-33 (session l.411-416): "Ask **one focused question
   at a time** ... Ask every edge value that changes an acceptance case (scope, empty/malformed input) before ending;
   a one-line edge follow-up may ride along, never two independent decisions."

   **What it did.** It asked the target-solution question and attached the whitespace question as "Edge, one line:"
   (`human-questions.md` Q1, line 4). That label mirrors the carve-out's wording. The edge question is not a
   follow-up to the solution decision. It is a separate business decision, a Meaning/Data edge of the story term
   "empty", and the carve-out sentence itself names "empty/malformed input" as an edge value. Nothing in the text
   says the ride-along must belong to the **same** decision as the main question. The actor read "edge follow-up"
   as "any one-line edge question", so the bundling recurred **because of** that line, not for want of reading it.

   **Correct path.** Ask "empty" first (Meaning/Data comes before the target solution in the grill's order), and the
   solution in the next turn, or the other way round. Lean fix in `skills/vela-grill/SKILL.md:32-33`: "a one-line
   follow-up on the **same** decision may ride along; any other question, edge or not, waits for the next turn". The
   hop wording from PR #101 can stay. It did its job, because it got `vela-grill` loaded.

Observations, not pack defects:
- The `.gitignore` gap from r1 recurred. The scaffold's `.gitignore` ends in `*.pfx` with no trailing newline. The
  actor's `echo "/.vela-runs/" >> .gitignore` produced `*.pfx/.vela-runs/` in the scaffold commit `8df6603`, so
  `.vela-runs/.../diff.txt` was committed in `2936317` and untracked in `304a21a`, where it stays in history. This is
  a Vela CLI scaffold gap (no trailing newline), already noted in r2, to relay to the Vela repo. It is not a skill
  fix.
- Actor slips that don't fail any criterion:
  - A parallel tool call raced the implementation into the "scaffold" commit. The RED commit does not compile on
    its own.
  - The test file was written with a heredoc plus a python patch.
  - `review.md` was not saved under `.vela-runs/`.
  - The Canvas assumption says "a create without Name fails validation anyway". That overstates it: `name` is
    application-required, and an SDK create can omit it. The Build Report's "Assumptions taken" and the actor
    report state the residual risk correctly.
- Copilot specifics that worked:
  - `vela-grill` was actually loaded (the first time in this campaign)
  - the `vela-reviewer` task dispatch
  - the Mono runner
  - the frozen-spec commit before the tests
  - spec-check on a real base
  - a full 10-row trace
  - the stop at the apply gate

## Verdict
**fail** (grader). Checks pass 19/19, criteria 1-7, the models note, the known findings and ask-vs-assume are all
met, and mutation killed 2/2.

**PR #100 held:** the target solution was asked, not guessed, and was never `Default`. **PR #101 did not hold:**
the hop line was read and `vela-grill` was loaded, yet two independent decisions were still bundled in Q1. The
actor treated the whitespace question as the "one-line edge follow-up" that `vela-grill` allows to "ride along".

The next Copilot run must re-check one decision per turn after tightening the carve-out to "same decision only".
