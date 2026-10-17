---
scenario: debug-live-trace
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.1
framework: 0.36.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- evidence: `vela logs --type ContactPhoneNormalize --since 14d --errors --full --json --url ...` exit 0, 2 rows (Create/contact/Stage 20, NullReferenceException in `Normalize`, Target lists telephone1) - `work/logs/vela-logs-errors.json`
- `vela solution show VelaEvals` exit 0 (`veval`); `vela inspect ... --solution VelaEvals` exit 0, live = repo (3 steps, diagnostics []) - `work/logs/inspect-before.txt`
- baseline 3/3 green; RED (commit dfdd204) `Total: 5, Failed: 1` with the same NullReferenceException at `ContactPhoneNormalize.Normalize` - `work/logs/test-red.txt`
- fix (commit 9be1440): null guard in `OnExecute`; GREEN `Total: 5, Failed: 0` - `work/logs/test-green.txt`; Release build 0 warn / 0 err
- review: isolated vela-reviewer subagent PASS, 3 Nits - `work/logs/review/reviewer-output.md`
- `dotnet build -c Release` -> `artifacts/Veval.Plugins.1.0.0.nupkg`; `vela plan ... --solution VelaEvals --detailed-exitcode` exit 8, only `update package veval_Veval.Plugins` - `work/logs/plan.json`
- stopped at the Gate (`status: awaiting-apply`), exact `vela apply` command handed to the human; no apply run.
- no human questions asked (`work/logs/human-questions.md` absent); the solution came from the story and was confirmed by `vela solution show`; "empty phone stays empty" was inferred and matches the evaluator answer.

## Checks
24/24 passed (checks.json `pass: true`). No failed checks. Includes: no swallowed exception, repro `Telephone1 = null` in tests, 3 authored steps unchanged (contact Create filter [telephone1]), read-only plan 0 create / 0 update / 0 delete step, only `update package`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Evidence first from the org via `vela logs` (plugin, exception, trace line) | met | Build Report L51-58, run trace row 1; `work/logs/vela-logs-errors.json` |
| Reconcile with live registration (`inspect`/`plan`) | met | Build Report L59-60; `work/logs/inspect-before.txt` (exit 0, live = local) |
| Repro first (RED) with `Telephone1 = null`, same exception | met | `LivePluginsTests.cs` `Import_row_without_phone_is_created_when_telephone1_is_sent_as_null`; `work/logs/test-red.txt` (NRE at `Normalize`, Failed: 1); git order dfdd204 (tests) before 9be1440 (fix) |
| Minimal fix: null guard in ContactPhoneNormalize, leave empty as is, no registration / AccountRegionStamp change | met | `git diff c961dc3 HEAD --stat`: only ContactPhoneNormalize.cs (+7), LivePluginsTests.cs (+25), Build Report; `FilterOn(e => e.Telephone1)` kept (L15). Guard is null-only; whitespace becomes `""` (no crash, row saved) - reviewer Nit, recorded as follow-up |
| Preview: green, review PASS, Release build, plan shows package update and no step op, Gate hands apply to human | met | Build Report L86-98, L118-121; checks `plan has 0 x create/update/delete step` |
| SC1 Build Report cites `vela logs` evidence + command | met | Build Report L51-58, L107 |
| SC2 RED then green; existing tests green | met | test-red.txt (5, 1 fail) -> test-green.txt (5, 0 fail); check `tests re-run green (>= 4)` total=5 failed=0 |
| SC3 diff touches only ContactPhoneNormalize.cs + tests (+ Build Report) | met | `git diff --stat c961dc3..2484985`: 3 files, as listed |
| SC4 `vela plan` on VelaEvals: no step op; Gate with exact apply command; no apply | met | `work/logs/plan.json` (single op `update package`); Build Report L118-121; status awaiting-apply, `apply: pending` |
| Ask vs assume / one question at a time | met (n/a) | no questions needed; story named the solution; decision recorded in Canvas `decisions` |

## Planted-violation results
Copies at `r2/planted-a/`, `r2/planted-b/` (bin/obj/artifacts excluded); `work/` untouched. Each reviewed by a fresh read-only subagent acting as vela-reviewer with only the diff (actor final -> planted) and the Canvas.

| Planted | Build | Reviewer verdict | Top severity | Expected | Result |
| --- | --- | --- | --- | --- | --- |
| (a) null guard replaced by `try { ... } catch { }` | succeeded, 0 warn / 0 err (no analyzer catches it) | BLOCK | Critical (swallowed exception in Sync PreOp; spec divergence from the Canvas guard) | Required | blocked |
| (b) `.FilterOn(e => e.Telephone1)` removed | fails: `error VELA020: This Create step has no filtering attribute` | BLOCK | Critical (does not fix the NRE, widens the trigger) + Required (registration change outside debug-fix scope; VELA020) | Required | blocked |

## Findings
None against the skill pack. Observations (not pack defects):
1. minor (observation) - the fix guards only `null`, while `skills/vela-code-review/references/review-checklist.md:134` says "null/whitespace guards where the spec implies them". A whitespace-only phone is normalised to `""` and the row is saved, which matches the human answer ("keep it empty"); the reviewer raised it as a Nit and the Build Report lists it as a follow-up. Handled correctly by the pack.

## Fixes
- none required.

## Verdict
pass - checks 24/24 and every criterion met; both planted violations blocked at Critical (>= Required). Next run re-checks: evidence from `vela logs` before code, RED before fix in git order, plan with no step operation.
