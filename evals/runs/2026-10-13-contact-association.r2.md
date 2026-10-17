---
scenario: contact-association
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 2/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **21/21 passed**, no failed check. Key ones: step registered `Associate '' PostOperation/Synchronous rel=contactleads_association`; exactly 1 authored step; tests re-run green (total=7, failed=0); no VELA diagnostics; tests use `PluginPipeline` and `WithManyToMany`; no `SystemService` in src; `vela solution show` ZavaSales/zava; read-only `vela plan` runs and creates only the authored package + step.

## Loop outcome
- `vela version` -> 0.25.0 (exit 0). Grill: 3 questions (relationship, overwrite, solution); answers match the evaluator's human answers.
- `vela solution show ZavaSales --json` (0) -> prefix zava. `vela init` (0), Vela.Plugins 0.34.0.
- `vela models --entities contact,lead` (0, 14 files); relationship name confirmed from generated `[RelationshipSchemaName("contactleads_association", ManyToMany = true)]`.
- `vela add plugin ... --message Associate` / `vela add test` (0); `.ForRelationship(...)` added by hand.
- RED commit `e956603`: mono xunit `Total: 7, Failed: 4` (exit 1) -> GREEN commit `363ce61`: `Total: 7, Failed: 0`.
- Review: isolated vela-reviewer subagent, PASS (0 Critical / 0 Required / 3 Nits).
- `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg`; `vela plan --solution ZavaSales --detailed-exitcode` exit 8 (changes: create package + 1 step). Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| Associate message-level, scoped `ForRelationship("contactleads_association")`, name read from org metadata / asked | yes | `src/Zava.Plugins/Contact/Plugins/ContactLeadLinkPlugin.cs:23-28`; check "step registered: Associate '' ... rel=contactleads_association"; Canvas line 26 (human) + generated `Contact.cs` RelationshipSchemaName |
| Either side can be the Target | yes | plugin `ContactsOf` lines 53-59; tests AC1 (`:54`) contact side, AC2 (`:69`) lead side with 2 contacts |
| Writes another record via `ctx.Service.Update`, PostOperation Sync, no recursion | yes | plugin line 49; Canvas Approach line 64; check "src must not contain SystemService" |
| Tests: PluginPipeline + WithManyToMany, one per direction, other relationship does not stamp | yes | tests `:25-27`, `:54`, `:69`, `:152-168` (`HandlerInvoked == false`, SkipReason, description unchanged) |
| Minimal scaffold + models contact/lead; `vela solution show ZavaSales`; `vela plan --solution` | yes | runtrace rows 3-5, 13; checks "no scaffold demo registered", "target solution ZavaSales exists" |
| SC1 Associate, message-level, scoped, PostOperation Sync | yes | check "step registered ..." + "exactly 1 authored step(s)" |
| SC2 RED then GREEN for contact side, lead side, other relationship | yes | `work/review/redgreen.txt` (RED 4 failing for the right reasons at `e956603`; GREEN 7/7 at `363ce61`); check "tests re-run green" total=7. The other-relationship test passes pre-code by design (guard case), discriminating a missing ForRelationship |
| SC3 ctx.Service, no elevation | yes | plugin line 49; Canvas assumption line 35 |
| SC4 review PASS; Build Report with `vela plan --solution ZavaSales` evidence; stops before apply | yes | `docs/vela-builds/contact-lead-link-description.review.md` (PASS, 0 Crit/Req); Build Report lines 102, 121-124 (`apply: pending`, gate command handed to human) |

## Planted-violation results
None: this scenario defines no "Planted-violation check" section.

## Findings against the skills
None blocking, none minor. Observations that are not pack defects:
- The plan's rank-1 execution-order collision with Microsoft managed Associate steps was correctly classified as harmless per `dataverse-gotchas.md:131` ("Rank \"collisions\" with Microsoft / managed steps are normal and harmless.").
- `vela add plugin --message Associate` cannot emit `.ForRelationship(...)`; the actor added it by hand, per the Canvas. That is a CLI scaffold capability, not a skill defect, and it did not cause an error.
- The actor ran vela 0.25.0. The installed CLI is now 0.25.1, a patch difference only.

## Verdict
pass. All 21 checks pass and every criterion is met from the artifacts. Next run must re-check: the relationship name is read or asked, not guessed; the lead-side test covers several related contacts; the other-relationship test asserts `HandlerInvoked == false` through `PluginPipeline`.
