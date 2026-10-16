---
scenario: account-multi-step
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 2/3
checks: pass
grader: pass
vela_cli: 0.25.0
framework: 0.34.0
model: claude-opus-5-5
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **21/21 passed**, no failed checks. These include: build green, no VELA diagnostics, 14 tests re-run green, Create and Update steps both registered PreOperation/Sync with filter `name`, exactly 2 authored steps, `HandleUpdate` and `OnExecute` both present, no `Service.Update/Create` write-back, a `PluginPipeline` test present, and a read-only `vela plan` that creates only authored steps.

## Loop outcome
- `vela version` → 0.25.0. `vela solution show ZavaSales` → exit 0 (prefix `zava`).
- `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Name` → exit 0, "Added step Update (HandleUpdate)" (commit ebbf9c9).
- `vela add test ... --message Update` → exit 2 (file exists). The actor did not force it and wrote the tests by hand in a new class, using the pipeline shape.
- RED (commit 52d0ce9, empty handler): mono xunit.console, `Total: 14, Failed: 3`. The failures were for the right reason: the value stayed lowercase.
- GREEN: `Total: 14, Failed: 0`. Release build: 0 warnings, 0 errors.
- Isolated vela-reviewer: PASS, 0 Critical/Required, 5 Nits.
- `dotnet build -c Release` built the nupkg (dll inside, sha256 recorded). `vela plan` → exit 8 (changes), 0 diagnostics. The actor stopped at the apply gate; `apply` was not run.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse via `vela add step`, not a new plugin or a hand-written step | met | Build Report run trace row 3. Commit ebbf9c9 shows the generated step + `HandleUpdate` stub. Check "exactly 2 authored step(s)". |
| Generated handler `HandleUpdate` kept; `OnExecute` kept | met | `src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs:27,30` (HandleUpdate) and `:19,53` (OnExecute). Checks "HandleUpdate"/"OnExecute". |
| Placeholder replaced with `e => e.Name` | met | `AccountDefaultDescription.cs:24`. The actor passed `--filtering-attributes Name`, so the CLI emitted `FilterOn(e => e.Name)` directly (ebbf9c9) and no `e.Id /* TODO */` placeholder ever existed. That still satisfies the intent: the step is gated on the correct column and the build is VELA-clean. |
| Stage PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:22,38,49`. There is no service write (check "src must not contain Service.Update"). |
| Harness: multi-step, every test states its trigger; Create tests updated and green | met | `AccountDefaultDescriptionTests.cs:14` adds `.OnCreate()` (the diff against baseline c2a9e95). `AccountNumberUppercaseTests.cs:25` uses `.OnUpdate()`. Pipeline tests dispatch by message. No `.Stage()` is chained, which is correct per `skills/vela-test-harness/references/harness-api.md:66-70`: stage is only needed when several steps share a message. 14/14 green (`logs/green.txt`). |
| SC1 Canvas records `reuse: add-step:AccountDefaultDescription` + Update step | met | `docs/vela-builds/account-number-uppercase.md` front-matter `reuse:` and `steps:` (Update, PreOperation, filter Name, pre-image). |
| SC2 Placeholder replaced; build green, no VELA00x in authored code | met | Checks "build succeeds" and "no VELA diagnostics". `logs/build-release.txt` shows 0 warnings. |
| SC3 RED then green: name changed → uppercased; name unchanged/filter → not run; Create still passes | met | `logs/red.txt` has 3 FAIL (AC1, AC2, AC8). `logs/green.txt` has 14/14. Name not sent → `Assert.Empty(p.ExecutionLog)` (`AccountNumberUppercaseTests.cs:131-138`). Same name → no change (`:107-115`). Null number stays null (`:80-85`). The 3 Create regressions pass. |
| SC4 `vela-code-review` PASS | met | `review/reviewer-verdict.md` records an isolated subagent, PASS, 0 Critical/Required. |
| Human answers honoured ("Name changes" = sent with a different value; null number stays null) | met | Canvas assumption 1 (HasChanged against the pre-image) and AC4. |

## Planted-violation results
None. The scenario defines no "Planted-violation check" section.

## Findings against the skills
1. minor: `skills/vela-test-harness/SKILL.md:53` says "Add a test class with `vela add test <Name> --kind plugin --entity <Entity> --message <M>`". It gives no path for adding a second step to a plugin that already has a test class. In this run, `vela add test AccountDefaultDescription --message Update` exited 2 ("File already exists ... Use --force"), and the actor had to improvise a hand-written class. The skill should say what to do in the add-step case: keep the existing file and do not `--force`; write the new step's tests in a new class (or name the CLI option, if one exists). Per the house rule, this should not be worked around in the skill if it is a CLI gap. It should be flagged to the user as a possible Vela gap (`vela add test` has no way to target a new step or test-class name for an existing plugin).
2. minor: there is stale rubric text in `evals/scenarios/account-multi-step.md`, in "What the skills must get right".
   - The harness bullet requires "`.OnCreate()` / `.OnUpdate()` + stage". The pack (`harness-api.md:66-70`, `vela-test-harness/SKILL.md:71-72`) correctly says to add `.Stage(...)` only when several steps share a message.
   - The placeholder bullet assumes `vela add step` always emits `FilterOn(e => e.Id /* TODO */)`. With `--filtering-attributes Name`, it emits the real column.
   - The scenario should be aligned so that a future grader does not fail a correct run.

## Fixes
- None yet (grader is read-only on the pack).

## Verdict
**pass**: checks 21/21 and every criterion is met. The quality of the self-run is good: reuse via add-step, both generated handler names kept, PreOperation Target edit with a pre-image `HasChanged` guard and write-only-if-different, 11 acceptance cases plus 3 Create regressions, RED seen, an isolated review, and the plan run on the final package. Next run should re-check how the actor handles the `vela add test` collision (finding 1).
