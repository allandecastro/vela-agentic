---
scenario: ambiguous-story-grill
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: n/a            # no scaffold in this scenario, so no csproj; vela-grill floor is Vela.Plugins >= 0.29.1
runner: "campaign actor + separate grader"
---

## Loop outcome
- `vela version` -> `vela 0.21.0` (exit 0) (`work/grill-log.md:2`).
- vela-plan-review announced. It found that direction, "status", the relationship and the trigger were ambiguous, and handed off to vela-grill (`grill-log.md:3-4`).
- vela-grill asked 7 questions, one per turn, all multiple choice: direction, meaning and rule, relationship, other events, timing, security, and solution/prefix (`grill-log.md:6-12`).
- The actor went back to vela-plan-review and filled the Canvas (`grill-log.md:13`). The Canvas is `docs/vela-builds/contact-deactivation-account-status.md` with `status: proposed`.
- As the scenario requires, there was no scaffold, no models run, no plan and no apply. `work/` contains only the grill log and the Canvas.

## Deterministic checks: 8/8 passed
- The Canvas exists.
- It mentions contact, statecode, Update, Sync, PostOperation and parentcustomerid/Company Name.
- Nothing was scaffolded (no .sln).
- Failed checks: none.

## Criteria

| Criterion | Met? | Evidence |
| --- | --- | --- |
| plan-review finds branches it can't resolve by assumption and routes to vela-grill instead of guessing | met | `grill-log.md:3-4` (ambiguity named, then "Using vela-grill"); Canvas `decisions:` L30-36 all `by: human` |
| vela-grill asks one load-bearing question at a time, tied to the registration (not a questionnaire) | met | `grill-log.md:6-12`: 7 separate Q/A turns, each answered with one letter or one line. Topics follow the skill order (meaning, direction, trigger/events, timing, security, solution) |
| Asks for solution and prefix instead of inventing them | met | `grill-log.md:12` Q7 -> ZavaSales / zava; Canvas L14-15 |
| Canvas records Contact **Update**, filtered on `statecode`, Sync | met | Canvas L6-10, O section L89-95 (`OnUpdate().PostOperation().Sync().FilterOn(e => e.StateCode)`) |
| Canvas records the "all contacts inactive" rule | met | Canvas L31, L51-54, E L61 (active-contact query excluding self) |
| PostOperation justified by the write to another record | met | Canvas L8, A section L65-67 |
| No unresolved branch | met | All story branches decided (L30-36). The one `open_question` (L45) is about unknown org-side logic, not a story branch, and is deferred to review before apply |
| SC1: no scaffold or code before the ambiguity is resolved | met | `work/` has only 2 files; check "nothing scaffolded" passed |
| SC2: every question answerable in one line and changes the registration or the acceptance cases | met (see note) | Each answer is one line (`grill-log.md:6-12`). Each answer changes the registration (entity/message/filter/stage/Sync/solution) or the acceptance cases: Q4 gives the out-of-scope case L28, Q6 gives the UserService case L26. Note: the log records the topic of each question but not its full text, so the wording itself cannot be checked |
| SC3: the Canvas is complete, answers are attributed to the human, and the two required acceptance cases are present | met | All 7 REASONS sections are filled (L49-124); `decisions` are `by: human`; the cases are at L17 ("last active contact ... deactivated -> account deactivated") and L18 ("another contact ... still active -> account untouched") |

Observations (not failures):
- The human's answer sheet includes "default Inactive status reason". The actor did not ask about it. It recorded statuscode 2 as an assumption (L40), which matches the human's intent.
- Q5 and Q6 also carry an accepted race limitation and rollback-on-failure. These are attributed to the human, but the human's answer sheet does not state them. They were probably consequences written into the chosen multiple-choice option, as vela-grill step 2 asks ("Explain the consequence of each in the question"). The full question text is not logged, so this cannot be confirmed.

## Planted-violation check
The scenario has no planted-violation section. Not applicable.

## Findings against the skills
1. minor - `skills/vela-grill/SKILL.md:40-41` says "Record answers in the Vela Canvas ... each marked as the human's decision". It does not require recording the question as asked, or the consequences the options presented. As a result, decisions like "accepts the race" (Q5) and "rolls back the contact save" (Q6) end up attributed to the human with no record of whether the human stated them or accepted them as part of an option's wording. A suggested fix is to ask the Canvas decision to quote the chosen option text.
2. minor - `skills/vela-grill/SKILL.md:35` lists "Data: what exact values are read and written" as a question for the human. It does not say whether a status reason (statuscode) is a business decision or a platform fact. The actor treated "statuscode 2 = Inactive" as a platform assumption (Canvas L40). The outcome was right, but the boundary is unclear for orgs with custom status reasons.

## Fixes
- none yet

## Verdict
**pass.** Checks passed 8/8 and the grader found every criterion met. The next run must re-check SC2 (the question wording) if the grill log starts including the full question text.
