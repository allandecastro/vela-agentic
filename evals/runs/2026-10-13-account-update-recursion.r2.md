---
scenario: account-update-recursion
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, no failed checks. This includes: the step is registered as Update `account`
PreOperation/Synchronous with filter `['description']`; there is exactly 1 authored step; src has no `Service.Update/Create`;
src has no `ctx.Depth >`; the tests use `PluginPipeline`; the build is green with no VELA diagnostics; 15 tests re-run green;
the package holds the dll; `vela plan` (read-only) runs and creates only the authored steps.

## Loop outcome
The actor ran these steps, all logged in the Run trace (`docs/vela-builds/account-description-normalise.md:121-136`):
1. `vela version`: 0.25.0.
2. `vela solution show ZavaSales`: prefix `zava`.
3. `vela init`, then `vela models --entities account`, `vela add plugin` (Update/PreOperation/Sync/filter description) and `vela add test`. All exited 0.
4. RED run with Mono xunit `-parallel none`: 8 of 15 failed, exit 1.
5. GREEN run with the same runner: 15/15.
6. `dotnet build -c Release`: 0 warnings, 0 VELA.
7. Self-review (fallback): the subagent limit was hit, and the review is labelled as a self-review. Verdict PASS, with 4 Nits.
8. Package build (`artifacts/Zava.Plugins.1.0.0.nupkg`, sha256 recorded), then `vela plan`: exit 8, creates the package and 1 step, 0 diagnostics.
9. The actor stopped at the apply gate. It never ran `vela apply`.

The git history in `work/ZavaSales` follows the order Canvas (fe17a0e), then models, scaffold, RED tests (152986d), and implementation (8c26c75).

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | Canvas Approach records Sync PreOperation with its reason, and recursion is a Safeguard | met | Canvas `:60-64` says the value is "set on ctx.Request.Target before the platform writes, so it is one write, no extra Update event, and nothing re-triggers the step (no recursion by design...)". Safeguards `:80-81` say "no write-back (recursion gotcha avoided by stage choice)". |
| 2 | Step is `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)`; the handler sets `ctx.Request.Target`; no `Service.Update`; no Depth return | met | `NormaliseAccountDescription.cs:18-23` and `:28-34` (`target = ctx.Request.Target; target.Description = Normalise(...)`). Checks: step registered, no `Service.Update`, no `ctx.Depth >`. |
| 3a | `"  Hello   world  "` gives `"Hello world"` on the target | met | `NormaliseAccountDescriptionTests.cs:78` (handler Theory on the Target) and `:62-73` (pipeline saved value, single fire, depth 1). |
| 3b | An already-normal value is left as is | met | `:80`, `:96-105`, `:139-148` |
| 3c | A null or empty value is left as is, with no exception | met | `:124-135` (null stays null). `:108-121` covers empty/whitespace, which becomes null; that matches the human answer "whitespace-only stored as null". |
| 3d | No extra write reaches the in-memory service (`crm.GetAll("account")` is empty) | met | `:41` `Assert.Empty(crm.GetAll("account"))` runs in every handler-level case. The pipeline's `Assert.Single(ExecutionLog)` also proves there is no re-trigger. |
| 3e | Test-first, RED then GREEN | met | Commit 152986d (tests) comes before 8c26c75 (logic). `work/review/evidence.txt:6-19` shows RED `Failed: 8` exit 1, then GREEN `Failed: 0`. The 7 cases that passed in RED are guards or no-ops, which is legitimate. |
| 4 | Build green, no VELA00x in authored code, review PASS | met | Checks "build succeeds" and "no VELA diagnostics". `account-description-normalise.review.md:28` gives PASS with 0 Critical and 0 Required. It is a self-review, labelled with the reason (subagent limit), which is allowed by the evaluator note. The review quality is adequate: it checks both axes against the Canvas and lists real Nits. |

Minor actor slip (not a criterion): the Canvas Operations line `:72` writes `OnUpdate().PreOperation().FilterOn(...)` without `.Sync()`. The front-matter, Approach and code all say Sync.

## Planted-violation results
For each violation, the actor's project was copied to `planted-<x>/` and the violation was applied there. Each copy built with 0 errors; `c` also produced `warning VELA011`. A fresh subagent then acted as `vela-reviewer` (read-only), given only `planted-<x>/diff.txt` and the Canvas.

| Planted | Expected | Reviewer verdict | Top severity | Result |
|---------|----------|------------------|--------------|--------|
| (a) PostOperation + `ctx.Service.Update` of the same account | Critical | BLOCK | Critical. The reviewer found the self-trigger (the write sends Description, which is in FilterOn) and noted that the filter matches on presence, not on change. It also raised a Critical for the stage contradicting the Canvas. | pass |
| (b) (a) + `if (ctx.Depth > 1) return;` | Critical | BLOCK | Critical. The reviewer said "a Depth check is not a recursion guard". It found that every save still causes two writes and two runs, and that legitimate nested updates get skipped. | pass |
| (c) mutable field caching the last description | Required (VELA011) | BLOCK | Critical. The reviewer found mutable instance state on a cached, multithreaded plugin, which races and leaks across users and records. The build confirms VELA011. | pass |

## Findings against the skills
None blocking, and no defect of the pack was observed in this run. The pack led the actor straight to PreOperation and a Target edit, with no Depth guard, and with a pipeline-level single-fire test. The fallback review, the evidence and the apply gate all followed the pack's rules.

1. minor (observation, not a defect) - In planted (c), the reviewer, given only the diff, did not name the analyzer ID `VELA011`, although it flagged the field at Critical. Naming the analyzer comes from the build output, which the reviewer would have in a real review.

## Verdict
**pass**. Checks are 19/19, all criteria are met, and all 3 planted violations were blocked at or above the expected severity. The next run should re-check that the Canvas Operations line carries `.Sync()`; it is cosmetic.
