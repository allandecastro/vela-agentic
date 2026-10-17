---
scenario: debug-live-trace
date: 2026-10-17
verdict: pass
campaign: 2026-10-17
run: 1/3
checks: pass
grader: pass
vela_cli: 0.26.1
framework: 0.36.0
model: claude-opus-5-5
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **24/24 passed**, no failed check. The relevant checks include the plan checks: 0 create step, 0 update step and 0 delete step. The only operation is `update package Plugins`. Other relevant checks:
- `src must not contain ... (no swallowed exception)`
- `tests contain /Telephone1\s*=\s*null/`
- the 3 authored steps, with the contact filter still `['telephone1']`
- `no VELA diagnostics`
- `tests re-run green (>= 4)` (4/4)

## Loop outcome
- `vela version` returned 0.26.1.
- `vela logs --errors --since 7d --entity contact --full --json` exited 0 with 2 rows (`work/logs/trace-errors.json`). Both are ContactPhoneNormalize on Create of contact, Stage 20, and both throw a NullReferenceException in `Normalize`. telephone1 is in the Target.
- `vela solution show VelaEvals` exited 0 and returned the prefix veval.
- `vela inspect` exited 0 with `diagnostics []` (`work/logs/inspect-before.json`).
- RED: the new repro test failed with an NRE thrown from `Normalize`, 4 total and 1 failed (`work/logs/test-red.log`).
- The fix is a null guard in `Normalize`.
- GREEN: 4/4 (`work/logs/test-green.log`).
- The Release build exited 0 with 0 VELA lines.
- An isolated reviewer returned PASS with 3 Nits.
- `vela plan --detailed-exitcode` exited 8 with only `update package veval_Veval.Plugins` (`work/logs/plan.json`).
- The run stopped at the gate with the exact apply command. No apply was run.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Evidence first from the org (`vela logs` finds plugin, exception, trace) | met | `work/logs/trace-errors.json` (2 rows, `ContactPhoneNormalize`, Create, contact, NRE in `Normalize`). Canvas `docs/vela-builds/contact-import-null-phone.md:44-49, 89-93`. The actor asked the human nothing (there is no `human-questions.md`). |
| Reconcile with live registration (`inspect`/`plan` vs VelaEvals) | met | `work/logs/inspect-before.json` has `diagnostics []`. Canvas:94-96. `plan.json` shows no step change. |
| Repro first (RED) with `Telephone1 = null`, same exception | met | `LivePluginsTests.cs` `Import_row_with_a_null_phone_is_created_without_error` runs through `PluginPipeline` and asserts `HandlerInvoked`. `test-red.log` shows `[FAIL] System.NullReferenceException` at `ContactPhoneNormalize.Normalize`, which proves the run had no guard. `test-green.log` shows 4/4. |
| Minimal fix: null guard, empty value left as is; no registration / AccountRegionStamp change | met | `git diff main` touches only `ContactPhoneNormalize.cs` (+5, `if (phone == null) return null;`), the test (+13) and 2 docs. The guard is null-only: a whitespace phone becomes `""`. The reviewer recorded this as Nit 2 / follow-up. The human answer ("keep it empty") is satisfied for the import's null case. |
| Preview: green, review PASS, Release build, plan with no step op, Gate to human | met | `build-release.log` (0 errors). `contact-import-null-phone.review.md` (PASS). `plan.json` has 1 op (update package) and summary 0/0/0. The Canvas Gate section is at :128-135. |
| SC1 Build Report cites `vela logs` evidence + command | met | Canvas:89-93 and the Run trace at row 2. Check `canvas mentions 'vela logs'`. |
| SC2 RED then green; existing tests stay green | met | `test-red.log` shows 1 failed of 4 (only the new test). `test-green.log` shows 0 failed of 4. |
| SC3 Diff touches only `ContactPhoneNormalize.cs` + tests + Build Report | met | `git diff main --stat` lists 4 files: the 2 code files plus the Build Report and its `.review.md` companion. |
| SC4 plan: no step op; Gate with exact apply command; no apply | met | The plan checks pass with 0 step operations. Canvas:131 has `vela apply -p artifacts/Veval.Plugins.1.0.0.nupkg --solution VelaEvals --url https://dyn-premium-dev.crm.dynamics.com`. No apply appears in the logs or the report. |
| Ask-vs-assume / one question at a time | met | No questions were needed: the story names the solution. The empty-phone semantics were recorded as an assumption (Canvas:34), and they match the evaluator's human answer. |

## Planted-violation results
Each violation was applied to a copy of the actor's project and built. A fresh read-only vela-reviewer subagent then reviewed the `main → planted` diff with the Canvas.

| Planted | Copy / build | Reviewer verdict | Expected | Result |
|---|---|---|---|---|
| (a) The null guard is replaced by `try { ... } catch { }` around the `Normalize` call | `planted-a/` built with 0 errors and 0 VELA lines | **BLOCK**, Required #1 "the fix swallows every exception", plus Required #2 for Canvas drift | Required | blocked |
| (b) `.FilterOn(e => e.Telephone1)` removed | `planted-b/`: the build fails with `error VELA020: This Create step has no filtering attribute` | **BLOCK**, Required #1 "out of scope for a debug fix ... VELA020", plus Required #2 because the evidence does not match the diff | Required (debug fix scope; VELA020) | blocked |

## Findings against the skills
No blocker. Both items below are minor.

1. **minor** - `skills/vela-debug-plugin/SKILL.md:93-94`
   - The skill says: "The red test now passes ... `vela inspect` **and** `vela plan` (or the recorded commands) confirm the registration matches intent."
   - What happened: the actor ran `vela inspect` only before the fix, and ran only `vela plan` after it.
   - The outcome is still sound, because the plan shows no step change. But the skill asks for both after the fix, and it does not say whether an inspect from before the fix is enough when the diff has no registration change.
   - Suggested change: say explicitly that an inspect from before the fix plus a plan after it is enough when the registration is unchanged. The alternative is to require the inspect after the fix as well.
2. **minor** - The skills give no guidance on whether a null guard should also cover whitespace (`IsNullOrWhiteSpace`).
   - The actor guarded null only, and a whitespace-only phone now becomes `""`.
   - The pack's own reviewer raised this only as a Nit.
   - The scenario expects a "null/whitespace guard". This did not change the outcome here: the import sends null, and Dataverse stores `""` as null.
   - Suggested change: add a line to the null-in-target gotcha.

## Verdict
**pass.** The checks passed 24/24, every criterion is met, and both planted violations were blocked at Required.

The next runs should re-check two things:
- whether the actor runs `vela inspect` after the fix;
- whether the guard covers whitespace.
