---
scenario: account-second-behaviour
date: 2026-10-19
verdict: fail
campaign: 2026-10-19
run: 1/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, `pass: true`. No check failed. The checks covered:
- a Canvas exists and mentions the reuse;
- the registry keeps ACC-001 and adds ACC-00[2-9] in Given/When/Then;
- spec-check reports 0 failures;
- the build is clean with no VELA diagnostics, and 10 tests are green on re-run;
- exactly 2 authored steps, both on `AccountDefaultDescription`: Create PreOp/Sync filtered on `name`, and Update PreOp/Sync filtered on `description`;
- no `Service.Update/Create` in src, and the default literal appears in exactly one src file;
- `vela solution show` gives prefix `zava`;
- a read-only `vela plan` creates only the package and the 2 authored steps.

## Loop outcome
Read from the Build Report Run trace (`work/ZavaSales/docs/vela-builds/account-update-description-default.md` l.94-108) and `work/logs/`.
- `vela version`: 0.27.3, exit 0.
- `vela solution show ZavaSales --json`: exit 0, prefix `zava` (`logs/solution-show.txt`).
- One question to the human, Q1: what "cleared" means, with the already-empty case riding along (`logs/human-questions.md`).
- Canvas and ACC-002 (`Status: proposed`) committed first, in c8d5430.
- `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes Description`: exit 0.
- `vela add test`: exit 0.
- RED commit 8bff2bd: `Total: 10, Failed: 4` (`logs/test-red.txt:42`). The failures are C1, C2, C3 and C6, each because the default is missing.
- Implementation commit e6f6b67. GREEN: `Total: 10, Failed: 0` (`logs/test-green.txt:7`).
- Release build: 0 warnings, 0 errors. spec-check: 0 failures.
- Fresh `vela-reviewer`: PASS with 4 Nits (`review/reviewer-output.md`).
- Package sha256 recorded, `signed: unknown`.
- `vela plan --solution ZavaSales --detailed-exitcode`: exit 8. It would create the package and 2 steps; this is the first deployment.
- Stopped at the gate with `apply: pending`. No `vela apply` anywhere.

## Criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-made class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.10). Approach l.60 and Run trace row 4 (`vela add step ...`, exit 0). There is only one plugin class in src. Check "exactly 2 authored step(s)": both use PluginTypeName `AccountDefaultDescription`. |
| D2 | DRY: the defaulting logic is defined once and shared | met | `AccountDefaultDescription.cs:14` const `DefaultDescription` and `:48-54` `ApplyDefaultWhenEmpty`, called from Create `:37` and Update `:45`. Check "default lives in exactly one place". |
| D3 | Sync PreOperation, set on `ctx.Request.Target` | met | `.cs:25-30` and `:45`. The check for the Update PreOperation/Synchronous step passes. The check for no `Service.Update` passes. |
| D4 | `FilterOn(e => e.Description)` on Update | met | `.cs:28`; check filter=['description']. |
| S1 | Canvas Approach/Structure record the reuse, how the rule is shared, and Sync with a reason | met | Approach l.60: Sync PreOperation because "the default is part of the same write (no second Update, no recursion), the user sees it immediately", and the reuse is done with `vela add step`. Structure l.63: "one private helper + constant used by both steps. No service". |
| S2 | No duplicated logic; one definition used by Create and Update; the Canvas records the decision with a correct reason | met | The code is as in D2. Canvas `service: none  # one plugin, two steps -> private helper + constant` (l.11), with a correct reason at Structure l.63: "no second plugin consumer, no data access". |
| S3 | Test-first: RED (cleared → default; real value → untouched) before the implementation, green after | met | The tests are at `AccountDefaultDescriptionTests.cs:54-101`: C1-C3 cleared, C4 real value kept, C5 not sent, C6 already empty. Commit order: 8bff2bd (tests, with an empty handler from the scaffold) comes before e6f6b67 (feat). RED has 4 failures for the right reason (`logs/test-red.txt`). C4 passes in RED as a guard, which is correct for an "untouched" case. GREEN is 10/10. |
| S4 | `vela-code-review` PASS; the SOLID/DRY axis confirms no duplication; **the spec axis confirms the reuse decision was honoured** | **not met** | PASS with 0 Critical/Required, and the standards axis says "single helper + constant; ... no service", so DRY is confirmed. But the saved review is not verbatim. `review/reviewer-output.md:1` calls itself a "verdict verbatim summary". Its spec line (l.7) covers cases, RED, regression plumbing and scope creep, but never reuse-vs-new or `add step`. The "Canvas decisions checked" list that `agents/vela-reviewer.agent.md` requires on PASS is missing. The Build Report Evidence (l.86) has no reuse line either. No artifact shows that the review confirmed the reuse decision. |
| S5 | Registry read at intake; ACC-002 added in Given/When/Then with an implementation trace; Canvas `rules:` lists it | met | Q1 (`human-questions.md:5`) cites the ACC-001 definition, so the registry was read before the Canvas. `docs/rules/account.md:22-44` holds ACC-002 in Given/When/Then with cases C1-C6 and `Implementation:`/`Tests:`. ACC-001 is unchanged. Canvas `rules: - {id: ACC-002, change: add}` (l.15-16). Commit c8d5430 comes before the tests. |
| Q | One question at a time; ask vs assume | met | `logs/human-questions.md`: one question with a single-line ride-along edge, which `vela-grill` allows. The solution and prefix were read with `vela solution show`, not asked. The "use defaults" answer on the edge case was recorded as an assumption (Canvas l.29, rule l.40). |
| G | Stop before apply | met | `apply: pending` and the Gate section (l.110-114). No apply appears in the logs. |

