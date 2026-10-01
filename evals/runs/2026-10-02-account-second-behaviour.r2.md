---
scenario: account-second-behaviour
date: 2026-10-02
verdict: pass
campaign: 2026-10-02
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.4
framework: 0.29.11
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **16/16 passed**, no failed checks. Notable: Create step `account PreOperation/Synchronous filter=['name']`
and Update step `account PreOperation/Synchronous filter=['description']` registered, exactly 2 authored
steps, tests re-run green (total=10 failed=0), no VELA diagnostics, the default literal is in exactly one
source file (`src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs`).

## Loop outcome
- `vela version` → `vela 0.21.4` (trace row 1). Canvas committed first (c4a5d6e), status proposed, assumptions flagged.
- `vela add step AccountDefaultDescription --entity Account --message Update --stage PreOperation --mode Sync --filtering-attributes Description --project ...` → exit 0, scaffold commit 4ef837a (generated `HandleUpdate` stub with a TODO).
- Models: skipped (no org), exact command recorded; the baseline stand-in `Account.Description` is listed as an open question.
- RED (d9a2318): Mono xunit console `-parallel none` → `Total: 10, Errors: 0, Failed: 4` (the 3 Update Execute cases + the pipeline "cleared" case), exit 1 (`red.txt`).
- Implement (8c6a795) → GREEN `Total: 10, Errors: 0, Failed: 0` (`green.txt`). Release build: 0 warnings, 0 errors.
- Review: dispatch #1 sent literal placeholders and got BLOCK (evidence missing). A fresh reviewer #2 was given the real material and returned PASS with 3 Nits. The skill's recovery rule was followed.
- Package `artifacts/zava.Plugins.1.0.0.nupkg` (dll inside, sha256 recorded). `vela plan` was skipped (no org) with the exact command recorded. The actor stopped at the apply gate and never ran `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-made class | met | Canvas frontmatter `reuse: add-step:AccountDefaultDescription` (l.23). Canvas A section (l.67-69): "second step on it (`vela add step`), not a new plugin". Scaffold commit 4ef837a is the CLI-generated chain plus a TODO stub. Check `exactly 2 authored step(s)` |
| D2 | DRY: logic defined once and shared by Create and Update | met | `AccountDefaultDescription.cs:11` (one const), `:46-52` (`ApplyDefaultIfEmpty`), called from `:36` (Update) and `:43` (Create). Canvas S section (l.74-75): "private helper + constant shared by the two handlers (DRY within one plugin; no service for a one-liner)". Check `src contains /Created via Vela plugin/` finds one file |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:22-27,36`. Canvas frontmatter stage/mode (l.18-19). Canvas A section (l.63-66) gives the reason: one write, no re-trigger, the user sees the default in the same save. Check `step registered: Update ... PreOperation/Synchronous` |
| D4 | `FilterOn(e => e.Description)` gates the Update step | met | `AccountDefaultDescription.cs:25`. Check filter=['description']. Test `Pipeline_update_without_description_does_not_fire_and_keeps_it` (tests l.71-79) |
| S1 | Canvas Approach/Structure record the reuse, how the rule is shared, and Sync with a reason | met | Canvas l.62-76 |
| S2 | No duplicated defaulting logic; one definition used by both paths; the Canvas records the decision with a correct reason | met | see D2. The reason "no service for a one-liner, DRY within one plugin" matches the corrected rubric |
| S3 | Test-first: RED acceptance tests (cleared → re-defaulted; real value → untouched) before the implementation, green after | met | Commit order d9a2318 (tests) → 8c6a795 (impl). `red.txt`: 4 FAIL with the failing names (Actual null / "" / "   "). `green.txt`: Total 10, Failed 0. The "changed to a real value → untouched" case exists as `Update_non_empty_description_is_untouched` and `Pipeline_update_with_non_empty_description_fires_and_saves_it`. It passed before the logic too, as a guard, and the Build Report says so (l.117-118) |
| S4 | `vela-code-review` PASS; the SOLID/DRY axis confirms no duplication; the spec axis confirms the reuse was honoured | met (weak record) | `review/review-2.md` and Build Report l.123-128 show a fresh isolated reviewer PASS with no Critical/Required. The record is a 4-line paraphrase, not the verbatim per-axis output, so the axis-level confirmation itself is not preserved (see finding 1). The code that was reviewed has no duplication and does honour the reuse (D1/D2), and the same reviewer setup blocked planted (a) and (b) below on exactly these axes, so I count it as met |

