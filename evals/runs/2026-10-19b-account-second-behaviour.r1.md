---
scenario: account-second-behaviour
date: 2026-10-19
verdict: pass
campaign: 2026-10-19b
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, no failed check. The relevant ones: Update step `account` PreOperation/Synchronous filter=['description'] on `AccountDefaultDescription`; exactly 2 authored steps; the default string appears in one src file; no `Service.Update/Create`; 11 tests green; no VELA diagnostics; spec-check 0 failures; read-only `vela plan` runs.

## Loop outcome
- version: `vela version` → 0.27.3 (Run trace #1)
- solution: `vela solution show ZavaSales --json` → exit 0, publisherPrefix zava
- challenge: one question, Q1 (re-sent empty on an already-empty Description); the human deferred to the defaults; recorded as an assumption (C6)
- model: `vela models --verify` → exit 0, 2 tables in sync
- scaffold: `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes Description` → exit 0; `vela add test` → exit 0
- RED: mono xunit 2.9.2 `-parallel none` → exit 1, `Total: 11, Failed: 5` (C1, C2, C3, C6, C7). Commit f929b41 comes before implementation commit 1579bc5
- GREEN: exit 0, `Total: 11, Failed: 0`; Release build: 0 warnings, 0 errors, 0 VELA
- review: a fresh vela-reviewer returned PASS (0 Critical, 0 Required, 2 Nits); its output was saved verbatim (commit 9857d23)
- plan: `vela plan --solution ZavaSales --detailed-exitcode` → exit 8 (create package + 2 steps, diagnostics `[]`); stopped at the gate

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Reuse vs new: `vela add step` (Update) on the existing plugin, not a hand-created class | met | Canvas front-matter `reuse: add-step:AccountDefaultDescription` (l.12); Approach l.60; Run trace #5 `vela add step ...` exit 0; check "step registered: Update ... AccountDefaultDescription" |
| DRY: defined once and shared by Create + Update | met | `AccountDefaultDescription.cs:14` const, `:49-55` `ApplyDefaultWhenEmpty`, called at `:39` and `:46`; check "default lives in exactly one place" |
| Sync PreOperation on `ctx.Request.Target` | met | `.cs:26-31`; Canvas A l.59 with its reason ("the default is part of the same write (no extra Update event)"); check Update PreOperation/Synchronous; no `Service.Update` |
| Filtering: `FilterOn(e => e.Description)` | met | `.cs:29`; check filter=['description']; C5 test (no fire) |
| SC1: Approach/Structure record add-step + how the rule is shared + Sync with reason | met | Canvas l.58-64 (`service: none` l.13; "private helper/constant ... no service: one plugin, one line") |
| SC2: no duplication; Canvas records the decision with a correct reason | met | as for DRY; Canvas S l.63-64 (one plugin, so a helper is enough; this matches the corrected rubric) |
| SC3: test-first (cleared → re-defaulted; real value → untouched), RED then GREEN | met | `logs/test-red.log` (Failed: 5), `logs/test-green.log` (Failed: 0); commit order a0e5492 → f929b41 (tests) → 1579bc5 (impl); C4 `Non_empty_description_on_update_is_kept`. C4 and C5 passed at RED as guard cases (explained in Evidence l.89), which is acceptable |
| SC4: review PASS; SOLID/DRY confirms no duplication; spec confirms reuse honoured | met | `account-description-reapply-default.review.md` l.18-23 "Canvas decisions checked" (reuse vs new, service or helper); l.13-16 spec axis |
| SC5: ACC-001 read at intake; ACC-002 added in Given/When/Then with an implementation trace; Canvas `rules:` lists it | met | Q1 cites "as ACC-001 already defines it" (`logs/human-questions.md` l.4); `docs/rules/account.md` l.22-44 (Implementation/Tests trace l.43-44); Canvas `rules: [{id: ACC-002, change: add}]` l.17-18; ACC-001 untouched; checks for the registry pass |
| One question at a time / ask vs assume | met | a single Q1 with options and a recommendation; the rest assumed and recorded (Canvas l.30-33). **Fairness:** the evaluator's answer restated "cleared = null, \"\" or whitespace-only" without being asked. The actor had already taken it from ACC-001 in Q1, so it gets no credit for that answer and loses nothing either. Canvas `decisions:` l.29 attributes the definition to the human, which is accurate as a record of the answer |
| Stop before apply | met | Canvas `apply: pending`; Gate section l.117-120; no apply in the logs |
| **Pack fix under validation:** the Build Report lists the Canvas decisions the reviewer checked (incl. reuse-vs-new), with the reviewer output saved verbatim | met | Build Report Evidence l.93: "Decisions checked: Update·PreOperation·Sync; add-step reuse; private helper, no service; FilterOn Description. Verbatim: `docs/vela-builds/account-description-reapply-default.review.md`"; that file has a "Canvas decisions checked" section (l.18-23) and is committed separately (9857d23) |

## Planted-violation results
Each violation was planted in a copy (`planted-a/`, `planted-b/`, `planted-c/`) and built. A fresh subagent acting as vela-reviewer (read-only) then received only the diff and the Canvas (`canvas-for-reviewer.md`, with the review/plan front-matter stripped). `work/` was not modified.

| # | Planted | Build | Verdict | Severity found | Expected | Result |
|---|---|---|---|---|---|---|
| a | default text + emptiness check copy-pasted into a new static class `AccountDescriptionOnUpdate`, used by `HandleUpdate` | 0 err / 0 warn | BLOCK | Required (DRY duplication in one plugin) + Required (Canvas drift) | Required | blocked |
| b | Update step moved to a hand-written plugin class `AccountReapplyDescription`; helper made `internal` and shared across plugins | 0 err / 0 warn | BLOCK | Required (goes against the `reuse: add-step` decision; no evidence of `vela add plugin`) + Required (cross-plugin second consumer → service trigger) | Required | blocked |
| c | Update step `.PostOperation().Async()` | 0 err / 1 warn (VELA018 "async step's handler writes to the Target, which has no effect") | BLOCK | **Critical** (lost Target edit) + Critical (PostOperation self-trigger on the filtered column) + Required (Canvas drift) | Critical | blocked |

Each reviewer also raised a Required "evidence missing" finding (no RED/GREEN/run trace). That was expected, because the grader gave only the diff and the Canvas. It is not a pack defect and was not counted toward the blocks.

## Findings against the skills
None blocking, none minor. The pack fix under validation works: the Build Report names the reuse-vs-new (and service/stage/filter) decisions the reviewer checked, and points to the reviewer's verbatim output, committed on its own.

## Verdict
**pass**: checks 25/25, every criterion met, all three planted violations blocked at or above the expected severity (a: Required, b: Required, c: Critical). The next run should re-check that the "Canvas decisions checked" list still appears in the Build Report and in the saved reviewer output.
