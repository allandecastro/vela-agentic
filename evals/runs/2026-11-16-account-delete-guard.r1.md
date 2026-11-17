---
scenario: account-delete-guard
date: 2026-11-16
verdict: pass
campaign: 2026-11-16
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.31.0
framework: 0.43.0
runner: campaign actor + separate grader
mutation: 7/7, 0 missing test(s)
---

## Loop outcome
Paths below are relative to `r1/work/ZavaSales/`. The trace is `.vela-runs/account-delete-guard/trace.md`.
- version: `vela version` → 0.31.0 (exit 0).
- grill: Q1-Q4, one question at a time (`logs/human-questions.md`). Q1 "active" = parentcustomerid + statecode Active. Q2 security context: the human deferred, so the actor used the caller and kept its SYSTEM recommendation as a gate question. Q3: EN 1033 + FR 1036 in the in-code dictionary. Q4 roles: the human deferred.
- Canvas + rule ACC-002 committed before any test (4f05e11).
- scaffold:
  - `vela solution show ZavaSales` → exit 0, `zava`.
  - `vela add step AccountDefaultDescription --message Delete --stage PreValidation --mode Sync --handler OnDeleteGuard` → exit 0.
  - `vela add service AccountActiveContacts --entity Contact` → exit 0.
  - `vela add test` → exit 0.
  - No model change.
- RED (8b732d0): mono xunit `Total: 11, Failed: 3` (C1 refuse, C5, C7).
- GREEN: `Total: 11, Errors: 0, Failed: 0, Skipped: 0`.
- Build: 0 Error(s) / 0 Warning(s), no VELA00x.
- spec-check: 0 failure(s).
- review (isolated vela-reviewer):
  - Round 1: BLOCK, 1 Required (weak C6 assertion) + Nits. Fixed in 5e99dd9.
  - Round 2: PASS.
- package: `artifacts/zava_zava.Plugins.1.0.0.nupkg` (dll present), unsigned (signing requirement unknown).
- `vela plan --solution ZavaSales --detailed-exitcode` → **exit 8**, `diagnostics: []`. It creates the package, the ACC-001 Create step (baseline, never deployed) and the **Delete · account · PreValidation · Sync** step.
- No `vela apply`. Status: awaiting-apply.

