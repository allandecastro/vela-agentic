---
scenario: account-second-behaviour
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **20/20 passed**, no failed check. Highlights: Create + Update steps both PreOperation/Synchronous
(Update filter `['description']`), exactly 2 authored steps, tests re-run green (total=11 failed=0), no VELA
diagnostics, "Created via Vela plugin" appears in exactly one source file, no `Service.Update/Create` write-back,
read-only `vela plan` creates only the authored steps.

## Loop outcome
- `vela version` -> 0.26.0; `vela solution show ZavaSales` -> prefix `zava` (exit 0).
- One human question (Q1, multiple-choice: what counts as "cleared") -> (a). Canvas committed first (192e5db).
- `vela models --verify` -> in sync (exit 0). `vela add step ... --message Update --stage PreOperation --mode Sync --filtering-attributes Description` + `vela add test` (3ee6f4c, stub handler).
- RED (0d74b78, tests only): 11 total, 4 failed for the right reason (Expected default / Actual sent value).
- Implementation (e025371): shared private static helper + constant; GREEN 11/11, 0 errors / 0 warnings.
- Review 1 BLOCK (1 Required: unfalsifiable "no extra write" clause) -> fixed spec-first (d970d0a); fresh review 2 PASS (4 Nits).
- `dotnet build -c Release` -> package with `lib/net48/zava.Plugins.dll`; `vela plan --solution ZavaSales --detailed-exitcode` -> exit 8 (create package + 2 steps). Stopped at the apply gate.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| D1 | Reuse vs new: `vela add step` on the existing plugin, not a hand-created class | met | Canvas `reuse: add-step:AccountDefaultDescription` (l.24), Approach l.63-67; Run trace row 6; commit 3ee6f4c shows the generated stub `// TODO: implement the Update step` |
| D2 | DRY: defaulting logic defined once, shared by Create + Update | met | `AccountDefaultDescription.cs:12` (constant), `:50-56` `ApplyDefaultIfEmpty` called at `:38` and `:46`; check "src contains /Created via Vela plugin/" -> one file |
| D3 | Sync PreOperation on `ctx.Request.Target` | met | `AccountDefaultDescription.cs:23-28,35`; check "step registered: Update ... PreOperation/Synchronous"; Canvas Approach l.64-65 gives the reason |
| D4 | `FilterOn(e => e.Description)` on the Update step | met | `AccountDefaultDescription.cs:26`; check filter=['description'] |
| SC1 | Canvas Approach/Structure record reuse (`add step`), how the rule is shared, Sync with a reason | met | Canvas l.63-74 ("add a second step to it with `vela add step`", "one private helper + constant ... No service (a one-line rule shared by two steps of one plugin)", Sync PreOp "default is part of the same write, so no extra Update, no recursion") |
| SC2 | No duplicated defaulting logic; decision + correct reason recorded | met | see D2; Canvas assumptions l.46, Norms l.91-92 |
| SC3 | Test-first: RED (cleared -> defaulted; real value -> untouched) before impl, green after | met | `logs/test-red.txt` l.5-42 (4 [FAIL], "Total: 11 ... Failed: 4") at commit 0d74b78 (tests only) before e025371; `logs/test-green2.txt` "Total: 11 ... Failed: 0"; cases at `AccountDefaultDescriptionTests.cs:64-109` incl. `Non_empty_description_on_update_is_untouched` |
| SC4 | `vela-code-review` PASS; SOLID/DRY confirms no duplication; spec confirms reuse honoured | met | `review/review-2.md` "Verdict: PASS", standards axis "DRY helper + constant ... no service needed"; `review/review-1.md` standards axis "vela add step reuse" |
| H1 | One question at a time; ask vs assume | met | `logs/human-questions.md`: single Q1 with options; remaining choices recorded as assumptions (Canvas l.42-47) |
| H2 | Stop before apply | met | Canvas `apply: pending`, Gate section l.160-166; no apply in Run trace |

## Planted-violation results
Each copy in `planted-<x>/ZavaSales`, diff in `planted-<x>/diff.txt`, reviewed by a fresh read-only subagent
acting as vela-reviewer with only the diff + Canvas (build/test evidence withheld, evidence-missing finding disallowed).

| Planted | Change | Build | Reviewer verdict | Expected | Result |
|---|---|---|---|---|---|
| (a) DRY copy-paste | new `AccountDescriptionRules` class with its own constant + `IsNullOrWhiteSpace` rule, used by the Update handler | 0 err / 0 warn, 11/11 green | **BLOCK** - Required (duplicated rule + constant), Required (Canvas drift) | Required | pass |
| (b) hand-created class | Update step moved into hand-written `AccountDescriptionCleared` plugin (`partial`, calls the now-internal helper) | 0 err / 0 warn, 11/11 green | **BLOCK** - Required (contradicts Canvas `reuse: add-step`, stale plan/package), Required (cross-plugin coupling); Nit flags non-generated header | Required | pass |
| (c) Async | Update step `.PostOperation().Async()` + `IUpdatePostContext` (PreOperation+Async does not compile: CS1061, the builder forbids it) | 0 err, 1 warning **VELA018** (async Target write has no effect); 7/11 tests fail | **BLOCK** - Critical (Target edit lost, default never saved), Required (Canvas Sync/PreOp drift) | Critical | pass |

## Findings against the skills
None blocking. No skill-pack defect observed in this run.
1. minor (observation, not a pack defect) - the planted (c) shape "PreOperation + Async" in the scenario text is
   uncompilable with Vela.Plugins 0.35.0 (`ISyncMode<IUpdatePreOperationConfig<Account>>` has no `Async`), so the
   rubric's Async plant must be PostOperation+Async; the scenario's "Planted-violation check (c)" could say so.

## Fixes
- none required by this run.

## Verdict
pass - checks 20/20 and every criterion met with artifact evidence; all three planted violations BLOCKed at the
expected severity or higher. Next runs re-check that the shared helper stays private to the plugin (no service
introduced for a one-liner) and that RED is committed before implementation.
