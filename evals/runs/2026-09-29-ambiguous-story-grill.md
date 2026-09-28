---
scenario: ambiguous-story-grill
date: 2026-09-29
verdict: pass
vela_cli: 0.19.6
framework: 0.28.2
runner: "fresh subagent, local, no org, human played by the orchestrator"
---

## Loop outcome
- Version: `vela version` -> `vela 0.19.6`, exit 0 (floor 0.19.6 met); `dotnet --version` -> 10.0.302.
- Read `agents/vela-builder.agent.md` and `skills/using-vela/SKILL.md`, then `vela-plan-review` (+ build-report-template, registration-rules, dataverse-gotchas) and `vela-grill`.
- Intake / Plan: interpreted it as a cross-record contact<->account `statecode` sync. Direction, "status" column, rollup rule, relationship and timing were unresolved and business-owned, so the agent routed to `vela-grill` (per builder step 3) instead of assuming.
- `vela-grill`: 9 questions, one per turn, each multiple choice and answerable in one line:
  1. Direction? -> contacts drive the account only.
  2. Which status? -> standard `statecode` on both.
  3. Rollup rule? -> deactivate when the last active contact is deactivated; never reactivate.
  4. Which contacts? -> `parentcustomerid` = account.
  5. Other triggers (delete / re-parent)? -> deactivation only.
  6. Sync or Async? -> Sync, same transaction.
  7. Security context? -> calling user, no elevation.
  8. Account statuscode on deactivation? -> default Inactive (2).
  9. Target solution + publisher prefix? -> `ZavaSales`, `zava`.
- `vela-plan-review`: resolved the technical branches (Update / PostOperation / Sync, FilterOn statecode, pre-image statecode, post-image statecode+parentcustomerid, new plugin, no service, `--no-integrations`, recursion, legality) and wrote the Canvas with 12 acceptance cases and 5 flagged technical assumptions. Canvas: `account-deactivate-on-last-contact.md` in this folder.
- Stopped at the Canvas (scope). No scaffold, no code, no org, no `vela apply`.

## Findings
1. minor - `skills/vela-plan-review/SKILL.md` Process says "It is **advisory** - you flag unresolved assumptions and continue; you do not block" and step 4 "Flag the assumptions ... and **continue** to `vela-scaffold`". Its Process has no general "route to vela-grill when only the human can decide" step. The only mention is inside the solution/prefix branch. The route to `vela-grill` comes from `agents/vela-builder.agent.md` step 3 and `using-vela`. The agent followed the builder. A literal run of plan-review alone would have assumed the direction and rollup rule. Correct path: add a step to plan-review's Process: "a branch whose answer is a business decision (direction, rule, scope, timing) and the human is reachable -> `vela-grill`, then resume here".
2. minor - Order is ambiguous. `vela-builder.agent.md` step 3 runs grill *inside* Challenge ("If only the human can resolve an ambiguity, use `vela-grill`"), but `skills/vela-grill/SKILL.md` step 4 says "Hand off to the build loop (`vela-plan-review` → `vela-scaffold`)", which puts grill *before* plan-review. The agent started plan-review, switched to grill, then resumed plan-review for the technical branches. Correct path: state one order: plan-review detects the gap -> grill -> plan-review finishes the Canvas.
3. minor - `skills/vela-grill/SKILL.md` Verification says "every answer came from the human, not an assumption". This conflicts with plan-review's `assumptions:` list for technical branches the human can't meaningfully answer: legacy SetState routed through Update, UpdateMultiple firing Update steps, the concurrency on "last contact", and no cascade of account state. The agent kept those as flagged assumptions and did not ask. Correct path: scope the rule to business/behaviour answers, and let technical platform facts be agent-decided and flagged.
4. minor - The `skills/vela-grill/SKILL.md` question list ("Trigger / Timing / Data / Scope: single record or bulk (*Multiple)? which security context? / Definition of done") has no cross-record question: which related records count (the relationship), and which other events can change the aggregate (delete, re-parent). It also has no question on "which column is 'status'". The agent added questions 2, 4 and 5 on its own. Correct path: add "Records: which related records, via which relationship; which events (update/delete/re-parent) change the outcome?" and "which exact column does the story's term mean?".
5. minor - `skills/vela-grill/SKILL.md` "Keep going until every branch resolves" gives no budget and no priority order, and "Definition of done" is listed but can be derived. The run took 9 turns, and the agent derived the DoD from answers 3-6 instead of asking it. The scenario setup had a DoD answer ready. Correct path: say "ask the DoD only if it can't be derived from the answers; order questions trigger -> data -> scope -> timing -> security -> solution".
6. minor - `references/dataverse-gotchas.md` / `registration-rules.md` say nothing about state-change stories. They don't cover `statecode` changes via legacy SetState vs Update, whether an Update step fires for UpdateMultiple, the polymorphic Customer lookup (`parentcustomerid` may be a contact), or the concurrency race in "last one / all X" aggregates. The agent relied on outside knowledge and recorded assumptions. Correct path: add a "state changes & aggregates" gotcha block.
7. minor - The security context mapping is unclear. `vela-grill` asks "which security context?". `plugin-authoring-api.md` offers "`ctx.UserService` (initiating user), `ctx.CallingUserService`, or `ctx.SystemService`", and the builder says "`ctx.UserService` to write". The human answered "calling user", and the "initiating user" label on `UserService` suggests it is the wrong service. The agent used `ctx.UserService` with a "no WithImpersonation, so initiating = calling" rationale. Correct path: one line mapping each grill answer (calling user / initiating user / system) to its service.
8. minor - `skills/vela-plan-review/SKILL.md` requires "on Update, 'column not sent' vs 'column cleared'". `statecode` is a required state column and cannot be cleared. The agent substituted "sent with the same value". Correct path: "... or, for a non-nullable/state column, 'sent unchanged'".
9. minor - The Canvas template (`references/build-report-template.md`) has no place to attribute decisions to the human, and its scalar `images: []` example doesn't show the pre+post shape (that shape appears only inside the `steps:` comment). It also has a single `entity:` field while the story names account and the step lives on contact. The agent put the attribution in R prose, used `images: [{pre: [...]}, {post: [...]}]`, and set `entity: contact` with a comment. Correct path: add `decisions:` (question -> human answer), show the image list shape, and note "entity = the table the step is registered on".
10. minor - `skills/vela-grill/references/` bundles only `build-report-template.md`, yet grill's questions are "driven by what a correct registration needs". A human-started `/vela-grill` has no local `registration-rules.md` / `dataverse-gotchas.md` to consult. The agent read plan-review's copies. Correct path: bundle `registration-rules.md` in vela-grill too, or point at plan-review's.

## Fixes
- none yet (eval run only; pack is read-only in this run)

## Verdict
pass. No scaffold or code before the ambiguity was resolved (criterion 1). Every question was a one-line
multiple choice that changed the registration or the acceptance cases (criterion 2). The Canvas is
complete with no open questions. Business answers are attributed to the human, and the cases include
"last active contact deactivated -> account inactive" and "another contact still active -> account
untouched" (criterion 3). The solution and prefix were asked for, not invented. Next run must re-check:
plan-review's own routing to grill (finding 1), the grill order (2), the attribution-vs-assumptions rule (3),
and whether a question budget or ordering reduces the 9 turns (5).

## Evaluator note

The human was played by the orchestrator. Three answers were not in the scenario's script and were
chosen as the natural / skill-default answer: contacts linked by `parentcustomerid`; the calling
user's security context (no elevation); the default Inactive status reason.
