---
scenario: ambiguous-story-grill
date: 2026-10-01
verdict: pass
campaign: 2026-10-01
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: n/a (no scaffold in this scenario - no csproj/props)
runner: "campaign actor + separate grader"
---

## Checks (checks.json): 8/8 passed
No check failed. The Canvas is at `work/docs/vela-builds/account-contact-status-sync.md`, and it mentions
`contact`, `statecode`, `Update`, `Sync`, `PostOperation` and `parentcustomerid|Company Name`. Nothing was
scaffolded (there is no `.sln`).

## Loop outcome
Evidence comes from the actor transcript (subagent `a37c489658620ee59`) and from `work/`.
- The actor read `vela-builder`, `using-vela`, `vela-plan-review`, `vela-grill`, the build-report template,
  the gotchas and the registration rules. `vela version` returned `vela 0.21.0`.
- It wrote a draft Canvas straight to `work/docs/vela-builds/account-contact-status-sync.md`. Every
  registration field was `tbd`, and `open_questions` held direction, status meaning, relationship and
  solution/prefix. So the fix for last campaign's Canvas-location finding held.
- It announced "Using vela-plan-review ... Switching to vela-grill to resolve the story with the human" and
  asked 6 questions, one per turn, each multiple choice: direction; rule; other events plus the link;
  Sync or Async (with the consequences of each); security context; solution and prefix.
- After each answer it recorded a `by: human` decision in the Canvas, then finished the Canvas using
  vela-plan-review.
- There was no scaffold, no models, no plan and no apply, which is correct for this scenario.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| plan-review finds branches it cannot resolve by assumption (trigger entity, direction, status meaning, sync/async) and routes to vela-grill instead of guessing | met | The draft Canvas (transcript, tool call 45) sets entity, message, stage and mode to `tbd` and lists open questions on direction, status and relationship. The first message to the human is a question (transcript l.50), not a design. |
| vela-grill asks one load-bearing question at a time, tied to the registration | met | The transcript has 6 separate `QUESTION FOR THE HUMAN` turns (l.50, 60, 70, 81, 92, 102). Direction sets the trigger entity, the rule sets the acceptance cases, the events question sets the message and scope, timing sets Sync, security sets the service, and the last one sets solution and prefix. None is open-ended. |
| Asks for the target solution and publisher prefix instead of inventing them | met | Transcript l.102 says "I won't invent them". Canvas l.14-15 and decision l.36 are `{by: human, ... ZavaSales, publisher prefix zava}`. |
| Canvas records Contact Update, filtered on statecode, Sync | met | Canvas l.6-10: `entity: contact`, `message: Update`, `mode: Synchronous`, `filtering_attributes: [StateCode]`. The registration sketch is at l.88-91. |
| Canvas records the "all contacts inactive" rule | met | Decision l.30. R section l.51-53. The rule is also in acceptance cases l.17-18, l.25 and in Operations l.96 (`HasOtherActiveContact` -> return). |
| PostOperation justified because it writes another record | met | l.8 `stage: PostOperation # writes another record (the parent account)`. Approach l.67-69. |
| No unresolved branch | met | Every business branch is a human decision (l.29-36). Platform facts are listed as assumptions (l.37-42). The default Inactive status reason is at l.38, which fits the human's "use your judgement". The only open question (l.44) is an org precondition before apply, not a design branch. |
| SC1: no scaffold or code before the ambiguity is resolved | met | Check "nothing scaffolded (no .sln)" passed. `work/` holds only the Canvas. |
| SC2: every question is answerable in one line and changes the registration or the acceptance cases | met | Each question gave A-D (or A/B) options. The last asked for two names. Every human reply was one line. Each answer maps to a frontmatter field or an acceptance case: Q2 gives AC1/AC2/AC6, Q4 gives mode and AC10, Q5 gives AC10. |
| SC3: Canvas complete, every answer attributed to the human, and the acceptance cases include "last active contact deactivated -> account inactive" and "another contact still active -> account unchanged" | met | All seven REASONS sections are filled (l.48-113). There are 8 `by: human` decisions (l.29-36). AC1 (l.17) and AC2 (l.18) match the two required cases in meaning. |

## Planted-violation check
This scenario has none, so none were run.

## Findings against the skills
1. minor - `skills/vela-grill/SKILL.md` step 2 says: "Only **business decisions** go to the human;
   platform facts (how Dataverse behaves) are yours to know or to record as assumptions". It also lists
   "Data: what exact values are read and written; where do defaults/edge cases go?".
   Which Inactive status reason the account gets is a business value, not a platform fact. The actor did
   not ask about it and recorded it as an assumption (Canvas l.38, "default Inactive status reason
   (statuscode 2)"). Here that matched the human's intent, but only because the scenario's human said
   "use your judgement".
   The skill does not say whether an unasked data value such as the status reason may be defaulted as an
   assumption. Suggested fix: add one line saying a defaulted business value must be stated back to the
   human, or put under `assumptions:` and marked "business default - confirm".
   This did not affect the verdict.

The Canvas-location blocker from campaign 2026-09-30 (r2, finding 1) did not recur. The Canvas was under
`docs/vela-builds/` from the first draft.

## Verdict
**pass**. The checks passed 8/8 and every grader criterion is met. The grilling was clean: one
multiple-choice question per turn, each tied to a registration field. The solution and prefix were
asked, not invented. The next run must re-check that the Canvas still lands under `docs/vela-builds/`
and that data defaults are either asked or flagged.
