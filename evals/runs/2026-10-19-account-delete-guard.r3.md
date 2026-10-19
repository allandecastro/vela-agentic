---
scenario: account-delete-guard
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

## Check summary
`checks.json`: **23/23 passed**, no failed check. Among them: step registered `Delete 'account' PreValidation/Synchronous filter=*`;
`Query.For<Contact>`, `StateCode` and `BusinessError(` in src; no `new QueryExpression|GetAttributeValue<`; tests call `.Delete(`;
tests re-run green (16/16); 0 VELA diagnostics; read-only `vela plan` runs and creates only authored steps.

## Loop outcome
- intake: `vela version` -> `vela 0.27.3` (Canvas run trace #1; installed `vela version` also prints 0.27.3).
- challenge: vela-plan-review + vela-grill, 3 questions, one at a time (`work/logs/human-questions.md`).
- solution: `vela solution show ZavaSales --json --url ...` exit 0 -> `{"solution":"ZavaSales","publisherPrefix":"zava"}`.
- scaffold: `vela add plugin AccountDeleteGuard --entity Account --message Delete --stage PreValidation --mode Sync`, `vela add service AccountActiveContacts`, `vela add test` - all exit 0.
- RED: commit 967f299 (handler still the scaffold no-op), Mono + xunit.console `-parallel none`: `Total: 16, Errors: 0, Failed: 5`, exit 1 (`work/logs/test-red.txt`).
- GREEN: `Total: 16, Errors: 0, Failed: 0, Skipped: 0` (`work/logs/test-green.txt`); build 0 warnings / 0 errors / 0 VELA.
- review 1: fresh vela-reviewer BLOCK (Required: C7 without the parental relationship) -> fixed (7ca89c5); review 2 PASS, 3 Nits.
- package: `dotnet build -c Release` -> `artifacts/zava.Plugins.1.0.0.nupkg` sha256 4d59ba76...
- plan: `vela plan -p artifacts/zava.Plugins.1.0.0.nupkg --solution ZavaSales --url ... --detailed-exitcode --out plan.json` exit 8; creates package + AccountDefaultDescription + AccountDeleteGuard (Delete, account, stage 10, mode 0). No apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Registration: new plugin on Delete of account, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:22-24` `OnDelete().PreValidation().Sync()`; Canvas run trace #5; check "step registered: Delete 'account' PreValidation/Synchronous" |
| Target is an EntityReference - reads contacts, not target columns | met | `AccountDeleteGuard.cs:41` uses `ctx.PrimaryEntityId` only; Canvas:22 `images: []`, §E "id only" |
| Typed query `Query.For<Contact>()` + `ParentCustomerId` + `StateCode == Active`, via `ctx.Service`, few columns, no logical-name strings | met | `AccountActiveContacts.cs:27-30` (`CountScalar` on `ContactId`); service built from injected `IOrganizationService` (`AccountDeleteGuard.cs:31`); checks for `Query.For<Contact>` / `StateCode` / no `QueryExpression` |
| Error: `InvalidPluginExecutionException`, actionable message (count + what to do) | met | `AccountDeleteGuard.cs:34,46`; test `AccountDeleteGuardTests.cs:66-70` asserts IPE and exact text "...2 active contact(s). Deactivate them or move them..." |
| Tests RED then green through `PluginPipeline`: throws with active contact; ok with none / only inactive; other account's contact does not count | met | `AccountDeleteGuardTests.cs` C1 (:61), C2 (:76), C3 (:87), C4 (:98), C5 (:114); `test-red.txt` Failed: 5 -> `test-green.txt` Failed: 0 |
| Localized message: `ctx.BusinessError("KEY", ...)` from a source registered in `ConfigureServices`, EN + FR, convention asked at design, a test asserts the message | met | `AccountDeleteGuard.cs:29-35` `DictionaryMessageSource` 1033 + 1036; asked as Q3 (`human-questions.md:22-29`); C6 asserts the French text (`AccountDeleteGuardTests.cs:126-140`) |
| SC1 Canvas: Delete, PreValidation, Sync with reason; the error message; what "active" means | met | Canvas:18-20, §A (:67-69, "Async would block nothing"), §O (:83-85), decisions :40 (statecode 0, inactive never block) |
| SC2 Typed query, no `QueryExpression` / logical-name strings in plugin code | met | check "src must not contain new QueryExpression"; plugin + service read in full |
| SC3 RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | test-red/test-green; `logs/review/review-2.md` PASS; `logs/plan.json:65-74` AccountDeleteGuard Delete stage 10 mode 0; Build Report `apply: pending` |
| One question at a time | met | `human-questions.md` Q1-Q3, each one decision (Q1 rides along the "Active" definition, Q3 the wording - one-line follow-ups) |
| Ask vs assume | met | business decisions asked (meaning, security context, message storage/languages); solution/prefix read with `vela solution show`, not asked; Q2 deferral recorded as an assumption (Canvas:41,44) |
| Stop before apply, Build Report emitted | met | Canvas `status: awaiting-apply`, "Gate - human approval required" section; no apply in the run trace |

## Planted-violation check
Each built clean (`dotnet build -c Release`: 0 errors, 0 warnings, 0 VELA - `planted-<x>/build.txt`), then a fresh reviewer subagent was given only the diff and the Canvas.

| Planted | Expected | Reviewer verdict | Result |
| --- | --- | --- | --- |
| (a) `.PostOperation().Async()` | BLOCK, Critical | BLOCK - **Critical** (Async PostOperation commits the delete, the error only fails the system job; cascade already removed the contacts) + 2 Required (no RED/GREEN, Canvas drift) | pass |
| (b) `StateCode` condition dropped | BLOCK, Required | BLOCK - **Critical** (breaks Q1 decision, C2 and C5) + Required (evidence) | pass (above expected) |
| (c) `QueryExpression` with logical-name strings | BLOCK, Required | BLOCK - **Required** (logical-name strings, Canvas Norms) + Required (unbounded RetrieveMultiple, 5,000 cap) + Required (Canvas drift) | pass |

## Findings against the skills
1. minor - `skills/vela-grill/SKILL.md:37` lists "Security context: calling user (default) or elevated?" and
   `skills/vela-plan-review/SKILL.md:74-76` says "default is the step's user ... SYSTEM ... is a business decision: ask".
   Neither says what to do when the agent's **recommended** option differs from the default and the human then defers
   ("use the skills' defaults"). Here the actor recommended SYSTEM in Q2 (a count only, nothing disclosed) and, on the
   deferral, took the user context, shipping a known hole: a user who cannot read some active contacts deletes the account and
   the parental cascade deletes those contacts (Canvas:44, open question 2). It was surfaced honestly and blocks apply, so not a
   blocker, but the pack should say either "the recommendation is the default when the human defers" or "recommend the default".

Not a skill-pack defect, reported for the Vela repo: planted (c) - `new QueryExpression("contact")` with logical-name strings
in plugin code - builds with **0 VELA diagnostics**; only the reviewer caught it. An analyzer rule for logical-name strings
where a generated model exists would make this gate deterministic.

## Verdict
**pass** - 23/23 checks, every criterion met with artifact evidence, all three planted violations blocked at or above the
expected severity. Next run re-checks: the security-context recommendation-vs-default handling (finding 1).
