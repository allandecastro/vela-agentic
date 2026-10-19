---
scenario: account-deactivate-cascade
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, `pass: true`. No check failed. The checks covered:
- a Canvas that mentions `statecode` and `SetState`;
- a clean build with no VELA diagnostics;
- 12 tests green on re-run;
- the step Update / account / PostOperation / Synchronous with filter `[statecode]`;
- no step on SetState or SetStateDynamicEntity;
- `Query.For<Contact>` and `StateCodeOptionSet.Inactive` in src;
- no `QueryExpression`, `GetAttributeValue` or `SystemService` in src;
- `new SetStateRequest` in the tests;
- a read-only plan that creates only the package and the authored steps.

## Loop outcome
Read from the Run trace in `docs/vela-builds/account-deactivate-cascade.md` (lines 140-155) and from `work/logs/`.
- `vela version` returned 0.27.3, exit 0.
- `vela solution show ZavaSales --json`, exit 0, prefix `zava`.
- Two questions to the human, one at a time: Q1 timing, Q2 security context. Q2 was answered "use the defaults".
- The Canvas and rule ACC-002 (proposed) were committed first (`b3a018c`).
- `vela models --entities account,contact --verify`, exit 0, in sync.
- `vela add plugin ... --message Update --stage PostOperation --mode Sync --filtering-attributes StateCode`, exit 0. `vela add test`, exit 0.
- RED commit `eb29c99`: `Total: 12, Errors: 0, Failed: 4` (C1, C2, C3, C7). Then the implementation, commit `5b14285`.
- GREEN: `Total: 12, Errors: 0, Failed: 0`.
- `spec-check`: 0 failures.
- Isolated reviewer: PASS, 0 Critical, 0 Required, 5 Nits. Two Nits were synced into the Canvas.
- Release build: `artifacts/zava.Plugins.1.0.0.nupkg`, unsigned.
- `vela plan --solution ZavaSales --detailed-exitcode`, exit 8. It creates the package, the step AccountDeactivateCascade, and the step AccountDefaultDescription (baseline, never deployed; raised as an open question).
- Stopped at the gate with `apply: pending`. No apply.

## Criteria

| Criterion | Met? | Evidence |
|---|---|---|
| Update step on `account` filtered on `statecode`, not SetState (VELA022) | met | `AccountDeactivateCascade.cs:17-20`; check "step registered: Update 'account' PostOperation/Synchronous filter=['statecode']"; checks "no step on SetState / SetStateDynamicEntity"; Canvas line 49 and Safeguards line 106 ("Not SetState (VELA022)") |
| Transition: act only on new state Inactive; reactivation does nothing | met | `AccountDeactivateCascade.cs:28-33` (Target Inactive and pre-image not Inactive); C4 test `:129-139`; Canvas lines 46, 48, 74 |
| Sync PostOperation, with the reason (immediate, all-or-nothing) | met | `.PostOperation().Sync()` at `:18-19`; Canvas Approach lines 71-74 and decision line 41; C7 proves the rollback (`Tests.cs:165-199`) |
| Typed query `Query.For<Contact>()`, writes `StateCode` + `StatusCode` with `ctx.Service`; no SystemService without a reason | met | `:35-50`; checks "src contains Query.For<Contact>", "src must not contain SystemService" |
| No logical-name strings in plugin code | met | `AccountDeactivateCascade.cs` has none; the only one in the change is `"systemuser"` in the tests (`Tests.cs:172-176`), a reviewer Nit |
| Tests through `PluginPipeline`: Update deactivates; SetStateRequest does too; reactivation does nothing; another account untouched | met | `Tests.cs:22` (`PluginPipeline`), C1 `:86`, C2 `:99-113` (`new SetStateRequest`), C4 `:130`, C3 `:116` |
| Canvas: Update + statecode filter and why not SetState; Sync PostOperation and why; the transition | met | Canvas lines 18-22, 49, 70-74, 94, 106 |
| RED then green | met | `logs/test-red.log`: Failed 4, failures C1/C2/C3/C7 named verbatim; `logs/test-green.log`: Failed 0. The RED commit `eb29c99` (tests only) precedes the feat commit `5b14285` |
| Review PASS | met | `logs/review/review-1.md`: "Verdict: PASS", no Critical or Required |
| `vela plan --solution ZavaSales` shows the new Update step | met | `logs/plan.json` operations: create step `zava.Plugins.Account.Plugins.AccountDeactivateCascade`; Canvas line 133 (stage 40, Sync, filter statecode); check "read-only vela plan runs" |
| No apply | met | Canvas `apply: pending`, `status: awaiting-apply`; no apply in the Run trace |
| One question at a time; ask vs assume | met | `logs/human-questions.md`: Q1 (timing, a real human decision) and Q2 (security context) asked separately. Q2's "use the defaults" is recorded as an assumption (Canvas line 44). The parentcustomerid scope, status reason Inactive and no reactivation are assumed in line with the key and recorded (Canvas lines 45-48) |

## Planted-violation results
Each violation was applied to a copy under `r1/planted-<x>/` (diffs in `r1/planted-<x>.diff`). Each copy built clean with 0 errors, 0 warnings and no VELA diagnostics. A fresh read-only subagent acting as vela-reviewer got only the diff and the Canvas. As extra evidence, the actor's own suite was re-run on each copy.

| Planted | Expected | Reviewer verdict | Pass? | Suite on the copy |
|---|---|---|---|---|
| (a) transition guard removed | Critical | BLOCK: 2 Critical (C4 reactivation, C6 re-send), 1 Required (no fresh run) | pass | Failed 2 (C4, C6) |
| (b) contact write switched to `ctx.SystemService`, no Canvas reason | Required | BLOCK: 1 Critical (C7 broken, privilege escalation), 2 Required (SystemService against the human Q2 decision, review-checklist:76-77; no fresh run) | pass (higher severity) | Failed 1 (C7) |
| (c) step moved to `.Async()` | Required | BLOCK: 1 Critical (breaks the Q1 all-or-nothing decision and C7), 2 Required (Canvas drift; stale evidence and plan) | pass (higher severity) | Failed 1 (C7) |

## Findings against the skills
1. **minor** - `skills/vela-plugin-authoring/references/plugin-authoring-api.md:125` shows `.ToList(ctx.Service);   // or .FirstOrDefault(svc), ...` but never says whether `ToList` pages past the 5000-row page.
   - The actor recorded "Not verified whether Query.ToList pages past the 5000-row page" (Canvas line 50).
   - The reviewer raised the same uncertainty as a Nit ("unless Vela's `ToList` pages").
   - For a cascade over child records, that is a silent-miss risk that neither agent could settle from the pack.
   - The reference should state the paging behaviour in one line.
   - If Vela does not document it, flag it to the Vela repo rather than adding a workaround in the skill.

No blocker against the skills.

## Fixes
- None yet.

## Verdict
**pass**. Checks are 25/25, every criterion is met, and all three planted violations were BLOCKed at or above the expected severity.

The next run must re-check two things:
- that the actor keeps the Update + `statecode` registration (no SetState);
- that it records the paging question if the reference is still silent.
