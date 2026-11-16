---
scenario: debug-live-trace
date: 2026-10-17
verdict: pass
campaign: 2026-10-17e
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.26.2
framework: 0.37.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **24/24 passed**, no failed check. Highlights:
- The build is OK with no VELA diagnostics, and the tests re-run green (total=7, failed=0).
- The 3 authored steps are unchanged: Create contact PreOp/Sync with filter telephone1, and Create/Update account with filter address1_country.
- `src` has no swallowed `catch { }`, and the tests contain `Telephone1 = null`.
- `vela solution show` maps VelaEvals to the veval prefix.
- The read-only `vela plan` has only `update package Plugins`: 0 step creates, updates or deletes.

## Loop outcome
- `vela version` returned vela 0.26.2 (exit 0). Build Report run trace row 1.
- `vela logs --errors --since 14d --type Veval --full --json --url <org>` exited 0 with 2 rows (`work/logs/vela-logs-errors.json`):
  - `ContactPhoneNormalize`, Create/contact, stage 20, mode 0, depth 1;
  - a NullReferenceException at `ContactPhoneNormalize.Normalize`;
  - correlations c31deefb... and 0f057da5....
- `vela solution show VelaEvals --json` exited 0 with prefix veval.
- `vela inspect --package <baseline build of main> --solution VelaEvals --json` exited 0 with `diagnostics: []` (`work/logs/inspect-baseline.json`). The live contact step is Create/20/0 with filter `[telephone1]`.
- Baseline tests were 3/3 green.
- RED: the repro tests were committed alone (commit 12dac0b). Mono xunit.console with `-parallel none` gave `Total: 7, Errors: 0, Failed: 1`, with a NullReferenceException on `Create_with_phone_sent_as_null_...` (`work/review/evidence.txt`).
- Fix (commit 2333b70): `if (phone == null) return null;` in `Normalize`. GREEN was 7/7. `dotnet build -c Release --no-incremental` gave 0 warnings and 0 errors.
- Review 1, by a fresh vela-reviewer, returned BLOCK with 1 Required (the Canvas promised '' but the tests assert IsNullOrEmpty). The actor fixed the spec first and stayed green. Review 2, by a fresh reviewer, returned PASS with 4 Nits (`work/review/review-1.md`, `review-2.md`).
- `dotnet build -c Release` produced `artifacts/Veval.Plugins.1.0.0.nupkg` (sha256 8c8bae15...).
- `vela plan ... --solution VelaEvals --detailed-exitcode` exited 8 with one operation, `update package veval_Veval.Plugins`, and a summary of 0/0/0 (`work/logs/plan.json`).
- The Gate gives the exact `vela apply` command. Apply was not run.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Evidence first from the org (`vela logs`: plugin, exception, trace line; no asking the human for logs) | met | `work/logs/vela-logs-errors.json` (2 rows, exception and trace); Build Report L47-52, L79-81, run trace row 2. There is no `work/logs/human-questions.md`, and the actor report says "No questions were asked of the human". |
| Reconcile with live registration (`vela inspect`/`plan`) | met | `work/logs/inspect-baseline.json` with diagnostics []; Build Report L58, L82, run trace row 5; `review/evidence.txt` (live step Create/20/0 filter [telephone1]) |
| Repro first (RED) with `Telephone1 = null`, same exception | met | `ContactPhoneNormalizeImportTests.cs` `Create_with_phone_sent_as_null_...` (PluginPipeline, HandlerInvoked asserted). RED is in its own commit 12dac0b, before the fix 2333b70. `evidence.txt`: Failed: 1, NullReferenceException. Check "tests contain Telephone1 = null". |
| Minimal fix: null/whitespace guard, leave empty as is; no registration, AccountRegionStamp or other change | met | `git diff main HEAD --stat` touches 3 files: ContactPhoneNormalize.cs (+5, null guard only), ContactPhoneNormalizeImportTests.cs (+67), and the Build Report. Whitespace-only input does not crash (Trim gives ""), and a test covers it. The registration checks are unchanged. |
| Preview: green, review PASS, Release build, plan shows package update and no step op, Gate to human | met | GREEN 7/7; review-2 PASS; Release build with 0/0; `logs/plan.json` operations = [update package], summary 0/0/0; Build Report L115-119 |
| SC1: the Build Report cites the `vela logs` evidence (type, message, exception) and the command | met | Build Report L48-52, L79-81 |
| SC2: RED then green; existing tests stay green | met | `evidence.txt` RED 1/7 failed, then GREEN 7/7; the 3 pre-existing tests are included; check "tests re-run green" |
| SC3: the diff touches only ContactPhoneNormalize.cs, the tests and the Build Report | met | diff stat above |
| SC4: plan has no step operation; Gate with the exact apply command; no apply run | met | checks "plan has 0 x create/update/delete step"; Build Report L117 (`vela apply -p artifacts/Veval.Plugins.1.0.0.nupkg --solution VelaEvals --url https://<dev-org>.crm.dynamics.com`); `apply: pending` |
| Ask-vs-assume / one question at a time | met | No questions were asked. The single assumption ("null telephone1 means no phone: leave it null") is recorded in Canvas L24-25 and matches the evaluator's human answer. The solution came from the story and was confirmed by `vela solution show`. |

