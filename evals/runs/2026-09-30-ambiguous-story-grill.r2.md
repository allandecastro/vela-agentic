---
scenario: ambiguous-story-grill
date: 2026-09-30
verdict: fail
campaign: 2026-09-30
run: 2/3
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

All seven failures have one cause: the Canvas is at `work/account-contact-status-sync.md`, not under
`work/docs/vela-builds/`. The content checks then have no file to read. The file does contain every
term the checks look for: `contact` (l.6), `statecode` (l.18), `message: Update` (l.7), `Sync()` (l.106),
`stage: PostOperation` (l.8), and `parentcustomerid` (l.25, l.35).

## Loop outcome
- `vela version` gave `vela 0.21.0`, exit 0 (actor transcript, 4th Bash call).
- It read vela-plan-review, registration-rules and the gotchas. It found unresolvable branches and wrote a
  placeholder Canvas (`canvas-draft.md`) with 7 open questions. There was no scaffold.
- vela-grill asked 7 questions, one per turn. Each was multiple choice and each answer was one line: A/B/C, or "ZavaSales / zava".
- It checked the flags with `vela init|add plugin|add service|add test|models --help` and `vela add --help`.
- It wrote the full Canvas to `work/account-contact-status-sync.md` and removed the draft.
- There was no scaffold, no models, no plan and no apply. That is correct for this scenario.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| plan-review finds unresolvable branches (trigger entity, direction, what "status" means, sync/async) and routes to vela-grill instead of guessing | met | The draft Canvas `open_questions` Q1-Q7 cover direction, status meaning, relationship, rule, timing, events and solution. The first output to the human is a question, not a design. |
| vela-grill asks one load-bearing question at a time, tied to the registration | met | Transcript: 7 separate `QUESTION FOR THE HUMAN` turns. Direction and events set the trigger entity and message, status meaning sets the filter, the relationship sets the data, timing sets Sync/Async, security sets the service context, and the last question sets solution and prefix. None is open-ended. |
| Asks for the target solution and publisher prefix instead of inventing them | met | Q7 in the transcript. Canvas l.14-15 and decision l.39 `{by: human, ... ZavaSales, publisher prefix zava (Q7)}`. |
| Canvas records Contact Update, filtered on statecode, Sync | met | Canvas l.6-10: `entity: contact`, `message: Update`, `mode: Synchronous`, `filtering_attributes: [StateCode]`. Registration sketch at l.103-109. |
| Canvas records the "all contacts inactive" rule | met | l.34, l.54-55, l.117-118 (query for another active contact; if one exists, return). |
| PostOperation justified because it writes another record | met | l.8 `stage: PostOperation # writes ANOTHER record (the account)`. Approach l.72-73. |
| No unresolved branch | met | l.47 `open_questions: []`. Platform facts are listed as assumptions (l.40-46), and the default Inactive reason is at l.43, which fits the human's "use your judgement". |
| SC1: no scaffold or code before the ambiguity is resolved | met | check "nothing scaffolded (no .sln)" passed. `work/` holds only the Canvas. |
| SC2: every question answerable in one line and changes the registration or acceptance cases | met | Every question offered A/B/C options (Q7 was a two-value answer), and every answer was one line. Each maps to a frontmatter field or an acceptance case: Q4 gives AC10/AC11, Q5 gives the mode, Q6 gives AC12. |
| SC3: Canvas complete, every answer attributed to the human, acceptance cases include "last active contact deactivated -> account inactive" and "another contact still active -> account unchanged" | met (content) / not met (location) | All seven REASONS sections are filled (l.51-139), and the 7 decisions (l.33-39) are all `by: human`. AC1 (l.18) and AC2 (l.19) match the required cases. However, the file is not at `docs/vela-builds/<slug>.md`, the path AGENTS.md and the template name. |

## Planted-violation check
This scenario has none, so none were run.

## Findings against the skills
1. **blocker** - `agents/vela-builder.agent.md` l.63-65 says: "**New solution (no repository yet):** draft the Canvas
   outside the project, then `vela init` → ... → move the Canvas into `docs/vela-builds/<slug>.md`".
   The template (`skills/vela-plan-review/references/build-report-template.md` l.13) says: "One file per story:
   `docs/vela-builds/<slug>.md` starts as the Canvas".
   In this scenario the run ends before `vela init`, so the "move" never happens. The actor followed the
   builder text and left the Canvas at `work/account-contact-status-sync.md`. That failed 7 of 8
   deterministic checks, even though the content is complete.
   The pack does not say where the Canvas lives when the run stops before the scaffold, or what "outside
   the project" means as a concrete path.
   Fix, pick one:
   - Name the draft location as `<workdir>/docs/vela-builds/<slug>.md` from the start. `vela init --output .`
     tolerates an existing `docs/`, so this needs confirming.
   - Or state that a Canvas-only run (grill, blocked story) must still leave the Canvas at
     `docs/vela-builds/<slug>.md`.
2. minor - `skills/vela-grill/SKILL.md` l.22 says: "Announce: `Using vela-grill to resolve the story`". In the
   transcript the announcements (`Using vela-plan-review ...`, `Using vela-grill ...`) never appear in a
   message to the human. Only the actor's final report claims them. This is actor compliance, not a skill
   defect, and it is recorded here for traceability only.

## Verdict
**fail**, because the checks failed (1/8). The grader's own verdict is pass: every behavioural criterion is met. The grilling was a
good example: one multiple-choice question per turn, and each question mapped to a registration field.
The next run must re-check that the Canvas lands under `docs/vela-builds/` once finding 1 is fixed.
