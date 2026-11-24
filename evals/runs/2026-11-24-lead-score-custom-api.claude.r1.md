---
scenario: lead-score-custom-api
date: 2026-11-24
verdict: pass
campaign: 2026-11-24
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.33.0
framework: 0.44.0
runner: "campaign actor + separate grader"
mutation: "5/6, 1 missing test(s)"
---

Actor: fresh Claude Code general-purpose subagent (`claude-opus-5-5`) given `r1/actor-prompt.md`, resumed once with
the answers. Validates main (PluginPipeline only, Vela.Plugins 0.44.0 / CLI 0.33.0). Eval shim blocks org writes (noted, not a fail).

## Checks
19/19 passed (`checks.json`). No failed check.

## Loop outcome
- `vela version` 0.33.0. Routed to a Custom API; Q1-Q5 asked as one numbered turn, each with a proposed default (`work/logs/human-questions.md`).
  Q4 (message language) deferred by the human → kept as an open question at the gate (`vela-grill`: "never assumed; no default covers it").
- `vela solution show ZavaSales --json` exit 0; `vela init ZavaSales --prefix Zava --publisher-prefix zava --solution ZavaSales` exit 0;
  models skipped (no table, reason in trace row 6); `vela add customapi LeadScore --prefix zava --global --action` exit 0;
  `vela add test LeadScore --kind customapi --prefix zava` exit 0.
- Commits: Canvas + LEAD-001 C0-C10 (6e55fb4) → scaffold (a133e07) → RED (44a1446, `Total: 17, Failed: 17`) → implement (6bf4ded,
  GREEN 17/17) → Build Report (0198bcd).
- spec-check 0 failures. Review: fresh **general-purpose** subagent acting as the worktree `agents/vela-reviewer.agent.md` → PASS, 3 Nits.
- Release build → `zava_Zava.Plugins.1.0.0.nupkg`; `vela plan --detailed-exitcode` exit 8 (create custom-api + package; isFunction false).
  Stopped before apply.

## Criteria
| Criterion | Met? | Evidence |
| --- | --- | --- |
| SC1 routed to `vela-custom-api` | met | Canvas `skills:` + trace row 7; no step registered (check "exactly 0 authored step(s)") |
| SC2 Canvas: global, Action because flows, string in → int out, error cases | met | `docs/features/lead-score/README.md:6-7` (`binding: global, kind: action, callers: [flows]`), C6-C8, C10 |
| SC3 `vela add customapi <Name> --action --prefix zava`, `zava_LeadScore`, no dots | met | trace row 7; check "exactly one custom API: function=False ..."; "no dotted Custom API names" |
| SC4 test-first via `vela add test --kind customapi`: 55 / 10 / empty → IPEE | met | RED 17/17 failed before 6bf4ded; `LeadScoreTests.cs:44-91` (`ThrowsAny<InvalidPluginExecutionException>`) |
| SC5 build clean of VELA00x; review PASS | met | check "no VELA diagnostics"; `.vela-runs/lead-score/review.md` PASS |
| Ask vs assume | met | no-@ / case-insensitivity asked; deferrals recorded as assumptions; Q4 left open, not invented |
| Stop before apply | met | `apply: pending` |

## Planted violations
Copies in `r1/planted-a|b|c/` (committed, built 0 warn / 0 err). Fresh general-purpose subagents acting as the worktree reviewer, diff + Canvas only.
| Planted | Expected | Reviewer | Pass |
| --- | --- | --- | --- |
| (a) `email` → `lead.email` (definition + read) | Required+ | **BLOCK, Required** (dotted parameter; drift from Canvas `inputs`) | yes |
| (b) empty email → `leadScore = -1; return` | Required | **BLOCK, Critical** (C6/C7 broken, silent success to flows) + Required | yes |
| (c) `.AsFunction()` + `ctx.Service.Create(new Entity("note"))` | Required | **BLOCK, Critical** (Function called by flows) + Critical (unplanned write) + Required (Function with side effects, magic strings) | yes |

## Mutation
5/6 killed. Survivor:
- `LeadScore.cs:39` `at < 0` → `at <= 0`: **missing test**. With the mutant, `"@fortune500.com"` (`@` at index 0, empty local part) throws
  "The email must contain '@'..." instead of scoring 55. LEAD-001 says only "no '@'" fails, and the Canvas assumption (Q3 default) says an
  address with '@' that is otherwise malformed is not an error (`README.md` assumptions, C9 `bob@` → 10). The empty-domain side has a test
  (C9); the empty-local-part side does not. Missing test: `[InlineData("@fortune500.com")]` → 55 (under C1 or a new case at design time).

## Findings against the skills
No pack error about the 0.44 harness or CLI 0.33: `GetCustomApiDefinition()` members (`IsFunction`, `IsBound`, `InputParameters`,
`IsOptional`, `AllowedCustomProcessingStepType`), `pipeline.Service.Execute(OrganizationRequest)`, missing-input
`FaultException<OrganizationServiceFault>`, `ctx.BusinessError(ProjectMessages...)` all compiled and behaved first time (no CS errors in the
transcript). Previous-record findings held: definition test tagged `LEAD-001/C0`; errors are localized keys.

1. minor - `skills/vela-plugin-testing/SKILL.md:29` "each **edge** (empty / null / invalid / boundary)" does not name the two sides of a
   position guard. The actor tested the empty-domain side (`bob@`, C9) but not the `@`-at-index-0 side, so `at <= 0` survives. Same
   survivor site as the 2026-11-24 Copilot run (there `at <= 0` → `at < 0`), in the other direction - the gap recurs. Suggest: "for an index
   / length guard, a case at each end (first and last position)".
2. minor - `vela-grill` did not surface the empty-local-part value as an edge question ("Ask every edge value that changes an acceptance case"),
   so the behaviour rests on a generic Q3 default rather than a named case.

## Verdict
pass - 19/19 checks, every criterion met, all 3 planted violations BLOCKed at Required or higher. Mutation 5/6 with one missing test
(`@fortune500.com`), not failing while the score is calibrated.
