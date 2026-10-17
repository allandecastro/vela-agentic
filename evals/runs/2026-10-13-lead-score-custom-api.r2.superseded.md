---
superseded_by: 2026-10-13-lead-score-custom-api.r2.md   # rubric corrected mid-campaign; kept for transparency
scenario: lead-score-custom-api
date: 2026-10-13
verdict: fail
run: 2/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed** (`pass: true`). No failed checks. Highlights: build succeeds, no VELA
diagnostics, tests re-run green (total=16 failed=0), exactly one Custom API `zava_ScoreLead`
function=False bound=False in=[String] out=[Int32], no dotted names, package holds the dll, read-only
`vela plan` runs and creates only the authored Custom API + package.

## Loop outcome
- INTAKE/CHALLENGE: vela-plan-review routed to vela-custom-api; grill asked for the solution (ZavaSales) and the no-'@' rule; Canvas committed first (`aaa7214`).
- `vela solution show ZavaSales --json` -> `{"solution":"ZavaSales","publisherPrefix":"zava"}` (exit 0).
- SCAFFOLD: `vela init ZavaSales --prefix Zava --publisher-prefix zava -o .` (0); `vela add customapi ScoreLead --global --action` (0, "Created global Custom API ScoreLead (zava_ScoreLead)"); `vela add test ScoreLead --kind customapi` (0).
- RED (`17c133d`): `Total: 16, Errors: 0, Failed: 15` (work/red-run.log). GREEN (`f8ab535`): `Total: 16, Failed: 0` (work/green-run.log).
- One mid-build spec correction (null email = platform FaultException), Canvas updated first and logged in the Sync log.
- REVIEW: isolated vela-reviewer subagent, PASS, 0 Critical / 0 Required / 4 Nits (docs/vela-builds/lead-score.review.md).
- PREVIEW: `dotnet build -c Release` -> `artifacts/Zava.Plugins.1.0.0.nupkg`; `vela plan ... --detailed-exitcode` exit 8 (create custom-api + package, 0 diagnostics). Stopped before apply.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | vela-plan-review routes to vela-custom-api | met | lead-score.md:52 (`skills: [vela-plan-review, vela-grill, vela-custom-api, ...]`), :67 "Custom API (an operation someone *calls*), not a plugin step" |
| 2 | Canvas: global, Action because flows call it, 1 required string in -> 1 int out, error cases | met | lead-score.md:19 (`binding: global, kind: action, callers: [flows], inputs: [email:string!], outputs: [leadScore:int]`), :49 and :67 (connector only calls Actions, even though pure computation), :33-38 error cases; checks "canvas mentions 'Action'/'flow'" |
| 3 | `vela add customapi <Name> --action` global, unique `<pfx>_<Name>`, no dot | met | lead-score.md:89/111 (`vela add customapi ScoreLead --global --action`); `--prefix` omitted but the CLI took `zava` from the project's VelaPublisherPrefix as the skill instructs (vela-custom-api SKILL.md:47-48 "pass `--prefix` only when the project has none"); ScoreLead.cs:22 `zava_ScoreLead`; check "no dotted Custom API names" |
| 4 | Test-first RED then green via `vela add test --kind customapi`: fortune500->55, other->10, empty->IPE | met | lead-score.md:112; ScoreLeadTests.cs:45-72; red-run.log `Failed: 15`, green-run.log `Failed: 0`; git `17c133d` (tests only) before `f8ab535` (impl) |
| 5 | Build clean of VELA00x; vela-code-review PASS | met | checks "build succeeds", "no VELA diagnostics"; lead-score.review.md "**PASS.** There are no Critical or Required findings" |
| P-a | Dotted parameter name -> **Critical** | **not met** | BLOCK, but highest severity **Required** (see below) |
| P-b | Empty email returns -1 -> **Required** | met | BLOCK at Critical |
| P-c | Function writing a record -> **Required** | met | BLOCK at Critical |

## Planted-violation results
Each copied to `planted-<x>/`, built (`dotnet build -c Release`: 0 warnings, 0 errors, no VELA for all three), and reviewed by a fresh read-only subagent acting as vela-reviewer with only the diff + Canvas.

| Plant | Diff | Verdict | Highest severity | Result |
|-------|------|---------|------------------|--------|
| a | `EmailParameter = "email"` -> `"lead.email"` | BLOCK | Required (3 Required: spec drift, dotted name per gotcha + checklist, stale evidence) | **fail** (expected Critical) |
| b | empty email -> `SetOutputParameter(leadScore, -1); return;` | BLOCK | Critical (out-of-contract output to flows) + Required (error code in output instead of IPE) | pass |
| c | `.AsAction()` -> `.AsFunction()` + `ctx.Service.Create(zava_leadscorelog)` | BLOCK | Critical (Function called by flows; unplanned org write; "a Function must have no side effects") | pass |

## Findings against the skills
1. **blocker** - `skills/vela-code-review/references/review-checklist.md:65-72` - "a unique name without the target solution's publisher prefix - **Required** ...; the rest below - **Required**. ... Parameter names are plain identifiers - a dotted name ... is rejected when the definition is built". The checklist explicitly grades a dotted parameter name **Required**, so the reviewer (correctly following the pack) rated plant (a) Required, while the scenario expects **Critical**. The checklist's own scale (line 12: Critical = "will fail or misbehave on a live org") would put a name Dataverse rejects at Critical. Either raise the dotted-name severity to Critical in the checklist (and its synced copies), or align the scenario with the "rejected at definition build, so a green suite proves it" rationale - the two currently contradict each other.
2. minor - `skills/vela-custom-api/references/harness-api.md:175-178` (same in vela-test-harness) - "A missing required input (`optional: false`) throws as on Dataverse ... FaultException ... 'Required field ... is missing'". It does not say that an explicit `null` value for a required input is treated as missing. The actor's RED suite declared `null -> InvalidPluginExecutionException`, had to correct the Canvas mid-IMPLEMENT, and the replacement test (`Null_Email_Is_Rejected_As_Missing_By_The_Platform`) was never seen RED (reviewer Nit 1). One line ("a null value counts as missing") would have kept the acceptance cases right from the CHALLENGE step.

## Fixes
- (none yet)

## Verdict
**fail** - checks 19/19 pass and all five success criteria are met by the artifacts; the actor's build is clean and correct. The grader fails on planted violation (a): the review blocked, but at Required, not Critical, because the pack's checklist grades dotted parameter names Required (finding 1). Next run must re-check plant (a)'s severity after the checklist/scenario are aligned.
