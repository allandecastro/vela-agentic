---
scenario: account-second-behaviour
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **20/20 passed**, no failed checks. Highlights: build is clean with no VELA diagnostics. Tests re-run green with 18 total and 0 failed. The plugin registers two steps:
- Create/account PreOperation Sync, filter [name]
- Update/account PreOperation Sync, filter [description]

The default text appears only in `AccountDefaultDescription.cs`. There is no `Service.Update/Create` write-back. The read-only `vela plan` creates only the package and the two authored steps.

## Loop outcome
- `vela version` → 0.26.0. `vela solution show ZavaSales --json` → `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- The actor asked one question (Q1, what counts as "cleared") as a multiple-choice prompt, with the agent's own reading of the story stated first. The answer was (b): null, "" or whitespace (`work/logs/human-questions.md:3-10`). Everything else was recorded as an assumption, as the scenario's Human answers instruct.
- The Canvas was committed before any code (commit 17d87d8).
- `vela models --verify` → account in sync (exit 0).
- `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes Description` (exit 0), then `vela add test` (exit 0) (commit 4c49424).
- RED commit 8152439 touches tests only: 7 of 18 tests fail, each with `Expected "Created via Vela plugin"` (`logs/review/red-green.txt`).
- Implementation (a239aaf) → GREEN 18/18. The Release `--no-incremental` build reports 0 warnings and 0 errors.
- A fresh `vela-reviewer` returned PASS with 0 Critical, 0 Required and 3 Nits. Nit 1 was synced into the Canvas (4375981).
- Release build → `artifacts/zava.Plugins.1.0.0.nupkg`, sha256 recorded.
- `vela plan --solution ZavaSales --detailed-exitcode` → exit 8 (changes), with no diagnostics.
- The actor stopped at the apply gate with a Build Report. It raised one open question: this is the first deployment, so the baseline Create step would ship too.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Reuse vs new: `vela add step` on the existing plugin, no hand-made class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.21), Approach l.59-61. Run trace row 5 shows `vela add step`, commit 4c49424. There is one plugin class, `AccountDefaultDescription.cs`. |
| DRY: logic defined once, shared by Create and Update | met | `AccountDefaultDescription.cs:12` holds the constant and `:50-56` the `ApplyDefaultWhenEmpty` helper, used at `:38` (Update) and `:46` (Create). Check "src contains Created via Vela plugin" finds 1 file. |
| Sync PreOperation on `ctx.Request.Target` (not Async, not PostOp write-back) | met | `AccountDefaultDescription.cs:23-28,35`. The registration-probe check passes. There is no `Service.Update` (check). |
| `FilterOn(e => e.Description)` on Update | met | `AccountDefaultDescription.cs:26`. Probe filter is `['description']`. |
| SC1: Canvas Approach/Structure records the reuse, how the rule is shared, and Sync with a reason | met | Canvas A l.57-61: "Sync because ... it shapes the record in the same transaction", plus the reuse via `vela add step`. Canvas S l.64-67: private helper + constant, no service. |
| SC2: no duplicated logic; the Canvas records the decision with a correct reason | met | Code as above. Canvas S l.67 and frontmatter `service: none`: "No service (one-line rule, single plugin)". This matches the corrected rubric. |
| SC3: test-first RED (cleared → defaulted; real value → untouched), then green | met | RED commit 8152439 is tests only, with 7 failures (`red-green.txt`). The non-empty case is tested (`Update_non_empty_description_is_untouched`, `Update_with_non_empty_description_runs_and_saves_it_as_sent`). GREEN 18/18, re-run by the checks. |
| SC4: `vela-code-review` PASS; SOLID/DRY axis confirms no duplication; spec axis confirms reuse | met | `logs/review/reviewer-output.md`: "Approach respected (vela add step)", "DRY/SRP", Verdict PASS with 0 Critical and 0 Required. |
| One question at a time; ask vs assume | met | `human-questions.md` holds a single question, about the only real ambiguity. The no-pre-image choice is recorded as an assumption (Canvas l.38-41). |
| Stop before apply | met | Build Report `status: awaiting-apply`, `apply: pending`. No `vela apply` appears in the trace. |

## Planted-violation results
Each planted copy lives in `r3/planted-<x>/`. It was built, and its diff was reviewed by a fresh read-only subagent acting as `vela-reviewer`. The subagent saw the diff, the Canvas, the build lines, the RED/GREEN lines and the Run trace.

| Planted violation | Expected | Build | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) The rule and default text copied into a second class, `AccountUpdateDescriptionDefaulter`, used by `HandleUpdate` | BLOCK, Required (DRY) | 0 W / 0 E | **BLOCK**. Required: duplication of the rule and text between the steps (DRY). Required: drift from the Canvas. Required: stale test evidence. | pass |
| (b) A hand-written plugin class, `AccountDescriptionClearedDefault`, holds the Update step instead of `vela add step` | BLOCK, Required | 0 W / 0 E | **BLOCK**. Required: departs from the Canvas reuse decision, and the class was hand-created ("`vela add plugin` was never run"). Required: Update tests target the wrong plugin. Required: cross-plugin coupling through an internal helper. | pass |
| (c) The Update step registered Async (`.PostOperation().Async()`, `IUpdatePostContext`) | BLOCK, Critical | 0 E, 1 W: **VELA018** (async handler writes to the Target) | **BLOCK**. Critical: the Target edit after commit is never saved. Critical: VELA018. Required: departs from the Canvas Approach. | pass |

Note on (c): `.PreOperation().Async()` does not compile, because the Vela.Plugins 0.35.0 builder has no `Async()` on the PreOperation config (CS1061). The only Async shape that can be expressed is PostOperation, so that is what was planted. The analyzer (VELA018) and the reviewer both catch it.

## Findings against the skills
None. Nothing in this run traces back to a defect in the skill pack:
- The reuse, DRY, Sync/stage and filtering decisions were all reached.
- The review gate blocked all three planted violations at the expected severity or higher.

## Verdict
**pass**:
- checks: 20/20 pass
- grader: pass (every criterion met, all 3 planted violations blocked)

Next run should re-check:
- whether the Canvas's Sync reason names the concrete failure that Async would cause (the Target edit is lost). This run gives a correct but more general reason ("shapes the record in the same transaction").
