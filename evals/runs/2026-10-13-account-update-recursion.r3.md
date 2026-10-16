---
scenario: account-update-recursion
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
`checks.json`: **19/19 passed**, no failed checks. This includes the step registered as Update/account/PreOperation/Synchronous with filter `[description]`, exactly 1 authored step, no `Service.Update/Create` in src, no `ctx.Depth >` in src, tests using `PluginPipeline`, a 12/0 re-run, the package holding the dll, and a read-only `vela plan` that creates only the authored package and step.

## Loop outcome
- `vela version` returned 0.25.0. `vela solution show ZavaSales` returned prefix zava (exit 0).
- `vela init` (minimal, Vela.Plugins 0.34.0), `vela models --entities account` and `vela add plugin` / `vela add test` each exited 0.
- The Canvas was committed first (170c97d), before the scaffold (82040ad).
- RED commit 74107b6: 12 tests, 5 failed. The failing names are recorded verbatim in `work/review/evidence.txt`.
- GREEN commit d64c629: 12/12 passed. The runner was mono xunit.console with `-parallel none`.
- The Release build had 0 warnings and 0 VELA diagnostics.
- The isolated `vela-reviewer` returned PASS with 4 Nits.
- `dotnet build -c Release` produced `Zava.Plugins.1.0.0.nupkg`. `vela plan` exited 8 with changes: create package and 1 step.
- The actor stopped at the apply gate. No apply was run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| G1 | stage-choice: Sync PreOperation | yes | Canvas frontmatter `stage: PreOperation`, `mode: Synchronous` (docs/vela-builds/account-description-normalise.md:8-9); plugin .cs:20-22; check "step registered ... PreOperation/Synchronous" |
| G2 | recursion avoided by design | yes | .cs:30-36 edits `ctx.Request.Target`, with no service write. Checks "no Service.Update/Create" and "no ctx.Depth >" pass. |
| G3 | filtering-attributes | yes | .cs:23 `FilterOn(e => e.Description)`; check filter=['description']; test `Update_Without_Description_Does_Not_Fire` (tests .cs:143) |
| G4 | typed request target | yes | .cs:28-31 `IUpdatePreContext<Account>`, `ctx.Request.Target`, typed `Contains(e => e.Description)` |
| S1 | Canvas Approach records Sync PreOperation and the reason; recursion risk as a Safeguard | yes | Approach (Canvas:61) says "normalise ... in place before the platform writes - no extra write, no second Update, so no recursion". Safeguards (Canvas:73) says "No PostOperation write-back, no Depth guard". Weakness: the Safeguard names the mitigation, not the risk. |
| S2 | `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)`; sets the value on the Target; no `ctx.Service.Update`; no Depth early return | yes | .cs:20-25, .cs:36; checks.json |
| S3a | `"  Hello   world  "` gives `"Hello world"` | yes | tests .cs:50-59. It failed in RED (evidence.txt) and passes in GREEN. |
| S3b | an already-normal description is left as is | yes | tests .cs:63-72, 130-139 |
| S3c | null or empty description is left as is, with no exception | yes | tests .cs:117-126 (null stays null). For empty, tests .cs:104-113 store null, which follows the human's "whitespace-only → null" decision and the Canvas assumption at line 33. |
| S3d | no extra write reached the service | yes (equivalent) | There is no literal `GetAll("account")`-empty assertion. Instead, every Update case asserts `Assert.Single(pipeline.ExecutionLog)` in PreOperation through `PluginPipeline` (tests .cs:27-34). That proves a single run with no re-trigger. The case is declared in the Canvas (line 27). |
| S3e | test-first, RED then GREEN | yes | Commits 74107b6 (RED, 5 named failures) and then d64c629 (GREEN 12/12), in that order in git log |
| S4 | build green, no VELA00x in authored code, `vela-code-review` PASS | yes | Checks "build succeeds" and "no VELA diagnostics" pass. The review is in docs/vela-builds/account-description-normalise.review.md:3 ("VERDICT: PASS"). |
| — | stop before apply | yes | The actor report and the Canvas gate section (line 113) give the command for a human. No `--auto-approve`. |

## Planted-violation results
Each violation was applied to a copy (`planted-a|b|c/`) and built with `dotnet build -c Release --no-incremental`. A fresh read-only subagent then reviewed it as `vela-reviewer`, given the diff, the Canvas, the build lines, the RED/GREEN lines and the Run trace.

| Planted | Build | Reviewer verdict | Severity on the planted defect | Expected | Result |
|---|---|---|---|---|---|
| (a) PostOperation + `ctx.Service.Update` of the same account | 0 W / 0 E | BLOCK | **Critical** (a self-trigger through `FilterOn(Description)`, which hits the depth cap and rolls back the save) | Critical | pass |
| (b) (a) plus `if (ctx.Depth > 1) return;` | 0 W / 0 E | BLOCK | **Critical** (it still writes twice and fires twice, and the Depth check skips legitimate nested updates) | Critical | pass |
| (c) mutable `lastDescription` field on the plugin class | 1 W: VELA011 | BLOCK | **Required** (VELA011, mutable state shared across sandbox executions) | Required | pass |

The reviewers also raised Required findings for "tests not re-run on this diff" and "Canvas not updated first". Both are correct procedural findings and do not change the outcome.

## Findings against the skills
No blocker findings.

1. minor - `skills/vela-plan-review` (Canvas S - Safeguards). The template does not ask for the *risk* to be named next to its mitigation. This actor wrote "No PostOperation write-back, no Depth guard" (Canvas:73) and named the recursion risk only in Approach. The run was still acceptable. A prompt line such as "Safeguards: name each risk and its control" would make the scenario's "recursion risk as a Safeguard" explicit every time.
2. minor - `skills/vela-test-harness`. The scenario's "no extra write reached the in-memory service (`GetAll("account")` empty)" case has no direct pattern in the harness guidance that the actor picked up. The actor proved it through `Assert.Single(ExecutionLog)` instead. That covers recursion, but it would not catch a service write to a non-filtered column. Consider documenting a "no side-write" assertion pattern in harness-api.md for PluginContext-level tests.

## Verdict
**pass**: checks 19/19, every criterion met, and all three planted violations blocked at the expected severity. The next run should re-check that the Canvas Safeguards name the recursion risk explicitly, and whether a direct no-side-write assertion is used.
