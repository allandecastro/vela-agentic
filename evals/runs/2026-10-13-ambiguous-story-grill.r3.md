---
scenario: ambiguous-story-grill
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 3/3
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
- Read `using-vela`, `vela-plan-review`, `vela-grill`; announced "Using vela-plan-review to grill the plan,
  then vela-grill to resolve the story with the human (this story is too ambiguous to settle with
  assumptions)", restated the two readings (contact->account vs account->contacts).
- 8 questions, one per turn, each multiple choice: direction (A) -> status meaning (A, statecode, default
  reason) -> rule (B, deactivate only) -> link (A, parentcustomerid) -> trigger events (A, deactivation
  only; delete / re-parent offered) -> timing Sync vs Async with rollback consequence (A) -> security
  context (A, calling user) -> target solution (ZavaSales).
- `vela solution show ZavaSales --json --url https://<dev-org>.crm.dynamics.com` ->
  `{"solution":"ZavaSales","publisherPrefix":"zava"}`, exit=0.
- Final Canvas `work/docs/vela-builds/account-deactivate-when-no-active-contacts.md`, `status: proposed`,
  `open_questions: []`. No scaffold, no `vela apply`.

Evidence of the interview is the actor's session transcript
(the actor session transcript, not committed),
since `work/` holds only the Canvas. (The actor's report file says "7 questions" while listing 8 decisions;
the transcript shows 8 - a report inconsistency, not a run defect.)

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| plan-review finds unresolvable branches (trigger entity, direction, status meaning, sync/async) and routes to vela-grill instead of guessing | met | Transcript first turn: announces both skills, names the direction ambiguity; direction, status, timing all asked, none assumed |
| vela-grill asks one load-bearing question at a time, tied to the registration | met | Transcript: 8 separate `QUESTION FOR THE HUMAN` turns, each A/B(/C), mapping to trigger entity, data column, acceptance rule, lookup, message scope, mode, security context, solution |
| Asks for the target solution, does not invent it; prefix from `vela solution show` | met | Transcript Q8 ("I will read its publisher prefix ... with `vela solution show`") + output exit=0; Canvas l.14-15 |
| Canvas records Contact Update, filtered on statecode, Sync | met | Canvas l.6-10, l.85-86 |
| Canvas records the "all contacts inactive" rule | met | Canvas l.31, l.51-53, O step 3 l.90 |
| PostOperation justified by writing another record | met | Canvas l.8, l.65-67 |
| No unresolved branch | met | Canvas l.44 `open_questions: []`; remaining items (l.37-43) are platform assumptions, not business branches |
| SC1: no scaffold or code before ambiguity resolved | met | check "nothing scaffolded (no .sln)"; `work/` contains only the Canvas |
| SC2: every question answerable in one line and changes registration or acceptance cases | met | Transcript: all answers one line ("A - only deactivation.", "ZavaSales."); each fed a Canvas field or case (l.6-15, l.18-27) |
| SC3: Canvas complete, every answer attributed to the human | met | Canvas l.28-36: 8 `{by: human}` decisions matching the 8 answers; all R/E/A/S/O/N/S sections filled (l.48-108) |
| SC3: case "last active contact deactivated -> account inactive" | met | Canvas l.18 |
| SC3: case "another contact still active -> account unchanged" | met | Canvas l.19 |

Quality notes (not failures): the security-context question was asked rather than defaulted - acceptable
(it changes an acceptance case: l.26 permission-denied rollback). The default Inactive status reason value
(statuscode 2) is recorded as an assumption (l.41), matching the human's "default Inactive status reason".
The no-recursion assumption (l.42) is backed by a planned PluginPipeline case (l.27).

## Planted-violation results
None: the scenario has no "Planted-violation check" section (no code is produced in this scenario).

## Findings against the skills
None. `vela-plan-review` routed to `vela-grill`; `vela-grill`'s one-question, multiple-choice, ask-the-solution
(not the prefix) and platform-facts-as-assumptions rules were followed and produced the expected Canvas.
No skill text misled the actor.

## Verdict
pass - checks 8/8 and every scenario criterion met from the Canvas and the actor transcript. Next run should
re-check the interview stays one question per turn and that the question count stays bounded (8 here, vs 7 in r1).
