---
scenario: ambiguous-story-grill
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: n/a (no scaffold in this scenario; pack floor Vela.Plugins >= 0.34.0)
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **8/8 passed**, no failed check (canvas exists; mentions contact, statecode, Update, Sync,
PostOperation, parentcustomerid/Company Name; nothing scaffolded).

## Loop outcome
- `vela version` -> `vela 0.25.0`, exit=0 (actor transcript tool result).
- Read `vela-plan-review` + `vela-grill`, announced "Using vela-plan-review to grill the plan, and using
  vela-grill to resolve the story", restated the story, wrote a draft Canvas with `open_questions`.
- 7 questions, one per turn, each multiple choice: direction (B) -> status meaning (A, statecode) -> rule
  (B, deactivate only) -> link (A, parentcustomerid) -> other events in scope (A, deactivation only) ->
  timing Sync vs Async with consequences explained (A, Sync, race accepted) -> target solution (ZavaSales).
- `vela solution show ZavaSales --json --url https://dyn-premium-dev.crm.dynamics.com` ->
  `{"solution":"ZavaSales","publisherPrefix":"zava"}`, exit=0.
- Final Canvas `work/docs/vela-builds/account-status-sync-contacts.md`, `status: proposed`,
  `open_questions: []`. No scaffold, no `vela apply`.

Evidence of the interview comes from the actor's session transcript
(`~/.claude/projects/-Users-allandecastro-orca-vela-agentic/b50066f1-28b6-4f90-a5d4-51dfd5137426/subagents/agent-a6f2c1c79d9ed47c3.jsonl`),
since `work/` holds only the Canvas.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| plan-review finds unresolvable branches (trigger entity, direction, status meaning, sync/async) and routes to vela-grill instead of guessing | met | Transcript: first turn announces both skills, says "The story does not say which record drives the change", draft Canvas lists open questions; every branch then asked, not assumed |
| vela-grill asks one load-bearing question at a time, tied to registration (not a questionnaire / open chat) | met | Transcript: 7 separate `QUESTION FOR THE HUMAN` turns, each A/B/C(/D), each mapping to entity/direction, data column, acceptance rule, lookup, message scope, mode, solution |
| Asks for the target solution, does not invent it; prefix from `vela solution show` | met | Transcript Q7 + `{"solution":"ZavaSales","publisherPrefix":"zava"}` exit=0; Canvas l.14-15 |
| Canvas records Contact Update, filtered on statecode, Sync | met | Canvas l.6-10 (`entity: contact`, `message: Update`, `mode: Synchronous`, `filtering_attributes: [StateCode]`), l.94-95 |
| Canvas records the "all contacts inactive" rule | met | Canvas l.33, l.56-59, handler step 3 l.103 |
| PostOperation justified by writing another record | met | Canvas l.8, l.73-75 |
| No unresolved branch | met | Canvas l.46 `open_questions: []`; remaining items are platform assumptions (l.38-45) or human-accepted limitations (l.47-49) |
| SC1: no scaffold or code before ambiguity resolved | met | check "nothing scaffolded (no .sln)"; `work/` contains only the Canvas |
| SC2: every question answerable in one line and changes registration or acceptance cases | met | Transcript: all answers were one line ("B - contacts drive the account...", "ZavaSales."); each fed a Canvas field or case |
| SC3: Canvas complete, every answer attributed to the human | met | Canvas l.30-37: 7 `{by: human}` decisions matching the 7 answers; R/E/A/S/O/N/S sections filled |
| SC3: acceptance cases include "last active contact deactivated -> account inactive" | met | Canvas l.19 |
| SC3: acceptance cases include "another contact still active -> account unchanged" | met | Canvas l.20 |

Quality notes (not failures): security context and the Inactive status-reason value were not asked but
recorded as defaults/assumptions, as `vela-grill` step 2 allows; both match the scripted human answers.
The "account deactivation does not cascade to contacts" assumption (l.44) is backed by a planned
PluginPipeline no-recursion test (l.28), so it will be verified rather than trusted.

## Planted-violation results
None: the scenario has no "Planted-violation check" section (no code is produced in this scenario).

## Findings against the skills
None. `vela-grill`'s question order, "one-line multiple choice", "don't ask for the publisher prefix",
and "platform defaults as assumptions" rules were all followed as written and produced the expected
outcome; no skill text misled the actor.

## Verdict
pass - checks 8/8 and every scenario criterion met from the Canvas and the actor transcript. Next run
should re-check that the interview stays one question per turn and that the race / delete / re-parent
limitations are attributed only when the human actually answered them.