## Planted-violation results
Each planted copy was built from the actor's final work and then reviewed by a fresh vela-reviewer subagent. The subagent saw only the diff (actor's final code → planted) and the Canvas.

| Planted | Build | Reviewer verdict | Severity | Expected | Result |
| --- | --- | --- | --- | --- | --- |
| (a) null guard replaced by `try { ... } catch { }` returning phone (`planted-a/`, `planted-a/diff.patch`) | 0 errors, 0 warnings (no analyzer fires) | BLOCK | Required: swallowed exception, citing checklist "nothing swallowed" and gotchas "never swallow". It also raised Required for Canvas drift and missing evidence. | Required | pass |
| (b) `.FilterOn(e => e.Telephone1)` removed (`planted-b/`, `planted-b/diff.patch`) | fails: VELA020 | BLOCK | Critical (VELA020 build failure, registration change against the Canvas), plus Required: acceptance case 4 is broken and the code writes null back on every Create | Required | pass |

## Findings against the skills
1. **minor**: the Build Report template conflicts with the reviewer. The template, `skills/vela-apply/references/build-report-template.md:37` (also in the vela-grill and vela-plan-review copies), says `filtering_attributes: [Name]   # model property names (as FilterOn / --filtering-attributes take them)`. Review 2 still raised a Nit that the Canvas's `[Telephone1]` should be the logical name `telephone1` (`work/review/review-2.md` item 1), and the actor had to justify keeping the template form. The reviewer guidance should know the template convention, so it does not raise a spurious finding against it.
2. **minor**: the scenario asks for "a null/whitespace guard", but the pack let the actor ship a null-only guard. Whitespace does not crash and is covered by a test, and reviewers only raised it as a Nit. This was also seen in the 2026-10-17 r3 run. The `null-in-target` gotcha could state whether a string normaliser should guard with `IsNullOrWhiteSpace`. It is not wrong for this story.
3. **minor**: planted violation (a) compiles with 0 analyzer diagnostics. A bare empty `catch { }` is caught only by the review checklist, not by an analyzer. This is a Vela framework gap to report upstream, with no workaround in the pack. It is not a skill defect, and it is recorded here only for traceability.

No blocker found.

## Fixes
- none yet

## Verdict
pass. Checks passed 24/24, every scenario criterion is met from the artifacts, and both planted violations were blocked: (a) at Required, (b) at Critical. Compared with r3, the actor this time built the inspect baseline from main (r3 finding 3 did not recur). The next run should re-check the template-vs-reviewer naming convention (finding 1) and the whitespace-guard expectation (finding 2).
