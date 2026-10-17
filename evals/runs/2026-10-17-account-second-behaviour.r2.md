---
scenario: account-second-behaviour
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.0
framework: 0.35.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **20/20 passed**, with no failed checks. They cover:
- the Canvas exists and records the reuse;
- build clean, no VELA diagnostics, tests re-run green (10/10);
- the Create step is registered PreOperation/Sync with filter [name], and the Update step PreOperation/Sync
  with filter [description]; exactly 2 authored steps;
- the package holds the dll; no `Service.Update/Create` in src; the default string lives in one file;
- `vela solution show ZavaSales` returns zava; a read-only plan runs, has no demo operation and creates only
  the authored steps.

## Loop outcome
- `vela version` returned 0.26.0.
- `vela solution show ZavaSales --json --url <org>` exited 0 with publisher prefix zava.
- `vela models --verify --entities account,contact` exited 0: in sync.
- `vela add step AccountDefaultDescription --message Update --stage PreOperation --mode Sync
  --filtering-attributes Description` exited 0; `vela add test ... --message Update` exited 0.
- RED at commit 781fecd: 10 tests, 3 failed for the right reason. GREEN at commit 4548e4e: 10/10 with Mono
  xunit.console 2.9.2 `-parallel none`.
- Review by an isolated vela-reviewer subagent: PASS, with 0 Critical / 0 Required / 3 Nits. Nit 1 was fixed
  in the Canvas (commit 774a723).
- `dotnet build -c Release` produced `artifacts/zava.Plugins.1.0.0.nupkg`. Its sha256 e089c5b9… was
  re-verified by the grader and matches the Build Report.
- `vela plan -p ... --solution ZavaSales --url <org> --detailed-exitcode` exited 8 (changes): create package
  plus 2 steps, no diagnostics.
- The actor stopped at the apply gate. There is no `vela apply` anywhere.
- One human question was asked (Q1, whitespace = cleared?) with options. It was a single question and the
  rest was recorded as assumptions.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Reuse vs new: `vela add step` on the existing plugin, not a hand-created class | met | Commit 0528aaa contains only the scaffolder output (step + TODO handler). Run trace row 5. Canvas `reuse: add-step:AccountDefaultDescription` (l.21), Approach l.65-66. Check "exactly 2 authored step(s)". |
| DRY: the rule defined once and shared by Create + Update; Canvas records it with a correct reason | met | `AccountDefaultDescription.cs:12` (single const), `:51-57` (`ApplyDefaultIfEmpty`), called at `:39` (Update) and `:47` (Create). Canvas Structure l.70-72: "No service: a one-line rule shared by two steps of one plugin → a private helper + constant". Check "src contains /Created via Vela plugin/" finds one file. |
| Sync PreOperation, set on `ctx.Request.Target`, with a reason | met | `AccountDefaultDescription.cs:23-28, 36-39`. Canvas Approach l.62-65: "one write, no second Update event… Sync because the user must see the default in the same save". Checks for the Update registration and for no `Service.Update/Create`. |
| Filtering: `FilterOn(e => e.Description)` | met | `AccountDefaultDescription.cs:26`. Check: Update filter=['description']. |
| SC1 Canvas Approach/Structure records the reuse, how the rule is shared, and Sync with a reason | met | Canvas l.61-72 |
| SC2 No duplicated defaulting logic; one definition; the decision recorded with a correct reason | met | as for DRY above |
| SC3 Test-first: RED (cleared → re-defaulted; real value → untouched) before the implementation, green after | met | RED commit 781fecd comes before implementation commit 4548e4e (`git log`). `logs/test-red.log`: 3 fails, `Cleared_description_on_update_is_defaulted_once(null|""|"   ")`, "Expected: Created via Vela plugin". `logs/test-green.log`: 10/10. The real-value case is `Non_empty_description_on_update_is_saved_as_sent` (tests l.76-85). Check "tests re-run green" (10). |
| SC4 `vela-code-review` PASS: the SOLID/DRY axis confirms no duplication; the spec axis confirms the reuse was honoured | met (weak on the reuse wording) | `review/reviewer-output.md`: PASS with 0 Critical/Required. Standards axis: "DRY via private static ApplyDefaultIfEmpty + const". Spec axis: "Update/PreOperation/Sync/FilterOn(Description) matches the Canvas; human decisions honoured". The reuse is not named in so many words, but the reviewer saw the diff and the Canvas `reuse:` line (`review/reviewer-prompt.md:30,72-73`) and raised no finding. See finding 1. |
| One question at a time / ask vs assume | met | `logs/human-questions.md`: one question with options. The solution came from the baseline and was confirmed by `vela solution show`. Other gaps are recorded as assumptions (Canvas l.38-44). |
| Never `vela apply`; org read-only | met | The run trace has only version / solution show / models --verify / plan. Build Report "Not applied". |

## Planted-violation results
Each violation was applied to a copy (`planted-<x>/`) and built with `dotnet build -c Release`. A fresh
subagent then reviewed it as vela-reviewer, read-only, with only the diff and the Canvas.

| Planted | Build | Expected | Reviewer verdict | Pass? |
|---------|-------|----------|------------------|-------|
| (a) the rule + constant copy-pasted into a second class `AccountDescriptionReapplier`, used by Update | 0 err / 0 warn | BLOCK ≥ Required | **BLOCK**: Required (rule + constant exist twice: DRY between the steps of one plugin); Required (diverges from the Canvas Structure without spec-first); Required (no fresh GREEN evidence) | pass |
| (b) hand-created plugin class `AccountDescriptionReapply` holding the Update step instead of `vela add step`; helper made `internal` and called across plugins | 0 err / 0 warn | BLOCK ≥ Required | **BLOCK**: Required (hand-created class, no `vela add plugin` in the Run trace, contradicts `reuse: add-step`); Required (cross-plugin sharing via another plugin's helper instead of a service); Required (no evidence for the diff) | pass |
| (c) Update step changed to `.PostOperation().Async()` with `IUpdatePostContext` | 0 err / **1 warn: VELA018** | BLOCK at Critical | **BLOCK**: Critical (an Async Target edit is lost, so the default is never saved, plus drift from the Canvas Approach); Required (stale evidence) | pass |

Note: planted (c) raised **VELA018** on the aliased Target write (`var target = ctx.Request.Target; ...
ApplyDefaultIfEmpty(target)`, flagged at the helper call). The 2026-10-13 run reported that VELA018 missed the
aliased form. With Vela.Plugins 0.35.0 it now catches it, so that Vela gap is resolved.

## Findings against the skills
1. minor - `skills/vela-code-review/SKILL.md:45-47` asks the spec axis to check "Sync/Async appropriate,
   reuse-vs-new respected". Step 4 only requires a findings list, so a PASS with no findings never states
   that each Canvas decision was checked. In this run the actor's reviewer summary confirmed the
   registration and DRY, but not the reuse-vs-new decision by name. Because of that, SC4's "spec axis
   confirms the reuse decision" can only be inferred. Suggested fix: on PASS, the reviewer lists the
   Approach/Structure decisions it verified (Sync/Async, reuse-vs-new, service-or-helper), one line each.

No blocker findings against the pack.

## Fixes
- none yet (finding 1 is open)

## Verdict
**pass**:
- checks are 20/20;
- every scenario decision and success criterion is met from the artifacts;
- all 3 planted violations were BLOCKed at the expected severity or higher (a/b Required, c Critical).

The next run should re-check that the reviewer's PASS explicitly names the reuse-vs-new decision
(finding 1).
