---
scenario: account-multi-step
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **21/21 passed**, no failed check (build green, no VELA diagnostics, 16 tests re-run green,
Create + Update steps both PreOperation/Synchronous filter `name`, exactly 2 authored steps, `HandleUpdate`
and `OnExecute` both present, `PluginPipeline` used, no `Service.Update/Create` write-back, package holds the
dll, read-only `vela plan` runs and creates only the authored steps).

## Loop outcome
- `vela version` -> 0.25.0; `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- Canvas committed first (377f7a2), with `reuse: add-step:AccountDefaultDescription`.
- `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Name` (exit 0), giving the `HandleUpdate` step.
- RED (67d4513): Mono xunit `-parallel none`, exit 1, `Total: 15, Failed: 4` (AC1, AC2, AC6, AC9 failed on the uppercase assertion) (`work/logs/red.txt`).
- GREEN (1b73410): `Total: 16, Errors: 0, Failed: 0` (`work/logs/green-2.txt`); `dotnet build --no-incremental` gave 0 warnings, 0 errors and 0 `VELA0` lines (`work/logs/verify-build-2.txt`).
- Two isolated `vela-reviewer` passes, both PASS with Nits only (`work/review/review-1.md`, `review-2.md`).
- Release package built (sha256 recorded); `vela plan` exit 8 (changes: package + 2 steps, `diagnostics: []`).
- Stopped at the apply gate; `vela apply` was not run.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse via `vela add step`, not a new plugin or a hand-written step | met | Canvas `docs/vela-builds/account-number-uppercase.md:87,113` (command + "Added step Update (HandleUpdate)"); check "exactly 2 authored step(s)" |
| Generated handler `HandleUpdate` kept; `OnExecute` kept for Create | met | `AccountDefaultDescription.cs:20,28,31,54`; checks "src contains /HandleUpdate/", "/OnExecute/" |
| Placeholder replaced with the gating column `e => e.Name` | met | `AccountDefaultDescription.cs:25`. The actor passed `--filtering-attributes Name`, so no `e.Id /* TODO */` placeholder was ever generated (RED commit 67d4513 already has `FilterOn(e => e.Name)`). The rubric accepts this ("seeing the error is not required"). |
| Stage PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:23,39,50`; check "step registered: Update 'account' PreOperation/Synchronous filter=['name']"; no `Service.Update` |
| Harness: every test states its trigger; existing Create tests updated and green | met | `AccountDefaultDescriptionTests.cs:14` `.OnCreate()`; `AccountNumberUppercaseTests.cs:20` `.OnUpdate()`; the other tests use `PluginPipeline`, which dispatches by write. No `.Stage()` is chained, which is correct per `harness-api.md:66-70` ("`.OnCreate()` / `.OnUpdate()` resolves the single step registered on that message"). |
| SC1: Canvas records `reuse: add-step:AccountDefaultDescription` and the Update step | met | Canvas frontmatter lines 9-10 |
| SC2: placeholder replaced; build green, no VELA00x in authored code | met | `logs/verify-build-2.txt` (0 Warning(s), 0 Error(s), 0 VELA0); checks "build succeeds", "no VELA diagnostics" |
| SC3: RED then green; name changed -> uppercased; name unchanged -> not run; Create cases pass | met | RED in `logs/red.txt` (Failed: 4 on AC1/2/6/9); GREEN in `logs/green-2.txt` (16/16). AC1 covers a name change. AC10 (Name not sent) asserts an empty `ExecutionLog`. AC8 (same Name resent) asserts the handler ran but changed nothing, which matches the human answer "sent with a different value". The 3 Create tests and AC11 are green. A null account number stays null (AC4, AC7). |
| SC4: `vela-code-review` PASS | met | `review/review-1.md`, `review/review-2.md`: both isolated reviewers PASS, 0 Critical / 0 Required |
| Stop before apply | met | Canvas `status: awaiting-apply`, `apply: pending`; the Gate section is left for a human |

## Planted-violation results
None. This scenario has no "Planted-violation check" section.

## Findings against the skills
No blocker.
1. minor (scenario rubric, not a skill): `evals/scenarios/account-multi-step.md` asks that "every test states its trigger (`.OnCreate()` / `.OnUpdate()` + stage)". The pack's verified harness rule (`skills/vela-test-harness/references/harness-api.md:66-69`) says the message alone resolves a single step per message, and to add `.Stage(...)` only when several steps match. The actor followed the pack. Align the rubric wording ("+ stage when ambiguous").
2. minor (scenario coverage, not a skill): the VELA001 placeholder gotcha was not exercised. `vela add step ... --filtering-attributes Name` generates the real column directly. This is valid, but this run gives no evidence for the placeholder path.

## Verdict
pass. Checks 21/21, and every criterion is met from the artifacts. The next run should re-check that the actor
still uses `.OnCreate()`/`.OnUpdate()` on Execute tests of a multi-step plugin.