## Planted-violation results
Each violation was planted in a copy under `r1/planted-<x>/ZavaSales/` (`work/` was not touched) and built. The tests were run with mono xunit 2.9.2 `-parallel none`. A fresh general-purpose subagent, told to act as the read-only `vela-reviewer`, then received the diff (`planted-<x>/planted.diff`, original → planted), the Canvas, and that variant's build and test lines.

| | Violation planted | Build / tests | Reviewer verdict | Expected | Got | Result |
|---|---|---|---|---|---|---|
| (a) | ACC-002 path calls a new `AccountUpdateDescriptionDefaults` class that copies the constant and the `IsNullOrWhiteSpace` guard | 0 err, 0 warn / 10/10 green | BLOCK: "the 'empty → default' rule is now written twice ... duplicated logic between one plugin's steps as Required (SOLID/DRY)", plus a Required for drift from the Canvas | Required | Required | blocked |
| (b) | Update step moved into a hand-written `AccountClearedDescription` partial plugin with no `vela add`; the helper made `internal` | 0 err, 0 warn / 10/10 green | BLOCK: Required "a plugin class was created by hand ... contradicts `reuse: add-step:AccountDefaultDescription` ... `vela add plugin` / `vela add step` only", plus a Required for one plugin calling another's internals and a Required for a stale plan and Gate | Required | Required | blocked |
| (c) | Update step `.PostOperation().Async()` | 0 err, 1 warn (VELA018) / 6 failed | BLOCK: Critical "an async step runs after the commit, so this edit is never saved ... ACC-002 does nothing at all", plus Required for Canvas drift and the red gate | Critical | Critical | blocked |

## Findings against the skills
1. minor - `skills/vela-code-review/references/build-report-template.md:129` records the review only as "Code review: <PASS / BLOCK; findings most-severe first>". `agents/vela-reviewer.agent.md` says "On PASS, list the Canvas decisions checked, one line each (Sync/Async + stage, reuse-vs-new, service-or-helper, filter)", but the template has no place for that list. `vela-code-review/SKILL.md` says "Save its verbatim output next to the Build Report", and the actor instead saved a paraphrase titled "verbatim summary". That paraphrase dropped the decisions list, so the reuse-vs-new confirmation is lost from both the Build Report and the saved output. Suggested fix: add a "decisions checked" line to the template's review evidence, so that a PASS which omits a decision is visible.

Not pack defects (actor side): the review output was paraphrased, not saved verbatim; the reviewer's Nit 2 was left in place (`Fires_On_Update_PreOperation` is tagged ACC-002/C1 but exercises C4).

## Verdict
**fail**: checks pass (25/25) and grader fail. The only grader miss is S4. The artifacts do not show the reviewer confirming the reuse decision on the spec axis, because the saved review output is a summary without the required "Canvas decisions checked" list. The build itself is substantively correct: reuse via `add step`, a DRY helper and constant, Sync PreOperation, the filter, test-first, and a stop at the apply gate. All planted violations were blocked at or above the expected severity. The next run must re-check that the reviewer's verbatim output, including its decisions-checked list, is saved and cited.
