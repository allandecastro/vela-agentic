---
scenario: account-delete-guard
date: 2026-10-19
verdict: fail
campaign: 2026-10-19
run: 2/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **23/23 passed**, `pass: true`. No failed check. The checks covered:
- a Canvas that names Delete and PreValidation;
- a clean Release build with no VELA diagnostics;
- 12 tests green on re-run;
- one new step: Delete `account`, PreValidation, Synchronous;
- exactly 2 authored steps, with no demo step;
- `Query.For<Contact>`, `StateCode` and `BusinessError(` in src, and no `new QueryExpression` or `GetAttributeValue<`;
- `.Delete(` in the tests;
- `vela solution show ZavaSales` returns prefix `zava`;
- a read-only plan that creates the package, AccountDeleteGuard and the baseline AccountDefaultDescription step.

The checks only grep for `BusinessError(`. They do not check the languages of the message source.

## Loop outcome
Read from the Build Report run trace (`work/ZavaSales/docs/vela-builds/account-delete-guard.md:125-139`) and `work/logs/`.
- `vela version`: 0.27.3, exit 0.
- `vela solution show ZavaSales --json`: exit 0, prefix `zava`.
- Two questions to the human, one at a time (`work/logs/human-questions.md`):
  - Q1: what counts as an active contact. Answer: A, contacts whose parent customer is the account and whose status is Active.
  - Q2: whose rights the count uses. Answer: "Use the skills' defaults and record it as an assumption."
- No question about the message source or the languages. The actor stretched the Q2 answer to cover them and assumed an in-code dictionary in English (1033) only.
- `vela add plugin`, `add service` and `add test`, each exit 0.
- RED: `Total: 12, Failed: 3` (`work/logs/test-red.log`), the right failures.
- GREEN: 12/12 with mono xunit.console 2.9.2 and `-parallel none`.
- `dotnet build -c Release --no-incremental`: 0 warnings, 0 errors, 0 VELA.
- `spec-check`: exit 0.
- Isolated reviewer: PASS with 4 Nits.
- Package `artifacts/zava.Plugins.1.0.0.nupkg`.
- `vela plan --solution ZavaSales`: exit 8, creates the package and 2 steps. The baseline ACC-001 step is correctly flagged as an open question that blocks the gate.
- No apply.

## Criteria

| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| M1 | Registration: new plugin on Delete of account, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:19-23`; Canvas S `account-delete-guard.md:71`; check `step registered: Delete 'account' PreValidation/Synchronous` |
| M2 | Target treated as an EntityReference; reads the contacts, not the target's columns | met | `AccountDeleteGuard.cs:39` uses `ctx.Request.Target.Id` only; Canvas E line 58 |
| M3 | Typed query `Query.For<Contact>()` on ParentCustomerId plus StateCode == Active, through `ctx.Service`, minimal columns, no logical-name strings | met | `AccountActiveContacts.cs:28-31` (`CountScalar` on `ContactId`); the service gets `IOrganizationService` = `ctx.Service` (`AccountDeleteGuard.cs:29`); check `src must not contain QueryExpression` |
| M4 | `InvalidPluginExecutionException` with an actionable message (the count; deal with the contacts first) | met | `AccountDeleteGuard.cs:32,45`; test `AccountDeleteGuardTests.cs:61-64` |
| M5 | Tests RED then green through `PluginPipeline`: throws with an active contact; passes with none or only inactive ones; another account's contact does not count | met | `AccountDeleteGuardTests.cs:51-111` (C1-C4); `work/logs/test-red.log` (3 failing for the right reason); check `tests re-run green (>= 6)` = 12/12 |
| M6 | Localized message: `ctx.BusinessError("KEY", ...)` from a message source registered in `ConfigureServices`, following the project convention **asked at design**, **with English and French templates**; a test asserts the message | **not met** | `AccountDeleteGuard.cs:30-32` registers only `.Add(1033, ...)`, with no 1036 template. The convention was never asked: `human-questions.md` holds only Q1 and Q2. Canvas assumption line 31 says "English (1033) only". The key, `ConfigureServices` registration and message assertion are present. |
| S1 | Canvas: Delete, PreValidation, Sync with the reason; the error message; what "active" means | met | Canvas front matter lines 7-9; A line 63-64; O line 88-89; decisions line 27 |
| S2 | Typed query, no `QueryExpression` or logical-name strings in plugin code | met | `AccountActiveContacts.cs`; checks |
| S3 | RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | `test-red.log` / `test-green.log`; `account-delete-guard.review.md` (PASS); `work/logs/plan.json` (create step AccountDeleteGuard); `apply: pending` |
| Q | One question at a time; ask rather than assume a business decision when a human is reachable | **partly met** | Questions came one at a time (Q1, Q2). The message source and languages were assumed, not asked, even though `vela-plan-review` says "the message source is the project's convention: ask once". See fairness note. |

**Fairness note.** The evaluator answered Q2, the security-context question, with "Use the skills' defaults and record it as an assumption". The actor reused that answer for the message source without asking. This is not a fair reading:
- that answer covered Q2 only;
- the pack names no default message source. `plugin-authoring-api.md:243` says "is the project's convention - ask the human".

Had the actor asked, the human answer was available: an in-code dictionary with 1033 and 1036. The actor did disclose the assumption and list it as an open question at the gate, which is honest. M6 is still not delivered: the French template is missing.

## Planted-violation results
Each plant was applied to a copy (`r2/planted-<x>/`), built with `dotnet build -c Release`, and reviewed by a fresh read-only vela-reviewer subagent. The reviewer saw only the diff and the Canvas. All three plants built with **0 errors, 0 warnings, 0 VELA**.

| Plant | Change | Expected | Reviewer verdict | Result |
|-------|--------|----------|------------------|--------|
| (a) | `.PreValidation().Sync()` → `.PostOperation().Async()` | Critical | BLOCK, **Critical** (Async runs after the delete commits and cannot refuse it; breaks C1; cites registration-rules "Never for validation"), plus Required spec drift | blocked |
| (b) | dropped the `StateCode == Active` condition | Required | BLOCK, **Critical** (breaks Q1 decision, C1 count, C2) | blocked |
| (c) | `QueryExpression("contact")` with `"parentcustomerid"` / `"statecode"` strings and `RetrieveMultiple(...).Count` | Required | BLOCK, **Required** (logical-name strings where `Query.For<T>()` would do; also `statecode == 0` magic number, unpaged RetrieveMultiple capped at 5,000 rows, Canvas drift) | blocked |

## Findings against the skills
1. **blocker**: `skills/vela-plan-review/SKILL.md:68-71` says: "a message the user sees → a localized key (the message source is the project's convention: ask once)".
   - **What the skill does:** the instruction sits in a bulleted list that ends "Record each choice in the Canvas". Step 4 then says "Flag the assumptions in one line and **continue** - unless a branch is a business decision only the human can make (a story term's meaning, which record drives which, the rule itself, edge values ...)". The message source and its **languages** are not on that must-ask list. The neighbouring items carry hard wording: the security context says "with a human reachable, ask", and the cache TTL says "never pick the TTL alone". The message source has only "ask once".
   - **What happened:** the actor treated the message source as assumable. It folded it into a "use the defaults" answer given to a different question, and invented a "skill default" (English only) that the pack does not define.
   - **Result:** the French template is missing, and M6 fails.
   - **Fix:** make the message source and languages a hard must-ask with a reachable human, in the same form as the security context: "with a human reachable, ask (one question: source and languages); never assume". State that the pack has no default source and that a generic "use defaults" answer to another question does not settle it.
2. minor: `skills/vela-code-review/references/review-checklist.md:99-100` says "a user-facing message hard-coded when the project localizes - **Required**".
   - **What happened:** the isolated reviewer passed a message source with one language and the languages never confirmed. The checklist checks only that the message is not hard-coded. It does not check that the source's languages match the Canvas or a human answer, or that an assumed message source is an unresolved design question.
   - **Fix:** add the axis "templates for every language the Canvas records; an *assumed* message source is an open spec point, not a Nit".
3. minor (observation, not a skill-text defect): planted variant (c) - `new QueryExpression("contact")` with logical-name strings - built with **0 VELA** diagnostics; only the review (checklist line 73-74) catches it. The deterministic check's `new QueryExpression` grep and the reviewer are the only guards; worth reporting to Vela as an analyzer gap (not a skill fix, per pack policy).

## Verdict
**fail.** The checks pass (23/23) and all three planted violations are blocked: (a) Critical, (b) Critical, (c) Required. The grader fails the run on M6: the localized message has no French (1036) template, and the message-source convention was assumed when the pack says to ask the human. The next run must re-check that the actor asks about the message source and languages as a separate question, and that the source carries both 1033 and 1036.
