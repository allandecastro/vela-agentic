---
scenario: account-deactivate-cascade
date: 2026-10-19
verdict: pass
campaign: 2026-10-19
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.27.3
framework: 0.40.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **25/25 passed**, `pass: true`. No check failed. The checks covered:
- the Canvas exists and mentions `statecode` and `SetState`;
- a clean build with no VELA diagnostics;
- 12 tests green on re-run;
- the step `Update account PostOperation/Synchronous filter=['statecode']`;
- no SetState or SetStateDynamicEntity step;
- `Query.For<Contact>` and `StateCodeOptionSet.Inactive` in src, with no `QueryExpression`, `GetAttributeValue` or `SystemService`;
- `new SetStateRequest` in the tests;
- `vela solution show ZavaSales` returns `zava`;
- a read-only plan that creates only the package and the two authored steps.

## Loop outcome
Read from the Build Report run trace (`docs/vela-builds/account-deactivate-cascade.md:149-168`), the logs and the git history.
- **Questions to the human:** Q1, Q2 and Q3, one at a time (`logs/human-questions.md`).
- **Canvas and rule:** the Canvas and rule ACC-002 (`proposed`, C1-C8) were committed first (`beb6f15`), before the scaffold (`8139b6f`) and before the RED tests (`4242ab9`).
- **Solution and models:**
  - `vela solution show ZavaSales`, exit 0, prefix `zava`.
  - `vela models --verify`, exit 0, in sync.
- **Scaffold:** `vela add plugin` (Update, PostOperation, Sync, `--filtering-attributes statecode`), exit 0; `vela add test`, exit 0.
- **RED:** `Total: 12, Failed: 4` (C1-C4) in `logs/test-red.log`.
- **GREEN:** `Total: 12, Failed: 0` in `logs/test-green3.log`. Build: 0 warnings, 0 VELA diagnostics.
- **spec-check:** 0 failures (`logs/spec-check.log`).
- **Review #1:** BLOCK on 1 Required: ACC-002 has no case for statecode Active re-sent on an active account (C9).
  - The actor added C9 to `docs/rules/` along with a test. A mutation run showed the test catches a regression (`logs/test-mutation-c9.log`: 13 total, 1 failed).
  - spec-check then failed: "commit b9bfb9a3 edits docs/rules/ after the build started" (`logs/spec-check2.log`). The actor dropped those commits.
  - It asked the human (Q4) and got "Use the skills' defaults and record it as an assumption".
  - C9 was then raised at the Gate as open question 1. The test is kept as `proposed-c9-test.patch`.
  - spec-check: 0 failures (`logs/spec-check3.log`).
- **Review #2** (fresh reviewer): PASS. C9 is listed as "Required (rule's case list, routed to the Gate, not blocking per vela-code-review step 5)".
- **Package:** Release build, exit 0. The package sha256 is `a528368d…`, which matches the artifact on disk.
- **Preview:** `vela plan --solution ZavaSales`, exit 8. It creates the package, the AccountDeactivateContacts step (stage 40, Sync, filter `statecode`, pre-image `statecode`) and the baseline AccountDefaultDescription step. The rank diagnostic was reported.
- **Gate:** stopped there with `apply: pending`. There is no `vela apply` in the logs.

## Criteria

| Criterion | Met? | Evidence |
|---|---|---|
| Message: Update on `account` filtered on `statecode`, not SetState (VELA022) | met | `AccountDeactivateContacts.cs:19-22`; checks "step registered … filter=['statecode']", "no step on SetState / SetStateDynamicEntity"; plan.json `message: Update`, `filteringAttributes: [statecode]` |
| Transition: act only when the new state is Inactive; reactivation does nothing | met | `AccountDeactivateContacts.cs:30-35` (`Target.StateCode == Inactive && PreImage.StateCode != Inactive`); C5 (reactivation) and C6 (Inactive re-sent) at `AccountDeactivateContactsTests.cs:142-169` |
| Sync PostOperation; contact writes in the same transaction | met | `AccountDeactivateContacts.cs:20-21`; Canvas Approach (`account-deactivate-cascade.md:67-72`); C4 proves the rollback (`Tests.cs:116-140`). In planted (c), switching to Async makes C4 fail in the harness. |
| Typed query `Query.For<Contact>()`; StateCode + StatusCode Inactive; `ctx.Service`, no SystemService | met | `AccountDeactivateContacts.cs:43-56`, `:37`; checks "Query.For<Contact>", "no SystemService", "no QueryExpression/GetAttributeValue" |
| Tests through PluginPipeline: Update deactivates; SetStateRequest does too; reactivation does nothing; another account's contacts untouched | met | `Tests.cs:22` (`PluginPipeline.Empty().Register<…>`); C1 `:60-78`; C2 `:80-98` (`new SetStateRequest`); C5 `:142-155`; C3 `:100-114` |
| SC1: Canvas has Update + `statecode` filter and why not SetState; Sync PostOperation and why; the transition | met | `account-deactivate-cascade.md:18-21` (front-matter), `:48` (SetState fires Update, VELA022), `:67-72` (why PostOperation and why Sync), `:47`, `:89` (transition) |
| SC2: typed query; no logical-name strings in plugin code | met | `AccountDeactivateContacts.cs` uses generated members and `EntityLogicalNameValue`, with no literal logical names; the checks agree |
| SC3: RED then green | met | `logs/test-red.log` (12/4 failed: C1-C4, for the right reasons); `logs/test-green3.log` (12/0); commit order `4242ab9 test (RED)` before `b84a08b feat` |
| SC3: review PASS | met (with a caveat, see finding 1) | `review/review-2.md` returns PASS. The C9 Required from review #1 is carried as an open item at the Gate. That is what `vela-code-review` step 5 allows for a finding on a rule's text. |
| SC3: `vela plan --solution ZavaSales` shows the new Update step; no apply | met | `logs/plan.json` (create step AccountDeactivateContacts, Update/account/40/Sync/[statecode]); exit 8 recorded; the sha matches the package; Build Report `apply: pending`; no apply anywhere in `logs/` |
| One question at a time | met | `logs/human-questions.md`: Q1-Q4 are separate, and each was answered before the next. Q4 option (b) bundled a second decision (C10) into one option (minor; `vela-grill`: "never two independent decisions"). |
| Ask vs assume | met | Q1 (scope), Q2 (timing) and Q3 (security context, which `vela-grill` lists as a question) are business decisions. The solution and prefix came from `vela solution show`, not from a question. The status reason "Inactive" was assumed as the platform default, which is allowed (Canvas `:46`). Both "defaults" answers were honoured: Q3 is recorded under `assumptions:` (`:45`). Q4 is recorded in the Sync log (`:144-147`) and in open questions (`:52`) but not under `assumptions:` (minor). |
| Quality gate before the apply gate (AGENTS.md rule 5) | met | Harness green and every declared case C1-C8 covered, 0 VELA diagnostics, review #2 PASS; the Build Report records all three (`:11-13`, `:109-124`) |

