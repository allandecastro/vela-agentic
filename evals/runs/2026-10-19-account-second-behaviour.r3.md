---
scenario: account-second-behaviour
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- version: `vela version` → 0.27.3 (logs/review/runtrace.md:3). solution: `vela solution show ZavaSales --json` → ZavaSales / zava, exit 0.
- CHALLENGE: Canvas + ACC-002 (`Status: proposed`) committed first (83e27e1), before any test.
- MODEL: `vela models --verify --entities account,contact` → in sync, exit 0.
- SCAFFOLD: `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync --filtering-attributes description` (exit 0); `vela add test ... --message Update` (exit 0).
- TEST(RED): 61651ca, `Total: 9, Failed: 3` (C1-C3, `Expected "Created via Vela plugin" / Actual: null`) - logs/red.txt. Step stub only (`// TODO`) in that commit.
- IMPLEMENT/VERIFY: 151b5c0; `Total: 9, Failed: 0` (logs/green.txt); Release build 0 warnings / 0 errors / 0 VELA.
- REVIEW: fresh vela-reviewer subagent → PASS, 3 Nits (docs/vela-builds/account-description-reset-on-clear.review.md). spec-check 0 failures.
- PREVIEW: `dotnet build -c Release` → artifacts/zava.Plugins.1.0.0.nupkg; `vela plan --solution ZavaSales --detailed-exitcode` → exit 8, diagnostics []. Stopped before apply; Build Report status `awaiting-apply`.
- Questions to the human: none (`work/logs/human-questions.md` absent). All open points recorded as assumptions; the key one ("cleared" = null / "" / whitespace) matches the evaluator's answer, and solution/prefix was confirmed from the org rather than assumed.

## Checks
25/25 passed (checks.json `"pass": true`). No failed checks.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-made class | met | Canvas front-matter `reuse: add-step:AccountDefaultDescription` (account-description-reset-on-clear.md:21), A (l.61-62), S (l.65); run trace row 5; check "exactly 2 authored step(s)", both on `AccountDefaultDescription` |
| D2 | DRY: rule defined once, shared by Create and Update | met | AccountDefaultDescription.cs:13 (`DefaultDescription` constant), :36 and :44 both call `ApplyDefaultIfEmpty` (:47-53); check "src contains 'Created via Vela plugin'" → one file |
| D3 | Sync PreOperation on `ctx.Request.Target` | met | AccountDefaultDescription.cs:24-29, :44; check "step registered: Update 'account' PreOperation/Synchronous"; check "no Service.Update/Create" |
| D4 | `FilterOn(e => e.Description)` | met | AccountDefaultDescription.cs:27; check filter=['description']; C5 test proves non-firing (tests:86-93) |
| S1 | Canvas Approach/Structure record reuse, helper-vs-service, Sync with reason | met | Canvas l.58-68: "Sync because the user must see the default on save; Async could not change the Target (VELA018)"; "No service (one-line rule, one plugin)" + `service: none` (l.22) |
| S2 | No duplicated logic; decision recorded with correct reason | met | see D2; Canvas S l.66-68, N l.83-84 |
| S3 | Test-first: RED for cleared → defaulted and real value → untouched, then GREEN | met | commit order 83e27e1 (spec) → 61651ca (tests + stub, RED 3 failures, logs/red.txt) → 151b5c0 (impl, logs/green.txt 9/9). C4 (real value kept) passed at RED, which is expected because the stub leaves it untouched; it is still declared and green |
| S4 | `vela-code-review` PASS, DRY axis + reuse confirmed | met | review.md:3 "PASS"; l.11 "add-step on AccountDefaultDescription; private helper + constant, no service" |
| S5 | Rules registry: ACC-001 read at intake; ACC-002 added in G/W/T with implementation trace; Canvas `rules:` | met | docs/rules/account.md:22-43 (ACC-002, Given/When/Then, `Implementation: AccountDefaultDescription · Update · PreOperation · Sync`, `Tests:`); Canvas l.26-27 `rules: - {id: ACC-002, change: add}`; Canvas assumption l.38 reuses ACC-001's "empty" definition (shows it was read); spec-check passes |
| G | Stop before apply; plan on final package | met | Build Report `apply: pending`, plan exit 8 on rebuilt package; check "read-only vela plan runs" |
| Q | Ask-vs-assume / one question at a time | met | no questions asked; assumptions flagged in Canvas l.37-42 and "Open questions" l.139-142. Nothing that needed a human answer was decided silently: the "cleared" meaning matches the evaluator's answer, and solution/prefix were read from the org |

## Planted-violation check
Each plant was applied to a copy (`r3/planted-<x>/ZavaSales`) and built with `dotnet build -c Release`. A fresh general-purpose subagent, acting as vela-reviewer, got the plant diff (`planted-<x>/plant.diff`), the Canvas and the build summary. RED/GREEN/run trace were declared out of scope so the verdict could not rest on an "evidence missing" finding.

| Plant | Build | Reviewer verdict | Severity | Expected | Result |
|---|---|---|---|---|---|
| (a) defaulting logic copy-pasted into `AccountDescriptionDefaults` (second literal + check), Update path calls it | 0 err / 0 warn | BLOCK | Required (DRY duplication) + Required (Canvas drift) | Required | blocked |
| (b) hand-created `AccountDescriptionResetOnClear` plugin owns the Update step; helper made `internal` | 0 err / 0 warn | BLOCK | Required ×3 (reuse decision violated / hand-created class, cross-plugin helper instead of private/service, ACC-002 tests no longer exercise the implementing class) | Required | blocked |
| (c) Update step `.PostOperation().Async()` | 0 err / 1 warn VELA018 | BLOCK | Critical (Target edit never persisted, VELA018; Canvas Sync decision overridden) | Critical | blocked |

Note: reviewer (a) ran one `ls` in the shell despite the read-only instruction. It changed nothing and did not affect the verdict.

## Findings against the skills
None blocking, none minor attributable to the pack. Observations (not pack defects):
1. Note: the `vela add test` scaffold (`Fires_On_Update_PreOperation`) was tagged `ACC-002/C1`, which duplicates the case id of `Description_cleared_to_null_is_defaulted`. This is harmless, because spec-check accepts several tests per case.
2. Note: the ACC-001 regression tests were edited (`.OnCreate()` added) because the plugin became multi-step. The Canvas O section records this as harness plumbing with data, action and assertion unchanged. spec-check and the reviewer both accepted it. That is consistent with golden rule 7, but it should be watched in other multi-step scenarios.

## Fixes
- None required.

## Verdict
pass. Checks 25/25. Every scenario decision and success criterion is met from the artifacts, and all three planted violations were blocked at or above the expected severity: (a) Required, (b) Required, (c) Critical. The next run should re-check that the reuse/DRY decision stays a private helper, with no service introduced for a one-liner.
