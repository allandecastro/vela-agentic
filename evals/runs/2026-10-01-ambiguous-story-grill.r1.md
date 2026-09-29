---
scenario: ambiguous-story-grill
date: 2026-10-01
verdict: pass
campaign: 2026-10-01
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: n/a (no scaffold in this scenario - no csproj/props)
runner: "campaign actor + separate grader"
---

## Checks (checks.json): 8/8 passed
No failed checks. The Canvas is at `work/docs/vela-builds/account-contact-status-sync.md`, and nothing
was scaffolded (no `.sln`).

## Loop outcome
- The actor read the builder agent, `using-vela`, `vela-plan-review` and `vela-grill`, plus their
  references. `vela version` printed `vela 0.21.0`.
- It created `work/docs/vela-builds/account-contact-status-sync.md` as a draft Canvas before asking its
  first question. This follows the fixed wording at `agents/vela-builder.agent.md` l.62-64: "the Canvas
  is always `docs/vela-builds/<slug>.md` - before a project exists, under the working directory".
- The first message announces "Using vela-plan-review to grill the plan ... switching to vela-grill",
  restates the story, and explains why direction decides the step entity.
- There were 7 `QUESTION FOR THE HUMAN` turns, one question each, all multiple choice except Q7, which
  asked for two values. The human's answers are at actor transcript lines 57, 67, 77, 86, 97, 107 and 116
  (`agent-a35e342246cc9f2e5.jsonl`). The Canvas was updated after each answer.
- The actor checked the flags with `vela init --help` and `vela add plugin --help`, then finished the
  Canvas with `status: proposed` and `open_questions: []`.
- No scaffold, models, tests, plan or apply, which is correct for this scenario.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| plan-review finds the branches it cannot resolve (trigger entity, direction, what "status" means, sync vs async) and routes to vela-grill instead of guessing | met | The first turn routes to vela-grill explicitly and asks about direction as the branch that picks the step table. Status meaning (Q2), relationship (Q3), events (Q4) and Sync/Async (Q5) follow. No business value was guessed. |
| vela-grill asks one load-bearing question at a time, tied to the registration | met | 7 separate turns. Q1 (direction) sets the step entity. Q2 (rule and statecode) sets the filter and ACs. Q3 (`parentcustomerid`) sets the post-image and query. Q4 (events) sets the message scope. Q5 sets Sync/Async. Q6 sets UserService. Q7 sets the solution and prefix. None is open-ended. |
| Asks for the target solution and publisher prefix instead of inventing them | met | Q7 asks for them and offers a `tbd` placeholder rather than inventing values. Canvas l.16-17 and l.40 record `{by: human, what: "Target solution ZavaSales, publisher prefix zava."}`. |
| Canvas records Contact Update, filtered on statecode, Sync | met | Canvas l.6-10: `entity: contact`, `message: Update`, `stage: PostOperation`, `mode: Synchronous`, `filtering_attributes: [StateCode]`. The registration sketch is at l.102-106. |
| Canvas records the "all contacts inactive" rule | met | l.34 (decision), l.56-58 (R), l.69-70 (existence query), and step 3 of the O section (l.111). |
| PostOperation justified because it writes another record | met | l.8 `stage: PostOperation # writes another record (the parent account)`. l.73-76 add "Not PreOperation: the written record is not the Target." |
| No unresolved branch | met | l.49 `open_questions: []`. Platform facts are listed as assumptions (l.42-48), including the default Inactive status reason (statuscode 2, l.44), which fits "use your judgement". |
| SC1: no scaffold or code before the ambiguity is resolved | met | The check "nothing scaffolded (no .sln)" passed. `work/` holds only the Canvas and an empty `.git`. |
| SC2: every question answerable in one line, and each changes the registration or the ACs | met | Every answer was one line ("B - ...", "A - ...", "ZavaSales / zava"). Each maps to a front-matter field or an AC: Q4 gives AC9/AC10, Q5 gives `mode`, Q6 gives AC1/AC13. |
| SC3: Canvas complete, every answer attributed to the human, ACs include "last active contact deactivated -> account inactive" and "another contact still active -> account unchanged" | met | All 7 REASONS sections are filled (l.53-133). The 8 decision entries (l.33-40) are all `by: human`. AC1 (l.19) and AC2 (l.20) match the two required cases. |

## Planted-violation check
This scenario has none, so none were run.

## Findings against the skills
None this run. The blocker from the 2026-09-30 r2/r3 runs (where to put the Canvas when a run stops
before the scaffold) is resolved: `agents/vela-builder.agent.md` l.62-64 now names
`docs/vela-builds/<slug>.md` under the working directory, and the actor followed it on the first try.

## Verdict
**pass**. Checks passed 8/8 and every grader criterion is met. The grilling was one multiple-choice
question per turn, each tied to a registration field or an AC, and every business value came from the
human. Next runs must re-check that the Canvas location holds for r2 and r3, since the earlier failures
came from the actor reading the path instruction differently.
