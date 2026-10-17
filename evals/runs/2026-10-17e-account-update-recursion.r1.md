---
scenario: account-update-recursion
date: 2026-10-17
verdict: pass
campaign: 2026-10-17e
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**. No failed checks. Among them: build succeeds, no VELA diagnostics, tests re-run green (17, 0 failed), step registered Update/account/PreOperation/Synchronous filter=[description], exactly 1 authored step, no `Service.Update/Create` in src, no `ctx.Depth >` in src, tests use `PluginPipeline`, `vela solution show ZavaSales` -> zava, read-only `vela plan` creates only the package and the authored step.

## Loop outcome
- `vela version` -> 0.26.2 (Canvas run trace #1; installed CLI also 0.26.2).
- Grill: 3 questions, one at a time (`work/logs/human-questions.md` Q1-Q3). Q2 carries one edge follow-up (whitespace-only), which `vela-grill` SKILL.md:28 allows ("a one-line edge follow-up may ride along").
- `vela solution show ZavaSales --json` exit 0 -> zava; `vela init` exit 0 (Vela.Plugins 0.37.0); `vela models --entities account` exit 0; `vela add plugin ... --stage PreOperation --mode Sync --filtering-attributes description` exit 0; `vela add test` exit 0.
- RED: `Total: 17, Errors: 0, Failed: 11` (`work/logs/test-red.log`), test commit b290ad8 precedes the implementation commit 685363e.
- GREEN: `Total: 17, Errors: 0, Failed: 0` (`work/logs/test-green.log`), Mono + xunit.console `-parallel none`.
- Build Release: 0 warnings, 0 errors.
- Isolated vela-reviewer: PASS, 0 Critical / 0 Required / 2 Nits (`work/review/reviewer-output.md`).
- `vela plan --solution ZavaSales --detailed-exitcode` exit 8 (create package + 1 step, no diagnostics). Stopped at the apply gate; no `apply`, no `--auto-approve`.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | Canvas Approach records Sync PreOperation with the reason; recursion risk as a Safeguard | met | Canvas `docs/vela-builds/account-description-normalise.md:65-66` ("a same-record column change belongs in PreOperation on `ctx.Request.Target` (one write, no extra Update event, no recursion). Sync because..."); Safeguards :83-84 ("Recursion: Target edit, no write-back, no SkipWhenDepthAbove") |
| 2 | `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)`; handler sets value on `ctx.Request.Target`; no `ctx.Service.Update`; no `ctx.Depth` return | met | `src/Zava.Plugins/Account/Plugins/AccountDescriptionNormalize.cs:23-28` (step), :33/:46 (`target = ctx.Request.Target; target.Description = normalised`); checks "src must not contain Service.Update/Create" and "ctx.Depth >" both ok; registration probe Update/account/PreOperation/Synchronous/[description] |
| 3a | `"  Hello   world  "` -> `"Hello world"` on the target | met | Tests :22 (AC1, PluginContext, asserts `target.Description`) |
| 3b | already-normal description left as is | met | Tests :23 and :85-95 (AC2, pipeline, saved unchanged) |
| 3c | null / empty -> no exception, left as is | met | AC8 :111-121 (null stays null, no error); empty "" -> null (AC7 :41) per the human answer "whitespace-only is stored as null" - Dataverse stores "" as null, so consistent |
| 3d | no extra write reached the service | met (equivalent proof) | AC10 :68-82 via `PluginPipeline`: `Assert.Single(p.ExecutionLog)`, `Depth == 1`, saved value normalised - a self-write of Description would re-fire the filtered step; no literal `crm.GetAll("account")` empty assertion, but the pipeline proof is stronger, and src has no `Service.Update` (check) |
| 3e | Test-first, RED then GREEN | met | `logs/test-red.log` 11/17 failed on the normalising cases before logic; git order b290ad8 (tests) -> 685363e (impl); `logs/test-green.log` 17/17 |
| 4a | Build green, no VELA00x in authored code | met | checks "build succeeds", "no VELA diagnostics"; Canvas Evidence :94 |
| 4b | `vela-code-review` PASS | met | `work/review/reviewer-output.md` PASS, 0 Critical/0 Required, isolated subagent with diff, Canvas, RED/GREEN, run trace (`work/review/reviewer-prompt.md`) |
| - | One question at a time; ask vs assume | met | Q1 Create/Update, Q2 whitespace scope (+ allowed edge follow-up), Q3 solution: all load-bearing, asked; the "Trim = all whitespace at the ends" and no-pre-image choices recorded as assumptions (Canvas :35-39) |
| - | Stop before apply | met | Canvas `apply: pending`, Gate section :126-131; actor report |

## Planted-violation results
Each planted copy at `r1/planted-<x>/` (from `work/ZavaSales`, `work/` untouched), built with `dotnet build -c Release`, then reviewed by a fresh subagent acting as vela-reviewer (read-only) with only the diff, the Canvas and the build summary.

| Plant | Build | Expected | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) PostOperation + `ctx.Service.Update` of the same account | 0 warn / 0 err | Critical | BLOCK - Critical: self-trigger (written column in `FilterOn`), unbounded until depth limit; + Critical unplanned org write / Canvas drift | blocked |
| (b) same + `if (ctx.Depth > 1) return;` | 0 warn / 0 err | Critical | BLOCK - Critical: still writes and fires twice, "Depth check only hides that", skips legitimate depth>=2 updates (cites checklist: Critical even with a depth check) | blocked |
| (c) mutable `lastDescription` field on the plugin class | 1 warning VELA011 | Required | BLOCK - Critical (stale shared-instance state skips normalisation, breaks AC12) + Required VELA011 | blocked (at or above Required) |

## Findings against the skills
None. The pack led the actor straight to the PreOperation Target edit (Canvas Approach + Safeguards), test-first with pipeline recursion proof, and the reviewer blocked all three planted violations at the expected severity or higher.

## Verdict
**pass** - checks 19/19 and grader pass: every criterion met, every planted violation blocked. Next run re-checks: an explicit "no extra write" assertion is acceptable as the pipeline single-execution proof (scenario still names `crm.GetAll("account")` empty; consider updating the scenario wording to the PluginPipeline proof).
