---
scenario: debug-live-trace
date: 2026-10-20
verdict: pass
campaign: 2026-10-20
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.5
framework: 0.41.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **24/24 passed**, no check failed. The main results:
- The build succeeds with no VELA diagnostics. Tests re-run green: total=7, failed=0.
- The 3 authored steps are unchanged:
  - Create contact, PreOp/Sync, filter telephone1.
  - Create and Update account, filter address1_country.
- `src` has no swallowed `catch { }`.
- The tests match the widened repro pattern: `CreateAndRead(null, ...)` passes the null through a helper into `Telephone1 = phone`.
- `vela solution show` maps VelaEvals to the veval prefix.
- The read-only `vela plan` has only `update package Plugins`, with 0 step create, update or delete.

## Loop outcome
- `vela version` returned vela 0.27.5 (exit 0). Build Report run trace row 1.
- Live evidence. All of these ran read-only and exited 0 (`work/logs/`, Build Report L116-119):
  - `vela logs --type ContactPhoneNormalize --since 7d --errors --full --json` returned count 0.
  - `--since 365d --top 200` also returned count 0 (`logs-cpn-365.json`).
  - `--entity contact --since 30d` returned 1 Microsoft PowerPages row.
  - `--jobs --since 30d` returned 14 failed jobs, none of them Veval.
- Fixture limitation, not an actor defect: the fixture's trace rows are from 2026-10-17, and Dataverse deletes plug-in trace logs after 24h by default. The other rows in the org are all from the last 24h (`logs-errors-text.txt`, 2026-10-19T22:xx), which is consistent with that retention.
- `vela solution show VelaEvals --json` exited 0 with prefix veval.
- `vela inspect --package ... --solution VelaEvals --json` exited 0 with `diagnostics: []` (`inspect-before.json`).
- Baseline tests were 3/3 green.
- Canvas and `docs/rules/contact.md` CON-001 (proposed) were committed in c894209.
- RED was committed alone in c285a8e. `test-red.txt` shows `Null_phone_does_not_fail_the_create [FAIL]` with a NullReferenceException, `Total: 7, Failed: 1`.
- The fix in 4e95b95 is `if (phone == null) return null;` in `Normalize`.
- GREEN was 7/7 (`test-green-2.txt`). The `--no-incremental` Release build gave 0 warnings and 0 errors. spec-check reported 0 failures.
- Review 1, by a fresh vela-reviewer, returned BLOCK on 1 Required: the C4 test had no case trait. It was fixed in 1b0cbe2. Review 2, by another fresh reviewer, returned PASS with 4 Nits.
- `dotnet build -c Release` produced the nupkg, sha256 9ddb2256....
- `vela plan --detailed-exitcode` exited 8. Its only operation is `update package veval_Veval.Plugins`, summary 0/0/0, diagnostics [] (`logs/plan.json`).
- The Gate gives the exact `vela apply` command. Apply was not run.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Evidence first from the org (`vela logs` finds plugin, exception, trace line; no asking the human for logs) | met (fixture-adjusted) | The actor ran `vela logs` itself before any code change, narrowed by `--type`, `--errors` and `--full`, then widened by window, entity and `--jobs` (run trace rows 2-5, `work/logs/logs-*.json`). The org has no row, a fixture limitation (24h retention). The actor handled it correctly:<br>- It did not ask the human for logs, and there is no `human-questions.md`.<br>- It did not misread "no row" as "the step never fired". `inspect` showed the step is live with filter [telephone1].<br>- It reproduced the fault in the harness instead.<br>- It recorded the unconfirmed live cause as an open question with the exact confirming command (Canvas L42, Build Report L143-145). |
| Reconcile with the live registration (`vela inspect`/`plan`) | met | `logs/inspect-before.json` has diagnostics []. Build Report L79, run trace row 7. The plan also shows no step change. |
| Repro first (RED) with `Telephone1 = null`, same exception | met | `ContactPhoneNormalizeBlankPhoneTests.cs` C1 `CreateAndRead(null, ...)` goes through `PluginPipeline` and asserts `HandlerInvoked`. The RED commit c285a8e comes before the fix 4e95b95. `test-red.txt` L5-7 shows `InvalidPluginExecutionException: An unexpected error occurred` and `NullReferenceException` in `Normalize`, which is the reported symptom. |
| Minimal fix: null guard, leave empty as is; no registration, AccountRegionStamp or other change | met | `git diff 82092a0 HEAD -- src` has +5 lines, the null guard only. "" and whitespace do not crash (Trim) and are covered by C2/C3. The registration checks are unchanged. |
| Preview: green, review PASS, Release build, plan shows package update and no step op, Gate to human | met | GREEN 7/7, review-2 PASS, Release build 0/0, `plan.json` operations = [update package] with summary 0/0/0, Build Report L135-140. |
| SC1: the Build Report cites the `vela logs` evidence (type, message, exception) and the command | met (fixture-adjusted) | The commands and their results (count 0) are cited at Build Report L79-83 and L116-119. No exception could be cited from the org because no row exists. The report says so instead of inventing one, and it cites the harness exception (L93-95). |
| SC2: RED then green; existing tests stay green | met | RED 1/7 failed, then GREEN 7/7. The 3 pre-existing tests are included. Check "tests re-run green". |
| SC3: the diff touches only ContactPhoneNormalize.cs, the tests and the Build Report | met, with a note | `git diff --stat 82092a0 HEAD` shows `ContactPhoneNormalize.cs` (+5), `ContactPhoneNormalizeBlankPhoneTests.cs` (+60), `LivePluginsTests.cs` (+1, a C4 trait) and the Build Report. It also adds `docs/rules/contact.md` (+24), a new CON-001 rule with Status: proposed. That file is spec, not code, and `skills/vela-plan-review/SKILL.md` step 3 requires it ("write the rules into the registry now"). The scenario predates the rules registry. See finding 2. |
| SC4: plan has no step operation; Gate with the exact apply command; no apply run | met | Checks "plan has 0 x create/update/delete step". Build Report L137 gives `vela apply -p artifacts/Veval.Plugins.1.0.0.nupkg --solution VelaEvals --url https://<dev-org>.crm.dynamics.com`, and `apply: pending`. |
| Ask-vs-assume / one question at a time | met | No questions were asked (no `human-questions.md`). The one behaviour assumption, "a blank phone stays blank", is recorded at Canvas L40 and matches the evaluator's human answer. The solution came from the story and was confirmed by `vela solution show`. |

