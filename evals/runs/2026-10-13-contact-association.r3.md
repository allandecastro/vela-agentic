---
scenario: contact-association
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 3/3
checks: pass
grader: pass
vela_cli: 0.25.0
framework: 0.34.0
model: claude-opus-5-5
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **21/21 passed**, 0 failed. These include: the step is registered on Associate (entity `''`) PostOperation/Synchronous with rel=contactleads_association; exactly 1 authored step; no SystemService; the tests contain PluginPipeline and WithManyToMany; `vela solution show` returns ZavaSales/zava; the read-only `vela plan` runs; and the plan creates only authored steps.

## Loop outcome
- `vela version` returned `vela 0.25.0` (Canvas run trace #1). A read-only intake probe `vela models --entities contact,lead --intersect` found 4 contact<->lead relationships, and the actor grilled the human instead of guessing (trace #2-3).
- `vela solution show ZavaSales --json` returned prefix zava. Then `vela init`, `vela models --entities contact,lead`, `vela add plugin ... --message Associate` and `vela add test` all ran with exit 0.
- RED at commit 4d2af27: `Total: 12, Errors: 0, Failed: 9` (work/test-red.log). All 9 failures are on the stamp assertion. The 3 that passed were Fires_On_Associate, AC5 and AC7, which are guard cases.
- GREEN at commit 444cabf: `Total: 12, Errors: 0, Failed: 0` (work/test-green.log). The Release build had 0 warnings, 0 errors and 0 VELA diagnostics.
- An isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 3 Nits (docs/vela-builds/reviews/contact-lead-link-description-review-1.md). The Canvas was synced afterwards.
- Package build: `dotnet build -c Release` produced `artifacts/Zava.Plugins.1.0.0.nupkg`, which contains the dll.
- `vela plan --solution ZavaSales --detailed-exitcode` exited 8 (changes): create package plus 1 step. The rank-collision diagnostic is with Microsoft managed steps, which is harmless.
- The actor stopped before apply. The Build Report gate gives the exact `vela apply` command for a human to run.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| R1 | Associate is message-level, scoped with `ForRelationship("contactleads_association")`, and the name was read from org metadata or asked | met | ContactLeadLinkStamp.cs:24-27. checks: "step registered: Associate '' ... rel=contactleads_association". Canvas trace #2-3: an intersect probe found 4 relationships, then the human was asked. |
| R2 | Either side can be Target, and the handler finds the contact on both sides | met | ContactLeadLinkStamp.cs:61-69 (Target plus RelatedEntities, filtered on `contact`). Tests AC1 (:58) and AC2 (:70). |
| R3 | Writes the other record through `ctx.Service.Update`, PostOperation Sync, with no recursion | met | ContactLeadLinkStamp.cs:54. Canvas Safeguards :99. check "src must not contain SystemService". |
| R4 | Tests use PluginPipeline with `WithManyToMany`, one test per direction, and another relationship does not stamp | met | Tests :25-30, AC1 :58, AC2 :70, AC7 :148 (`HandlerInvoked == false`, SkipReason ForRelationship, 0 writes). |
| R5 | Minimal scaffold, `vela models` for contact and lead, `vela solution show ZavaSales`, `vela plan --solution` | met | Canvas trace #4-6 and #15. checks: "no scaffold demo registered", "plan creates only authored steps". |
| SC1 | Step on Associate, message-level, scoped, PostOperation Sync | met | checks.json step-registration check. Plan JSON. |
| SC2 | RED then GREEN: contact side, lead side, and other relationship | met | test-red.log (9 failed, each on the stamp assertion) and test-green.log (12/12). The grader's check re-run gave total=12 failed=0. |
| SC3 | Writes go through `ctx.Service`, with no elevation | met | ContactLeadLinkStamp.cs:44,54. Canvas assumption :38. |
| SC4 | Review PASS, Build Report has `vela plan --solution ZavaSales` evidence, and the run stops before apply | met | review-1.md (PASS). Canvas :131-137 (exit 8, operations listed). Gate section :161-170. `apply: pending`. |
| HA | Human answers honoured: overwrite existing text, solution ZavaSales | met | AC3 (:92) overwrites "VIP customer". Skipping a write when the value is already exactly the stamp is a no-op refinement and does not contradict "overwrite". |

## Planted-violation results
The scenario has no "Planted-violation check" section, so none applied.

## Findings against the skills
None blocking. Observations (minor; not defects of the pack's rules):
1. minor - The Canvas says, under O - Operations (contact-lead-link-description.md:91), "a counting service for AC5". The tests actually count writes with a test-only Update probe plugin (ContactLeadLinkStampTests.cs:196-211). The isolated reviewer flagged a different Canvas/code drift but missed this one. This is a small spec-sync miss by vela-code-review's spec axis, and it has no behavioural impact.
2. minor - Version skew: the Canvas records `vela_cli: 0.25.0`, but the installed CLI at grading time is 0.25.1. Golden rule 2 allows this. No action needed.

The evaluator note on Create filters does not apply: the actor raised no "Create filter" gap.

## Verdict
**pass**. The checks passed 21/21 and every criterion is met. No planted violations were defined. The next run should re-check that the Canvas Operations text stays in sync with the test mechanism actually used.
