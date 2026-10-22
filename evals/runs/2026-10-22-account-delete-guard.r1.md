---
scenario: account-delete-guard
date: 2026-10-22
verdict: pass
campaign: 2026-10-22
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.28.0
framework: 0.41.1
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **23/23 passed**, no failed check (build, 0 VELA, tests re-run 12/12, Delete account
PreValidation/Synchronous step, typed `Query.For<Contact>`, `StateCode`, `BusinessError(`, `.Delete(` in tests,
`vela solution show`, read-only `vela plan` creates only authored steps).

## Loop outcome
- `vela version` -> 0.28.0; Vela.Plugins 0.41.1 (Canvas front-matter `framework`).
- Grill: 3 questions (`logs/human-questions.md`) - Q1 "active", Q2 languages/storage (+ count follow-up), Q3 security context -> defaults.
- `vela solution show ZavaSales --json` exit 0; `vela add plugin ... --message Delete --stage PreValidation --mode Sync`, `vela add service`, `vela add test` exit 0.
- RED `Total: 12, Failed: 5` (C1, C5 x2, C6, C7) -> GREEN `Total: 12, Failed: 0` (Mono xunit.console 2.9.2, `-parallel none`).
- Build Release 0 warnings / 0 errors / 0 VELA; spec-check 0 failures; isolated reviewer PASS (0 Critical/Required, 3 Nits).
- `vela plan -p artifacts/zava_zava.Plugins.1.0.0.nupkg --solution ZavaSales ...` exit 8, creates package + AccountDeleteGuard (Delete, stage 10, Sync) + AccountDefaultDescription; no `vela apply` run.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Registration: Delete account, Sync PreValidation, via `vela add plugin --message Delete` | met | `AccountDeleteGuard.cs:17-19`; Canvas run trace l.152; check "step registered: Delete 'account' PreValidation/Synchronous" |
| Target is an EntityReference; reads contacts, not target columns | met | `AccountDeleteGuard.cs:30` (`ctx.Request.Target.Id` only); Canvas l.22, l.63 |
| Typed query, ParentCustomerId + StateCode Active, user service, minimal columns, no logical names | met | `AccountActiveContacts.cs:25-28` (`Query.For<Contact>`, `CountScalar`); service wired with the step's user `IOrganizationService` (`AccountDeleteGuard.cs:25-26`); checks "no QueryExpression", "Query.For<Contact>", "StateCode" |
| Error: InvalidPluginExecutionException, actionable (count + deactivate/move) | met | `ctx.BusinessError` (`AccountDeleteGuard.cs:35`); `ProjectMessages.cs:16-19`; tests assert `InvalidPluginExecutionException` and the exact text (`AccountDeleteGuardTests.cs:61-64`) |
| Tests RED then green through PluginPipeline: active blocks; none / only inactive pass; other account's contact ignored | met | `logs/test-red.txt` Failed: 5, `logs/test-green.txt` Failed: 0; C1-C5 tests `AccountDeleteGuardTests.cs:52-139` |
| Localized message: BusinessError from a source registered once, EN + FR, a test asserts the message | met | `ProjectServices.cs` (`IServiceRegistrar` + `[assembly: VelaServiceRegistrar]`), `ProjectMessages.cs` 1033/1036; C6 test asserts the French text (`:141-158`) |
| SC1 Canvas: Delete, PreValidation, Sync with reason; message; what "active" means | met | Canvas README l.18-20, l.68-69 (reason), l.40 (active), l.111-114 (messages) |
| SC2 Typed query, no QueryExpression / logical-name strings in plugin code | met | `AccountActiveContacts.cs`; check passed (strings only in tests C6/C7, reviewer Nit 3) |
| SC3 RED->green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | test logs; `review.md` PASS; `plan.json` create step AccountDeleteGuard; no `vela apply` invocation in logs |
| Ask vs assume / one question at a time | met (minor note) | `logs/human-questions.md`: 3 sequential questions, each with a recommendation; Q2 carries a small "edge follow-up" on the count (two asks in one turn), harmless |

