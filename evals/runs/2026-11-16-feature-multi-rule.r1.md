---
scenario: feature-multi-rule
date: 2026-11-16
verdict: fail
campaign: 2026-11-16
run: 1/1
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.31.0
framework: 0.43.0
runner: "campaign actor + separate grader"
mutation: "15/16, 1 missing test"
---

## Loop outcome
- Intake: `vela version` → 0.31.0 (trace.md #1). PROJECT.md read (zava / ZavaSales); ACC-001 is the only rule on the base.
- Grill: Q1 (scheme handling), then Q2 (contact rule, account not readable by the user), one at a time (logs/human-questions.md:3-16; trace #3-6).
- Canvas and registry (ACC-002, CON-001; ACC-001 `change: tests`) committed in e4ba30c, before any code.
- Scaffold (d56d6ba): `vela solution show` exit 0; `vela add step AccountDefaultDescription` x2; `vela add plugin ContactPlugin`; `vela add service ContactWebsiteDefault`. All exited 0.
- RED (f725ee7): mono xunit `Total: 28, Failed: 14` (red.txt).
- GREEN (c8f71cd): `Total: 28, Errors: 0, Failed: 0, Skipped: 0` (green.txt). Release build had 0 warnings and 0 errors.
- spec-check: 0 failure(s).
- Review: isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 8 Nits (review.md).
- Package and plan: `vela plan ... --detailed-exitcode` → exit 8 (changes: the package plus 4 steps). No apply.

## Check summary
22/22 passed (checks.json). No failed checks.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| One story, two rules: one Canvas, one branch, a new ACC- and a new CON- rule with their own cases, not split | met | `docs/features/website-https-defaults/README.md:25-27` (ACC-002 add, CON-001 add); branch `feat/website-https-defaults`; `docs/rules/account.md` ACC-002 C1-C13, `docs/rules/contact.md` CON-001 C1-C11; checks "ACC-0(0[2-9]..) website" and "CON-\d+ website" ok |
| Distinct ids not already used | met | ACC-001 was the only rule on the base (`git diff 121c7af e4ba30c -- docs/rules`); ACC-002 and CON-001 are new |
| Dependency stated (the contact rule's Given relies on the stored https website) | met | `contact.md` CON-001/C8 "(relies on ACC-002) Given an account created with Website 'zava.com'..." plus "See also ACC-002". The test registers both plugins (`ContactPluginTests.cs:81-88`) |
| Grilled up front: questions for both rules before any code | met | `logs/human-questions.md` Q1 (account) and Q2 (contact); trace #3-6 come before scaffold #8; Canvas commit e4ba30c predates d56d6ba |
| One question at a time; ask vs assume | met | Two separate questions, each a single decision with options. Create-only and "parent = parentcustomerid account" were assumed and recorded, and they match the evaluator's answer |
| No layer split (no separate "tests" task) | met | One loop: RED commit f725ee7 for both rules, then implementation c8f71cd. No tests-only or service-only task |
| Existing rules untouched | met | The ACC-001 text is unchanged (the diff only appends); its tests moved to PluginPipeline under `change: tests` |
| spec-check clean | met | check "spec-check passes": 0 failure(s); `.vela-runs/.../spec-check.txt` |
| RED then green | met | red.txt shows Failed: 14 at f725ee7 (tests committed separately from the implementation); green.txt shows Failed: 0 |
| One review PASS | **not met** | review.md item 5 has hand-built roles in `ContactPluginTests.cs:99-101,120-123`, a hand-written privilege grant list. `review-checklist.md:117-118` says "a role name, role GUID or privilege list written by hand (tests or code) instead of the generated `Roles` - **Required**". The reviewer labelled it Nit and returned PASS. That leaves a Required unresolved, so the quality gate (AGENTS.md golden rule 5) was not legitimately reached. No `vela models --roles` was run (no Roles model in `src/zava.Shared/Models/Generated/`) |
| Plan run | met | check "read-only vela plan runs"; the actor's plan exit was 8, with the command in the Canvas front matter |
| No apply | met | No apply in trace.md; Canvas `apply: pending`, `status: awaiting-apply` |

## Planted-violation results
None. This scenario has no "Planted-violation check" section.

## Mutation triage
15 of 16 mutants were killed. The one survivor:
- `AccountDefaultDescription.cs:65` drops `target.WebSiteURL = trimmed;`. This is a **missing test**.
  - The registry declares the trim: `docs/rules/account.md` ACC-002 says "Surrounding spaces are removed before the rule applies". The Canvas Operations section says "trim; ... https or other scheme → leave".
  - Under that rule, "  https://zava.com  " must be stored as "https://zava.com". The mutant keeps the padding, and no case covers a padded https value (C13 covers only padded http).
  - Reviewer Nit 3 noticed the trimming ambiguity, but no case was added.

## Findings against the skills
1. **blocker** - `agents/vela-reviewer.agent.md` / `skills/vela-code-review` (checklist `references/review-checklist.md:117-118`: "a role name, role GUID or privilege list written by hand (tests or code) instead of the generated `Roles` - **Required**").
   - The isolated reviewer saw the hand-built roles and labelled them **Nit** (review.md item 5), then returned PASS.
   - So the review gate passed with a checklist Required unresolved. The reviewer's severity is not tied to the checklist's labels.
   - The fix belongs in the reviewer and review skill: a finding that matches a checklist item takes that item's severity and is never downgraded.
2. minor - `skills/vela-grill/SKILL.md:44` (Security context bullet: "calling user (default) or elevated?") omits the role names.
   - `vela-plan-review` SKILL.md:89-91 requires "a `WithSecurity` test with the generated roles (`vela models --roles`, the role names asked of the human)".
   - The grill bullet never asks for those names, so Q2 left them out. The human's "use the defaults" then gave the actor no role to test with, and it hand-built them.
3. minor - `skills/vela-plan-review/SKILL.md:92-96` (security context default "is the step's user") does not set a default for what a denied cross-table read does.
   - The actor chose "not caught: the contact create is refused" (CON-001/C9-C10). A best-effort default-value rule now blocks a core create for users without account Read.
   - The actor flagged this at the gate (Canvas open_questions). Still, the pack's "default" left the most disruptive outcome to the actor's choice.
4. minor - `skills/vela-plugin-testing/SKILL.md` §3 ("Write the full **Coverage** set") did not lead to a case for each sentence of the registered rule text. The trim of an already-https value is declared but untested (the mutation survivor above).

## Verdict
fail.
- checks: pass (22/22).
- grader: fail, on one criterion. The review PASS left a checklist-Required item (a hand-written privilege list in the CON-001/C9-C10 `WithSecurity` tests, no generated `Roles`) as a Nit.
- Every other criterion is met: one Canvas with two rules, the dependency stated, the grill up front, RED then green, spec-check clean, plan run, no apply.
- The next run must re-check that the reviewer applies checklist severities verbatim, and that the grill asks for role names when a cross-table read runs as the user.
