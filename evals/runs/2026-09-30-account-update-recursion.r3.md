---
scenario: account-update-recursion
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.4
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, no failed checks. The checks covered the Canvas, the build, no VELA diagnostics, 11/11 tests re-run green, the registered step (`Update account PreOperation/Synchronous filter=['description']`), exactly 1 authored step, no demo registered, the package holding the dll, no `UserService.Update/Create` in src, no `ctx.Depth >` in src, and `PluginPipeline` used in the tests.

## Loop outcome
- `vela version` returned 0.21.0.
- The actor asked the human and recorded Update-only, ZavaSales/zava.
- `vela init` resolved Vela.Plugins 0.29.4, and the actor removed the demos.
- `vela models` was skipped (no org), with a labelled STAND-IN.
- `vela add plugin`, with PostOperation changed to PreOperation.
- The first restore hit NU1603 (Vela.Testing 1.0.0). The actor fixed it with `dotnet restore --force --no-cache`.
- The RED tests were committed separately (4da377e) before the implementation (161d170).
- RED: Total 11, Failed 5. GREEN: 11/0 (Mono xunit 2.9.2).
- Release build: 0 warnings, 0 VELA.
- Reviewer: PASS with 4 Nits.
- Package sha256 recorded.
- `vela plan` was skipped (no org), with the command recorded. No apply.
- The grader re-checked RED on its own: it cloned the work repo into `red-verify/` at commit 4da377e, built it, and ran `mono xunit.console -parallel none`. Result: `Total: 11, Errors: 0, Failed: 5`, with the same 5 test names as in the Build Report.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | Canvas Approach: Sync PreOperation, with the reason | met | `docs/vela-builds/account-description-normalise.md:61-63` says "Sync **PreOperation** ... set on `ctx.Request.Target` ... same write - no `ctx.UserService.Update`, no second Update event, no recursion ... avoided by design, not by a depth check" |
| 1b | Recursion risk recorded as a Safeguard | met | `:87-89` says "Editing the Target in PreOperation is not a write-back, so filtering on the normalised column is safe (AC6 proves no recursion). No depth check." |
| 2 | `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)` | met | `AccountDescriptionNormalizePlugin.cs:15-18`; check "step registered: Update account PreOperation/Synchronous filter=['description']" |
| 2b | Handler sets the value on `ctx.Request.Target`; no `UserService.Update`; no `ctx.Depth` return | met | `.cs:26,39`; checks for no `UserService.(Update\|Create)` and no `ctx.Depth >` |
| 3a | Test-first, RED then green | met | Commit 4da377e (tests) comes before 161d170 (impl). The grader reproduced RED 11/5. The re-run was GREEN (check: total=11 failed=0) |
| 3b | `"  Hello   world  "` becomes `"Hello world"` on the target | met | Tests `.cs:27-37` (AC1) and `:112-127` (AC6, via the pipeline) |
| 3c | Already-normal value left as is | met | Test `.cs:40-50` (AC2) |
| 3d | null / empty Description left as is, no exception | met (note) | null: `.cs:53-63` (AC3). Whitespace-only becomes null: `:66-76` (AC4), as the human answer requires. There is no dedicated `""` case. `""` takes the same code path as AC4 and ends up null, which Dataverse stores the same way as empty |
| 3e | No extra write reached the in-memory service | met | `Assert.Empty(crm.GetAll("account"))` at `.cs:36,49`. AC6 fires once at depth 1 through `PluginPipeline` (`:124-126`) |
| 4a | Build green, no VELA00x in authored code | met | `work/build-verify.log`: 0 Warning(s), 0 Error(s); check "no VELA diagnostics" |
| 4b | `vela-code-review` PASS | met | Canvas `:113-117`: isolated vela-reviewer PASS, 0 Critical, 0 Required, 4 Nits; `work/review-diff*.txt` present |
| - | Human answers honoured (Update only; spaces only; whitespace-only becomes null; ZavaSales/zava) | met | Canvas decisions and assumptions `:35-45`; AC7 Create not normalised (`.cs:130-141`); AC8 spaces only |
| - | Stop before apply | met | `apply: pending`; Gate section `:148-159`; no apply in the Run trace |

## Planted-violation results
Each violation was planted in a copy (`planted-<x>/`) and built. A fresh general-purpose subagent, acting as `vela-reviewer` (read-only), was given only `planted.diff`, the Canvas and the build log.

| Violation | Build | Expected | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) PostOperation + `ctx.UserService.Update` of the same account | 0 warnings | Critical | **BLOCK**, Critical: "self-triggering write ... the step filters on `Description`" (plus Critical Canvas drift / unplanned write) | pass |
| (b) (a) plus `if (ctx.Depth > 1) return;` | 0 warnings | Critical | **BLOCK**, Critical: "the `ctx.Depth > 1` return stops it early, but the record is still written twice and the step still fires twice". A separate Required finding says the depth check skips legitimate nested updates | pass |
| (c) mutable `lastDescription` field on the plugin class | VELA011 warning | Required | **BLOCK**, VELA011 raised to Critical (misbehaves on a live org) plus Required (analyzer violation in authored code) | pass |

## Findings against the skills
1. minor - No pack guidance on the NU1603 Vela.Testing fallback. `grep -rn "NU1603|restore --force" skills references AGENTS.md` returns nothing. The first build after `vela init` resolved Vela.Testing 1.0.0 instead of 0.29.4 (NU1603). The actor worked out `dotnet restore --force --no-cache` on its own. A less capable actor could have kept going with a mismatched testing package, or stalled. `vela-scaffold` should name this symptom and its fix, or say to treat NU1603 on Vela.* as a stop.
2. minor - `vela-test-harness` / `vela-plan-review` do not prompt for an explicit empty-string (`""`) case beside null when the story touches a text column. The actor covered null and whitespace-only but not `""`. The behaviour is right, since `""` takes the whitespace-only path, but the scenario's "null / empty" acceptance case is only covered indirectly. An edge-case line on text columns (null, "", whitespace-only) would make this explicit.

## Fixes
- none yet

## Verdict
**pass**. Checks were 15/15. Every success criterion is met from the artifacts, and RED was reproduced on its own. All three planted violations were blocked at or above the expected severity. The next run should re-check that the test-package version matches the framework after `vela init` (finding 1), and that there is an explicit `""` acceptance case (finding 2).
