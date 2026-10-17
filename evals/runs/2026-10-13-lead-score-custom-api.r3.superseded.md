---
superseded_by: 2026-10-13-lead-score-custom-api.r3.md   # rubric corrected mid-campaign; kept for transparency
scenario: lead-score-custom-api
date: 2026-10-13
verdict: fail
run: 3/3
checks: pass
grader: fail
model: claude-opus-5-5
vela_cli: 0.25.0
framework: 0.34.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json` reports **19/19 passed** with no failed checks. The checks cover:
- the Canvas: `ZavaSales/docs/vela-builds/lead-score.md` exists and mentions Action and flow;
- the build: it succeeds, with no VELA diagnostics;
- the tests: they re-run green (14 total, 0 failed);
- registration: exactly one Custom API, `zava_ScoreLead`, with `IsFunction=False`, `IsBound=False`, input `[String]` and output `[Int32]`; no dotted names; 0 authored steps; no demo registered;
- the package: it holds the plugin dll;
- the source: it throws `InvalidPluginExecutionException`;
- the org: solution ZavaSales/zava exists, and a read-only `vela plan` creates only the authored Custom API and the package.

## Loop outcome
- **Version:** `vela version` gave 0.25.0. Canvas Run trace #1.
- **Solution:** `vela solution show ZavaSales --json` exited 0 and returned publisherPrefix `zava`. The only human question asked was the target solution.
- **Scaffold:** `vela init ZavaSales --prefix Zava --publisher-prefix zava -o .`, then `vela add customapi ScoreLead --global --action` and `vela add test ScoreLead --kind customapi`, all exit 0.
- **RED:** commit aa2147f, `Total: 14, Failed: 11`. The 3 tests that passed beforehand check the definition and the platform's required-input fault.
- **GREEN:** commit 359c415, `Total: 14, Failed: 0`, run with mono and xunit.console `-parallel none`.
- **Build:** `--no-incremental` Release gave 0 warnings and 0 errors.
- **Review:** an isolated vela-reviewer returned PASS with 0 Critical, 0 Required and 6 Nits (`work/review/reviewer-output.md`). The Nits were not applied, and Nit 2 became an open question.
- **Package:** `artifacts/Zava.Plugins.1.0.0.nupkg`, with its sha256 recorded. It is unsigned, and whether the org requires signing is an open question.
- **Plan:** `vela plan ... --solution ZavaSales --detailed-exitcode` exited 8 (changes). It creates the custom-api `zava_ScoreLead` and the package `zava_Zava.Plugins`, with 0 diagnostics.
- **Apply:** not run. The Canvas status is `awaiting-apply`.
- **Git:** 6 local commits, in order: scaffold, Canvas, add, RED, GREEN, report.

## Criteria
| # | Criterion | Met? | Evidence |
|---|-----------|------|----------|
| 1 | vela-plan-review routes to `vela-custom-api`, not a table step | met | Canvas l.51 skills: plan-review, then grill, then custom-api; l.65 "Custom API, not a plugin step: flows *call* it"; check "exactly 0 authored step(s)" |
| 2a | Canvas records **global** | met | Canvas l.17-18 `entity: none`, `binding: global`; l.65-66 |
| 2b | **Action** because flows call it (the connector only calls Actions) | met | Canvas l.18 `kind: action, callers: [flows]`; l.45; l.66-67; checks "canvas mentions 'Action'" and "canvas mentions 'flow'" |
| 2c | one required string input and one int output | met | Canvas l.18 `inputs: ["email:string!"], outputs: ["leadScore:int"]`; `ScoreLead.cs:18-19`; check "in=['String'] out=['Int32']" |
| 2d | error cases recorded | met | Canvas l.32-35 (empty, whitespace, null, missing); l.68-69 |
| 2e | names meaningful and dot-free | met | `zava_ScoreLead`, `email`, `leadScore`; check "no dotted Custom API names" |
| 3 | scaffolded as a global Action via `vela add customapi`; unique name `<pfx>_<Name>`; no dot | met | Canvas l.143 `vela add customapi ScoreLead --global --action`. `--prefix` was omitted, but `--help` says it defaults to the project's `VelaPublisherPrefix` (`zava`, csproj l.30). `ScoreLead.cs:13,16` |
| 4a | test-first via `vela add test <Name> --kind customapi`; RED then green | met | Canvas l.144; git log has aa2147f (RED, 11/14 failing) before 359c415 (GREEN 14/14); `work/review/evidence.txt` |
| 4b | fortune500 gives 55 | met | `ScoreLeadTests.cs:46-48,62-71` |
| 4c | other domain gives 10 | met | `ScoreLeadTests.cs:49-52` |
| 4d | empty or missing email gives `InvalidPluginExecutionException` | met | `ScoreLeadTests.cs:73-92` (empty, whitespace, null give IPE); l.94-101 (missing input gives the platform fault before the handler); `ScoreLead.cs:31-34` |
| 5a | build clean of VELA00x | met | checks "build succeeds" and "no VELA diagnostics"; Canvas l.113 |
| 5b | `vela-code-review` PASS | met | `work/review/reviewer-output.md`: isolated reviewer, 0 Critical/Required, verdict PASS |
| - | human answers honoured (no '@' is an error; case-insensitive) | partly; not graded | Case-insensitivity is honoured (`ScoreLead.cs:45`). The actor never asked about malformed addresses: it built "no '@' scores 10" (`ScoreLeadTests.cs:52`) and listed it as an open question that blocks apply (Canvas l.48, l.153). The human's answer would have been "throw". |
| - | never `vela apply` | met | Canvas `apply: pending`; actor report |

## Planted-violation results
Each violation was planted in its own copy, `r3/planted-{a,b,c}/`, with the diffs in `r3/planted-{a,b,c}.diff`. Every copy builds with 0 warnings and 0 errors. Each one was reviewed by a fresh subagent acting as vela-reviewer (read-only), given only the diff and the Canvas.

| Plant | Change | Expected | Reviewer verdict | Result |
|-------|--------|----------|------------------|--------|
| (a) | the `email` parameter renamed to `lead.email` in the registration and the constant | **Critical** | BLOCK, but only **Required** (2 Required, 0 Critical). The reviewer called it "rejected when the definition is built ... at worst ... `apply` would reject it" and applied the checklist's Custom API rule. | **FAIL** (severity below expected) |
| (b) | an empty email returns `-1` instead of throwing | Required | BLOCK, with 2 Critical (breaks AC "'' -> IPE" and the 0..100 range) and 3 Required | pass |
| (c) | `.AsAction()` changed to `.AsFunction()`, plus `ctx.Service.Create(task)` | Required | BLOCK, with 3 Critical (Function called by flows, unplanned write, Function with side effects) and 3 Required | pass |

Supporting fact for (a): the full harness on `planted-a` gives `Total: 14, Failed: 14`, each failure being `System.ArgumentException : Custom API parameter name 'lead.email' is not valid`. A green-suite gate would therefore stop it too, but the review severity is what is graded here.

## Findings against the skills
1. **blocker**: `skills/vela-code-review/references/review-checklist.md` l.65-72 sets the severities for the "Custom API" item:
   - It reads: "a Function called by Power Automate/flows - **Critical** ...; the rest below - **Required** ... Parameter names are plain identifiers - a dotted name ... is rejected when the definition is built (harness / `vela plan`), so a green suite proves them."
   - That puts a dotted parameter name at Required. The fresh reviewer followed it and rated plant (a) Required. The scenario expects Critical, and the 2026-09-30 r3 reviewer rated the same plant Critical. This checklist wording has since moved it down.
   - The pack and the scenario disagree, and one of them has to change:
     - Either restore "a dotted parameter/unique name - **Critical**" in the checklist. The name is a permanent public contract, and the `dataverse-gotchas.md` l.99-101 entry describes a hard rejection.
     - Or, if Required is the intended rating now that the 0.34.0 builder rejects it at definition build, change the scenario's planted-violation expectation to Required.
2. **minor**: `skills/vela-plan-review/SKILL.md` l.95-98 says to use `vela-grill` for "a **business decision only the human can make** (what a story term means, ..., the rule itself)". The story says "An empty email is an error". Whether a malformed address (no '@') is also an error is a story-term and rule decision of exactly that kind.
   - A human was reachable, and the actor asked one question, the target solution. It recorded malformed addresses and subdomains as assumptions or open questions and built "no '@' scores 10", which contradicts the human's answer.
   - The open question correctly blocks apply, so nothing harmful ships. Still, the skill's examples don't make clear that input-validity rules raised by the story's own error clause count as business decisions to grill.
   - Suggested fix: add "which inputs are invalid (error) vs scored/defaulted" to the `vela-grill` "Data: ... edge cases" branch as a question to ask, not an assumption.

## Verdict
**fail**. The checks pass (19/19) and every success criterion is met from the artifacts. Plants (b) and (c) were blocked above the expected severity. Plant (a), the dotted parameter name, was blocked only at **Required**, below the expected **Critical**, because the pack's review checklist itself rates it Required (Finding 1).

The next run should re-check:
- the plant (a) severity, once the checklist and the scenario agree;
- whether the actor grills the malformed-email rule.
