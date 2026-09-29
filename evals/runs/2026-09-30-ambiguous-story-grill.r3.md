---
scenario: ambiguous-story-grill
date: 2026-09-30
verdict: fail
campaign: 2026-09-30
run: 3/3
checks: fail
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: n/a (no scaffold in this scenario - no csproj/props)
runner: "campaign actor + separate grader"
---

## Checks (checks.json): 1/8 passed
Failed:
- canvas exists (docs/vela-builds/*.md)
- canvas mentions 'contact'
- canvas mentions 'statecode'
- canvas mentions 'Update'
- canvas mentions 'Sync'
- canvas mentions 'PostOperation'
- canvas mentions 'parentcustomerid|Company Name'

Passed: nothing scaffolded (no .sln).

All seven failures have one cause, the same as in r2. The Canvas is at
`work/account-contact-status-sync.canvas.md`, not under `work/docs/vela-builds/`, so the content checks
have no file to read. The file does contain every term they look for: `entity: contact` (l.6),
`message: Update` (l.7), `stage: PostOperation` (l.8), `mode: Synchronous` (l.9), `statecode` (l.11) and
`parentcustomerid` (l.11, l.31).

## Loop outcome
- `vela version` returned `vela 0.21.0` (the actor's report, consistent with the transcript).
- The actor announced "Using vela-plan-review to grill the plan. Using vela-grill to resolve the story." It
  drafted a Canvas with the open branches, then asked its first question. Nothing was scaffolded.
- vela-grill asked 7 questions, one `QUESTION FOR THE HUMAN` turn each (actor transcript, entries 60, 71,
  81, 91, 101, 111 and 120). Each was multiple choice, and each answer was one line.
- The actor checked the flags with `vela --help` and `vela add --help`, then finished the Canvas with
  `status: proposed` and `open_questions: []`.
- There was no scaffold, no models, no plan and no apply, which is correct for this scenario.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| plan-review finds the branches it cannot resolve (trigger entity, direction, what "status" means, sync vs async) and routes to vela-grill instead of guessing | met | Transcript entry 53 drafts the Canvas "with the open branches". The first message to the human (entry 60) is a question about direction, and it lists the branches still to come: what "status" means, the relationship, Sync/Async, and solution/prefix. |
| vela-grill asks one load-bearing question at a time, tied to the registration | met | 7 separate turns. Direction sets the step entity. The rule and status meaning set the filter (statecode) and the ACs. The relationship sets the pre-image and query. Events set the message scope. Timing sets Sync/Async. Security sets UserService. The last question sets the solution and prefix. None of them is open-ended. |
| Asks for the target solution and publisher prefix instead of inventing them | met | Transcript entry 120 asks for them. Canvas l.14-15 and l.35: `{by: human, what: "Target solution ZavaSales, publisher prefix zava"}`. |
| Canvas records Contact Update, filtered on statecode, Sync | met | Canvas l.6-10 give `entity: contact`, `message: Update`, `mode: Synchronous` and `filtering_attributes: [StateCode]`. The registration sketch is at l.97-100. |
| Canvas records the "all contacts inactive" rule | met | l.17-18 (the ACs), l.30 (the decision), and l.105-106 (the service queries for any remaining active contact, and returns if it finds one). |
| PostOperation justified because it writes another record | met | l.8 `stage: PostOperation # writes ANOTHER record (the account)`. Approach at l.67-69. |
| No unresolved branch | met | l.45 `open_questions: []`. Platform facts are recorded as assumptions (l.36-44), including the default Inactive reason (statuscode 2, l.43), which fits "use your judgement". |
| SC1: no scaffold or code before the ambiguity is resolved | met | The check "nothing scaffolded (no .sln)" passed. `work/` holds only the Canvas. |
| SC2: every question answerable in one line, and each changes the registration or the ACs | met | Every question gave A/B/C(/D) options; Q7 took a two-value answer. Each one maps to a front-matter field or an AC: Q4 gives the AC at l.27, Q5 gives `mode`, Q6 gives the AC at l.26. |
| SC3: Canvas complete, every answer attributed to the human, ACs include "last active contact deactivated -> account inactive" and "another contact still active -> account unchanged" | met (content) / not met (location) | All 7 REASONS sections are filled (l.49-122). The 7 decisions (l.29-35) are all `by: human`. AC l.17 and l.18 match the required cases. But the file is not at `docs/vela-builds/<slug>.md`, which is the path AGENTS.md and the template name. The deterministic checks fail on that. |

## Planted-violation check
This scenario has none, so none were run.

## Findings against the skills
1. **blocker** (repeat of r2 finding 1, still open). `agents/vela-builder.agent.md` l.63-65 says:
   "**New solution (no repository yet):** draft the Canvas outside the project, then `vela init` → ... →
   move the Canvas into `docs/vela-builds/<slug>.md`". But
   `skills/vela-plan-review/references/build-report-template.md` l.13 says: "One file per story:
   `docs/vela-builds/<slug>.md` starts as the Canvas".
   This scenario ends before `vela init`, so the "move" never happens. The actor followed the builder
   and left the Canvas at `work/account-contact-status-sync.canvas.md`. It also added a `.canvas.md`
   suffix that no skill defines. That failed 7 of 8 deterministic checks, even though the content is
   complete.
   The pack names no concrete path for a Canvas when the run stops before the scaffold (a grill-only run
   or a blocked story).
   Fix: give the draft path explicitly, for example `<workdir>/docs/vela-builds/<slug>.md` from the start
   (confirm that `vela init --output .` tolerates an existing `docs/`). Or state that a Canvas-only run
   still leaves the Canvas at `docs/vela-builds/<slug>.md`. The runs split 1/3: r1 put it under
   `docs/vela-builds/` and passed 8/8, while r2 and r3 followed the "draft outside the project" wording.
   Since the outcome depends on which instruction the actor reads, the ambiguity is in the pack, not bad
   luck on the actor's part.

## Verdict
**fail**, because the checks failed (1/8). The grader's own verdict is pass: every behavioural criterion is
met, and the grilling was exemplary, with one multiple-choice question per turn, each tied to a
registration field or AC. The only defect is where the Canvas was left (finding 1). After the fix, the next
run must re-check that the Canvas lands under `docs/vela-builds/`.
