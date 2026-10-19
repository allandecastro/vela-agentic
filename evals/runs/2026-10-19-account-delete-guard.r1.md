---
scenario: account-delete-guard
date: 2026-10-19
verdict: fail
campaign: 2026-10-19
run: 1/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **23/23 passed**, no failed check. The checks covered the step registration (Delete, account, PreValidation, Synchronous), the build and 0 VELA diagnostics, 13 green tests, the typed query with `Query.For<Contact>` and `StateCode`, `BusinessError(`, the `.Delete(` pipeline tests, `vela solution show`, a read-only `vela plan` and authored-only plan operations.

## Loop outcome
- `vela version` returned 0.27.3. `vela solution show ZavaSales` and `vela models --verify` both exited 0.
- One grill question was asked (Q1, the security context). The coordinator answered "use the skills' defaults", so it went in as assumption A1.
- Scaffolded with `vela add plugin AccountDeleteGuard --message Delete --stage PreValidation --mode Sync`, `vela add service` and `vela add test`.
- RED: commit a75a65e, mono xunit run `Total: 13, Failed: 2` (both C1). GREEN: `Total: 13, Failed: 0`.
- Review 1 was BLOCK (one Required on C5 realism). After the fix, review 2 was PASS with 3 Nits.
- Package built. `vela plan --solution ZavaSales --detailed-exitcode` exited 8. It creates the package, the `AccountDeleteGuard` step (stage 10, mode 0) and the never-deployed ACC-001 step, which was flagged as Q4.
- No apply was run.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Registration: Delete of account, Sync PreValidation, scaffolded with `vela add plugin ... --message Delete` | met | `AccountDeleteGuard.cs:19-21`; Canvas run trace #5; check "step registered: Delete 'account' PreValidation/Synchronous"; `logs/plan.json` stage 10 / mode 0 |
| Target is an EntityReference: reads the contacts, not the target's columns | met | `AccountDeleteGuard.cs:38` uses `ctx.PrimaryEntityId` only; Canvas `images: []` |
| Typed query on active contacts (`ParentCustomerId` + `StateCode == Active`), on `ctx.Service`, few columns, no logical names | met | `AccountDeleteCheck.cs:24-27` (`Query.For<Contact>()...CountScalar(_service, c => c.ContactId)`); service built on the user's `IOrganizationService` (`AccountDeleteGuard.cs:29`); the SYSTEM mutant fails C5 (`logs/test-mutant2-systemservice.log`); check "must not contain new QueryExpression" |
| Error is an IPE with an actionable message (count + deal with them first) | met | `AccountDeleteGuard.cs:33,42`; test `AccountDeleteGuardTests.cs:62-67` |
| Tests RED then green through PluginPipeline (active blocks; none, inactive-only and other-account do not block) | met | `AccountDeleteGuardTests.cs` C1-C4; `logs/test-red.log` (2 FAIL, C1); `logs/test-final.log` `Total: 13, Failed: 0` |
| **Localized message:** `ctx.BusinessError` from a source registered in `ConfigureServices`, the project's convention **asked at design**, **English and French** templates, a test asserts the message | **not met** | `BusinessError` and the `ConfigureServices` source are present (`AccountDeleteGuard.cs:30-33,42`) and the message is asserted (`AccountDeleteGuardTests.cs:65-67`). But only 1033 is registered and there is no French (1036) template. Canvas assumption A2 says "message source - skills' default, **not asked** ... English (1033) only", and Q2 was left open. `logs/human-questions.md` shows that only Q1 was put to the human. |
| SC1: Canvas has Delete / PreValidation / Sync with the reason, the error message, and what "active" means | met | Canvas front-matter lines 18-20; A - Approach (line 61); O (line 72); assumption A3 (line 41) |
| SC2: typed query, no `QueryExpression` and no logical-name strings in plugin code | met | `AccountDeleteCheck.cs`; check passed |
| SC3: RED then green; review PASS; `vela plan --solution ZavaSales` shows the new Delete step; no apply | met | the logs above; `docs/vela-builds/account-delete-guard.reviews.md` review 2 PASS; `logs/plan.json`; Build Report `apply: pending` |
| One question at a time | met | `logs/human-questions.md`: a single focused multiple-choice question (Q1) |
| Ask vs assume | **not met** | The message source and languages are a project convention that the pack says to ask about. The actor assumed them instead (A2 "not asked"), even though it had identified the question (Q2). The human's answer would have been English + French in an in-code dictionary. The security context was asked correctly. |

## Planted-violation results
Each plant was applied to a copy (`planted-a|b|c/`). Every copy built clean: 0 errors, 0 warnings, 0 VELA. A fresh read-only subagent acting as vela-reviewer got only the diff and the Canvas.

| Plant | Expected | Reviewer verdict | Pass? |
| --- | --- | --- | --- |
| (a) `.PreValidation().Sync()` changed to `.PostOperation().Async()` | Critical | BLOCK: **Critical** (Async cannot block the delete; the cascade loses the contacts) + 2 Required (code/Canvas drift, stale evidence) | pass |
| (b) `StateCode` condition removed | Required | BLOCK: **Critical** (C2 regression; inactive contacts block) + Required (stale evidence) | pass |
| (c) `QueryExpression` with logical-name strings | Required | BLOCK: **Required** (logical-name strings; Canvas Norms) + Required (unbounded `RetrieveMultiple` count) + Required (Canvas drift / stale evidence) | pass |

## Findings against the skills
1. **blocker** - `skills/vela-grill/SKILL.md`, step 2 question list.
   - The list covers Meaning / Direction / Trigger / Timing / Data / Security context / Target solution / DoD. It has no item for the user-facing message source and languages.
   - `skills/vela-plan-review/SKILL.md:69` does say "a message the user sees → a localized key (the message source is the project's convention: ask once)". `references/plugin-authoring-api.md:243` says "is the project's convention - ask the human".
   - What happened: the actor ran the grill checklist, asked only the security question, then recorded the message convention as "A2 (message source - skills' default, not asked) ... English (1033) only" and Q2 open.
   - Result: the localized-message criterion failed (no French template).
   - Fix: add the message source + languages to the grill's question list whenever the story has a user-facing message.
2. minor - the pack names no "default" message source or language set.
   - The actor described an English-only in-code `DictionaryMessageSource` as "the skill default" (Canvas A2), but no skill defines one.
   - The plan-review / authoring-api wording ("ask once" / "ask the human") gives no fallback for when no one answers. So "use the skills' defaults" left the actor to invent one.
   - Fix: either state a default (and that it is an assumption to flag), or say that this question is never defaulted.
3. minor - `skills/vela-code-review/references/review-checklist.md:99-100` only covers "a user-facing message hard-coded when the project localizes - **Required**".
   - It does not cover a message convention or language set that the human never decided.
   - Review 1 rated the English-only source a Nit ("acceptable as A2/Q2"), so the review gate did not catch the unasked convention.
   - Fix: add an item where a localization source or language set assumed without the human is at least Required at review, or at least a blocking open question at the Gate.

## Verdict
**fail.**
- Checks pass 23/23, and all three planted violations were blocked at or above the expected severity.
- The grader fails the run on two criteria:
  - The localized-message rubric is not met (English only, convention not asked at design).
  - Ask-vs-assume is not met for the message convention.
- Next run must re-check that the grill (or plan-review) asks the message source + languages in one question, and that the build registers both the 1033 and 1036 templates with a test asserting the message.
