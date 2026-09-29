---
scenario: account-update-recursion
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.3
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **15/15 passed**, `pass: true`. No failed checks. The checks confirm:
- `step registered: Update account PreOperation/Synchronous filter=['description']`
- `exactly 1 authored step(s)`
- `src must not contain /UserService\.(Update|Create)\(/`
- `src must not contain /ctx\.Depth\s*>/`
- `tests contain /PluginPipeline/`
- `tests re-run green (>= 4)`, with total=11 and failed=0
- `no VELA diagnostics`
- `no scaffold demo registered`

## Loop outcome
Paths are relative to `work/ZavaSales/`.

| # | Step | Result |
| --- | --- | --- |
| 1 | `vela version` | 0.21.0 (Canvas Run trace #1) |
| 2 | Challenge | Canvas drafted, 4 human questions answered |
| 3 | First `vela init` | Resolved Vela.Plugins 0.29.4. The tests floated to Vela.Testing 1.0.0 (NU1603), so the actor discarded this scaffold. |
| 4 | Second `vela init --core-version 0.29.3` | Exit 0 |
| 5 | Scaffold | Demos removed (commit 978cc14). `vela add plugin ... --message Update --filtering-attributes Description` run, then edited to PreOperation (f23f543). |
| 6 | `vela models` | Skipped, no org; exact command recorded. No-org stand-in `Description` added to `src/zava.Shared/Models/Generated/Account.cs:47-51`. |
| 7 | RED | Tests committed alone in c5b5d03. The plugin at that commit is the TODO stub. Runner result: Total 11, Failed 7. |
| 8 | GREEN | b41352e. `mono xunit.console -parallel none`: Total 11, Failed 0. Build: 0 warnings, 0 errors. |
| 9 | Review | Isolated vela-reviewer: PASS, 0 Critical/Required, 4 Nits |
| 10 | Package | `artifacts/zava.Plugins.1.0.0.nupkg`, sha256 recorded |
| 11 | `vela plan` | Skipped, no org; exact command recorded. `vela apply` was not run. The run stopped at the gate (Build Report `status: awaiting-apply`). |

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| 1. Canvas Approach records Sync PreOperation with the reason (same-record column, no extra write, nothing re-triggered) | met | `docs/vela-builds/account-normalise-description.md:63-66`: "Sync PreOperation on Update ... one write, no second Update event, so no recursion even though the step filters on the column it edits." Front-matter `stage: PreOperation`, `mode: Synchronous` (l.18-19). |
| 1b. Recursion risk recorded as a Safeguard | met | Canvas l.86: "Recursion: PreOperation target edit, no write-back, no `ctx.Depth` check." |
| 2. Step is `OnUpdate().PreOperation().Sync().FilterOn(e => e.Description)` | met | `src/zava.Plugins/Account/Plugins/AccountNormalizeDescription.cs:18-23`; check `step registered: Update account PreOperation/Synchronous filter=['description']` |
| 2b. Handler sets the value on `ctx.Request.Target` | met | Same file, l.28 and l.38: `target = ctx.Request.Target` ... `target.Description = normalised` |
| 2c. No `ctx.UserService.Update`, no `ctx.Depth` return | met | File l.26-47; checks `src must not contain /UserService.../` and `/ctx\.Depth\s*>/` both ok |
| 3. Test-first: RED, then GREEN | met | Git order: tests in c5b5d03 (plugin still the TODO stub at that commit), implementation in b41352e. Canvas l.103-104 records RED 11/7 and GREEN 11/0. Check re-run: total=11, failed=0. |
| 3a. `"  Hello   world  "` becomes `"Hello world"` on the target | met | `tests/.../AccountNormalizeDescriptionTests.cs:19`, asserts `target.Description` at l.37 |
| 3b. Already-normal description left as is | met | Tests l.21 (AC3). Handler assigns only when the value differs (l.36). |
| 3c. null / empty left as is, no exception | met | Empty `""` becomes null (tests l.23, human answer: whitespace-only stored as null). Sent-null stays null (l.41-55). Not-sent case covered through the pipeline (l.57-70). |
| 3d. No extra write reached the in-memory service | met | `Assert.Empty(crm.GetAll("account"))` at tests l.38 and l.54. The pipeline test AC10 (l.72-87) proves a single execution at depth 1. |
| 4. Build green, no VELA00x in authored code | met | Checks `build succeeds` and `no VELA diagnostics`; Canvas l.101 |
| 4b. `vela-code-review` PASS | met | Canvas l.106-111: isolated reviewer PASS, 0 Critical/Required, 4 Nits (documented, not blocking) |
| Human answers honoured (Update only; space-only collapse; whitespace-only stored as null; ZavaSales/zava) | met | Canvas decisions l.39-42. Tests AC4, AC6 and AC11. `vela init --name ZavaSales --prefix zava`. |
| Stop before apply | met | Canvas l.15 `apply: pending`; Gate section l.138-148; no apply in the Run trace |

## Planted-violation results
Setup for each violation:
- The actor's project was copied to `planted-<x>/`, with `work/` untouched.
- The violation was applied with CRLF line endings preserved, so the diff stays minimal.
- The copy was built with `dotnet build -c Release`.
- A fresh general-purpose subagent, acting as vela-reviewer (read-only: Read, Grep, Glob), was given only the diff file and the Canvas.

| # | Violation | Build | Reviewer verdict | Top severity | Expected | Result |
| --- | --- | --- | --- | --- | --- | --- |
| a | PostOperation + `ctx.UserService.Update` of the same account | 0 errors, 0 warnings (analyzers blind) | BLOCK | **Critical**: "write sends `Description`, which is the step's own filtering attribute ... so the step fires again" | Critical | **blocked** |
| b | (a) plus `if (ctx.Depth > 1) return;` | 0 errors, 0 warnings (analyzers blind) | BLOCK | **Critical**: "Each user save now means two writes and two step executions. Per review-checklist 'Recursion', this is Critical even when a `ctx.Depth` check stops it early". Separate Required finding on the Depth check itself: it "skips legitimate nested updates" | Critical | **blocked** |
| c | Mutable `lastDescription` field on the plugin class | 1 warning: VELA011 at l.16 | BLOCK | **Required**: VELA011, instance reused across executions | Required | **blocked** |

Diffs: `planted-a.diff`, `planted-b.diff`, `planted-c.diff`.

## Findings against the skills
1. minor - `skills/vela-scaffold/SKILL.md:126-128` covers only the case where "The **baseline scaffold build fails right after `vela init`** (an incompatible auto-resolved framework version)".
   - In this run the baseline build **succeeded**. Vela.Plugins resolved to 0.29.4, but no Vela.Testing 0.29.4 exists, so the test project silently floated to Vela.Testing/Vela.Plugins 1.0.0, surfacing only as warning NU1603. The harness then ran against a different framework than the shipped package.
   - The actor caught this on its own and re-scaffolded with `--core-version 0.29.3`. The skill did not direct it to.
   - Suggested fix: add an "NU1603 / Vela.Testing version != Vela.Plugins version in the baseline restore" symptom to the same bullet, with the same `--core-version` remedy.
2. minor - The review severities for a `ctx.Depth` guard are inconsistent.
   - In planted (b), the reviewer rated the write-back Critical, citing the review-checklist "Recursion" entry, which says it stays Critical "even when a `ctx.Depth` check stops it early".
   - It rated the `ctx.Depth > 1` return itself only **Required**.
   - The gate still blocks, but the scenario expects the Depth "fix" to read as Critical. It would be clearer if `review-checklist.md` stated that a Depth guard placed on a self-writing step is part of the Critical finding, not a separate Required one.
3. Observation, no defect: the scaffold's analyzers are silent on (a) and (b), with 0 warnings. Only the review step catches self-recursion, and it did.

No blocker findings against the skill pack.

## Verdict
**pass**:
- checks 15/15;
- every scenario criterion met from the artifacts;
- all three planted violations blocked at the expected severity or higher.

Next runs (2/3, 3/3) must re-check:
- the actor still picks PreOperation without prompting;
- the `--core-version` / NU1603 float is still caught, or the skill has been fixed to name it.
