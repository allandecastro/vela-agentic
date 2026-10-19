---
scenario: account-delete-guard
date: 2026-10-19
verdict: pass
campaign: 2026-10-19b
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Loop outcome
- Checks: **23/23 passed** (`checks.json`), no failed check.
- Intake: 3 questions, one at a time (`work/logs/human-questions.md` Q1-Q3): active contacts, security context, message languages and source.
- `vela solution show ZavaSales` exit 0. `vela models --verify` exit 0 (2 tables in sync).
- `vela add plugin AccountDeleteGuard --message Delete --stage PreValidation --mode Sync`, `vela add service`, `vela add test`: each exit 0.
- RED (Mono xunit `-parallel none`): exit 1, 13 total / 5 failed. GREEN: exit 0, 13 / 0 failed.
- Release build: 0 warnings, 0 VELA. spec-check: 0 failures.
- Isolated reviewer: PASS (0 Critical, 0 Required, 3 Nits).
- `vela plan --solution ZavaSales` exit 8: creates the package, the AccountDeleteGuard step and the AccountDefaultDescription step.
- No apply. Status: awaiting-apply.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| Registration: Delete account, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:22-24`; Canvas run trace row 5; check "step registered: Delete 'account' PreValidation/Synchronous" |
| Target is an EntityReference; the check reads the contacts, not the target's columns | met | `AccountDeleteGuard.cs:42` uses `ctx.PrimaryEntityId` only; Canvas E section |
| Typed query `Query.For<Contact>` with ParentCustomerId + StateCode Active, through `ctx.Service`, minimal columns, no logical names | met | `AccountActiveContacts.cs:26-29` (CountScalar aggregate); service built on the step's `IOrganizationService` (`AccountDeleteGuard.cs:31`); checks "Query.For<Contact>", "StateCode", "no QueryExpression" |
| `InvalidPluginExecutionException` with an actionable message (count; deactivate or move) | met | `ctx.BusinessError` at `AccountDeleteGuard.cs:47`; 1033 text at `:34` |
| Tests: RED then green through PluginPipeline (throws with active; deleted with none or inactive only; another account's contact does not count) | met | `AccountDeleteGuardTests.cs` C1/C2/C3/C4; `logs/test-red.log` (5 failed), `logs/test-green.log` (0 failed) |
| Localized message: `ctx.BusinessError("KEY")`, source registered in `ConfigureServices`, EN + FR, project convention **asked at design**, a test asserts the message | met | `human-questions.md` Q3 asks for both the languages and where the texts live (answer: 1033/1036, in-code dictionary); `AccountDeleteGuard.cs:29-35`; tests C1 (`:67-68`) and C5 (`:120-121`) assert the text |
| SC1 Canvas: Delete, PreValidation, Sync with the reason; the message; what "active" means | met | Canvas `account-delete-guard.md:17-20, 39, 65-66, 86-88` |
| SC2 typed query, no QueryExpression / logical-name strings in plugin code | met | `AccountActiveContacts.cs`; check "src must not contain new QueryExpression" |
| SC3 RED then green; review PASS; plan shows the new Delete step; no apply | met | logs above; `account-delete-guard.review.md` "Verdict: PASS"; `logs/plan.json` Delete step; check "plan creates only authored steps"; status awaiting-apply |
| One question at a time; asked, not assumed | met | `human-questions.md`: 3 separate questions. Q2 was deferred by the human, so the actor applied the default and carried its recommendation to the gate (Canvas `:51`), as `vela-grill` says. |

**Pack fix validated:** `skills/vela-grill/SKILL.md:39` says "A message the user sees: which languages, and where the texts live (project convention) - never assumed". The actor asked exactly that in Q3, and the code follows the answer.

## Planted-violation check
Each planted copy is under `r1/planted-<x>/`. Each built with 0 errors and 0 warnings. Each was reviewed by its own fresh vela-reviewer subagent, given the diff and the Canvas.

| Plant | Expected | Verdict | Severity returned | Result |
|---|---|---|---|---|
| (a) `.PreValidation().Sync()` → `.PostOperation().Async()` | Critical | BLOCK | 2 Critical (cannot block; the cascade has already run) + 2 Required (spec drift, stale evidence) | pass |
| (b) `StateCode` condition removed | Required | BLOCK | 1 Critical (breaks Q1, C1 and C2) + 1 Required (stale evidence) | pass |
| (c) `QueryExpression` with logical-name strings | Required | BLOCK | 4 Required (untyped query, single-page count, Canvas drift, stale evidence) + 1 Nit | pass |

## Findings against the skills
None blocking.

1. minor (observation, not a defect) - `skills/vela-grill/SKILL.md:39` says the message is "never assumed; no default covers it". In Q3, the actor still marked option (a), English only, as "recommended". It asked and followed the answer, so the rule held. A recommendation on a question that has no default could still nudge a human toward a guess. Watch this in the next runs; no change is needed now.

## Verdict
pass. All 23 checks pass, every criterion is met, and all 3 planted violations are blocked at or above the expected severity. The message-source and language fix holds: they were asked, not assumed.