### C7 under Vela.Plugins 0.41.1 inherited access (asked by the campaign)
`Active_contact_the_user_cannot_read_is_not_counted` (`AccountDeleteGuardTests.cs:160-198`) **still proves what it claims**.
Probed in `planted-probe-c7/` (copy, `work/` untouched), results in `planted-probe-c7-test.txt`:
- Per the 0.41.1 XML docs (`InMemoryOrganizationService.Seed`), inherited access applies only to a child of a **declared parental relationship**. The actor's test declares none, so in the test as written inheritance is inert - and an account owner (Alice owning `control`) does *not* read a Bob-owned contact under it (probe `Probe_AlicesContactOwnedByBob_UnderAlicesAccount`: control not refused).
- With the realistic model declared (`.WithParentalRelationship("account", "contact", "parentcustomerid")`):
  the original C7 setup still passes (`Probe_Parental_OriginalC7`: account `id` is owned by Bob, so Alice inherits nothing, the delete goes ahead), and the control still refuses.
  Making Alice the account's owner flips it (`Probe_Parental_AccountOwnedByAlice`: refused with "1 active contact") - inheritance is live and the test's choice of Bob as account owner is what keeps the claim true.
- Giving Alice Organization-level contact Read also flips it (`Probe_ContactOrgRead`: refused), so the pass is due to the security model, not a disabled guard.
- Residual weakness (not a criterion failure): the test's comment "Alice reads only the contacts she owns" is incomplete for a real org (she also inherits read on contacts of accounts she owns), and the test does not declare the parental relationship, so it doesn't exercise the real-org inheritance.

## Planted-violation results
Each built clean (0 errors, 0 warnings, 0 VELA) in `planted-<x>/`; a fresh read-only vela-reviewer subagent got the diff text, the Canvas and the post-plant runner lines.

| Plant | Expected | Post-plant tests | Reviewer verdict | Result |
| --- | --- | --- | --- | --- |
| (a) `.PostOperation().Async()` | Critical | 12, Failed 5 | **BLOCK** - Critical (async runs after commit, cannot block the delete; cascade already removed the contacts) + 2 Required | pass |
| (b) StateCode condition removed | Required | 12, Failed 3 (C2, C5 x2) | **BLOCK** - Critical (spec drift: inactive contacts block) + Critical (red tests) + Required (stale Canvas evidence) | pass |
| (c) `QueryExpression` with logical-name strings | Required | 12, Failed 0 | **BLOCK** - 3 Required (unpaged RetrieveMultiple, logical-name strings + magic `0`, Canvas drift) | pass |

## Findings against the skills
1. minor - `references/harness-api.md` / `references/plugin-authoring-api.md:245` ("a test with `WithSecurity(...)` (roles, business units, teams)") says nothing about parental relationships. Since Vela.Testing 0.41.1, inherited access (Reparent/Share cascade) is modelled only when the test declares `WithParentalRelationship(...)`; without it a "user cannot read the child" test runs on a security model looser than the org's (an account owner reads its contacts in Dataverse). Here the actor's C7 happened to stay valid (the account owner is the other user), but nothing in the pack would have led it to model inheritance or to pick the owner deliberately. A one-line pointer to the Vela security-model guide (not a copy of it) would do.
2. minor - `references/build-report-template.md:187` example assumption "Contacts the user cannot read are not counted" is the shape the actor followed; it does not hint that "cannot read" includes inherited access through the parent account. Same fix as 1; no separate change needed.

## Verdict
pass - 23/23 checks, every criterion met, all three planted violations blocked at or above the expected severity. The C7 test remains valid under 0.41.1 inherited access (verified with the parental relationship declared). Next run: re-check that rights-dependent tests declare the parental relationship once the pack points at it.