## Checks
23/23 passed (`checks.json`). No failed check.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Registration: Delete of account, Sync PreValidation | met | `AccountDefaultDescription.cs:25-29`; check "step registered: Delete 'account' PreValidation/Synchronous". The step is on the table's existing plugin (`vela add step`), not from `vela add plugin` as the scenario says. The pack requires this: registration-rules.md:63-65 "The table has one (whatever its name) → each story is a step on it". See finding 1. |
| Target is an EntityReference; reads contacts, not target columns | met | `AccountDefaultDescription.cs:36` `ctx.Request.Target.Id`; Canvas `images: []`. |
| Typed query, ParentCustomerId + StateCode Active, caller service, minimal columns | met | `AccountActiveContacts.cs:30-33` (`Query.For<Contact>()`, two typed `Where`, `CountScalar`). The caller `IOrganizationService` is wired at `ProjectServices.cs:24`. Checks for typed query / StateCode / no QueryExpression pass. |
| IPE with an actionable message (count, deal with contacts first) | met | `Messages.cs:21-24` gives the count and says to deactivate or move the contacts. Tests assert the exact text at `AccountDefaultDescriptionTests.cs:78-80`. |
| Tests RED then green through PluginPipeline (active blocks; none / inactive-only succeed; another account's contact does not count) | met | Trace rows 9 and 12. Tests C1 (:72), C2 (:87), C3 (:100), C4 (:112) all go through `p.Service.Delete`. Mutation 7/7 killed. |
| Localized: `ctx.BusinessError` + source registered in services, EN + FR, message asserted | met | `AccountDefaultDescription.cs:39`, `ProjectServices.cs:21`, `Messages.cs:21-24`. C1 asserts EN (:80) and C5 asserts FR (:134). |
| SC1: Canvas has Delete, PreValidation, Sync + reason, the message, what "active" means | met | README.md:7-9 and :44 (reason), :32 (message), :40 (Q1 definition). |
| SC2: typed query, no QueryExpression / logical-name strings in plugin code | met | Same check. The only logical-name strings are in tests (`"parentcustomerid"`, `"usersettings"` for the harness). |
| SC3: RED→green; review PASS; plan shows the Delete step; no apply | met | Trace rows 9, 12, 18, 21. `plan.json` and `check-plan.json` hold the Delete step. No apply in the trace or logs. |
| One question at a time; asks rather than assumes | met | `logs/human-questions.md`: Q1-Q4 each asked separately. The deferred answers are recorded as assumptions (README.md:41, :43) and re-raised at the gate (:131-136). |
| Stop before apply with a Build Report | met | README.md:123-136 has the gate, the apply command, rollback and blocking decisions. |

## Planted-violation check
Each violation was applied to a copy of the project (`r1/planted-<x>/`) and built with 0 errors. Each was then reviewed by a fresh general-purpose subagent acting as `agents/vela-reviewer.agent.md` (pack read from the repo), given the diff and the Canvas.

| Plant | Expected | Verdict / top severity | Result |
| --- | --- | --- | --- |
| (a) `.PostOperation().Async()` | Critical | BLOCK / **Critical**: "An Async PostOperation step cannot block the delete". It cites registration-rules "Async ... Never for validation". | pass |
| (b) StateCode condition dropped | Required | BLOCK / **Critical** (≥ Required): inactive contacts now block, which breaks C2 and contradicts Q1/ACC-002. | pass |
| (c) QueryExpression + logical-name strings | Required | BLOCK / **Required**: logical-name strings where `Query.For<T>()` fits. It also flags `RetrieveMultiple().Entities.Count` as unbounded and capped at 5000 (Required). | pass |

## Mutation triage
7 killed, 0 survived, 0 invalid (score 1.0). No survivors to triage. The two `drop Where` mutants on `AccountActiveContacts.cs:30` were killed: C2 kills the StateCode one and C4 kills the ParentCustomerId one.

## Findings
1. minor (eval scenario, not a skill): `evals/scenarios/account-delete-guard.md` says "a new plugin on Delete ... scaffolded with `vela add plugin ... --message Delete`". The pack says the opposite in `using-vela/references/registration-rules.md:63-65`: "One plugin class per table ... The table has one (whatever its name) → each story is a step on it (`vela add step`)". The actor followed the pack. Align the scenario's "What the skills must get right" with the one-class-per-table rule.
2. minor: the Q2 default security context (`vela-grill/SKILL.md:44`, `vela-plan-review/SKILL.md:92`: "default is the step's user (`ctx.Service`)") leaves a hole in a **blocking guard**. When the actor applied the default, active contacts the deleter cannot read are not counted, and the parental cascade then deletes them (case C6, README.md:37, :132-134). That contradicts the story's plain wording. The actor caught this, recommended SYSTEM and escalated it at the gate, so the run is fine. The skills, though, do not say that a guard/validation counting related rows is the typical case where the caller default under-counts. Consider one line in the plan-review security-context bullet.
3. minor: `vela-code-review/SKILL.md:34` says to "paste their **contents**" into the reviewer's material. The actor's first reviewer dispatch died on a network error and two resumes failed. The successful dispatch got its material as a file (`.vela-runs/.../review-material.md`) instead of pasted inline, and the actor flagged this itself. The skill gives no guidance for a large or failing dispatch. This is an observation, and the review was still independent and valid.
4. minor: in round 1 the reviewer raised a Nit that "the harness skill is vela-test-harness". The pack repo names it `vela-plugin-testing`, but the installed plugin in this host still lists `vela:vela-test-harness`. A stale installed copy is leaking a skill name into reviews. Re-install or bump the plugin before the next campaign. Not a defect in the repo's skills.

## Verdict
**pass**:
- Checks: 23/23.
- Every scenario criterion and success criterion is met from the artifacts.
- All 3 planted violations BLOCK at or above the expected severity.
- Mutation: 7/7.

The next run must re-check:
- the scenario's `vela add plugin` wording (finding 1);
- that the gate question on the security context is still raised when the human defers.
