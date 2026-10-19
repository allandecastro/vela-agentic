---
scenario: account-update-recursion
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 1/3
checks: pass
grader: pass
vela_cli: 0.27.3
framework: 0.40.0
model: claude-opus-5-5
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, `pass: true`. No failed checks. Highlights: step registered Update ·
account · PreOperation · Synchronous · filter `[description]`; exactly 1 authored step; `src` contains no
`Service.Update/Create` and no `ctx.Depth >`; tests use `PluginPipeline`; build green, no VELA
diagnostics; tests re-run green (11/11); read-only `vela plan` creates only package + the authored step.

## Loop outcome
- Grill: 3 questions to the human (`work/logs/human-questions.md`) - Update only; space runs only and
  whitespace-only -> null; solution ZavaSales.
- `vela solution show ZavaSales` exit 0 (`zava`) -> `vela init` exit 0 -> `vela models --entities account` exit 0
  -> `vela add plugin ... --stage PreOperation --mode Sync --filtering-attributes description` exit 0 ->
  `vela add test` exit 0.
- RED: mono xunit.console `-parallel none`, `Total: 11, Failed: 6` exit 1 (C1, C3, C4, C5, C6, C10).
- GREEN: `Total: 11, Failed: 0` exit 0 (and on the final Release build, `logs/test-final.log`).
- `dotnet build -c Release`: 0 Warning(s), 0 Error(s), 0 VELA00x (`logs/build-release.log:12-13`).
- spec-check exit 0; isolated `vela-reviewer` PASS (0 Critical / 0 Required / 4 Nits).
- `vela plan --solution ZavaSales --detailed-exitcode` exit 8 (changes: create package + 1 step). Stopped
  at the apply gate (`status: awaiting-apply`), no `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | Canvas Approach records Sync PreOperation with the reason; recursion risk as a Safeguard | met | `docs/vela-builds/account-description-normalise.md:69-72` ("Update · PreOperation · Sync, editing `ctx.Request.Target.Description`: the normalised value is part of the triggering write - no second Update, nothing re-fires ... no `Depth` / `SkipWhenDepthAbove` guard"); Safeguards `:97-98` ("Recursion gotcha avoided by design (Target edit, not a PostOperation self-Update)") |
| 2 | Step `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)`; handler sets value on `ctx.Request.Target`; no `ctx.Service.Update`; no `ctx.Depth` early return | met | `src/Zava.Plugins/Account/Plugins/AccountDescriptionNormalise.cs:21-26` (registration), `:31,41` (`target = ctx.Request.Target; target.Description = normalised`); checks "src must not contain Service.Update/Create", "no ctx.Depth >", "step registered ... PreOperation/Synchronous filter=['description']" all ok |
| 3a | Test-first RED then green | met | git log: `2463be6 test: RED harness tests` before `1f6af87 feat: normalise`; `logs/test-red.log:63` `Failed: 6` (each Actual = raw input); `logs/test-green.log:7` `Failed: 0` |
| 3b | `"  Hello   world  "` -> `"Hello world"` | met | C1 `AccountDescriptionNormaliseTests.cs:33-40` (`"  Hello   big  world  "` -> `"Hello big world"`, same shape), plus C10 `"  a   b  "` -> `"a b"` |
| 3c | Already-normal description left as is | met | C2 `:44-53` |
| 3d | null / empty -> left as is, no exception | met | C7 null stays null and the handler ran (`:101-110`); C6 `''` -> null (`:90-97`) - the human answer (whitespace-only -> null) makes null the "as is" value; no exception in either |
| 3e | No extra write reached the service | met | Proven through `PluginPipeline` instead of `crm.GetAll` empty: C10 `:140-150` asserts `Assert.Single(p.ExecutionLog)` and `run.Depth == 1` - a write-back would add a second, depth-2 execution. Confirmed by the planted runs: (a)/(b) turn C10 red (`planted-a/test.log`, `planted-b/test.log`) |
| 4a | Build green, no VELA00x in authored code | met | check "build succeeds", "no VELA diagnostics"; `logs/build-release.log:12-13` |
| 4b | `vela-code-review` PASS | met | `docs/vela-builds/account-description-normalise.review.md` (isolated subagent, `VERDICT: PASS`, 0 Critical / 0 Required) |
| - | Asked vs assumed (human answers) | met | All three load-bearing decisions asked (`logs/human-questions.md` Q1-Q3), matching the evaluator answers; the rest recorded as assumptions (Canvas `:47-53`) |
| - | One question at a time | met, with a nit | Q1 and Q3 single; Q2 bundles an "Edge follow-up" (whitespace-only -> null?) with the character-set question (`human-questions.md:13`). Same topic, actor-side, not blocking |
| - | Stop before apply | met | Build Report `status: awaiting-apply`, `apply: pending`; gate command given, never run |

## Planted-violation check
Each planted copy lives at `r1/planted-<x>/` (diff in `r1/planted-<x>.diff`), built with
`dotnet build -c Release`, harness re-run, then a fresh read-only subagent acting as `vela-reviewer` got
only the diff text and the Canvas.

| # | Violation | Build / harness on the planted copy | Reviewer verdict (fresh subagent) | Expected | Result |
|---|---|---|---|---|---|
| a | `.PreOperation()` -> `.PostOperation()` + `ctx.Service.Update(new Account { Id = ctx.PrimaryEntityId, Description = normalised })` | build 0 warnings / 0 errors (no analyzer catches it); harness `Total: 11, Failed: 2` (Fires_On_Update_PreOperation, C10 Update_Normalises_Once_Without_Retriggering) | **BLOCK** - Critical `:41` "saves the account a second time from inside its own step ... filtered on `Description` ... fires again at depth 2" (+ Required stage vs Canvas, Nit stale comment) | Critical | **pass** |
| b | (a) "fixed" with `if (ctx.Depth > 1) return;` | build 0 warnings / 0 errors; harness `Failed: 2` (same two) | **BLOCK** - Critical `:46` "writes to its own record from PostOperation ... The new `if (ctx.Depth > 1) return;` only hides this ... A legitimate Description update from another plugin, a flow or a workflow already runs at depth 2 or more, so it is skipped" (+ 2 Required: stage, Canvas drift) | Critical | **pass** |
| c | `private string lastDescription;` written in the handler | build `warning VELA011: 'lastDescription' is a writable field` (1 warning, 0 errors); harness 11/11 green | **BLOCK** - Required `:19/:40` "mutable instance field ... review-checklist (Runtime: mutable plugin fields - **Required** [VELA011])" | Required | **pass** |

All three planted violations blocked at the expected severity. Note: the reviewer for (c) worked from the
diff only and hedged that "a clean build with this field in place would mean the analyzer isn't covering
it" - the real build does raise VELA011, so analyzer and review agree.

## Findings against the skills
No blocker against the skill pack. The skills drove the right design (PreOperation Target edit, no
write-back, no depth guard), and the review checklist rates every planted violation correctly.

1. minor (eval scenario, not a skill) - `evals/scenarios/account-update-recursion.md` success criterion 3
   says "no extra write reached the in-memory service (`crm.GetAll("account")` empty)". This only applies
   to a unit harness with an empty service. The pack's `harness-api.md` steers the agent to `PluginPipeline`
   with a seeded account, where `GetAll("account")` always holds the seeded row. The actor showed "no
   extra write" with `Assert.Single(p.ExecutionLog)` + `run.Depth == 1` (C10), and the planted runs
   (a)/(b) confirm that test catches a write-back. Reword the criterion to "no second execution / no
   depth-2 run (`PluginPipeline.ExecutionLog`)" so later graders don't argue over it.
2. minor (observation, actor-side) - `work/logs/human-questions.md:13` Q2 attaches an "Edge follow-up" to the
   character-set question, which bends `skills/vela-grill/SKILL.md:51` "One at a time, each load-bearing".
   It is the same topic and was answered in one go. The skill text is clear, so this is not a pack defect.
   Recorded so later runs can watch for it.

## Verdict
**pass** - checks 19/19 and grader pass. Every success criterion is met from the artifacts, and all three
planted violations are blocked at the expected severity (a, b Critical; c Required). The next run must
re-check that C10, or an equivalent single-execution assertion, stays among the declared cases. It is the
only test that turns red on a PostOperation write-back: C1-C9 stay green in planted (a)/(b).
