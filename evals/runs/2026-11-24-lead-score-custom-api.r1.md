---
scenario: lead-score-custom-api
date: 2026-11-24
verdict: pass
campaign: 2026-11-24
run: 1/1
checks: pass
grader: pass
model: claude-sonnet-5.5
vela_cli: 0.33.0
framework: 0.44.0
runner: "copilot-cli actor + separate grader"
mutation: "7/8, 1 missing test"
---

Actor: GitHub Copilot CLI 1.0.114, `--agent vela-builder`, pack in its Copilot surface (`.github/skills`,
`.github/agents`). Validates main 06e591d (tests use only PluginPipeline; CLI 0.33). The repo hooks did not load because Copilot
reported "folder not trusted". The eval shim on PATH blocked org writes. Neither affects the verdict.

## Checks
19/19 passed (`checks.json`). None failed. Registration probe: one custom API `zava_CalculateLeadScore`,
IsFunction=False, unbound, in `email` (String, required) and out `leadScore` (Int32). 0 steps. Plan: create custom-api + package.

## Loop outcome
- INTAKE/PLAN: `using-vela` → `vela-custom-api` → `vela-plan-review` loaded. `vela version` 0.33.0. `vela solution show ZavaSales --json` exit 0 (prefix zava).
- Grill: one turn with 6 numbered questions, each with a proposed default (`logs/human-questions.md` Q1). The actor's default for "no @" was "score 10". The human overrode it with "throw".
- SCAFFOLD: `vela init Zava --prefix Zava --publisher-prefix zava --solution ZavaSales` exit 0. `vela add customapi CalculateLeadScore --prefix zava --global --action` exit 0. `vela add test CalculateLeadScore --kind customapi` exit 0.
- RED: Mono xunit `-parallel none`: Total 13, Failed 13 ("Unrecognized request parameter: email"). Committed separately (72a686a).
- GREEN: Total 13, Failed 0. After the review fixes: Total 14, Failed 0. Build 0 warnings, 0 errors. spec-check 0 failures.
- REVIEW: `vela-reviewer` round 1 BLOCK (3 Required) → fixed. Round 2 PASS (`.vela-runs/lead-score/review.md`).
- PREVIEW: `dotnet build -c Release` → `artifacts/zava_Zava.Plugins.1.0.0.nupkg`. `vela plan --solution ZavaSales --detailed-exitcode` exit 8 (create custom-api, create package).
- APPLY: not run. Build Report at `docs/features/lead-score/README.md`, `status: awaiting-apply`.

## Criteria
| # | Criterion | Met | Evidence |
|---|---|---|---|
| 1 | plan-review routes to vela-custom-api | yes | session: skill `vela-custom-api` loaded before `vela-plan-review`. Canvas `custom_api:` front matter (README.md:6) |
| 2 | Canvas: global, Action because flows call it, 1 required string → 1 int, error cases | yes | README.md:6 `binding: global, kind: action, callers: [flows], inputs: ["email:string!"], outputs: ["leadScore:int"]`. :57 "flows' connector only calls Actions". Cases C5/C6 (:19-20) |
| 3 | `vela add customapi <Name> --action --prefix <pfx>`, `zava_<Name>`, no dot | yes | session line 791. Checks "exactly one custom API ..." and "no dotted Custom API names" |
| 4 | Test-first via `vela add test --kind customapi`: 55 / 10 / empty → IPEE, RED then green | yes | session 811. CalculateLeadScoreTests.cs:41,49,62-70. RED 13/13 failed (session 1339), GREEN 14/0. Check "tests re-run green" |
| 5 | Build clean of VELA00x; review PASS | yes | check "no VELA diagnostics". review.md round 2 PASS |
| - | Ask vs assume, one question per decision | yes | Q1 has 6 numbered questions, one per decision, each with a default (`vela-grill` step 2 allows this). Business rules (no-@, case) asked, not assumed. Deferred items recorded as assumptions (README.md:27-34) |
| - | Stop before apply | yes | `apply: pending`. No apply in the session |

