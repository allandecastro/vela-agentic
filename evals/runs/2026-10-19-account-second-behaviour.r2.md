---
scenario: account-second-behaviour
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, no failures. These checks cover the following:
- Canvas exists and mentions reuse.
- ACC-001 is kept and ACC-002 is added in Given/When/Then.
- spec-check passes with 0 failures.
- The build is clean, with 0 VELA diagnostics.
- Tests re-run green (9/9).
- The registration probe shows exactly 2 steps: Create PreOp Sync filter `name`, and Update PreOp Sync filter `description`, both on `AccountDefaultDescription`.
- `src` has no `Service.Update/Create`.
- The literal "Created via Vela plugin" appears exactly once in `src`.
- `vela solution show` returns ZavaSales/zava.
- A read-only `vela plan` creates only the package and the 2 authored steps.

## Loop outcome
- **Version and solution:** `vela version` reported 0.27.3, and `vela solution show ZavaSales` exited 0 with `zava`.
- **Challenge:** the actor asked one question (Q1) and committed the Canvas and ACC-002 (`proposed`) in eaee7ce before any test.
- **Models:** `vela models --verify` exited 0 with "All 2 table(s) are in sync".
- **Scaffold:** `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes Description` and `vela add test` both exited 0.
- **RED:** commit d1c2e3a; mono xunit `-parallel none` exited 1 with `Total: 9, Failed: 4` (C1, C2, C3, C6).
- **GREEN:** commit 8400e40; exited 0 with `Total: 9, Failed: 0`.
- **Release build:** 0 warnings, 0 errors.
- **spec-check:** 0 failures.
- **Review:** an isolated vela-reviewer returned PASS with 4 Nits (commit 0385166).
- **Package and plan:** the package was built, and `vela plan --solution ZavaSales --detailed-exitcode` exited 8 (changes) with 0 diagnostics.
- **Apply gate:** the Build Report is in commit 8d16197, and the actor stopped at the gate. No apply was run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse: `vela add step` on the existing plugin, no hand-created class | yes | Canvas `reuse: add-step:AccountDefaultDescription` (l.21), A - Approach (l.63), Run trace row 5; the probe shows both steps on one type |
| D2 | DRY: one definition shared by Create and Update | yes | `AccountDefaultDescription.cs:15` is the single constant and `:55-61` is `ApplyDefaultWhenEmpty`, called by both handlers (`:44`, `:51`); check "default lives in exactly one place" |
| D3 | Sync PreOperation, edits `ctx.Request.Target` | yes | `AccountDefaultDescription.cs:26-31`, `:37`; Canvas A (l.60-62); check "step registered: Update ... PreOperation/Synchronous" |
| D4 | `FilterOn(e => e.Description)` | yes | `AccountDefaultDescription.cs:29`; probe filter `['description']` |
| 1 | Canvas Approach/Structure record the reuse, the helper and Sync with a reason | yes | Canvas l.59-68 ("the default is part of the same write ... no extra Update event"; "No service (one plugin): ... private helper") and front-matter `service: none` with its reason (l.22) |
| 2 | No duplicated logic; the decision is recorded with a correct reason | yes | see D2; Canvas S (l.66-67) and N (l.81) |
| 3 | Test-first: RED acceptance tests (cleared → defaulted; real value → untouched) then GREEN | yes | Commit order eaee7ce → d1c2e3a (tests plus a `TODO` stub handler) → 8400e40 (implementation). `logs/test-red.log` shows `Total: 9, Failed: 4`, with failing names verbatim in Canvas l.102-103. `logs/test-green.log` shows `Failed: 0`. C4 ("New text" kept) and C5 (not sent, no fire) are in the tests at l.81-105 |
| 4 | vela-code-review PASS; DRY axis confirms no duplication; spec axis confirms the reuse | yes | `docs/vela-builds/account-description-cleared-default.review.md`: "Verdict: PASS", decisions checked "reuse vs new (second step via `vela add step`...)", "service or helper (none; private static `ApplyDefaultWhenEmpty` + one constant...)" |
| 5 | Rules registry: ACC-001 read at intake; ACC-002 added in G/W/T with its implementation trace; Canvas `rules:` lists it | yes | `docs/rules/account.md:22-43` (Given/When/Then, cases C1-C6, `Implementation: AccountDefaultDescription · Update · PreOperation · Sync (HandleUpdate)`). Canvas `rules: [{id: ACC-002, change: add}]` (l.26-27). Q1 cites "the same definition as ACC-001", so the rule was read before planning. The ACC-001 text is unchanged and spec-check passes |
| - | One question at a time; ask vs assume | yes | `logs/human-questions.md` has a single Q1 on the one real ambiguity (a vs b: pre-image). The answer it left to the defaults is recorded as an assumption (Canvas l.39) and as an open question (l.45) |
| - | Stop before apply | yes | Canvas `apply: pending`; Gate section; no apply in the logs |

## Planted-violation results
Each violation was planted in a copy under `r2/planted-<x>/ZavaSales`, built, and reviewed by a fresh subagent acting as vela-reviewer. The reviewer received only the diff (`planted-<x>/planted.diff`) and the Canvas.

| Plant | Change | Build | Reviewer verdict | Severity of the matching finding | Expected | Result |
|---|---|---|---|---|---|---|
| (a) DRY copy-paste | New `Account/AccountDescriptionDefaults.cs` with its own constant and empty check; `HandleUpdate` calls it, Create keeps the private helper | 0 errors, 0 warnings | **BLOCK** | Required: "The rule and the default text now exist twice" | Required | pass |
| (b) Hand-created plugin | Update step moved into a hand-written `AccountDescriptionClearedDefault : EntityPluginBase<Account>`; helper widened to `internal static` | 0 errors, 0 warnings | **BLOCK** | Required: "The new plugin class was created by hand" (no `vela add`), plus reuse-vs-new drift | Required | pass |
| (c) Async | Update step `.PostOperation().Async()` | 0 errors, 1 warning, **VELA018** | **BLOCK** | Critical: "Target edit is discarded ... ACC-002 does nothing on the org" | Critical | pass |

All three reviewers also raised a Required "evidence does not cover this diff" finding, because the Canvas evidence predates the plant. That finding is correct but secondary. Each reviewer blocked on the planted defect itself, at the expected severity.

## Findings against the skills
No blocker or minor defects of the skill pack were observed in this run. The actor followed every gate of the loop with its evidence. The rules registry, the Canvas decisions and the review all match the rubric.

Observations, not defects:
1. Because the plugin became multi-step, the ACC-001 tests needed `.OnCreate()` plumbing, which is a touch on regression tests. The actor recorded it in the Sync log and spec-check accepted it. No change is needed in the pack, but a later run should check that spec-check keeps accepting harness-only plumbing on regression tests and rejects edits to their assertions.
2. The reviewer's Nit 1 (the `Contains` guard in `HandleUpdate` is never exercised, because `FilterOn` blocks that path) recurs in this scenario. It is the actor's choice, not something the skill text prescribes.

## Verdict
**pass**: checks 25/25, every criterion is met, and all three planted violations were blocked at the expected severity or higher. The next run must re-check the same items, especially the RED commit preceding the implementation commit, and that the review's DRY and reuse lines are present on PASS.