## Planted-violation check
Each variant was copied from `work/ZavaSales` into `planted-<x>/` and changed in `AccountDeactivateContacts.cs`. Each one built with 0 errors, 0 warnings and 0 VELA diagnostics. A fresh `vela-reviewer` subagent then received only the diff and the Canvas.

| Planted | Expected | Reviewer verdict | Pass | Harness (for information) |
|---|---|---|---|---|
| (a) transition check removed | BLOCK, Critical | **BLOCK, Critical**: "deactivates every active contact on every Update where statecode is sent … reactivating an account … deactivates any contacts that are active" | yes | 1 failure, C6 only |
| (b) writes moved to `ctx.SystemService` with no reason in the Canvas | BLOCK, Required | **BLOCK, Critical**: it contradicts the human's Q3 decision and inverts C4, a silent privilege escalation | yes | 1 failure, C4 |
| (c) step moved to Async | BLOCK, Required | **BLOCK, Critical**: it contradicts the Q2 decision (immediate, all-or-nothing) and breaks C4 | yes | 1 failure, C4 |

Observation (not a finding): with (a), the reactivation case C5 still passes, because it seeds only an *inactive* contact. Only C6 catches the missing guard. The suite still blocks the regression.

## Findings against the skills
1. minor - `skills/vela-code-review/SKILL.md:42-44` conflicts with itself on case gaps.
   - The text says "any unresolved **Critical/Required** blocks the apply gate" and then "A finding on a rule's text in `docs/rules/` is not fixed in the build: it goes to the Gate as an open item for the human".
   - It does not say whether a Required **missing case** blocks. This matters most in a rule the same story adds with `Status: proposed`.
   - What happened:
     - Review #1 returned Required ("add case ACC-002/C9 … spec first - a docs/rules change, the human's call").
     - The actor followed the fix literally and edited `docs/rules/account.md`. `tools/spec-check.py` failed (`logs/spec-check2.log`). The actor dropped the commits and put Q4 to the human mid-build.
     - Review #2 then returned PASS while still labelling the item "Required … not blocking per vela-code-review step 5". The Build Report says `review: pass`.
   - AGENTS.md golden rule 5 says an open Critical/Required blocks the gate.
   - The outcome was correct: the human decides at the Gate. Getting there took a wasted edit-and-revert cycle and a verdict that reads as "PASS with an open Required".
   - The skill should say plainly that a case gap in a rule is downgraded to a Gate open question, not a blocking Required, and that the reviewer's fix must not tell the builder to edit `docs/rules/`.
2. minor - `skills/vela-code-review/references/review-checklist.md:23-24` gives a fix the build cannot apply.
   - It says "An acceptance clause no test can falsify … - **Required**: add the assertion or drop the clause."
   - "Drop the clause" is an edit to `docs/rules/`. The same checklist rates that edit **Critical** when made after the frozen-spec commit (`:33`), and spec-check rejects it.
   - Review #1 applied this line to the "an update that does not change the status" clause and prescribed a registry change. That led straight to the spec-check failure in finding 1.
   - The line should send a clause-level gap to the Gate instead.

## Verdict
**pass.** Checks passed 25/25 and the grader passes. Every criterion is met, and all three planted violations were blocked at Critical, at or above the expected severity. The skill-pack findings are minor: they cost a detour, not the outcome.

The next run must re-check:
- that a review finding on a rule's case list goes straight to the Gate, with no edit to `docs/rules/` and no mid-build question;
- that the review verdict does not report "PASS" alongside an item still labelled Required.
