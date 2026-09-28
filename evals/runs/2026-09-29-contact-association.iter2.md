---
scenario: contact-association
date: 2026-09-29
verdict: pass
vela_cli: 0.21.0
framework: n/a (not scaffolded; pack states the limit for Vela.Plugins 0.29.3)
runner: "fresh subagent, local, no org, iteration 2"
---

## Loop outcome
- 0 version: `vela version` -> `vela 0.21.0` (exit 0), meets the 0.21.0 floor.
- 1 Intake: read literally - contact <-> list N:N association (`listcontact_association`) -> Associate, stamp `contact.description`.
- 2 Plan: new plugin, no service, no integrations; solution/prefix unknown.
- 3 Challenge (`vela-plan-review`): the "Association" grilling branch fired - Associate needs a message-level
  registration (primary entity `none`), not expressible in Vela 0.29.3 (dataverse-gotchas.md) -> Canvas
  recorded as **blocked (framework limit)**, with the limit, the AddMember/AddListMembers question (Q1),
  overwrite/removal (Q2) and solution/prefix (Q3) as open questions, and a hand-off naming what Vela needs.
  Canvas: `contact-marketing-list-description.md` (this folder). No human reachable -> questions written, not asked.
- 4-12: **not run** by design. No `vela init`/`vela add`, no package, no `vela models`/`vela plan` (no org; would-be
  commands recorded in the Canvas, flags checked with `vela models --help` / `vela plan --help`), no `vela apply`.

## Findings
1. minor - `agents/vela-builder.agent.md` has no exit path for a blocked story. Its loop is "Challenge ... and
   **continue** (advisory gate)" through steps 4-12, and step 12 says "open the PR as a **draft** as soon as the Vela
   Canvas exists". Only `vela-plan-review` ("record the story as **blocked (framework limit)** and stop") and
   `dataverse-gotchas.md` ("stop before scaffolding") say to stop. The agent had to decide that the gotcha overrides
   the builder's "advisory gate, continue", and what to do with the draft-PR instruction (skipped: no repository is
   created before scaffold, and a PR for a blocked, empty change has no diff). Correct path: add a "Blocked" exit to
   the builder (stop after Challenge; deliver the Canvas + hand-off; no scaffold, no PR or a Canvas-only PR - say which).
2. minor - `references/build-report-template.md`: `status: proposed          # proposed | approved | superseded`.
   There is no `blocked` status and no hand-off section for a blocked Canvas, although the gotcha says "record it in
   the Canvas as blocked". The agent left `status: proposed` with a comment and invented a "Hand-off" section. Correct
   path: add `blocked` to the enum plus a `blocked_by:` / "what Vela needs" field.
3. minor - `skills/vela-plan-review/SKILL.md`: "Also confirm the story really means Associate (marketing-list members
   may come through `AddMember` / `AddListMembers`)." It does not say who confirms (a business question for
   `vela-grill`, or a platform fact the agent must know), nor what happens if the answer is AddMember/AddListMembers
   (is that deliverable - e.g. `OnMessage("AddListMembers")` on a `list` plugin - or also blocked?). The pack has no
   recipe, legal-matrix row, or harness guidance for AddMember/AddListMembers, and says nothing about dynamic lists
   (no event at all). With no human, the agent logged it as open question Q1 and stayed blocked; a run with a human
   who answers "via the list's Add members" would have nowhere to go. Correct path: state the rule explicitly -
   "blocked either way until verified; AddMember/AddListMembers is a separate, unverified registration" - or add a
   verified recipe.
4. minor - `skills/vela-plan-review/SKILL.md` step 4 ("No human reachable ... Continue on a flagged assumption") and
   the Association branch ("record ... blocked ... and stop") point in opposite directions for this story; the
   precedence (a framework-limit stop beats the unattended-continue rule) is implied, not stated.
5. minor - the limit is pinned to a version ("Vela 0.29.3 cannot express") while the floor is `Vela.Plugins >= 0.29.1`
   and `vela init --core-version <ver>` exists; the local NuGet cache also holds `vela.plugins/1.0.0`. The pack gives
   no check to tell whether the framework the scaffold would pull still has the limit (e.g. inspect
   `GetStepDefinitions()` for an `OnAssociate()` step). The agent assumed the limit holds without verifying.

No blocker against the scenario's criteria.

## Fixes
- none yet (skill pack is read-only in this run).

## Verdict
**pass.** Criterion 1: the Canvas names the limit (Associate filter primary entity `none` vs Vela binding `OnAssociate()`
to the plugin's table) and marks the story blocked, with the AddMember/AddListMembers question as open question Q1.
Criterion 2: nothing scaffolded, packaged or proposed for apply. Criterion 3: the Canvas "Hand-off" section says Vela
needs a message-level Associate/Disassociate registration (and a `vela plan` diagnostic) - reported, not worked around.
Next run must re-check: findings 1-3 (a blocked exit in the builder + template), and - once Vela supports message-level
Associate - the flip back to a build.
