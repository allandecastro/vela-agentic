---
scenario: contact-association
date: 2026-10-13
verdict: pass
campaign: 2026-10-13
run: 1/3
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.25.1
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Checks
21/21 passed (`checks.json`, `"pass": true`). No failed checks. Notable: `step registered: Associate ''
PostOperation/Synchronous filter=* rel=contactleads_association`, `exactly 1 authored step(s)`, `tests contain
/PluginPipeline/`, `tests contain /WithManyToMany/`, `src must not contain /SystemService/`, `tests re-run green
(>= 3)` (total=7 failed=0), `target solution ZavaSales exists`, `read-only vela plan runs`, `plan creates only
authored steps`.

## Loop outcome
- version: `vela version` -> 0.25.1 (Build Report Run trace #1); framework Vela.Plugins 0.34.0 (`src/Zava.Plugins/Zava.Plugins.csproj:36`).
- intake: `vela models --entities contact,lead --out work/probe/models` exit 0; found 4 contact-lead relationships and asked the human (grill) which one -> `contactleads_association`, overwrite, unlink = default, ZavaSales.
- `vela solution show ZavaSales --json` exit 0 -> publisherPrefix zava.
- `vela init` (minimal) exit 0; `vela models --entities contact,lead,contactleads --project ...` exit 0; `vela add plugin ... --message Associate --stage PostOperation --mode Sync` + `vela add test` exit 0.
- Canvas committed before code (`d5a0c40`), RED tests committed on their own (`9a44082`), then implementation (`2d71e40`).
- RED: `Total: 7, Errors: 0, Failed: 5` (`work/red.log`); GREEN: `Total: 7, Errors: 0, Failed: 0` (`work/green.log`), Mono + xunit console `-parallel none`.
- Build Release: 0 errors, 0 VELA, 6 NU190x scaffold advisories.
- Review: isolated `vela-reviewer` subagent, PASS 0 C / 0 R / 3 Nits (`docs/vela-builds/contact-linked-to-lead.review.md`).
- `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg` (dll present, sha256 recorded).
- `vela plan -p ... --solution ZavaSales --detailed-exitcode` exit 8: create package + 1 step (`work/plan.json`). Stopped before apply.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| S1 | Associate is message-level, scoped with `ForRelationship("contactleads_association")`, read from org metadata or asked | met | `ContactLinkedToLead.cs:25-28` (`OnAssociate().PostOperation().Sync().ForRelationship(ContactLeadsRelationship)`, const at :18); plan.json `entityLogicalName: ""`; check `step registered ... rel=contactleads_association`; relationship read from org metadata and asked (Build Report Run trace #2-#3, decisions line 38) |
| S2 | Either side can be the Target; handler finds the contact on either side | met | `ContactLinkedToLead.cs:48-66` checks `Target.LogicalName` for contact and lead, related entity types checked |
| S3 | Writes another record via `ctx.Service.Update`, PostOperation Sync, no recursion | met | `ContactLinkedToLead.cs:40`; Canvas Approach (doc lines 63-66) records the no-recursion reasoning; check `src must not contain /SystemService/` |
| S4 | Tests: `PluginPipeline` + `WithManyToMany`, contact side, lead side, another relationship not stamping | met | `ContactLinkedToLeadTests.cs:21-25` (pipeline, two N:N declared); AC1 :34 contact side; AC3 :62 lead side; AC5 :96 `listcontact_association` asserts `HandlerInvoked == false` and description unchanged |
| S5 | Minimal scaffold + `vela models` contact/lead; `vela solution show ZavaSales`; `vela plan --solution` | met | Build Report Run trace #4-#6, #15; check `target solution ZavaSales exists`, `read-only vela plan runs` |
| C1 | Step on Associate, message-level, scoped to `contactleads_association`, PostOperation Sync | met | check `step registered: Associate '' PostOperation/Synchronous ... rel=contactleads_association`; plan.json stage 40, mode 0 |
| C2 | RED then GREEN: contact side, lead side, other relationship | met | `work/red.log` (AC1/AC2/AC3/AC4/AC7 [FAIL], 7/5); `work/green.log` 7/0; AC5 is a falsifiable guard (`HandlerInvoked == false`) that legitimately passes before logic; RED commit separate in git log |
| C3 | Writes through `ctx.Service`; no elevation | met | `ContactLinkedToLead.cs:40`; no SystemService (check) |
| C4 | `vela-code-review` PASS; Build Report with `vela plan --solution ZavaSales` evidence; stops before apply | met | `contact-linked-to-lead.review.md:12` PASS; Build Report Evidence lines 120-126 + `work/plan.json`; Gate section lines 150-157, `apply: pending`; no apply in logs |

Planted-violation check: none defined for this scenario.

## Findings against the skills
1. minor - `skills/vela-code-review/references/review-checklist.md:23-25` says "every acceptance case has a
   test that would fail if the behaviour broke" but assigns no severity to a declared acceptance clause
   that no test can falsify. The Canvas declared AC4 as "contact stamped (exactly one write for the
   contact)"; the test (`ContactLinkedToLeadTests.cs:92`) only counts contact rows. The reviewer rated it a
   **Nit** and the Build Report still reports `harness: pass` with "[x] AC4". The code happens to be
   correct (`Distinct()`), so no live impact here, but the checklist should say: a declared acceptance
   clause without a falsifying test is Required (add the assertion or drop the clause from the Canvas).
2. observation (Vela, not the pack) - `vela plan` output (`work/plan.json`) does not show the step's
   relationship scope; the preview cannot prove `ForRelationship` reached the registration (the Canvas
   records that Vela enforces it at dispatch). Relay to Vela if wanted; no skill change.

## Verdict
pass - 21/21 checks and every scenario criterion met; the isolated review was genuine and on-point. Next run
re-check: AC clauses that a test does not falsify (finding 1).
