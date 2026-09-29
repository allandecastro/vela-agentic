---
scenario: ambiguous-story-grill
date: 2026-10-01
verdict: pass
campaign: 2026-10-01
run: 3/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: n/a (no scaffold in this scenario - no csproj/props)
runner: "campaign actor + separate grader"
---

## Checks (checks.json): 8/8 passed
No failed checks. The Canvas is at `work/docs/vela-builds/account-contact-status-sync.md`. It mentions
contact, statecode, Update, Sync, PostOperation and parentcustomerid/Company Name. No `.sln` was created.

## Loop outcome
Source: the actor transcript (subagent `agent-a5945c5d7a3224cff.jsonl`, 2026-09-29). An earlier attempt,
`agent-a1f099c6fba379173`, was interrupted after 4 questions on 2026-09-28. The run on 2026-09-29 is the
one that produced `work/`.
- The actor read using-vela, vela-plan-review and vela-grill, and its references. `vela version` returned
  `vela 0.21.0` (entry 36).
- It drafted the Canvas at `docs/vela-builds/account-contact-status-sync.md` with `status: proposed` and
  the open branches (entry 43). Its first message to the human (entry 49) restated the story and listed
  the open branches: status meaning, direction, relationship, triggering events, sync/async, and
  solution/prefix.
- vela-grill asked 8 questions, one `QUESTION FOR THE HUMAN` turn each (entries 49, 58, 67, 77, 87, 97, 107
  and 116). All were multiple choice except the solution/prefix question. Each answer was one line, and
  each was written into the Canvas as `by: human` right after it arrived.
- The actor handed back to vela-plan-review (entry 121) and checked flags with `vela init/add plugin/add
  test/plan --help` (entry 122). It then wrote the final Canvas with `open_questions: []` (entry 128).
- There was no scaffold, no models, no plan and no apply, which is correct for this scenario.

## Criteria
| Criterion | Met? | Evidence |
|---|---|---|
| plan-review finds the branches it cannot resolve (trigger entity, direction, what "status" means, sync vs async) and routes to vela-grill instead of guessing | met | Entry 49 lists status meaning, direction, relationship, triggering events, sync/async and solution/prefix as open questions in the draft Canvas. It asks the first one instead of assuming. |
| vela-grill asks one load-bearing question at a time, tied to the registration | met | 8 separate turns. Q1 (status → `statecode` filter), Q2 (direction → step entity), Q3 (rule → ACs l.17-20), Q4 (relationship → post-image and query, l.11, l.63-64), Q5 (events → message scope, l.35), Q6 (timing → `mode`), Q7 (security → UserService, AC l.26) and Q8 (solution/prefix). None is open-ended. Q3 also carried two edge-case follow-ups (no contacts, race), and they were answered in the same line. |
| Asks for the target solution and publisher prefix instead of inventing them | met | Entry 116 asks for them and says "never invented". Canvas l.14-15, l.38: `{by: human, what: "Target solution ZavaSales, publisher prefix zava"}`. |
| Canvas records Contact Update, filtered on statecode, Sync | met | Canvas l.6-10: `entity: contact`, `message: Update`, `mode: Synchronous`, `filtering_attributes: [StateCode]`. The registration sketch is at l.91-96. |
| Canvas records the "all contacts inactive" rule | met | l.17-18 (ACs), l.31 (decision), l.53-56 (requirement), and l.102 (query for any remaining Active contact; if one is found, return). |
| PostOperation justified because it writes another record | met | l.8 `stage: PostOperation # writes ANOTHER record (the parent account)`. l.69-71: "it writes a *different* record ... (the same-record PostOp-write anti-pattern does not apply)". |
| No unresolved branch | met | l.46 `open_questions: []`. Platform facts are listed as assumptions at l.39-45: SetState goes through Update, PostOp visibility, statuscode 2, no cascade, and Update vs UpdateMultiple. |
| SC1: no scaffold or code before the ambiguity is resolved | met | The check "nothing scaffolded (no .sln)" passed. `work/` contains only `docs/vela-builds/account-contact-status-sync.md`. |
| SC2: every question answerable in one line, and each changes the registration or the ACs | met | Every human answer in the transcript is one line (entries 51, 60, 69, 79, 89, 99, 109, 118). Each one maps to a front-matter field or an AC (see row 2). |
| SC3: Canvas complete, every answer attributed to the human, ACs include "last active contact deactivated -> account inactive" and "another contact still active -> account unchanged" | met | All 7 REASONS sections are filled (l.50-124). All 10 decisions at l.29-38 are `by: human`, and each matches a coordinator answer in the transcript, so none was invented. AC l.17 is "last active contact ... deactivated -> account statecode=Inactive". AC l.18 is "contact deactivated while another contact ... is still Active -> account unchanged". |

## Planted-violation check
The scenario has no planted violations, so none were run.

## Findings against the skills
None blocking.
1. minor (observation, not a pack defect as written): `skills/vela-grill/SKILL.md` l.22 says "Announce:
   `Using vela-grill to resolve the story`". The actor's turns start with `QUESTION FOR THE HUMAN:`, as the
   eval harness requires, so the announcement never appears (entry 49). The only skill announcement is
   "Handing back to vela-plan-review" (entry 121). The requirement comes from the harness prompt, so this
   is not a skill defect. It does leave the trace without the announcement that golden rule 3 asks for.
2. minor: `skills/vela-grill/SKILL.md` l.25 says "Ask **one focused question at a time**". Q3 (entry 67)
   bundled the rule with two edge-case sub-questions (an account with no contacts, and the
   parallel-deactivation race). The human answered all three in one line, so this did not cost a turn. The
   skill does not say whether edge-case follow-ups may ride on the question they belong to. Consider one
   line that allows that, or forbids it, so runs behave consistently.

## Verdict
**pass**. All 8 checks passed, and every behavioural criterion is met. The grilling asked one
multiple-choice question per turn, each tied to a registration field or AC. The solution and prefix were
asked, not invented. The Canvas is complete at `docs/vela-builds/`, and every decision is attributed to
the human. This confirms the fix for the Canvas location from campaign 2026-09-30 (r2/r3 finding 1).
