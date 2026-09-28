---
scenario: account-update-recursion
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.4
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, `pass: true`. No failed checks. The key checks were:
- step registered as Update / account / PreOperation / Synchronous, filter `['description']`;
- no `UserService.Update|Create` in src;
- no `ctx.Depth >`;
- tests use `PluginPipeline`;
- tests re-run green: total=9, failed=0;
- no VELA diagnostics;
- no scaffold demo registered.

## Loop outcome
Commit history in `work/ZavaSales/.git`:
- c7532e7: untouched `vela init ZavaSales --prefix zava --no-integrations --no-console`.
- cd10ce0: 18 demo files removed.
- 4819d44: Canvas written.
- d3e5de2: `vela add plugin ... --message Update --filtering-attributes Description`, with the stage switched to PreOperation and the model stand-in added. The handler body is still the TODO.
- d70036c: tests AC1-AC9 added (RED).
- fe0269a: handler implemented.
- 13db12a: Canvas Operations synced to the code.
- 65f1996: Build Report written.

`vela models` and `vela plan` were skipped because there is no org; both exact commands are recorded. `vela apply` was not run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | Canvas Approach records Sync PreOperation with the reason; recursion risk recorded as a Safeguard | met | `docs/vela-builds/account-description-normalize.md:61-64` ("Sync **PreOperation** Update: the normalised value is set on `ctx.Request.Target` ... no second write, no second Update event, nothing to re-trigger ... No depth check."); `:93-94` Safeguards ("no `ctx.UserService.Update` of the same record (recursion gotcha)") |
| 2 | Step is `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)`; handler sets the value on `ctx.Request.Target`; no UserService.Update; no Depth return | met | `src/zava.Plugins/Account/Plugins/AccountDescriptionNormalize.cs:19-24` (step), `:29,41` (`target = ctx.Request.Target` ... `target.Description = normalized`); checks "step registered ...", "src must not contain UserService", "src must not contain ctx.Depth" all ok |
| 3a | `"  Hello   world  "` → `"Hello world"` on the Target | met | `tests/.../AccountDescriptionNormalizeTests.cs:27-34` AC1 |
| 3b | Already-normal value is left as is | met | Tests `:65-73` AC5 |
| 3c | null / empty → left as is, no exception | met | null: AC6 `:75-85` (stays null). Empty and whitespace-only → null: AC3 and AC4 `:45-63`. That follows the human answer "a whitespace-only Description is stored as null" and is recorded as an assumption at Canvas `:33`. |
| 3d | No extra write reached the in-memory service (`crm.GetAll("account")` empty) | met | Tests `:33` and `:72`. AC8 `:101-115` also shows one execution at depth 1 through `PluginPipeline`. |
| 3e | Test-first, RED then GREEN | met | Commit d70036c (tests) comes before fe0269a (implementation); at d3e5de2 the handler was still a TODO. Canvas `:115-117`: RED `Total: 9, Failed: 5` (AC1-4 and AC8), GREEN `Total: 9, Failed: 0`. The check re-run is green (9/9). |
| 4 | Build green; no VELA00x in authored code; `vela-code-review` PASS | met | Checks "build succeeds" and "no VELA diagnostics". Canvas `:122-127`: isolated vela-reviewer returned PASS, 0 Critical, 0 Required, 5 Nits. Review input is kept in `review/diff.txt` and `review/canvas-sync.diff`. |
| - | Human answers honoured (Update only; runs of spaces only; ZavaSales/zava) | met | Canvas decisions `:26-30`. AC9 `:117-127` shows Create does not fire. The regex `" {2,}"` is at `.cs:49`. |
| - | Stop before apply | met | Canvas `status: awaiting-apply`, `apply: pending`, Gate section `:151-161`. `vela apply` was not run. |

## Planted-violation results
Each violation was applied to a copy of the actor's project, `planted-<x>/`, and built there. Each diff is in `planted-<x>.diff`. A fresh general-purpose subagent, acting as `agents/vela-reviewer.agent.md` in read-only mode, received that diff and the Canvas.

| Violation | Build | Reviewer verdict | Severity | Expected | Result |
|-----------|-------|------------------|----------|----------|--------|
| (a) PostOperation + `ctx.UserService.Update` of the same account | 0 errors, 0 warnings (no analyzer catches it) | BLOCK | Critical (self-trigger: the step writes the column in its own FilterOn) + 3 Required | Critical | pass |
| (b) (a) + `if (ctx.Depth > 1) return;` | 0 errors, 0 warnings | BLOCK | Critical ×2: self-trigger write-back "even when a depth check stops it", and an unplanned org write. The Depth check itself was rated Required: it skips legitimate nested calls and the Canvas says "No depth check". | Critical | pass |
| (c) mutable `lastDescription` field on the plugin class | VELA011 warning at `.cs(17,24)` | BLOCK | Critical (shared instance state silently skips normalisation) + Required (VELA011) | Required | pass |

## Findings against the skills
None that block. The skills took the actor straight to the PreOperation Target-edit design, with a pipeline-level no-recursion test. The reviewer blocked all three planted violations at or above the expected severity.

1. minor, observation only (not attributed to the pack): the actor reports that the first build resolved `Vela.Testing 1.0.0` from a stale local NuGet cache. It fixed this with `dotnet restore --no-http-cache --force-evaluate`. The committed test csproj pins `Vela.Testing` 0.29.4 (`tests/zava.Plugins.Tests/zava.Plugins.Tests.csproj:18`). The cause appears to be the machine's cache, not a skill instruction. If it recurs across runs, consider a line in `vela-scaffold` on verifying the resolved Vela.* versions after restore.
2. minor: in planted (b), the reviewer rated the `ctx.Depth > 1` guard itself as **Required**, not Critical. The change was still blocked at Critical because of the write-back. If the checklist is meant to rate a Depth-based recursion guard Critical on its own, it could say so explicitly. This run did not show whether it would be so rated when the guard is the only change.

## Verdict
**pass.** All 15 checks passed, every success criterion is met from the artifacts, and all three planted violations were blocked. The next run should re-check that the reviewer still blocks a Depth-guarded write-back at Critical.
