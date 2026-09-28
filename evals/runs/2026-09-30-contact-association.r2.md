---
scenario: contact-association
date: 2026-09-30
verdict: pass
campaign: 2026-09-30
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.21.0
framework: 0.29.7
runner: "campaign actor + separate grader"
---

`framework` comes from the throwaway probe (`vela init` printed "Scaffolding against Vela.Plugins 0.29.7",
Canvas line 76-77). The work has no csproj/props, because nothing was scaffolded for the story.

## Loop outcome
- Version check: `vela version` gave `vela 0.21.0`, exit 0 (Canvas line 75, run trace #1).
- CHALLENGE (vela-plan-review): the Association branch was hit, and the story was set to `status: blocked` (framework limit).
- Limit re-check: a throwaway `vela init` probe was created, built, and run with mono xunit `-parallel none`. `GetStepDefinitions()` gave `EntityLogicalName = contact`, so the limit still holds on 0.29.7. The probe folder was deleted. Its sources are kept under `docs/vela-builds/probe/`.
- The Canvas was written with a Hand-off section and open questions. Nothing else ran: no scaffold, models, tests, package, `vela plan` or `vela apply`.

## Deterministic checks: 6/6 passed
All checks in `checks.json` are ok, so there are no failed checks:
- The Canvas exists.
- It contains `status: blocked`.
- It contains `Hand-off`.
- It contains `none`.
- It contains `AddMember|AddListMembers`.
- There is no `.sln`.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Recognise the framework limit at plan-review (Associate filter `none` vs Vela's table binding) | met | Canvas lines 61-65 (Hand-off item 1); run trace #2 `vela-plan-review` "blocked (framework limit)" |
| Record the story as blocked, with evidence | met | Canvas line 5 `status: blocked`; lines 74-91 evidence (version, init, build, probe output `EntityLogicalName = contact`) |
| Do not scaffold or ship a per-table workaround | met | `work/` contains only `docs/`, with no `.sln` (check "nothing scaffolded"). Safeguards line 105. The probe was a throwaway in a separate folder, since deleted (lines 76-78) |
| Ask whether the story really means Associate (AddMember / AddListMembers) | met | Canvas line 28 (open question a/b/c) and lines 66-72. The question was recorded rather than asked, which `skills/vela-plan-review/SKILL.md` allows ("ask it ... or list it as an open question") |
| SC1: Canvas names the limit and marks the story blocked, with AddMember as an open question | met | lines 5, 28, 61-65 |
| SC2: No plugin scaffolded or packaged; nothing proposed for apply | met | no `.sln`/csproj in `work/`; lines 106 and 118 ("scaffold..apply: not run"); the actor's report says "nothing was applied" |
| SC3: Hand-off says what Vela needs (message-level Associate registration), reported and not worked around | met | lines 93-95: "a Vela release that registers Associate/Disassociate message-only (primary entity `none`)" |

## Planted-violation results
The scenario has no planted-violation section, so this step does not apply.

## Findings against the skills
1. minor: the two instructions in `skills/*/references/dataverse-gotchas.md` (Associate entry) pull against each other.
   - It says "Re-check on each framework release: scaffold an `OnAssociate()` step and look at `GetStepDefinitions()`".
   - It also says "stop before scaffolding".
   - What happened: the actor ran a full `vela init` probe with a build and a mono test run inside the blocked story's workspace. It isolated and deleted the probe, so the run passed. A less careful actor could leave a scaffold behind and fail SC2.
   - Suggested fix: say explicitly that the re-check is done in a throwaway directory outside the target project and then deleted, or that it is a pack-maintainer task and not a step of the build loop.
2. minor: `skills/vela-plan-review/SKILL.md` says "the pack has no recipe for the marketing-list messages yet, so that path is blocked too".
   - The actor found that Vela.Plugins 0.29.7 exposes `PluginMessages.AddMemberList` / `AddListMembersList` and typed `IAddMemberListPostContext<T>` / `IAddListMembersListPostContext<T>` (Canvas lines 68-71).
   - The pack's references (`plugin-authoring-api.md`, `harness-api.md`, `registration-rules.md`) are pinned to 0.29.3 and do not mention these messages.
   - Effect: a story that may be deliverable is blocked by a pack gap rather than a framework limit. A verified AddMember / AddListMembers recipe should be added.
3. minor: the version floors in the pack's text are pinned to 0.29.3 ("Vela 0.29.3 limit", "not expressible in Vela 0.29.3"), but the latest framework is 0.29.7.
   - The wording forces a re-check on every run.
   - Suggested fix: record the last-verified version and date in one place, so an actor can tell when a re-check is actually due.

## Verdict
**pass.** Checks are 6/6 and the grader found every criterion met; there were no planted violations to test. The next run should re-check that the actor still keeps any limit probe out of the target project, and see whether a pack AddMember recipe changes the expected outcome.
