---
scenario: lead-score-custom-api
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
`checks.json`: **19/19 passed**, 0 failed (`pass: true`). Notable: "exactly one custom API: function=False
bound=False in=['String'] out=['Int32']" -> `zava_ScoreLead`; "no dotted Custom API names"; "exactly 0 authored
step(s)"; "tests re-run green (>= 3)" -> total=16 failed=0; "no VELA diagnostics"; "read-only vela plan runs".

## Loop outcome
- INTAKE/CHALLENGE: routed to a Custom API (Canvas `## A - Approach`, lead-score.md:67); grill asked the solution (ZavaSales) and got the no-'@' rule changed to "error"; Canvas updated before code (Sync log, :84; Canvas commit aaa7214 precedes scaffold).
- `vela solution show ZavaSales --json` exit 0 -> prefix `zava`.
- SCAFFOLD: `vela init ZavaSales --prefix Zava --publisher-prefix zava` (exit 0); `vela add customapi ScoreLead --global --action` -> "Created global Custom API ScoreLead (zava_ScoreLead)"; `vela add test ScoreLead --kind customapi`.
- RED (commit 17c133d): `Total: 16, Errors: 0, Failed: 15` (red-run.log). GREEN (f8ab535): `Total: 16, Failed: 0` (green-run.log).
- VERIFY: `dotnet build -c Release --no-incremental` 0 warnings / 0 errors / 0 VELA.
- REVIEW: isolated vela-reviewer subagent, PASS, 0 Critical / 0 Required / 4 Nits (lead-score.review.md).
- PREVIEW: `vela plan ... --detailed-exitcode` exit 8 (changes): create custom-api + create package, diagnostics [].
- Stopped at the apply gate; no `vela apply`.

## Criteria
| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `vela-plan-review` routes to `vela-custom-api` (called operation, not a step) | met | lead-score.md:52 skills list; :67 "Custom API (an operation someone *calls*), not a plugin step"; checks "exactly 0 authored step(s)" |
| 2a | Canvas: global | met | lead-score.md:19 `binding: global`; :67 "**Global** - it takes an email, not a lead record" |
| 2b | Canvas: Action because flows call it (connector calls only Actions) | met | :19 `kind: action, callers: [flows]`; :49 assumption "Power Automate can only call Actions ... even though it is a pure computation"; :67 |
| 2c | Canvas: one required string in -> one int out | met | :19 `inputs: [email:string!], outputs: [leadScore:int]`; :39 |
| 2d | Canvas: error cases | met | :33-38 (no '@', '', whitespace -> InvalidPluginExecutionException; null/missing -> platform FaultException); :67 |
| 2e | Names meaningful and dot-free | met | `zava_ScoreLead`, `email`, `leadScore`; check "no dotted Custom API names" |
| 3 | `vela add customapi <Name> --action [--prefix]` global Action; unique name `<pfx>_<Name>`; no dots | met | Run trace :111 `vela add customapi ScoreLead --global --action` -> "zava_ScoreLead" (prefix taken from `VelaPublisherPrefix`=zava set by `vela init --publisher-prefix zava`, Zava.Plugins.csproj:30 - the documented fallback for an omitted `--prefix`); check "exactly one custom API ... function=False bound=False" |
| 4 | Test-first RED then green via `vela add test --kind customapi`; fortune500 -> 55, other -> 10, empty -> InvalidPluginExecutionException | met | :112 `vela add test ScoreLead --kind customapi`; ScoreLeadTests.cs:45-72; red-run.log `Failed: 15`, green-run.log `Failed: 0`; git order 17c133d (tests) before f8ab535 (impl) |
| 5 | Build clean of VELA00x; `vela-code-review` PASS | met | checks "no VELA diagnostics", "build succeeds"; lead-score.review.md "Verdict ... PASS", 0 Critical/Required |
| - | Human answers honoured (no '@' throws; case-insensitive; ZavaSales/zava) | met | ScoreLead.cs:37-42; tests :47, :75-79; check "target solution ZavaSales exists" |
| - | Stopped before apply | met | lead-score.md:17 `apply: pending`; no apply in Run trace |

## Planted-violation results
Each planted copy under `r2/planted-<x>/ZavaSales` (copied from `work/`, never modified), built with
`dotnet build ZavaSales.sln -c Release --no-incremental` (all: 0 errors, 0 warnings, 0 VELA) and tested with mono
xunit.console 2.9.2 `-parallel none`. A fresh general-purpose subagent acting as `vela-reviewer` (read-only, given only
`diff.txt`, the Canvas and `evidence.txt`) reviewed each.

| # | Violation (diff) | Suite at head | Reviewer verdict | Top severity | Expected | Result |
|---|---|---|---|---|---|---|
| a | `EmailParameter = "email"` -> `"lead.email"` | 16/16 red: `ArgumentException: Custom API parameter name 'lead.email' is not valid` | BLOCK | **Critical** (dotted parameter name, suite red, contract with flows broken) + Required (Canvas drift, stale gate evidence) | Required or Critical | blocked |
| b | empty/whitespace email -> `SetOutputParameter(leadScore, -1); return;` + test changed to `Assert.Equal(-1, ...)` (suite kept green) | 16/16 green | BLOCK | **Required** (spec says empty is an error; -1 outside 0-100) + Required (test weakened to fit the bug) | Required | blocked |
| c | `.AsAction()` -> `.AsFunction()` + `ctx.Service.Create(new Entity("task"))` in the handler; definition test flipped and an `InMemoryOrganizationService` injected (suite kept green) | 16/16 green | BLOCK | **Critical** (Function for flow callers; unplanned write / Function with side effect) + Required x4 | Required | blocked |

## Findings against the skills
No blocker and no minor defect of the skill pack was observed in this run. Observations (not pack defects):
1. note - the actor scaffolded with `vela add customapi ScoreLead --global --action` without `--prefix`; the unique
   name `zava_ScoreLead` came from `VelaPublisherPrefix` written by `vela init --publisher-prefix zava`, which is the
   documented fallback (`references/cli-surface.md`:56-57 "`--prefix`, else the project's `VelaPublisherPrefix`").
   The scenario's criterion 3 names `--prefix <pfx>`; the outcome is identical, so it is graded met. The scenario
   wording could say "`--prefix <pfx>` or a project `VelaPublisherPrefix`".
2. note - the null-email case moved from InvalidPluginExecutionException to the platform FaultException mid-build
   (Sync log lead-score.md:85) and its test was added after the RED run (review Nit 1). Handled spec-first and
   flagged by the reviewer; `references/harness-api.md` already documents the missing-required-input FaultException,
   so the Canvas could have declared it up front - actor variance, not a pack gap.

## Verdict
**pass.** checks 19/19 and every success criterion met from the artifacts; all three planted violations blocked at
or above the expected severity (a: Critical, b: Required, c: Critical). The next run must re-check that the Canvas
declares the platform's null/missing-required-input behaviour up front rather than correcting it mid-build.
