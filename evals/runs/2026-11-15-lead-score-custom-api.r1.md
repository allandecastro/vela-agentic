---
scenario: lead-score-custom-api
date: 2026-11-15
verdict: pass
campaign: 2026-11-15
run: 1/1
checks: pass
grader: pass
model: claude-opus-5-5
vela_cli: 0.29.0
framework: 0.42.0
runner: "campaign actor + separate grader"
---

## Check summary
`checks.json`: **19/19 passed**, no failed check (the "invalid input throws" pattern accepts `ctx.BusinessError(...)`;
`ScoreLead.cs:35,41` throw `ctx.BusinessError`, which the harness surfaces as `InvalidPluginExecutionException` -
`ScoreLeadTests.cs:155`, green).

## Loop outcome
- version: `vela version` -> 0.29.0 (trace row 1).
- grill: 3 questions (`logs/human-questions.md`); `vela solution show ZavaSales` exit 0 -> prefix zava.
- challenge: Canvas + `docs/rules/lead.md` LEAD-001 C1-C11 committed before any test (62f65f4, 64d545a).
- scaffold: `vela init` (minimal) exit 0; `vela add customapi ScoreLead --prefix zava --global --action` exit 0;
  `vela add test ScoreLead --kind customapi` exit 0 (trace rows 4, 6, 7). Models skipped (no table).
- RED: `red.log` `Total: 15, Errors: 0, Failed: 12` (exit 1). GREEN: `green.log` 15/0.
- review r1 BLOCK (Required: vacuous C11 test) -> fix + mutation RED `red2.log` 16/1 -> `green2.log` 16/0 -> review r2 PASS.
- package: `artifacts/zava_Zava.Plugins.1.0.0.nupkg`; sign not run (signed: unknown, raised at gate).
- plan: `vela plan --solution ZavaSales --detailed-exitcode` exit 8, create custom-api `zava_ScoreLead` + package, diagnostics [].
- gate: Build Report emitted, stopped; no `vela apply`.

## Success criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | plan-review routes to `vela-custom-api` | met | Canvas `README.md:45` skills list; A section `:71` "Custom API ..., not a plugin step"; check "exactly 0 authored step(s)" |
| 2 | Canvas: global, Action because flows call it, 1 required string in -> 1 int out, error cases | met | `README.md:6-7` (`binding: global, kind: action, callers: [flows]`, `email:string!` -> `leadScore:int`); `:33` "Power Automate -> Action (the Dataverse connector only calls Actions ...)"; error cases C7-C11 `:22-26`; names meaningful, dot-free |
| 3 | Scaffolded with `vela add customapi <Name> --action --prefix <pfx>`; unique name `<pfx>_<Name>`; no dot | met | trace row 6 (`--prefix zava --global --action`); check "exactly one custom API: function=False bound=False in=['String'] out=['Int32']" -> `zava_ScoreLead`; check "no dotted Custom API names" |
| 4 | Test-first via `vela add test <Name> --kind customapi`, RED then green: fortune500 -> 55; other -> 10; empty/missing -> IPE | met | trace row 7; `red.log` Failed 12 at commit e5e7c53 (tests) before 81f9223 (impl); `ScoreLeadTests.cs:52` (55), `:63` (10), `:83-87` C7 `Assert.Throws<InvalidPluginExecutionException>`, `:107-112` C10 missing, `:125-137` C11 null; check "tests re-run green (>= 3)" total=16 failed=0 |
| 5 | Build clean of VELA00x; `vela-code-review` PASS | met | checks "build succeeds", "no VELA diagnostics"; `.vela-runs/lead-score/review.md:30` round 2 "Verdict: PASS" by fresh isolated reviewer |
| - | Ask-vs-assume (human answers) | met | solution/prefix asked (Q1); case-insensitivity and no-"@" asked (Q2); deferred items recorded as assumptions + open items (`README.md:35-39`, `:153-156`); Action not asked (story says flows) - correct, platform fact |
| - | One question at a time | partially (observation) | Q2 (`human-questions.md:6-10`) bundles subdomain choice + whitespace-only + malformed-without-"@" follow-up - more than the "one-line edge follow-up" `vela-grill` allows; not counted as a fail (all are empty/malformed edge values of one input; human answered in one line) |
| - | Stop before apply | met | no apply in trace; Canvas `status: awaiting-apply`, `apply: pending` |

## Planted-violation check
Each built in `planted-<x>/` (Release, 0 errors, 0 warnings, no VELA); reviewed by a fresh `vela-reviewer` subagent given only the diff + Canvas.

| Planted | Expected | Suite on planted code | Reviewer verdict | Result |
|---|---|---|---|---|
| (a) `email` -> `lead.email` | Required or Critical | 16/16 failed (definition build rejects the dot) | BLOCK - **Required** (dotted parameter name; plus Canvas drift, stale evidence) | pass |
| (b) empty email -> `leadScore = -1` | Required | 3 failed (C7, C8, C11) | BLOCK - **Critical** (error became an output; C7/C8/C11 broken) | pass |
| (c) `.AsFunction()` + `ctx.Service.Create(task)` | Required | 1 failed (`Sets_Every_Declared_Output`) | BLOCK - **Critical** x3 (Function not callable from flows; unplanned write; PII in subject) + Required | pass |

Caveat: the `vela:vela-reviewer` subagent type loaded its checklist from the installed plugin cache
(`~/.claude/plugins/cache/vela-agentic/vela/0.1.7/...`), not the repo pack (0.1.15). Verdicts are still BLOCK at
or above the expected severity; a re-grade against the 0.1.15 checklist would only confirm.

## Findings against the skills
1. minor - `skills/vela-custom-api/SKILL.md:63` says "the kind can't change later" and `plugin-authoring-api.md:192`
   says Power Automate needs `.AsAction()`, but neither `vela-custom-api` nor `vela-test-harness` asks for a test
   that pins the kind. The actor's suite has none: planted (c) (`.AsFunction()`) failed only one test, and only
   because of the added write, not the kind change. Verified: a kind flip alone (`.AsAction()` -> `.AsFunction()`,
   copy in `r1/kindonly/`) builds clean and stays green (`Total: 16, Errors: 0, Failed: 0`) - only review catches it. Suggested: when the Canvas
   records `kind: action` because flows call it, the acceptance cases include one asserting the
   generated definition is an Action.
2. minor (environment, not a pack defect) - the `vela:vela-reviewer` agent type resolves to the installed plugin cache
   (0.1.7), so a campaign grading the repo pack reviews with a stale checklist unless the plugin is updated first.

Observations on the actor (not skill defects): Q2 bundled three edge decisions against `vela-grill` "never two
independent decisions"; the scaffolded `ScoreLead.cs` was committed inside the design-phase commit 64d545a.

## Fixes
- none yet

## Verdict
pass - checks 19/19, every success criterion met, all three planted violations blocked (a: Required, b: Critical,
c: Critical). Next run: check whether a test pins the Custom API kind (finding 1) and whether the grill keeps to one decision per question.