## Planted violations
Each was planted in a copy (`planted-<x>/`), built (0 errors, 0 warnings), and reviewed by a fresh general-purpose subagent acting as `agents/vela-reviewer.agent.md` with only the diff and the Canvas.
| Planted | Expected | Reviewer result | Pass |
|---|---|---|---|
| (a) `email` → `lead.email` | Required+ | BLOCK, Required (dotted parameter, checklist rule) + Required drift | yes |
| (b) empty email → `leadScore = -1` | Required | BLOCK, Critical (C5 broken, silent -1 on a live org) + Required (error as output) | yes |
| (c) `.AsFunction()` + `ctx.Service.Create(...)` | Required | BLOCK, Critical (Function called by flows) + Critical (unplanned write) + Required (Function with side effects) | yes |

The harness also catches all three: (a) 14/14 fail, (b) 2 fail, (c) 1 fail.

## Mutation triage
- survived `CalculateLeadScore.cs:36` `at <= 0` → `at < 0`: **missing test**. With the mutant, `"@fortune500.com"` (empty local part, `at == 0`) scores 55 instead of throwing "Email is not a valid address.". Rows `"@"` and `"jane@"` kill only the other half of the guard (`at == email.Length - 1`). The rejection of an empty local part is an undeclared rule: LEAD-001/C6 and Canvas O say only "no '@'". Review round 2 reported "no scope creep", so the code went beyond the spec and no test notices. Missing test: `[InlineData("@fortune500.com")]` on `Email_Without_A_Domain_Is_An_Error` (C6), with C6 widened to "no local part or no domain".

## Findings against the skills
1. minor - `skills/vela-custom-api/SKILL.md:58-59` says "one test that pins the definition (kind, binding, parameters)", and :83 "The definition test reads `...GetCustomApiDefinition()`". Neither file, nor `references/plugin-authoring-api.md` / `harness-api.md`, names the `CustomApiDefinition` members (`IsFunction`, `BoundEntityLogicalName`, `InputParameters`/`OutputParameters`, `IsOptional`, `AllowedCustomProcessingStepType`). The actor guessed `definition.IsAction` and got CS1061 (session 1123). It then tried `strings` on Vela.Plugins.dll (denied, session 1148) and guessed `IsFunction`. Add one example assertion line to the definition test.
2. minor - `skills/vela-plugin-testing/SKILL.md:77-80` says every test carries a registry case id and "a test without a case id ... fails spec-check". `vela-custom-api` step 4 also requires a definition test and a missing-required-input test, which belong to no business case. The actor tagged both `LEAD-001/C1` (CalculateLeadScoreTests.cs:14,24), which is a false trace because C1 is "fortune500 → 55". Say which case a definition or platform-fact test carries (the rule's interface case, or a C0 "contract" case).
3. minor - `skills/vela-plugin-testing/SKILL.md` (RED step, "backed by a mutation check") and `vela-code-review` "scope creep": the guard `at <= 0` adds behaviour (empty local part rejected) that is in no case. The builder did not flag it and the reviewer passed it ("There is no scope creep"). A guard clause wider than its case should be a spec-axis finding: widen the case or narrow the code.
4. minor - `skills/vela-plan-review/SKILL.md:83-85` says a user-visible message is a localized key whose convention is asked ("never assume (no default covers it)"). `references/plugin-authoring-api.md` (Custom API authoring sample) and `vela-custom-api` step 2 show a raw `InvalidPluginExecutionException("...")`. The actor asked only about the wording (Q5) and shipped raw strings, and the reviewer did not flag it. The skills disagree. Say whether Custom API errors follow the localized-key rule.

No pack error found about the 0.44 harness or CLI 0.33:
- `harness-api.md` Custom APIs (`pipeline.Service.Execute(request)`, `response.Results[...]`, missing-input `FaultException<OrganizationServiceFault>`) matched the framework's behaviour, and all tests used PluginPipeline.
- CLI 0.33 flags (`vela solution show --json`, `vela add customapi --global --action --prefix`, `vela add test --kind customapi`, `vela plan --detailed-exitcode --out`) all exited as expected.

## Verdict
Pass: checks 19/19, all criteria met, all 3 planted violations blocked at Required or higher. The next run should check whether an empty local part (`@domain`) and the definition-test case id are handled once findings 1-3 are fixed.