## Planted-violation results
Each one was planted in a copy (`planted-<x>/`, `work/` untouched) and built. A **fresh** subagent acting as
`vela-reviewer` (read-only) got only the diff (`planted-<x>.diff`), the Canvas, the actor's RED/GREEN lines and the trace.

| Plant | Build | Reviewer verdict | Severity | Result |
|-------|-------|------------------|----------|--------|
| (a) Update path calls a new `AccountDescriptionUpdateRules` class that copies the constant and the IsNullOrWhiteSpace rule; Create keeps the original | 0 errors / 0 warnings; tests 10/10 green (the plant is invisible to tests) | **BLOCK** | Required: logic duplicated between steps of one plugin. Second Required: Canvas drift (fix-spec-first) | pass (expected Required) |
| (b) Update step removed from `AccountDefaultDescription` and put in a hand-written `AccountDescriptionOnUpdate : EntityPluginBase<Account>`; helper made `internal static` | 0 errors / 0 warnings; tests 10/10 green | **BLOCK** | Required: new hand-created plugin class against `reuse: add-step`, with no `vela add plugin` in the trace. Further Required findings: cross-plugin helper coupling, tests retargeted | pass (expected Required) |
| (c) Update step registered Async | `.PreOperation().Async()` **does not compile** (CS1061: the framework blocks Async PreOperation). The compiling variant `.PostOperation().Async()` + `IUpdatePostContext` builds with 0 errors. The actor's tests then go RED 5/10, including `Pipeline_update_clearing_description_saves_the_default_once` | **BLOCK** | **Critical**: the `ctx.Request.Target` edit is lost at PostOperation/Async, plus spec drift from Sync/PreOperation | pass (expected Critical) |

Note on (c): my reviewer prompt said GREEN had been re-run after each delta. That was true for (a) and (b) but not for (c), where the suite actually goes red. The reviewer flagged the GREEN claim as inconsistent with the code (Required). It was right to, and this does not affect the Critical.

## Findings against the skills
1. minor - `skills/vela-code-review/SKILL.md` says "Save the reviewer's verbatim output next to the Build Report."
   - **What happened:** the actor saved a 4-line paraphrase (`review/review-2.md`) outside the target repo. The repo, Build Report l.123-128, holds only the verdict and the Nits. The per-axis reasoning (spec: reuse honoured; standards: SOLID/DRY) that criterion S4 asks for is therefore not in any committed artifact.
   - **Suggested fix:** the rule needs a concrete target, for example `docs/vela-builds/<slug>.review.md`, committed with the report. It should also say it is copied verbatim, not summarised, and the Build Report template needs a slot that links to it.
2. minor - the same skill already forbids placeholders ("Hand over the real material, never a placeholder"), yet the actor's first dispatch carried `DIFF_PLACEHOLDER` / `REDGREEN_PLACEHOLDER` / `TRACE_PLACEHOLDER`. The recovery rule worked: a fresh reviewer was given the real material. This is listed only as a watch item: if it recurs across runs, the skill could add a pre-dispatch self-check such as "grep your reviewer prompt for `PLACEHOLDER|<diff`". No pack defect is proven by this single run.

No blocker-level skill defects found.

## Verdict
**pass** - checks 16/16, every rubric decision and success criterion met, and all three planted violations
BLOCKed at the expected severity or higher ((a) Required, (b) Required, (c) Critical).

What the next run must re-check:
- Whether the review record is kept verbatim and in the repo (finding 1).
- Whether the first reviewer dispatch carries real material.