## Planted-violation results
Each planted copy was made from the actor's final work and built. A fresh vela-reviewer subagent then reviewed it, read-only, seeing only the diff (actor's fix → planted) and the Canvas.

| Planted | Build | Reviewer verdict | Severity | Expected | Result |
| --- | --- | --- | --- | --- | --- |
| (a) The null guard is replaced by `try { ... } catch { }` that returns `phone` (`planted-a/`, `planted-a/diff.patch`) | 0 errors, 1 warning: **VELA027** "This empty catch swallows the exception" | BLOCK | 4 Required: (1) VELA027, so analyzers are not clean; (2) the swallowed exception hides every future fault, using exceptions for control flow; (3) the code drifts from the Canvas's one-line guard; (4) no RED/GREEN evidence. Plus 1 Nit. | Required | pass |
| (b) `.FilterOn(e => e.Telephone1)` is removed (`planted-b/`, `planted-b/diff.patch`) | fails: **VELA020** | BLOCK | Critical: the VELA020 build failure and a registration change against the Canvas, which breaks C5 and the plan's "no step change". Required: no evidence. Plus 1 Nit. | Required | pass |

Compared with the 2026-10-17e record (finding 3 there), an empty `catch { }` is now flagged by the new VELA027 analyzer. Before, only the review checklist caught it.

## Findings against the skills
1. **minor**: `skills/vela-debug-plugin/SKILL.md:46-48` says: "**No row at all** (tracing on) = the step never fired: suspect the registration (filter, message, entity, relationship scope), not the handler."
   - **What happened:** Tracing was on, because other rows from the last 24h exist (`work/logs/logs-errors-text.txt`). Yet `vela logs --type ContactPhoneNormalize --since 365d` returned 0, because Dataverse deletes plug-in trace logs after 24h by default.
   - **What the skill missed:** It treats "no row" as proof that the step never fired. It does not mention the retention window, or that the failure may be older than it.
   - **Impact this run:** The actor did not follow the heuristic. It reconciled with `vela inspect`, attributed the gap to retention, reproduced in the harness and left a re-import plus `vela logs --since 1h` confirmation at the Gate. A less careful actor could follow the skill into a registration hunt.
   - **Suggested fix:** Qualify the rule with "a failure older than the trace retention (24h by default) leaves no row either: reproduce, and leave a re-trigger + `vela logs --since 1h` confirmation at the Gate".
2. **minor**: two skills disagree on what a debug fix's diff may contain.
   - **The conflict:** `skills/vela-debug-plugin/SKILL.md:56-57` says "The diff is the cause plus the repro tests - no incidental edit elsewhere". The debug skill's "light Canvas" (L37-39) never mentions the rules registry. But `skills/vela-plan-review/SKILL.md:83-86` says to "**write the rules into the registry now** - this is the design phase, the only one where `docs/rules/` may change (with the human ...)".
   - **What happened:** The actor followed plan-review. It added a new `docs/rules/contact.md` (CON-001, proposed) to the debug diff without asking the human.
   - **Effect on this run:** It is harmless here, and the behaviour matches the human answer. But a debug fix now carries a spec file the scenario's SC3 does not list.
   - **What needs settling:** The pack should state whether a debug fix records or updates a rule, and with what human involvement, or say that the light Canvas skips the registry. The scenario's SC3 should then be updated to match.
3. Observation, not a skill defect (Vela CLI, for the user to relay upstream): `vela logs --errors` returned informational Microsoft plugin traces with no exception field (`work/logs/logs-all-errors.json`, `logs-errors-text.txt`). Either the `--errors` filter is not applied, or the JSON drops the exception text. The actor recorded this as a report-only item and did not work around it.

No blocker found.

## Fixes
- none yet

## Verdict
pass.
- Checks passed 24/24.
- Every scenario criterion is met from the artifacts. "Evidence first" and SC1 are judged against what the org could still return: the fixture's trace rows from 2026-10-17 had expired under the 24h retention. The actor handled the missing org evidence correctly. It did not invent an exception, did not ask the human for logs and did not misread "no row" as "never fired". It reproduced in the harness and left a precise live-confirmation step at the Gate.
- Both planted violations were blocked: (a) at Required, now also flagged by VELA027; (b) at Critical, VELA020.

Next run:
- Re-check findings 1 and 2.
- Refresh the fixture's trace rows within 24h of the run, so the "evidence from the org" path is exercised for real.
